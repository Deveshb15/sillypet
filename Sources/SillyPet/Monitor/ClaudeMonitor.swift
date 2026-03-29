import Foundation

/// Monitors Claude Code via two methods:
/// 1. Hook-based events (authoritative — permission, task completion, session lifecycle)
/// 2. JSONL transcript tailing (supplementary — working signals only)
class ClaudeMonitor: AgentMonitor {
    var onEvent: ((AgentEvent) -> Void)?

    private let eventDir = "/tmp/sillypet-events"
    private var dirFD: Int32 = -1
    private var dirSource: DispatchSourceFileSystemObject?

    private let sessionsDir: String
    private let projectsDir: String
    private var transcriptOffsets: [String: UInt64] = [:]
    private var knownSessions: Set<String> = []
    private var pollTimer: Timer?
    private var recentEventTimes: [String: Date] = [:]

    init() {
        sessionsDir = NSHomeDirectory() + "/.claude/sessions"
        projectsDir = NSHomeDirectory() + "/.claude/projects"
    }

    func start() {
        installHooksIfNeeded()
        startHookMonitor()
        startTranscriptMonitor()
        print("[ClaudeMonitor] Started (hooks + JSONL transcript monitoring)")
    }

    func stop() {
        dirSource?.cancel()
        dirSource = nil
        pollTimer?.invalidate()
        pollTimer = nil
        if dirFD >= 0 {
            close(dirFD)
            dirFD = -1
        }
    }

    // MARK: - JSONL Transcript Monitoring (working signals only)

    private func startTranscriptMonitor() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.scanActiveSessions()
        }
        scanActiveSessions()
    }

    private func scanActiveSessions() {
        let fm = FileManager.default
        guard let sessionFiles = try? fm.contentsOfDirectory(atPath: sessionsDir) else { return }

        var activeSessionIDs = Set<String>()

        for file in sessionFiles where file.hasSuffix(".json") {
            let path = "\(sessionsDir)/\(file)"
            guard let data = fm.contents(atPath: path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sessionId = json["sessionId"] as? String,
                  let cwd = json["cwd"] as? String,
                  let _ = json["pid"] as? Int else {
                continue
            }

            activeSessionIDs.insert(sessionId)

            if !knownSessions.contains(sessionId) {
                knownSessions.insert(sessionId)
                let name = json["name"] as? String
                fireEvent(.sessionStart, message: name ?? "Claude session started", sessionId: sessionId)
            }

            let encodedCwd = cwd.replacingOccurrences(of: "/", with: "-")
            let transcriptPath = "\(projectsDir)/\(encodedCwd)/\(sessionId).jsonl"

            if fm.fileExists(atPath: transcriptPath) {
                tailTranscript(transcriptPath, sessionId: sessionId)
            }
        }

        let ended = knownSessions.subtracting(activeSessionIDs)
        for sessionId in ended {
            knownSessions.remove(sessionId)
            fireEvent(.sessionEnd, message: "Claude session ended", sessionId: sessionId)
        }
    }

    private func tailTranscript(_ path: String, sessionId: String) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let fileSize = attrs[.size] as? UInt64 else { return }

        if transcriptOffsets[path] == nil {
            transcriptOffsets[path] = fileSize > 2048 ? fileSize - 2048 : 0
            return
        }

        let lastOffset = transcriptOffsets[path] ?? 0
        guard fileSize > lastOffset else { return }

        guard let handle = FileHandle(forReadingAtPath: path) else { return }
        handle.seek(toFileOffset: lastOffset)
        let newData = handle.readDataToEndOfFile()
        handle.closeFile()

        transcriptOffsets[path] = fileSize

        guard let text = String(data: newData, encoding: .utf8) else { return }

        let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }
            parseTranscriptEntry(json, sessionId: sessionId)
        }
    }

    private func parseTranscriptEntry(_ json: [String: Any], sessionId: String) {
        let type = json["type"] as? String ?? ""
        guard type == "assistant" else { return }

        let message = json["message"] as? [String: Any] ?? [:]
        let stopReason = message["stop_reason"] as? String ?? ""
        guard stopReason == "tool_use" else { return }

        let content = message["content"] as? [[String: Any]] ?? []
        let toolUse = content.first { ($0["type"] as? String) == "tool_use" }
        let toolName = toolUse?["name"] as? String
        fireEvent(.working, message: "Using \(toolName ?? "tool")", sessionId: sessionId, toolName: toolName)
    }

    // MARK: - Event Dispatch

    private func fireEvent(_ kind: AgentEventKind, message: String, sessionId: String? = nil, toolName: String? = nil) {
        let now = Date()

        recentEventTimes = recentEventTimes.filter { now.timeIntervalSince($0.value) < 10.0 }

        let key = dedupeKey(kind: kind, sessionId: sessionId, toolName: toolName, message: message)
        if let last = recentEventTimes[key], now.timeIntervalSince(last) < 3.0 {
            return
        }
        recentEventTimes[key] = now

        let event = AgentEvent(source: .claude, kind: kind, sessionId: sessionId, message: message, toolName: toolName)
        DispatchQueue.main.async { [weak self] in
            self?.onEvent?(event)
        }
    }

    private func dedupeKey(kind: AgentEventKind, sessionId: String?, toolName: String?, message: String) -> String {
        let session = sessionId ?? "unknown-session"
        switch kind {
        case .permissionRequest, .working:
            return "\(session)|\(kind.rawValue)|\(toolName ?? "unknown-tool")"
        case .taskCompleted, .error:
            return "\(session)|\(kind.rawValue)|\(message)"
        default:
            return "\(session)|\(kind.rawValue)"
        }
    }

    // MARK: - Hook-based Monitoring (authoritative)

    private func startHookMonitor() {
        try? FileManager.default.createDirectory(atPath: eventDir, withIntermediateDirectories: true)

        dirFD = open(eventDir, O_EVTONLY)
        guard dirFD >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: dirFD,
            eventMask: [.write, .rename],
            queue: .global(qos: .userInteractive)
        )

        source.setEventHandler { [weak self] in
            self?.processEventFiles()
        }

        source.setCancelHandler { [weak self] in
            guard let self = self, self.dirFD >= 0 else { return }
            close(self.dirFD)
            self.dirFD = -1
        }

        source.resume()
        dirSource = source
    }

    private func processEventFiles() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: eventDir) else { return }

        for file in files.filter({ $0.hasSuffix(".json") }).sorted() {
            let path = "\(eventDir)/\(file)"
            guard let data = fm.contents(atPath: path) else { continue }

            switch ClaudeHookParser.parse(data: data) {
            case .event(let parsed):
                fireEvent(parsed.kind, message: parsed.message, sessionId: parsed.sessionId, toolName: parsed.toolName)
                try? fm.removeItem(atPath: path)
            case .ignored:
                try? fm.removeItem(atPath: path)
            case .incomplete:
                continue
            }
        }
    }

    // MARK: - Hook Installation

    private func installHooksIfNeeded() {
        let settingsPath = NSHomeDirectory() + "/.claude/settings.json"
        let hooksDir = NSHomeDirectory() + "/.claude/hooks"
        let stableScriptPath = hooksDir + "/sillypet-hook.sh"
        let fm = FileManager.default

        try? fm.createDirectory(atPath: hooksDir, withIntermediateDirectories: true)

        let scriptContent = ClaudeHookScript.content
        try? scriptContent.write(toFile: stableScriptPath, atomically: true, encoding: .utf8)
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stableScriptPath)

        var settings: [String: Any] = [:]
        if let data = fm.contents(atPath: settingsPath),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = existing
        }

        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        let desiredHooks: [String: (arg: String, matcher: String)] = [
            "PermissionRequest": ("permission_request", ""),
            "TaskCompleted": ("task_completed", ""),
            "SessionStart": ("session_start", ""),
            "SessionEnd": ("session_end", ""),
            "Stop": ("stop", ""),
            "StopFailure": ("stop_failure", ""),
            "PreToolUse": ("pre_tool_use", "")
        ]
        let managedEvents = Set(desiredHooks.keys).union(["Notification"])

        var changed = false

        for name in managedEvents {
            let originalList = hooks[name] as? [[String: Any]] ?? []
            var filteredList = originalList.filter { !Self.isManagedSillyPetHook($0) }

            if let desired = desiredHooks[name] {
                filteredList.append(Self.makeHookEntry(command: "\(stableScriptPath) \(desired.arg)", matcher: desired.matcher))
            }

            if filteredList.isEmpty {
                if hooks[name] != nil {
                    hooks.removeValue(forKey: name)
                    changed = true
                }
            } else {
                hooks[name] = filteredList
                if !NSArray(array: originalList).isEqual(to: filteredList) {
                    changed = true
                }
            }
        }

        if changed {
            settings["hooks"] = hooks
            if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
                let settingsURL = URL(fileURLWithPath: settingsPath)
                try? data.write(to: settingsURL, options: .atomic)
                print("[ClaudeMonitor] Hooks updated in \(settingsPath) (script at \(stableScriptPath))")
            }
        }
    }

    private static func isManagedSillyPetHook(_ entry: [String: Any]) -> Bool {
        let hookCommands = entry["hooks"] as? [[String: Any]] ?? []
        return hookCommands.contains { ($0["command"] as? String)?.contains("sillypet-hook.sh") == true }
    }

    private static func makeHookEntry(command: String, matcher: String) -> [String: Any] {
        [
            "matcher": matcher,
            "hooks": [["type": "command", "command": command]]
        ]
    }
}

struct ClaudeHookScript {
    static let content = """
    #!/bin/bash
    EVENT_TYPE="$1"
    EVENT_DIR="/tmp/sillypet-events"
    mkdir -p "$EVENT_DIR"
    INPUT=""
    if [ ! -t 0 ]; then INPUT=$(cat); fi
    if [ -z "$INPUT" ]; then INPUT="{}"; fi
    TIMESTAMP=$(date +%s%N 2>/dev/null || date +%s)
    TEMP_FILE="$EVENT_DIR/.${TIMESTAMP}_${EVENT_TYPE}.json.tmp"
    EVENT_FILE="$EVENT_DIR/${TIMESTAMP}_${EVENT_TYPE}.json"
    printf '{"source":"claude","type":"%s","data":%s,"ts":"%s"}' "$EVENT_TYPE" "$INPUT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$EVENT_FILE"
    exit 0
    """
}

struct ParsedClaudeHookEvent: Equatable {
    let kind: AgentEventKind
    let sessionId: String?
    let message: String
    let toolName: String?
}

enum ClaudeHookParseResult: Equatable {
    case event(ParsedClaudeHookEvent)
    case ignored
    case incomplete
}

struct ClaudeHookParser {
    static func parse(data: Data) -> ClaudeHookParseResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return .incomplete
        }

        let hookData = json["data"] as? [String: Any] ?? [:]
        let sessionId = hookData["session_id"] as? String

        switch type {
        case "permission_request":
            let toolName = hookData["tool_name"] as? String
            let message = firstNonEmptyString(
                hookData["message"] as? String,
                hookData["title"] as? String,
                toolName.map { "Claude needs permission for \($0)" },
                "Claude needs permission"
            )
            return .event(ParsedClaudeHookEvent(
                kind: .permissionRequest,
                sessionId: sessionId,
                message: message,
                toolName: toolName
            ))

        case "notification":
            let notificationType = hookData["notification_type"] as? String
            if notificationType == "idle_prompt" {
                return .ignored
            }
            return .ignored

        case "task_completed":
            let teammate = hookData["teammate_name"] as? String
            let subject = firstNonEmptyString(
                hookData["task_subject"] as? String,
                hookData["task_description"] as? String,
                "Task completed"
            )
            let message: String
            if let teammate, !teammate.isEmpty {
                message = "\(teammate) completed: \(subject)"
            } else {
                message = subject
            }
            return .event(ParsedClaudeHookEvent(
                kind: .taskCompleted,
                sessionId: sessionId,
                message: message,
                toolName: nil
            ))

        case "session_start":
            return .event(ParsedClaudeHookEvent(
                kind: .sessionStart,
                sessionId: sessionId,
                message: "Session started",
                toolName: nil
            ))

        case "session_end":
            return .event(ParsedClaudeHookEvent(
                kind: .sessionEnd,
                sessionId: sessionId,
                message: "Session ended",
                toolName: nil
            ))

        case "pre_tool_use":
            let toolName = hookData["tool_name"] as? String
            return .event(ParsedClaudeHookEvent(
                kind: .working,
                sessionId: sessionId,
                message: "Using \(toolName ?? "tool")",
                toolName: toolName
            ))

        case "stop":
            let message = firstNonEmptyString(
                hookData["last_assistant_message"] as? String,
                "Task completed"
            )
            return .event(ParsedClaudeHookEvent(
                kind: .taskCompleted,
                sessionId: sessionId,
                message: message,
                toolName: nil
            ))

        case "stop_failure":
            let message = firstNonEmptyString(
                hookData["last_assistant_message"] as? String,
                hookData["error_details"] as? String,
                hookData["error"] as? String,
                "Claude stopped with an error"
            )
            return .event(ParsedClaudeHookEvent(
                kind: .error,
                sessionId: sessionId,
                message: message,
                toolName: nil
            ))

        default:
            return .ignored
        }
    }

    private static func firstNonEmptyString(_ candidates: String?...) -> String {
        for candidate in candidates {
            let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return ""
    }
}
