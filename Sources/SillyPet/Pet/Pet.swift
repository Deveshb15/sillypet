import AppKit
import SpriteKit

/// A single pet instance — owns its window, scene, state machine, and movement.
class Pet {
    let type: AgentType
    let spriteType: SpriteType
    let window: PetWindow
    let movement: PetMovement
    let stateMachine: PetStateMachine

    var scene: PetScene { window.petScene }

    private var updateTimer: Timer?
    private var lastUpdateTime: CFTimeInterval = 0
    private var followingCursor = false
    private var isDragging = false

    init(type: AgentType, spriteType: SpriteType = .dog) {
        self.type = type
        self.spriteType = spriteType
        self.window = PetWindow(spriteType: spriteType)
        self.movement = PetMovement(position: CGPoint(
            x: window.frame.origin.x,
            y: window.frame.origin.y
        ))
        self.stateMachine = PetStateMachine()

        setupStateMachineCallbacks()
        setupDragCallbacks()
        startUpdateLoop()

        window.orderFront(nil)
    }

    deinit {
        updateTimer?.invalidate()
    }

    func handleEvent(_ event: AgentEvent) {
        stateMachine.handleEvent(event)

        // Show speech bubble for certain events
        switch event.kind {
        case .permissionRequest:
            let tool = event.toolName ?? "a tool"
            let name = event.source.displayName
            scene.showBubble(text: "\(name) needs\npermission: \(tool)", duration: 8.0)

        case .taskCompleted:
            let name = event.source.displayName
            scene.showBubble(text: "\(name) is done!", duration: 4.0)

        case .error:
            let msg = event.message ?? "Something went wrong"
            scene.showBubble(text: msg, duration: 5.0)

        case .sessionStart:
            let name = event.source.displayName
            scene.showBubble(text: "\(name) started!", duration: 3.0)

        default:
            break
        }
    }

    private func setupStateMachineCallbacks() {
        stateMachine.onStateChange = { [weak self] oldState, newState in
            guard let self = self else { return }

            // Update animation
            self.scene.playAnimation(for: newState)

            // Handle state-specific behavior
            switch newState {
            case .idle:
                self.movement.stop()
                self.followingCursor = false
                self.scene.stopZzz()

            case .walking(let direction):
                // If retreating after a notification, walk to the nearest edge
                let target: CGPoint
                if self.stateMachine.retreatingToSide {
                    target = self.movement.nearestScreenEdge()
                } else {
                    target = self.movement.randomScreenTarget()
                }
                self.movement.walkTo(target)
                self.scene.setFacing(right: direction == .right)

            case .running(let target):
                self.movement.runTo(target)
                self.followingCursor = true

            case .sitting:
                self.movement.stop()
                self.followingCursor = false
                self.scene.stopZzz()

            case .sleeping:
                self.movement.stop()
                self.followingCursor = false
                self.scene.playZzz()

            case .celebrating:
                self.movement.stop()
                self.followingCursor = false
                self.scene.stopZzz()
                self.scene.playCelebration()

            case .alert:
                self.movement.stop()
                self.followingCursor = false
                self.scene.stopZzz()
            }
        }
    }

    private func setupDragCallbacks() {
        scene.onDragStart = { [weak self] in
            guard let self = self else { return }
            self.isDragging = true
            self.movement.stop()
            self.followingCursor = false
        }

        scene.onDragMove = { [weak self] newOrigin in
            guard let self = self else { return }
            self.window.setFrameOrigin(NSPoint(x: newOrigin.x, y: newOrigin.y))
            self.movement.position = newOrigin
        }

        scene.onDragEnd = { [weak self] in
            guard let self = self else { return }
            self.isDragging = false
            let quips = [
                "Ouch! Don't move me\nlike that!",
                "Hey! I was comfy\nthere!",
                "Rude. I had the\nperfect spot.",
                "Excuse me, I'm\nworking here!",
                "Wheee! Do it again!\n...wait, no.",
                "I'm not a file.\nYou can't drag me!",
                "This is NOT in my\njob description.",
                "Put me down! I have\nagents to watch!",
                "My pixels are\nall scrambled now!",
                "Was it something\nI said?",
                "I just got here\nand you move me?!",
                "Fine. This spot\nis better anyway.",
                "Warning: pet may\nbite if moved again",
                "Recalculating\nroute...",
                "You could've just\nasked nicely!",
            ]
            self.scene.showBubble(text: quips.randomElement()!, duration: 3.0)
            self.stateMachine.transition(to: .idle)
        }
    }

    private func startUpdateLoop() {
        lastUpdateTime = CACurrentMediaTime()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.update()
        }
    }

    private func update() {
        let now = CACurrentMediaTime()
        let dt = CGFloat(now - lastUpdateTime)
        lastUpdateTime = now

        // Skip movement while user is dragging the pet
        if isDragging { return }

        // Update cursor tracking for running state
        if followingCursor {
            let cursorPos = movement.cursorTarget()
            movement.target = cursorPos
        }

        // Update movement
        movement.update(deltaTime: dt)

        // Update facing direction based on movement
        scene.setFacing(right: movement.facingRight)

        // Move the window to match pet position
        window.setFrameOrigin(NSPoint(x: movement.position.x, y: movement.position.y))

        // Check if running pet reached the cursor
        if case .running = stateMachine.currentState,
           movement.hasReachedTarget {
            followingCursor = false
            if stateMachine.pendingCelebration {
                stateMachine.pendingCelebration = false
                stateMachine.transition(to: .celebrating)
            } else {
                // After permission notification: sit briefly, then retreat
                stateMachine.transition(to: .sitting)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    guard let self = self, self.stateMachine.currentState == .sitting else { return }
                    self.stateMachine.retreatingToSide = true
                    let dir: PetState.Direction = self.movement.facingRight ? .right : .left
                    self.stateMachine.transition(to: .walking(direction: dir))
                }
            }
        }

        // Check if walking pet reached its edge target (retreating)
        if case .walking = stateMachine.currentState,
           stateMachine.retreatingToSide,
           movement.hasReachedTarget {
            stateMachine.retreatingToSide = false
            if stateMachine.hasActiveSessions {
                // Tasks still running — idle and wander on the side
                stateMachine.transition(to: .idle)
            } else {
                // No tasks — go to sleep
                stateMachine.transition(to: .sleeping)
            }
        }
    }
}
