import SpriteKit

class SpeechBubble: SKNode {
    private let backgroundNode: SKShapeNode
    private let labelNode: SKLabelNode
    private let maxWidth: CGFloat = 160
    private var hideTimer: Timer?

    override init() {
        backgroundNode = SKShapeNode()
        labelNode = SKLabelNode()
        super.init()

        labelNode.fontName = "Menlo-Bold"
        labelNode.fontSize = 11
        labelNode.fontColor = .black
        labelNode.numberOfLines = 0
        labelNode.preferredMaxLayoutWidth = maxWidth - 16
        labelNode.verticalAlignmentMode = .center
        labelNode.horizontalAlignmentMode = .center

        backgroundNode.fillColor = .white
        backgroundNode.strokeColor = NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        backgroundNode.lineWidth = 2

        addChild(backgroundNode)
        addChild(labelNode)

        isHidden = true
        zPosition = 100
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(text: String, duration: TimeInterval = 4.0) {
        labelNode.text = text

        // Calculate bubble size
        let textFrame = labelNode.frame
        let bubbleWidth = max(textFrame.width + 20, 60)
        let bubbleHeight = max(textFrame.height + 16, 30)
        let bubbleRect = CGRect(
            x: -bubbleWidth / 2,
            y: -bubbleHeight / 2,
            width: bubbleWidth,
            height: bubbleHeight
        )
        backgroundNode.path = CGPath(roundedRect: bubbleRect, cornerWidth: 8, cornerHeight: 8, transform: nil)

        // Add a small triangle pointer at bottom center
        let pointerPath = CGMutablePath()
        pointerPath.addPath(CGPath(roundedRect: bubbleRect, cornerWidth: 8, cornerHeight: 8, transform: nil))
        pointerPath.move(to: CGPoint(x: -6, y: -bubbleHeight / 2))
        pointerPath.addLine(to: CGPoint(x: 0, y: -bubbleHeight / 2 - 8))
        pointerPath.addLine(to: CGPoint(x: 6, y: -bubbleHeight / 2))
        pointerPath.closeSubpath()
        backgroundNode.path = pointerPath

        isHidden = false

        // Animate in
        setScale(0.3)
        alpha = 0
        run(SKAction.group([
            SKAction.scale(to: 1.0, duration: 0.2),
            SKAction.fadeIn(withDuration: 0.2),
        ]))

        // Auto-hide
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    func hide() {
        hideTimer?.invalidate()
        run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 0.3, duration: 0.15),
                SKAction.fadeOut(withDuration: 0.15),
            ]),
            SKAction.run { [weak self] in
                self?.isHidden = true
            },
        ]))
    }
}
