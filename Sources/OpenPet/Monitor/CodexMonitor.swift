import Foundation

/// Monitors OpenAI Codex by watching session JSONL files in ~/.codex/sessions/
class CodexMonitor: AgentMonitor {
    var onEvent: ((AgentEvent) -> Void)?

    private let sessionsDir: String
    private var source: DispatchSourceFileSystemObject?
    private var dirFD: Int32 = -1
    private var watchedFiles: [String: UInt64] = [:]  // path -> last read offset
    private var pollTimer: Timer?

    init() {
        sessionsDir = NSHomeDirectory() + "/.codex/sessions"
    }

    func start() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: sessionsDir) else {
            print("[CodexMonitor] Codex sessions directory not found, polling...")
            startPolling()
            return
        }

        watchDirectory()
    }

    func stop() {
        source?.cancel()
        source = nil
        pollTimer?.invalidate()
        pollTimer = nil
        if dirFD >= 0 { close(dirFD) }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let fm = FileManager.default
            if fm.fileExists(atPath: self.sessionsDir) {
                self.pollTimer?.invalidate()
                self.watchDirectory()
            }
        }
    }

    private func watchDirectory() {
        // Watch the sessions directory recursively using a timer
        // (FSEvents would be better but DispatchSource works for our case)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.scanForNewEvents()
        }
    }

    private func scanForNewEvents() {
        // Find today's session directory
        let fm = FileManager.default
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        let todayPath = "\(sessionsDir)/\(dateFormatter.string(from: Date()))"

        guard fm.fileExists(atPath: todayPath) else { return }

        guard let files = try? fm.contentsOfDirectory(atPath: todayPath) else { return }
        let jsonlFiles = files.filter { $0.hasSuffix(".jsonl") }

        for file in jsonlFiles {
            let path = "\(todayPath)/\(file)"
            tailFile(path)
        }
    }

    private func tailFile(_ path: String) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let fileSize = attrs[.size] as? UInt64 else { return }

        // First time seeing this file: skip to end so we only get new events
        if watchedFiles[path] == nil {
            watchedFiles[path] = fileSize
            return
        }

        let lastOffset = watchedFiles[path] ?? 0

        guard fileSize > lastOffset else { return }

        guard let handle = FileHandle(forReadingAtPath: path) else { return }
        handle.seek(toFileOffset: lastOffset)

        let newData = handle.readDataToEndOfFile()
        handle.closeFile()

        watchedFiles[path] = fileSize

        guard let text = String(data: newData, encoding: .utf8) else { return }

        let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }

        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            if let event = parseCodexEvent(json) {
                DispatchQueue.main.async { [weak self] in
                    self?.onEvent?(event)
                }
            }
        }
    }

    private func parseCodexEvent(_ json: [String: Any]) -> AgentEvent? {
        let type = json["type"] as? String ?? ""
        // Codex JSONL uses "payload" as the data key
        let payload = json["payload"] as? [String: Any] ?? [:]

        // Handle event_msg type
        if type == "event_msg" {
            let msgType = payload["type"] as? String ?? ""

            switch msgType {
            case "task_started":
                return AgentEvent(source: .codex, kind: .sessionStart, message: "Codex started working")

            case "task_complete":
                let lastMessage = payload["last_agent_message"] as? String
                return AgentEvent(source: .codex, kind: .taskCompleted, message: lastMessage ?? "Task complete")

            case "turn_aborted":
                let reason = payload["reason"] as? String
                return AgentEvent(source: .codex, kind: .error, message: reason ?? "Turn aborted")

            case "agent_message":
                return AgentEvent(source: .codex, kind: .working, message: "Codex is responding")

            case "user_message":
                return AgentEvent(source: .codex, kind: .working, message: "Codex received prompt")

            default:
                return nil
            }
        }

        // Handle response_item type (function calls = tool use)
        if type == "response_item" {
            let itemType = payload["type"] as? String ?? ""

            if itemType == "function_call" {
                let name = payload["name"] as? String
                return AgentEvent(source: .codex, kind: .toolUse, toolName: name)
            }
        }

        // Handle session_meta (first event in a session file)
        if type == "session_meta" {
            return AgentEvent(source: .codex, kind: .sessionStart, message: "Codex session started")
        }

        // Handle turn_context (new turn started)
        if type == "turn_context" {
            return AgentEvent(source: .codex, kind: .working, message: "Codex is thinking")
        }

        return nil
    }
}
