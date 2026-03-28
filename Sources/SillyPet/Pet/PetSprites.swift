import AppKit
import SpriteKit

// Central sprite rendering engine.
// Dispatches to per-animal SpriteSet data based on SpriteType.
// Each pixel = pixelScale x pixelScale points -> 80x80pt sprite at scale 5.

struct PetSprites {

    static let pixelScale: Int = 5  // Each pixel = 5x5 points -> 80x80pt sprite
    static let spriteSize: Int = 16

    // MARK: - Sprite Set Dispatch

    static func spriteSet(for type: SpriteType) -> SpriteSet {
        switch type {
        case .dog: return DogSprites.sprites
        case .cat: return CatSprites.sprites
        case .rabbit: return RabbitSprites.sprites
        case .fox: return FoxSprites.sprites
        case .penguin: return PenguinSprites.sprites
        case .hamster: return HamsterSprites.sprites
        case .owl: return OwlSprites.sprites
        case .frog: return FrogSprites.sprites
        case .duck: return DuckSprites.sprites
        case .panda: return PandaSprites.sprites
        }
    }

    // MARK: - Frame Lookup

    static func framesForState(_ state: PetState, spriteType: SpriteType) -> [[String]] {
        let set = spriteSet(for: spriteType)
        switch state {
        case .idle: return set.idle
        case .walking: return set.walk
        case .running: return set.run
        case .sitting: return set.sit
        case .sleeping: return set.sleep
        case .celebrating: return set.celebrate
        case .alert: return set.alert
        }
    }

    // MARK: - Texture Generation

    static func texturesForState(_ state: PetState, spriteType: SpriteType) -> [SKTexture] {
        let set = spriteSet(for: spriteType)
        return framesForState(state, spriteType: spriteType).map {
            textureFromPixelArt($0, colorMap: set.colorMap)
        }
    }

    static func textureFromPixelArt(_ rows: [String], colorMap: [Character: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)]) -> SKTexture {
        let image = imageFromPixelArt(rows, colorMap: colorMap)
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest  // Crisp pixel art, no smoothing
        return texture
    }

    static func imageFromPixelArt(_ rows: [String], colorMap: [Character: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)]) -> NSImage {
        let scale = pixelScale
        let width = spriteSize * scale
        let height = spriteSize * scale

        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()

        // Clear background
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()

        for (rowIndex, row) in rows.enumerated() {
            for (colIndex, char) in row.enumerated() {
                guard let color = colorMap[char], color.a > 0 else { continue }

                let nsColor = NSColor(
                    red: CGFloat(color.r) / 255.0,
                    green: CGFloat(color.g) / 255.0,
                    blue: CGFloat(color.b) / 255.0,
                    alpha: CGFloat(color.a) / 255.0
                )
                nsColor.setFill()

                // Flip Y: row 0 is top of sprite, but NSImage origin is bottom-left
                let rect = NSRect(
                    x: colIndex * scale,
                    y: (spriteSize - 1 - rowIndex) * scale,
                    width: scale,
                    height: scale
                )
                rect.fill()
            }
        }

        image.unlockFocus()
        return image
    }
}
