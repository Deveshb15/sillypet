import Foundation

/// Monitors Claude Code via two methods:
/// 1. JSONL transcript tailing (works immediately for all sessions)
/// 2. Hook-based events (works after session restart, more precise)
class ClaudeMonitor: AgentMonitor {
    var onEvent: ((AgentEvent) -> Void)?

    // Hook-based monitoring
    private let eventDir = "/tmp/openpet-events"
    private var dirFD: Int32 = -1
    private var dirSource: DispatchSourceFileSystemObject?

    // JSONL transcript monitoring
    private let sessionsDir: String
    private let projectsDir: String
    private var transcriptOffsets: [String: UInt64] = [:]  // path -> last read offset
    private var knownSessions: Set<String> = []
    private var pollTimer: Timer?

    // Debounce: don't fire duplicate events too quickly
    private var lastEventKind: AgentEventKind?
    private var lastEventTime: Date = .distantPast

    init() {
        sessionsDir = NSHomeDirectory() + "/.claude/sessions"
        projectsDir = NSHomeDirectory() + "/.claude/projects"
    }

    func start() {
        // 1. Start hook-based monitoring
        startHookMonitor()

        // 2. Start JSONL transcript monitoring (the reliable method)
        startTranscriptMonitor()

        // 3. Install hooks for future sessions
        installHooksIfNeeded()

        print("[ClaudeMonitor] Started (hooks + JSONL transcript monitoring)")
    }

    func stop() {
        dirSource?.cancel()
        dirSource = nil
        pollTimer?.invalidate()
        pollTimer = nil
        if dirFD >= 0 { close(dirFD); dirFD = -1 }
    }

    // MARK: - JSONL Transcript Monitoring

    private func startTranscriptMonitor() {
        // Poll every 2 seconds: check active sessions and tail their transcripts
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.scanActiveSessions()
        }
        // Initial scan
        scanActiveSessions()
    }

    private func scanActiveSessions() {
        let fm = FileManager.default

        // Read active session files from ~/.claude/sessions/*.json
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

            // Detect new sessions
            if !knownSessions.contains(sessionId) {
                knownSessions.insert(sessionId)
                let name = json["name"] as? String
                fireEvent(.sessionStart, message: name ?? "Claude session started", sessionId: sessionId)
            }

            // Find the transcript JSONL for this session
            let encodedCwd = cwd.replacingOccurrences(of: "/", with: "-")
            let transcriptPath = "\(projectsDir)/\(encodedCwd)/\(sessionId).jsonl"

            if fm.fileExists(atPath: transcriptPath) {
                tailTranscript(transcriptPath, sessionId: sessionId)
            }
        }

        // Detect ended sessions
        let ended = knownSessions.subtracting(activePIDs)
        for sessionId in ended {
            knownSessions.remove(sessionId)
            fireEvent(.sessionEnd, message: "Claude session ended", sessionId: sessionId)
        }
    }

    private func tailTranscript(_ path: String, sessionId: String) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let fileSize = attrs[.size] as? UInt64 else { return }

        // First time: skip to near the end (last 2KB) to avoid replaying history
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

            parseTranscriptEntry(json, sessionId: sessionId)
        }
    }

    private func parseTranscriptEntry(_ json: [String: Any], sessionId: String) {
        let type = json["type"] as? String ?? ""

        guard type == "assistant" else { return }

        // Get stop_reason from the message object
        let message = json["message"] as? [String: Any] ?? [:]
        let stopReason = message["stop_reason"] as? String ?? ""

        switch stopReason {
        case "end_turn":
            // Claude finished responding — task is done, waiting for user input
            fireEvent(.taskCompleted, message: "Claude finished", sessionId: sessionId)

        case "tool_use":
            // Claude wants to use a tool — might be asking for permission
            // Extract tool name from content
            let content = message["content"] as? [[String: Any]] ?? []
            let toolUse = content.first { ($0["type"] as? String) == "tool_use" }
            let toolName = toolUse?["name"] as? String

            fireEvent(.working, message: "Using \(toolName ?? "tool")", sessionId: sessionId, toolName: toolName)

        default:
            break
        }
    }

    private func fireEvent(_ kind: AgentEventKind, message: String, sessionId: String? = nil, toolName: String? = nil) {
        // Debounce: don't fire the same event type within 3 seconds
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
            let nt = hookData["notification_type"] as? String
            if nt == "permission_prompt" || nt == "idle_prompt" {
                return AgentEvent(source: .claude, kind: .permissionRequest, sessionId: sessionId,
                                  message: hookData["message"] as? String ?? "Permission needed",
                                  toolName: hookData["tool_name"] as? String)
            }
            return nil

        case "task_completed":
            return AgentEvent(source: .claude, kind: .taskCompleted, sessionId: sessionId,
                              message: hookData["task_subject"] as? String ?? "Task completed")

        case "session_start":
            return AgentEvent(source: .claude, kind: .sessionStart, sessionId: sessionId, message: "Session started")

        case "session_end", "stop":
            return AgentEvent(source: .claude, kind: .sessionEnd, sessionId: sessionId, message: "Session ended")

        default:
            return nil
        }
    }

    // MARK: - Hook Installation (for future sessions)

    private func installHooksIfNeeded() {
        let settingsPath = NSHomeDirectory() + "/.claude/settings.json"
        let fm = FileManager.default

        var settings: [String: Any] = [:]
        if let data = fm.contents(atPath: settingsPath),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = existing
        }

        let hookScript = Bundle.main.resourcePath.map { "\($0)/openpet-hook.sh" }
            ?? "\(eventDir)/../openpet-hook.sh"

        let makeEntry: (String) -> [String: Any] = { arg in
            ["matcher": [String: Any](), "hooks": [["type": "command", "command": "\(hookScript) \(arg)"]]] as [String: Any]
        }

        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        let events: [(String, String)] = [
            ("Notification", "notification"),
            ("TaskCompleted", "task_completed"),
            ("SessionStart", "session_start"),
            ("SessionEnd", "session_end"),
            ("Stop", "stop"),
        ]

        var changed = false
        for (name, arg) in events {
            var list = hooks[name] as? [[String: Any]] ?? []
            let installed = list.contains { e in
                (e["hooks"] as? [[String: Any]] ?? []).contains { ($0["command"] as? String)?.contains("openpet") == true }
            }
            if !installed {
                list.append(makeEntry(arg))
                hooks[name] = list
                changed = true
            }
        }

        if changed {
            settings["hooks"] = hooks
            if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
                try? fm.createDirectory(atPath: NSHomeDirectory() + "/.claude", withIntermediateDirectories: true)
                fm.createFile(atPath: settingsPath, contents: data)
                print("[ClaudeMonitor] Hooks updated in \(settingsPath)")
            }
        }
    }
}
