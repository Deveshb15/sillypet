#!/usr/bin/env swift
import AppKit

// Generate DMG background image with arrow pointing from app to Applications
let width: CGFloat = 660
let height: CGFloat = 440

let image = NSImage(size: NSSize(width: width, height: height))
image.lockFocus()

// Dark background
let bgGradient = NSGradient(colors: [
    NSColor(red: 24/255, green: 24/255, blue: 38/255, alpha: 1),
    NSColor(red: 32/255, green: 32/255, blue: 52/255, alpha: 1),
])!
bgGradient.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -90)

// Arrow settings
let arrowY: CGFloat = height / 2 + 15
let arrowStartX: CGFloat = 225
let arrowEndX: CGFloat = 435
let arrowColor = NSColor(white: 1.0, alpha: 0.35)

// Draw dashed arrow shaft
let shaft = NSBezierPath()
shaft.move(to: NSPoint(x: arrowStartX, y: arrowY))
shaft.line(to: NSPoint(x: arrowEndX - 15, y: arrowY))
arrowColor.setStroke()
shaft.lineWidth = 3
shaft.setLineDash([8, 6], count: 2, phase: 0)
shaft.lineCapStyle = .round
shaft.stroke()

// Draw arrow head (filled triangle)
let headSize: CGFloat = 16
let head = NSBezierPath()
head.move(to: NSPoint(x: arrowEndX, y: arrowY))
head.line(to: NSPoint(x: arrowEndX - headSize, y: arrowY + headSize * 0.65))
head.line(to: NSPoint(x: arrowEndX - headSize, y: arrowY - headSize * 0.65))
head.close()
arrowColor.setFill()
head.fill()

// "Drag to install" text
let text = "Drag to Applications to install"
let textAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
    .foregroundColor: NSColor(white: 1.0, alpha: 0.45),
]
let textSize = text.size(withAttributes: textAttrs)
let textX = (width - textSize.width) / 2
text.draw(at: NSPoint(x: textX, y: arrowY - 32), withAttributes: textAttrs)

// Gatekeeper note at bottom
let noteLines = [
    "If macOS blocks the app: System Settings \u{2192} Privacy & Security \u{2192} Open Anyway",
    "Or run:  xattr -cr /Applications/SillyPet.app",
]
let noteFont = NSFont.systemFont(ofSize: 11, weight: .regular)
let noteColor = NSColor(white: 1.0, alpha: 0.3)

for (i, line) in noteLines.enumerated() {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: noteFont,
        .foregroundColor: noteColor,
    ]
    let sz = line.size(withAttributes: attrs)
    let x = (width - sz.width) / 2
    let y: CGFloat = 45 - CGFloat(i) * 18
    line.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
}

image.unlockFocus()

// Save as PNG
guard let tiffData = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiffData),
      let pngData = rep.representation(using: .png, properties: [:]) else {
    print("Failed to generate background")
    exit(1)
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg_background.png"
try! pngData.write(to: URL(fileURLWithPath: outputPath))
print("Generated \(outputPath)")
