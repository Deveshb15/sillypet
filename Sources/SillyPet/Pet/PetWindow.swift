import AppKit
import SpriteKit

class PetWindow: NSPanel {
    static let windowSize: CGFloat = 200  // Enough for sprite + speech bubble

    let skView: SKView
    let petScene: PetScene

    init(spriteType: SpriteType = .dog) {
        let size = NSSize(width: Self.windowSize, height: Self.windowSize)

        skView = SKView(frame: NSRect(origin: .zero, size: size))
        skView.allowsTransparency = true
        skView.wantsLayer = true
        skView.layer?.isOpaque = false

        petScene = PetScene(size: CGSize(width: Self.windowSize, height: Self.windowSize), spriteType: spriteType)

        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar + 1
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false  // We want clicks on the pet
        isFloatingPanel = true

        // Set up the SpriteKit view
        skView.presentScene(petScene)
        contentView = skView

        // Initial position: bottom-right area of screen
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.maxX - Self.windowSize - 100
            let y = screen.visibleFrame.minY + 50
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    // Allow click-through on transparent areas by checking if the point
    // is within the sprite region via the content view's hit test
    override var ignoresMouseEvents: Bool {
        get { false }
        set { }
    }
}
