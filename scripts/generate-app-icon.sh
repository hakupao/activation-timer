#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-}"
if [[ -z "$OUT_DIR" ]]; then
  echo "Usage: scripts/generate-app-icon.sh <output-dir>" >&2
  exit 2
fi

mkdir -p "$OUT_DIR"
ICONSET="${OUT_DIR}/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

SWIFT_FILE="$(mktemp)"
trap 'rm -f "$SWIFT_FILE"' EXIT

cat >"$SWIFT_FILE" <<'SWIFT'
import AppKit
import Foundation

let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = outDir.appendingPathComponent("AppIcon.iconset")

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func drawIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    let scale = CGFloat(size) / 1024.0

    NSColor(calibratedRed: 0.055, green: 0.067, blue: 0.090, alpha: 1).setFill()
    bounds.fill()

    let radius = 224 * scale
    let card = bounds.insetBy(dx: 42 * scale, dy: 42 * scale)
    let cardPath = NSBezierPath(roundedRect: card, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.10, green: 0.31, blue: 0.70, alpha: 1),
        NSColor(calibratedRed: 0.03, green: 0.62, blue: 0.58, alpha: 1),
        NSColor(calibratedRed: 0.95, green: 0.67, blue: 0.22, alpha: 1)
    ])!
    gradient.draw(in: cardPath, angle: -38)

    NSColor(calibratedWhite: 1, alpha: 0.15).setStroke()
    cardPath.lineWidth = 8 * scale
    cardPath.stroke()

    let glowRect = NSRect(x: 210 * scale, y: 185 * scale, width: 610 * scale, height: 610 * scale)
    let glow = NSBezierPath(ovalIn: glowRect)
    NSColor(calibratedWhite: 1, alpha: 0.13).setFill()
    glow.fill()

    let dialRect = NSRect(x: 244 * scale, y: 218 * scale, width: 536 * scale, height: 536 * scale)
    let dial = NSBezierPath(ovalIn: dialRect)
    NSColor(calibratedWhite: 1, alpha: 0.94).setFill()
    dial.fill()

    NSColor(calibratedRed: 0.055, green: 0.067, blue: 0.090, alpha: 0.13).setStroke()
    dial.lineWidth = 18 * scale
    dial.stroke()

    let center = NSPoint(x: 512 * scale, y: 486 * scale)
    NSColor(calibratedRed: 0.07, green: 0.13, blue: 0.21, alpha: 1).setStroke()

    let minute = NSBezierPath()
    minute.move(to: center)
    minute.line(to: NSPoint(x: 512 * scale, y: 660 * scale))
    minute.lineWidth = 46 * scale
    minute.lineCapStyle = .round
    minute.stroke()

    let hour = NSBezierPath()
    hour.move(to: center)
    hour.line(to: NSPoint(x: 655 * scale, y: 486 * scale))
    hour.lineWidth = 46 * scale
    hour.lineCapStyle = .round
    hour.stroke()

    NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.16, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 462 * scale, y: 436 * scale, width: 100 * scale, height: 100 * scale)).fill()

    let bolt = NSBezierPath()
    bolt.move(to: NSPoint(x: 594 * scale, y: 790 * scale))
    bolt.line(to: NSPoint(x: 710 * scale, y: 790 * scale))
    bolt.line(to: NSPoint(x: 642 * scale, y: 654 * scale))
    bolt.line(to: NSPoint(x: 760 * scale, y: 654 * scale))
    bolt.line(to: NSPoint(x: 546 * scale, y: 356 * scale))
    bolt.line(to: NSPoint(x: 616 * scale, y: 562 * scale))
    bolt.line(to: NSPoint(x: 500 * scale, y: 562 * scale))
    bolt.close()
    NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.20, alpha: 1).setFill()
    bolt.fill()

    NSColor(calibratedWhite: 0, alpha: 0.12).setStroke()
    bolt.lineWidth = 8 * scale
    bolt.stroke()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "Icon", code: 1)
    }
    try png.write(to: url)
}

try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for (name, size) in sizes {
    let image = drawIcon(size: size)
    let url = iconset.appendingPathComponent(name)
    try writePNG(image, to: url)
    if name == "icon_512x512@2x.png" {
        try writePNG(image, to: outDir.appendingPathComponent(name))
    }
}
SWIFT

swift "$SWIFT_FILE" "$OUT_DIR"
iconutil -c icns "$ICONSET" -o "${OUT_DIR}/AppIcon.icns"

echo "Generated ${OUT_DIR}/AppIcon.icns"
