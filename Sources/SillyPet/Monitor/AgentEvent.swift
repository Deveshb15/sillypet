import Foundation

enum AgentType: String, CaseIterable, Codable {
    case claude = "claude"
    case codex = "codex"

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        }
    }
}

enum AgentEventKind: String, Codable {
    case sessionStart = "session_start"
    case sessionEnd = "session_end"
    case permissionRequest = "permission_request"
    case taskCompleted = "task_completed"
    case toolUse = "tool_use"
    case error = "error"
    case working = "working"
}

struct AgentEvent: Codable {
    let source: AgentType
    let kind: AgentEventKind
    let sessionId: String?
    let message: String?
    let toolName: String?
    let timestamp: Date

    init(source: AgentType, kind: AgentEventKind, sessionId: String? = nil,
         message: String? = nil, toolName: String? = nil) {
        self.source = source
        self.kind = kind
        self.sessionId = sessionId
        self.message = message
        self.toolName = toolName
        self.timestamp = Date()
    }
}

struct AgentSession: Identifiable {
    let id: String
    let type: AgentType
    let startTime: Date
    var status: SessionStatus

    enum SessionStatus {
        case active
        case waitingForPermission(tool: String?)
        case completed
        case error(String)
        case idle

        var label: String {
            switch self {
            case .active: return "Working"
            case .waitingForPermission(let tool):
                if let tool = tool { return "Needs permission: \(tool)" }
                return "Needs permission"
            case .completed: return "Done"
            case .error(let msg): return "Error: \(msg)"
            case .idle: return "Idle"
            }
        }
    }
}
