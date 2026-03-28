import AppKit

class PetMovement {
    var position: CGPoint
    var velocity: CGVector = .zero
    var target: CGPoint?
    var speed: CGFloat = 80.0
    var facingRight: Bool = true

    private let screenPadding: CGFloat = 20.0

    init(position: CGPoint) {
        self.position = position
    }

    func update(deltaTime: CGFloat) {
        guard let target = target else { return }

        let dx = target.x - position.x
        let dy = target.y - position.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance < 8.0 {
            velocity = .zero
            self.target = nil
            return
        }

        // Update facing direction
        if abs(dx) > 2.0 {
            facingRight = dx > 0
        }

        // Normalize and apply speed with easing
        let easeFactor: CGFloat = min(1.0, distance / 100.0)  // Slow down near target
        let currentSpeed = speed * max(0.3, easeFactor)

        let nx = dx / distance
        let ny = dy / distance

        velocity = CGVector(dx: nx * currentSpeed, dy: ny * currentSpeed)
        position.x += velocity.dx * deltaTime
        position.y += velocity.dy * deltaTime

        clampToScreen()
    }

    var isMoving: Bool {
        return target != nil
    }

    var hasReachedTarget: Bool {
        return target == nil && velocity == .zero
    }

    func runTo(_ point: CGPoint) {
        target = point
        speed = 500.0
    }

    func walkTo(_ point: CGPoint) {
        target = point
        speed = 80.0
    }

    func stop() {
        target = nil
        velocity = .zero
    }

    /// Random point along the bottom edges of the screen (left or right side)
    func randomScreenTarget() -> CGPoint {
        guard let screen = NSScreen.main else {
            return CGPoint(x: 400, y: 100)
        }

        let f = screen.visibleFrame
        let y = f.minY + screenPadding + CGFloat.random(in: 0...40)

        // Stick to left or right third of the screen
        let side = Bool.random()
        let x: CGFloat
        if side {
            x = CGFloat.random(in: (f.minX + screenPadding)...(f.minX + f.width * 0.25))
        } else {
            x = CGFloat.random(in: (f.maxX - f.width * 0.25)...(f.maxX - screenPadding - 100))
        }
        return CGPoint(x: x, y: y)
    }

    /// A point on the nearest screen edge (for retreating after notifications)
    func nearestScreenEdge() -> CGPoint {
        guard let screen = NSScreen.main else {
            return CGPoint(x: 50, y: 50)
        }

        let f = screen.visibleFrame
        let y = f.minY + screenPadding

        // Pick whichever side is closer
        let distToLeft = position.x - f.minX
        let distToRight = f.maxX - position.x
        let x: CGFloat
        if distToLeft < distToRight {
            x = f.minX + screenPadding + CGFloat.random(in: 0...60)
        } else {
            x = f.maxX - screenPadding - 80 - CGFloat.random(in: 0...60)
        }
        return CGPoint(x: x, y: y)
    }

    func cursorTarget() -> CGPoint {
        let mouse = NSEvent.mouseLocation
        // Offset slightly so the pet appears next to cursor, not under it
        return CGPoint(x: mouse.x - 40, y: mouse.y - 60)
    }

    private func clampToScreen() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame

        position.x = max(frame.minX + screenPadding, min(frame.maxX - screenPadding - 80, position.x))
        position.y = max(frame.minY + screenPadding, min(frame.maxY - screenPadding - 80, position.y))
    }
}
