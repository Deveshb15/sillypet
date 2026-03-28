#!/usr/bin/env swift
import AppKit

// Generate a macOS app icon from the dog pixel art
let frame: [String] = [
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
]

let colorMap: [Character: (r: CGFloat, g: CGFloat, b: CGFloat)] = [
    "o": (232/255, 168/255, 76/255),
    "d": (160/255, 103/255, 56/255),
    "w": (255/255, 248/255, 236/255),
    "b": (45/255, 45/255, 45/255),
    "p": (255/255, 153/255, 153/255),
    "t": (200/255, 128/255, 64/255),
]

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Draw rounded rect background (macOS icon shape)
let bgRect = NSRect(x: 0, y: 0, width: size, height: size)
let cornerRadius: CGFloat = CGFloat(size) * 0.22 // macOS icon corner ratio
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)

// Gradient background: warm sunset colors
let gradient = NSGradient(colors: [
    NSColor(red: 255/255, green: 183/255, blue: 77/255, alpha: 1),  // warm orange
    NSColor(red: 255/255, green: 138/255, blue: 101/255, alpha: 1), // salmon
    NSColor(red: 239/255, green: 108/255, blue: 137/255, alpha: 1), // pink
])!
gradient.draw(in: bgPath, angle: -45)

// Add subtle inner shadow / border
let borderPath = NSBezierPath(roundedRect: bgRect.insetBy(dx: 2, dy: 2), xRadius: cornerRadius - 2, yRadius: cornerRadius - 2)
NSColor(white: 1.0, alpha: 0.15).setStroke()
borderPath.lineWidth = 3
borderPath.stroke()

// Draw the dog sprite centered with padding
let padding: CGFloat = 140
let spriteArea = CGFloat(size) - padding * 2
let pixelSize = spriteArea / 16.0
let offsetX = padding + 50  // shift right slightly to center the actual drawn pixels
let offsetY = padding - 20  // shift down slightly

for (rowIndex, row) in frame.enumerated() {
    for (colIndex, char) in row.enumerated() {
        guard let color = colorMap[char] else { continue }
        NSColor(red: color.r, green: color.g, blue: color.b, alpha: 1.0).setFill()
        let rect = NSRect(
            x: offsetX + CGFloat(colIndex) * pixelSize,
            y: offsetY + CGFloat(15 - rowIndex) * pixelSize,
            width: pixelSize,
            height: pixelSize
        )
        rect.fill()
    }
}

image.unlockFocus()

// Save as PNG
guard let tiffData = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiffData),
      let pngData = rep.representation(using: .png, properties: [:]) else {
    print("Failed to generate icon")
    exit(1)
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
try! pngData.write(to: URL(fileURLWithPath: outputPath))
print("Generated \(outputPath)")
