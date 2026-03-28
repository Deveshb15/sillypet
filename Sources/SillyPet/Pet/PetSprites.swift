import AppKit
import SpriteKit

// Pixel art Shiba Inu dog - 16x16 sprites
// Each character maps to a color. Edit these to change the art!
//
// Color key:
//   . = transparent
//   o = orange (#E8A84C) - main body
//   d = dark brown (#A06738) - ear tips, markings
//   w = white/cream (#FFF8EC) - face, chest, paws
//   b = black (#2D2D2D) - eyes, nose
//   p = pink (#FF9999) - tongue
//   t = tail orange (#C88040)
//   g = gray (#888888) - shadow accent

struct PetSprites {

    static let pixelScale: Int = 5  // Each pixel = 5x5 points → 80x80pt sprite
    static let spriteSize: Int = 16

    // MARK: - Color Palette

    static let colorMap: [Character: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)] = [
        ".": (0, 0, 0, 0),
        "o": (232, 168, 76, 255),
        "d": (160, 103, 56, 255),
        "w": (255, 248, 236, 255),
        "b": (45, 45, 45, 255),
        "p": (255, 153, 153, 255),
        "t": (200, 128, 64, 255),
        "g": (136, 136, 136, 255),
    ]

    // MARK: - Animation Frames

    static let idle: [[String]] = [
        [ // Frame 1 - standing, tail up
            "................",
            "...dd...dd......",
            "..dod..dod......",
            "..doooooood.....",
            "..oooooooo......",
            "..obwwwbwo......",
            "...wwwbww.......",
            "...wwwwww.......",
            "..oooooooo......",
            "..oowwwooooo....",
            "..oowwwoooottt..",
            "..oo..oo........",
            "..oo..oo........",
            "..ww..ww........",
            "................",
            "................",
        ],
        [ // Frame 2 - standing, tail mid (wag)
            "................",
            "...dd...dd......",
            "..dod..dod......",
            "..doooooood.....",
            "..oooooooo......",
            "..obwwwbwo......",
            "...wwwbww.......",
            "...wwwwww.......",
            "..oooooooo......",
            "..oowwwooooo....",
            "..oowwwoooo.....",
            "..oo..oo..ttt...",
            "..oo..oo........",
            "..ww..ww........",
            "................",
            "................",
        ],
    ]

    static let walk: [[String]] = [
        [ // Frame 1 - front legs forward
            "................",
            "...dd...dd......",
            "..dod..dod......",
            "..doooooood.....",
            "..oooooooo......",
            "..obwwwbwo......",
            "...wwwbww.......",
            "...wwwwww.......",
            "..oooooooo......",
            "..oowwwooooo....",
            "..oowwwoooottt..",
            "...oo.oo........",
            "..oo...oo.......",
            "..ww...ww.......",
            "................",
            "................",
        ],
        [ // Frame 2 - legs together
            "................",
            "...dd...dd......",
            "..dod..dod......",
            "..doooooood.....",
            "..oooooooo......",
            "..obwwwbwo......",
            "...wwwbww.......",
            "...wwwwww.......",
            "..oooooooo......",
            "..oowwwooooo....",
            "..oowwwoooottt..",
            "..oo..oo........",
            "..oo..oo........",
            "..ww..ww........",
            "................",
            "................",
        ],
        [ // Frame 3 - back legs forward
            "................",
            "...dd...dd......",
            "..dod..dod......",
            "..doooooood.....",
            "..oooooooo......",
            "..obwwwbwo......",
            "...wwwbww.......",
            "...wwwwww.......",
            "..oooooooo......",
            "..oowwwooooo....",
            "..oowwwoooottt..",
            "..oo..oo........",
            "...oo.oo........",
            "...ww.ww........",
            "................",
            "................",
        ],
        [ // Frame 4 - legs together (same as frame 2)
            "................",
            "...dd...dd......",
            "..dod..dod......",
            "..doooooood.....",
            "..oooooooo......",
            "..obwwwbwo......",
            "...wwwbww.......",
            "...wwwwww.......",
            "..oooooooo......",
            "..oowwwooooo....",
            "..oowwwoooottt..",
            "..oo..oo........",
            "..oo..oo........",
            "..ww..ww........",
            "................",
            "................",
        ],
    ]

    // Run uses same frames as walk, played faster
    static let run: [[String]] = walk

    static let sit: [[String]] = [
        [ // Sitting down, tail visible
            "................",
            "................",
            "...dd...dd......",
            "..dod..dod......",
            "..doooooood.....",
            "..oooooooo......",
            "..obwwwbwo......",
            "...wwwbww.......",
            "...wwwwww.......",
            "..oooooooo......",
            "..oowwwooo.ttt..",
            "..oowwwoooo.....",
            "..oooooooooo....",
            "...wwwwwwww.....",
            "................",
            "................",
        ],
    ]

    static let sleep: [[String]] = [
        [ // Lying down, eyes closed
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "..dd............",
            ".dooooooooo.....",
            ".owwwwwwwwoo....",
            ".owwwwwwwwoo.t..",
            ".owwwbwwwwoo.tt.",
            "..oooooooooo.t..",
            "...wwwwwwww.....",
            "................",
            "................",
            "................",
        ],
        [ // Same but slight shift (breathing)
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "..dd............",
            ".dooooooooo.....",
            ".owwwwwwwwoo....",
            ".owwwwwwwwoo..t.",
            ".owwwbwwwwoo.tt.",
            "..oooooooooo.t..",
            "...wwwwwwww.....",
            "................",
            "................",
            "................",
        ],
    ]

    static let celebrate: [[String]] = [
        [ // Jump up! (shifted up, tongue out)
            "...dd...dd......",
            "..dod..dod......",
            "..doooooood.....",
            "..oooooooo......",
            "..obwwwbwo......",
            "...wwwbww.......",
            "...wwpwww.......",
            "..oooooooo......",
            "..oowwwooooo....",
            "..oowwwoooottt..",
            "..oo..oo........",
            "..ww..ww........",
            "................",
            "................",
            "................",
            "................",
        ],
        [ // Landing (squished, tongue out)
            "................",
            "................",
            "................",
            "...dd...dd......",
            "..dod..dod......",
            "..doooooood.....",
            "..oooooooo......",
            "..obwwwbwo......",
            "...wwwbww.......",
            "...wwpwww.......",
            "..oooooooo......",
            "..oowwwooooo....",
            "..oowwwoooottt..",
            "..oowwoooo......",
            "..wwwwwwww......",
            "................",
        ],
    ]

    static let alert: [[String]] = [
        [ // Ears extra perked, body tense
            "...dd...dd......",
            "..dod..dod......",
            "..dod..dod......",
            "..doooooood.....",
            "..oooooooo......",
            "..obwwwbwo......",
            "...wwwbww.......",
            "...wwwwww.......",
            "..oooooooo......",
            "..oowwwooooo....",
            "..oowwwoooottt..",
            "..oo..oo........",
            "..oo..oo........",
            "..ww..ww........",
            "................",
            "................",
        ],
    ]

    // MARK: - Texture Generation

    static func framesForState(_ state: PetState) -> [[String]] {
        switch state {
        case .idle: return idle
        case .walking: return walk
        case .running: return run
        case .sitting: return sit
        case .sleeping: return sleep
        case .celebrating: return celebrate
        case .alert: return alert
        }
    }

    static func texturesForState(_ state: PetState) -> [SKTexture] {
        return framesForState(state).map { textureFromPixelArt($0) }
    }

    static func textureFromPixelArt(_ rows: [String]) -> SKTexture {
        let image = imageFromPixelArt(rows)
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest  // Crisp pixel art, no smoothing
        return texture
    }

    static func imageFromPixelArt(_ rows: [String]) -> NSImage {
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
