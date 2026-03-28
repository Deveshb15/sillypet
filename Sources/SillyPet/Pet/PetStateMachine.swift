import AppKit

enum PetState: Equatable {
    case idle
    case walking(direction: Direction)
    case running(target: CGPoint)
    case sitting
    case sleeping
    case celebrating
    case alert

    enum Direction: Equatable {
        case left, right
    }

    static func == (lhs: PetState, rhs: PetState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.sitting, .sitting), (.sleeping, .sleeping),
             (.celebrating, .celebrating), (.alert, .alert):
            return true
        case (.walking(let a), .walking(let b)):
            return a == b
        case (.running(let a), .running(let b)):
            return a == b
        default:
            return false
        }
    }

    var animationKey: String {
        switch self {
        case .idle: return "idle"
        case .walking: return "walk"
        case .running: return "run"
        case .sitting: return "sit"
        case .sleeping: return "sleep"
        case .celebrating: return "celebrate"
        case .alert: return "alert"
        }
    }

    var frameRate: TimeInterval {
        switch self {
        case .idle: return 0.5
        case .walking: return 0.15
        case .running: return 0.08
        case .sitting: return 0.6
        case .sleeping: return 0.8
        case .celebrating: return 0.12
        case .alert: return 0.2
        }
    }
}

class PetStateMachine {
    private(set) var currentState: PetState = .idle
    var onStateChange: ((PetState, PetState) -> Void)?

    private var idleTimer: Timer?
    private var wanderTimer: Timer?
    private var celebrateTimer: Timer?
    var pendingCelebration = false
    var retreatingToSide = false
    var hasActiveSessions = false

    func transition(to newState: PetState) {
        let oldState = currentState
        guard oldState != newState else { return }
        currentState = newState
        cancelTimers()
        onStateChange?(oldState, newState)

        switch newState {
        case .idle:
            scheduleWander()
        case .celebrating:
            scheduleCelebrateEnd()
        case .alert:
            // Alert auto-transitions to running after a brief pause
            break
        default:
            break
        }
    }

    func handleEvent(_ event: AgentEvent) {
        switch event.kind {
        case .permissionRequest:
            transition(to: .alert)
            // After 0.5s alert animation, run to cursor
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard self?.currentState == .alert else { return }
                let mousePos = Self.mouseLocation()
                self?.transition(to: .running(target: mousePos))
            }

        case .taskCompleted:
            // Run to cursor first, then celebrate on arrival
            transition(to: .alert)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard self?.currentState == .alert else { return }
                let mousePos = Self.mouseLocation()
                self?.transition(to: .running(target: mousePos))
                self?.pendingCelebration = true
            }

        case .sessionStart, .working:
            if currentState == .idle || currentState == .sleeping {
                transition(to: .sitting)
            }

        case .sessionEnd:
            transition(to: .idle)

        case .error:
            transition(to: .alert)

        case .toolUse:
            break
        }
    }

    private func scheduleWander() {
        wanderTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 3...8), repeats: false) { [weak self] _ in
            guard self?.currentState == .idle else { return }
            let direction: PetState.Direction = Bool.random() ? .left : .right
            self?.transition(to: .walking(direction: direction))

            // Walk for 2-4 seconds, then back to idle
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 2...4)) { [weak self] in
                guard case .walking = self?.currentState else { return }
                self?.transition(to: .idle)
            }
        }
    }

    private func scheduleCelebrateEnd() {
        celebrateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            // Walk to the nearest screen edge, then sleep or idle
            self.retreatingToSide = true
            let direction: PetState.Direction = Bool.random() ? .left : .right
            self.transition(to: .walking(direction: direction))
        }
    }

    private func cancelTimers() {
        idleTimer?.invalidate()
        wanderTimer?.invalidate()
        celebrateTimer?.invalidate()
    }

    private static func mouseLocation() -> CGPoint {
        return NSEvent.mouseLocation
    }
}
