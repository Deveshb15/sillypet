import Foundation

/// Monitors Claude Code via two methods:
/// 1. JSONL transcript tailing (works immediately for all sessions)
/// 2. Hook-based events (works after session restart, more precise)
class ClaudeMonitor: AgentMonitor {
    var onEvent: ((AgentEvent) -> Void)?

    // Hook-based monitoring
    private let eventDir = "/tmp/sillypet-events"
    private var dirFD: Int32 = -1
    private var dirSource: DispatchSourceFileSystemObject?

    // JSONL transcript monitoring
    private let sessionsDir: String
    private let projectsDir: String
    private var transcriptOffsets: [String: UInt64] = [:]  // path -> last read offset
    private var knownSessions: Set<String> = []
    private var pollTimer: Timer?

    // Permission detection: when stop_reason=tool_use appears and no new
    // transcript activity follows within 4 seconds, fire permissionRequest
    private var pendingPermissions: [String: (timer: Timer, toolName: String?)] = [:]

    // Debounce: don't fire duplicate events too quickly
    private var lastEventKind: AgentEventKind?
    private var lastEventTime: Date = .distantPast

    init() {
        sessionsDir = NSHomeDirectory() + "/.claude/sessions"
        projectsDir = NSHomeDirectory() + "/.claude/projects"
    }

    func start() {
        startHookMonitor()
        startTranscriptMonitor()
        installHooksIfNeeded()
        print("[ClaudeMonitor] Started (hooks + JSONL transcript monitoring)")
    }

    func stop() {
        dirSource?.cancel()
        dirSource = nil
        pollTimer?.invalidate()
        pollTimer = nil
        for (_, pending) in pendingPermissions { pending.timer.invalidate() }
        pendingPermissions.removeAll()
        if dirFD >= 0 { close(dirFD); dirFD = -1 }
    }

    // MARK: - JSONL Transcript Monitoring

    private func startTranscriptMonitor() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.scanActiveSessions()
        }
        scanActiveSessions()
    }

    private func scanActiveSessions() {
        let fm = FileManager.default
        guard let sessionFiles = try? fm.contentsOfDirectory(atPath: sessionsDir) else { return }

        var activePIDs = Set<String>()

        for file in sessionFiles where file.hasSuffix(".json") {
            let path = "\(sessionsDir)/\(file)"
            guard let data = fm.contents(atPath: path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sessionId = json["sessionId"] as? String,
                  let cwd = json["cwd"] as? String,
                  let pid = json["pid"] as? Int else {
                continue
            }

            activePIDs.insert(sessionId)

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

        let ended = knownSessions.subtracting(activePIDs)
        for sessionId in ended {
            knownSessions.remove(sessionId)
            cancelPermissionTimer(sessionId: sessionId)
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

        let lastOffset = transcriptOffsets[path]!
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

            // Any new transcript entry means the session is progressing.
            // If a tool_use was pending permission, the tool was auto-approved.
            cancelPermissionTimer(sessionId: sessionId)

            parseTranscriptEntry(json, sessionId: sessionId)
        }
    }

    private func parseTranscriptEntry(_ json: [String: Any], sessionId: String) {
        let type = json["type"] as? String ?? ""

        guard type == "assistant" else { return }

        let message = json["message"] as? [String: Any] ?? [:]
        let stopReason = message["stop_reason"] as? String ?? ""

        switch stopReason {
        case "end_turn":
            fireEvent(.taskCompleted, message: "Claude finished", sessionId: sessionId)

        case "tool_use":
            let content = message["content"] as? [[String: Any]] ?? []
            let toolUse = content.first { ($0["type"] as? String) == "tool_use" }
            let toolName = toolUse?["name"] as? String

            fireEvent(.working, message: "Using \(toolName ?? "tool")", sessionId: sessionId, toolName: toolName)

            // Start permission detection: if no new transcript activity within
            // 4 seconds, the tool likely needs user permission
            startPermissionTimer(sessionId: sessionId, toolName: toolName)

        default:
            break
        }
    }

    // MARK: - Permission Detection Timer

    private func startPermissionTimer(sessionId: String, toolName: String?) {
        cancelPermissionTimer(sessionId: sessionId)

        let timer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.pendingPermissions.removeValue(forKey: sessionId)
            self.fireEvent(.permissionRequest,
                          message: "Needs permission for \(toolName ?? "tool")",
                          sessionId: sessionId, toolName: toolName)
        }
        pendingPermissions[sessionId] = (timer: timer, toolName: toolName)
    }

    private func cancelPermissionTimer(sessionId: String) {
        if let pending = pendingPermissions.removeValue(forKey: sessionId) {
            pending.timer.invalidate()
        }
    }

    // MARK: - Event Dispatch

    private func fireEvent(_ kind: AgentEventKind, message: String, sessionId: String? = nil, toolName: String? = nil) {
        let now = Date()
        if kind == lastEventKind && now.timeIntervalSince(lastEventTime) < 3.0 {
            return
        }
        lastEventKind = kind
        lastEventTime = now

        let event = AgentEvent(source: .claude, kind: kind, sessionId: sessionId, message: message, toolName: toolName)
        DispatchQueue.main.async { [weak self] in
            self?.onEvent?(event)
        }
    }

    // MARK: - Hook-based Monitoring (supplementary)

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
            if let fd = self?.dirFD, fd >= 0 { close(fd) }
        }

        source.resume()
        self.dirSource = source
    }

    private func processEventFiles() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: eventDir) else { return }

        for file in files.filter({ $0.hasSuffix(".json") }).sorted() {
            let path = "\(eventDir)/\(file)"
            guard let data = fm.contents(atPath: path) else { continue }

            if let event = parseHookEvent(data) {
                DispatchQueue.main.async { [weak self] in
                    self?.onEvent?(event)
                }
            }
            try? fm.removeItem(atPath: path)
        }
    }

    private func parseHookEvent(_ data: Data) -> AgentEvent? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let typeStr = json["type"] as? String else { return nil }

        let hookData = json["data"] as? [String: Any] ?? [:]
        let sessionId = hookData["session_id"] as? String

        switch typeStr {
        case "notification":
            // Notification hook — check for permission/idle prompts
            let nt = hookData["notification_type"] as? String
            let title = hookData["title"] as? String ?? ""
            let body = hookData["body"] as? String ?? ""
            // Match permission_prompt, idle_prompt, or notification text about permissions
            if nt == "permission_prompt" || nt == "idle_prompt"
                || title.lowercased().contains("permission")
                || body.lowercased().contains("permission")
                || title.lowercased().contains("waiting")
                || body.lowercased().contains("proceed") {
                return AgentEvent(source: .claude, kind: .permissionRequest, sessionId: sessionId,
                                  message: hookData["message"] as? String ?? body,
                                  toolName: hookData["tool_name"] as? String)
            }
            return nil

        case "task_completed":
            return AgentEvent(source: .claude, kind: .taskCompleted, sessionId: sessionId,
                              message: hookData["task_subject"] as? String ?? "Task completed")

        case "session_start":
            return AgentEvent(source: .claude, kind: .sessionStart, sessionId: sessionId, message: "Session started")

        case "session_end":
            return AgentEvent(source: .claude, kind: .sessionEnd, sessionId: sessionId, message: "Session ended")

        case "stop":
            // Stop hook fires when the model's turn ends.
            // If it contains tool_use content, permission is needed.
            let stopReason = hookData["stop_reason"] as? String
            let message = hookData["message"] as? [String: Any]
            let content = (message?["content"] as? [[String: Any]])
                ?? (hookData["content"] as? [[String: Any]])
                ?? []
            let toolUse = content.first { ($0["type"] as? String) == "tool_use" }

            if stopReason == "tool_use" || toolUse != nil {
                let toolName = toolUse?["name"] as? String
                return AgentEvent(source: .claude, kind: .permissionRequest, sessionId: sessionId,
                                  message: "Permission needed for \(toolName ?? "tool")",
                                  toolName: toolName)
            }
            // Non-tool stop is just the model finishing — not a session end
            return nil

        case "pre_tool_use":
            // PreToolUse fires for all tools — treat as working signal
            let toolName = hookData["tool_name"] as? String
            return AgentEvent(source: .claude, kind: .working, sessionId: sessionId,
                              message: "Using \(toolName ?? "tool")", toolName: toolName)

        default:
            return nil
        }
    }

    // MARK: - Hook Installation

    private func installHooksIfNeeded() {
        let settingsPath = NSHomeDirectory() + "/.claude/settings.json"
        let hooksDir = NSHomeDirectory() + "/.claude/hooks"
        let stableScriptPath = hooksDir + "/sillypet-hook.sh"
        let fm = FileManager.default

        // Always install/update the hook script at a stable location
        try? fm.createDirectory(atPath: hooksDir, withIntermediateDirectories: true)

        let scriptContent = """
        #!/bin/bash
        EVENT_TYPE="$1"
        EVENT_DIR="/tmp/sillypet-events"
        mkdir -p "$EVENT_DIR"
        INPUT=""
        if [ ! -t 0 ]; then INPUT=$(cat); fi
        if [ -z "$INPUT" ]; then INPUT="{}"; fi
        TIMESTAMP=$(date +%s%N 2>/dev/null || date +%s)
        EVENT_FILE="$EVENT_DIR/${TIMESTAMP}_${EVENT_TYPE}.json"
        printf '{"source":"claude","type":"%s","data":%s,"ts":"%s"}' "$EVENT_TYPE" "$INPUT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$EVENT_FILE"
        exit 0
        """
        try? scriptContent.write(toFile: stableScriptPath, atomically: true, encoding: .utf8)
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stableScriptPath)

        // Read current settings
        var settings: [String: Any] = [:]
        if let data = fm.contents(atPath: settingsPath),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = existing
        }

        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        let events: [(String, String)] = [
            ("Notification", "notification"),
            ("TaskCompleted", "task_completed"),
            ("SessionStart", "session_start"),
            ("SessionEnd", "session_end"),
            ("Stop", "stop"),
            ("PreToolUse", "pre_tool_use"),
        ]

        var changed = false
        for (name, arg) in events {
            var list = hooks[name] as? [[String: Any]] ?? []
            let correctCommand = "\(stableScriptPath) \(arg)"

            // Find existing sillypet hook entry
            let existingIdx = list.firstIndex { e in
                (e["hooks"] as? [[String: Any]] ?? []).contains { ($0["command"] as? String)?.contains("sillypet") == true }
            }

            let entry: [String: Any] = [
                "matcher": [String: Any](),
                "hooks": [["type": "command", "command": correctCommand]]
            ]

            if let idx = existingIdx {
                // Check if path is correct; update if stale
                let existingHooks = list[idx]["hooks"] as? [[String: Any]] ?? []
                let existingCommand = existingHooks.first?["command"] as? String ?? ""
                if existingCommand != correctCommand {
                    list[idx] = entry
                    hooks[name] = list
                    changed = true
                }
            } else {
                list.append(entry)
                hooks[name] = list
                changed = true
            }
        }

        if changed {
            settings["hooks"] = hooks
            if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
                fm.createFile(atPath: settingsPath, contents: data)
                print("[ClaudeMonitor] Hooks updated in \(settingsPath) (script at \(stableScriptPath))")
            }
        }
    }
}
