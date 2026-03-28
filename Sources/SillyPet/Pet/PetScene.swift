import SpriteKit

class PetScene: SKScene {
    let petSprite: SKSpriteNode
    let speechBubble: SpeechBubble
    let spriteType: SpriteType
    private var currentAnimationKey: String = ""
    private var confettiEmitter: SKEmitterNode?

    // Drag callbacks
    var onDragStart: (() -> Void)?
    var onDragMove: ((CGPoint) -> Void)?
    var onDragEnd: (() -> Void)?
    private var isDragging = false
    private var dragOffset: CGPoint = .zero

    init(size: CGSize, spriteType: SpriteType) {
        self.spriteType = spriteType
        // Create sprite with first idle frame
        let initialTexture = PetSprites.texturesForState(.idle, spriteType: spriteType).first!
        petSprite = SKSpriteNode(texture: initialTexture)
        petSprite.setScale(1.0)
        speechBubble = SpeechBubble()

        super.init(size: size)

        backgroundColor = .clear
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        // Position sprite at bottom center of scene
        let spriteHeight = CGFloat(PetSprites.spriteSize * PetSprites.pixelScale)
        petSprite.position = CGPoint(x: size.width / 2, y: spriteHeight / 2 + 10)
        petSprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        addChild(petSprite)

        // Position speech bubble above sprite
        speechBubble.position = CGPoint(x: size.width / 2, y: spriteHeight + 40)
        addChild(speechBubble)

        playAnimation(for: .idle)
    }

    func playAnimation(for state: PetState) {
        let key = state.animationKey
        guard key != currentAnimationKey else { return }
        currentAnimationKey = key

        petSprite.removeAction(forKey: "animation")

        let textures = PetSprites.texturesForState(state, spriteType: spriteType)
        guard !textures.isEmpty else { return }

        if textures.count == 1 {
            petSprite.texture = textures[0]
        } else {
            let animate = SKAction.animate(with: textures, timePerFrame: state.frameRate)
            petSprite.run(SKAction.repeatForever(animate), withKey: "animation")
        }
    }

    func setFacing(right: Bool) {
        petSprite.xScale = right ? 1.0 : -1.0
    }

    func showBubble(text: String, duration: TimeInterval = 4.0) {
        speechBubble.show(text: text, duration: duration)
    }

    func hideBubble() {
        speechBubble.hide()
    }

    // MARK: - Drag to move

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        let screenPos = NSEvent.mouseLocation
        let windowOrigin = view?.window?.frame.origin ?? .zero
        dragOffset = CGPoint(x: screenPos.x - windowOrigin.x, y: screenPos.y - windowOrigin.y)
        onDragStart?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let screenPos = NSEvent.mouseLocation
        let newOrigin = CGPoint(x: screenPos.x - dragOffset.x, y: screenPos.y - dragOffset.y)
        onDragMove?(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false
        onDragEnd?()
    }

    func playCelebration() {
        playAnimation(for: .celebrating)

        // Add confetti particles
        if let emitter = makeConfettiEmitter() {
            emitter.position = CGPoint(x: size.width / 2, y: size.height - 20)
            emitter.zPosition = 50
            addChild(emitter)

            // Remove after animation
            emitter.run(SKAction.sequence([
                SKAction.wait(forDuration: 2.0),
                SKAction.run { emitter.particleBirthRate = 0 },
                SKAction.wait(forDuration: 1.0),
                SKAction.removeFromParent(),
            ]))
        }
    }

    func playZzz() {
        // Add floating Z's for sleep state
        let zAction = SKAction.sequence([
            SKAction.run { [weak self] in
                guard let self = self else { return }
                let z = SKLabelNode(text: "z")
                z.fontName = "Menlo-Bold"
                z.fontSize = 10
                z.fontColor = NSColor(white: 0.5, alpha: 0.8)
                z.position = CGPoint(
                    x: self.petSprite.position.x + 30,
                    y: self.petSprite.position.y + 20
                )
                z.zPosition = 50
                self.addChild(z)

                z.run(SKAction.sequence([
                    SKAction.group([
                        SKAction.moveBy(x: CGFloat.random(in: -10...10), y: 40, duration: 1.5),
                        SKAction.fadeOut(withDuration: 1.5),
                        SKAction.scale(to: 1.5, duration: 1.5),
                    ]),
                    SKAction.removeFromParent(),
                ]))
            },
            SKAction.wait(forDuration: 1.2),
        ])
        run(SKAction.repeatForever(zAction), withKey: "zzz")
    }

    func stopZzz() {
        removeAction(forKey: "zzz")
    }

    private func makeConfettiEmitter() -> SKEmitterNode? {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 40
        emitter.numParticlesToEmit = 60
        emitter.particleLifetime = 2.0
        emitter.particleLifetimeRange = 0.5
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = 80
        emitter.particleSpeedRange = 40
        emitter.yAcceleration = -120
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -0.4
        emitter.particleScale = 0.08
        emitter.particleScaleRange = 0.04
        emitter.particleColorBlendFactor = 1.0
        emitter.particleColorSequence = nil

        // Create a small square texture for confetti
        let confettiImage = NSImage(size: NSSize(width: 8, height: 8))
        confettiImage.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 8, height: 8).fill()
        confettiImage.unlockFocus()
        emitter.particleTexture = SKTexture(image: confettiImage)

        // Colorful confetti
        emitter.particleColorRedRange = 1.0
        emitter.particleColorGreenRange = 1.0
        emitter.particleColorBlueRange = 1.0
        emitter.particleRotationRange = .pi
        emitter.particleRotationSpeed = 2.0

        return emitter
    }
}
