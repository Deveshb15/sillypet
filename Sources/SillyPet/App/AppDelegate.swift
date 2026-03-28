import AppKit
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    static var shared: AppDelegate!

    @Published var pets: [Pet] = []
    @Published var sessions: [AgentSession] = []
    @Published var eventLog: [String] = []

    private var claudeMonitor: ClaudeMonitor?
    private var codexMonitor: CodexMonitor?

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Spawn the default pet
        let pet = Pet(type: .claude)
        pets.append(pet)

        // Start monitors
        startMonitors()

        print("[SillyPet] Running! Your Shiba Inu is now on screen.")
    }

    func applicationWillTerminate(_ notification: Notification) {
        claudeMonitor?.stop()
        codexMonitor?.stop()
    }

    private func startMonitors() {
        // Claude Code monitor
        claudeMonitor = ClaudeMonitor()
        claudeMonitor?.onEvent = { [weak self] event in
            self?.handleEvent(event)
        }
        claudeMonitor?.start()

        // Codex monitor
        codexMonitor = CodexMonitor()
        codexMonitor?.onEvent = { [weak self] event in
            self?.handleEvent(event)
        }
        codexMonitor?.start()
    }

    private func handleEvent(_ event: AgentEvent) {
        // Log it
        let logEntry = "[\(event.source.displayName)] \(event.kind.rawValue): \(event.message ?? "")"
        eventLog.append(logEntry)
        if eventLog.count > 50 { eventLog.removeFirst() }

        print("[SillyPet] \(logEntry)")

        // Update session tracking
        updateSession(for: event)

        // Tell pets whether there are active sessions
        let active = sessions.contains { s in
            if case .active = s.status { return true }
            if case .waitingForPermission = s.status { return true }
            return false
        }
        for pet in pets {
            pet.stateMachine.hasActiveSessions = active
        }

        // Route to appropriate pet(s)
        // For MVP: all events go to the first pet
        if let pet = pets.first {
            pet.handleEvent(event)
        }

        // Play sound for important events
        if event.kind == .permissionRequest || event.kind == .taskCompleted {
            playNotificationSound(for: event.kind)
        }
    }

    private func updateSession(for event: AgentEvent) {
        switch event.kind {
        case .sessionStart:
            let session = AgentSession(
                id: event.sessionId ?? UUID().uuidString,
                type: event.source,
                startTime: event.timestamp,
                status: .active
            )
            sessions.append(session)

        case .sessionEnd:
            if let idx = sessions.lastIndex(where: { $0.type == event.source && $0.status.label == "Working" }) {
                sessions[idx].status = .idle
            }

        case .permissionRequest:
            if let idx = sessions.lastIndex(where: { $0.type == event.source }) {
                sessions[idx].status = .waitingForPermission(tool: event.toolName)
            }

        case .taskCompleted:
            if let idx = sessions.lastIndex(where: { $0.type == event.source }) {
                sessions[idx].status = .completed
            }

        case .error:
            if let idx = sessions.lastIndex(where: { $0.type == event.source }) {
                sessions[idx].status = .error(event.message ?? "Unknown error")
            }

        default:
            break
        }
    }

    private func playNotificationSound(for kind: AgentEventKind) {
        switch kind {
        case .permissionRequest:
            NSSound(named: "Funk")?.play()
        case .taskCompleted:
            NSSound(named: "Glass")?.play()
        default:
            break
        }
    }

    // MARK: - Public Actions

    func testPermissionAlert() {
        let event = AgentEvent(
            source: .claude,
            kind: .permissionRequest,
            message: "Test permission request",
            toolName: "Bash"
        )
        handleEvent(event)
    }

    func testTaskComplete() {
        let event = AgentEvent(
            source: .claude,
            kind: .taskCompleted,
            message: "Test task completed"
        )
        handleEvent(event)
    }

    func testSessionStart() {
        let event = AgentEvent(
            source: .claude,
            kind: .sessionStart,
            sessionId: "test-\(UUID().uuidString.prefix(8))",
            message: "Test session"
        )
        handleEvent(event)
    }
}
