// Renders the Stoker DMG installer-window background in the "Forge" light palette:
// a warm cream surface, an ember arrow from the app icon toward Applications, and
// bilingual install steps (drag-to-install + first-launch Gatekeeper hint).
//
// Drawing is authored once in 660x420 POINT space; reps are emitted at 1x (660x420 px)
// and 2x (1320x840 px) so the DMG background stays crisp on Retina. Coordinates use the
// native AppKit bottom-left origin (y up).
//
// Usage: swift render_dmg_background.swift <out-dir>
//   writes <out-dir>/dmg-background.png and <out-dir>/dmg-background@2x.png

import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

let W: CGFloat = 660, H: CGFloat = 420

func hex(_ v: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
            green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}

let ink       = hex(0x1A1916)
let secondary = hex(0x55514A)
let muted      = hex(0x827C72)
let ember      = hex(0xD85A2C)
let emberHot   = hex(0xFF8A4D)

func centered(_ s: NSAttributedString, y: CGFloat) {
    let sz = s.size()
    s.draw(at: NSPoint(x: (W - sz.width) / 2, y: y))
}

func attr(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor,
          tracking: CGFloat = 0) -> NSAttributedString {
    NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .kern: tracking,
    ])
}

func drawScene() {
    // Warm cream gradient surface. No edge-aligned frame: the DMG window's content area
    // does not map 1:1 to this image, so any border near the edges gets clipped.
    let bg = NSGradient(colors: [hex(0xFCF8F2), hex(0xF3ECE1)])!
    bg.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

    // Title (bilingual, centered near top).
    centered(attr("拖动安装  ·  Drag to Install", size: 21, weight: .bold, color: ink), y: H - 58)

    // Ember arrow in the gap between the app icon (left) and Applications (right).
    // The arrow's height matches where Finder renders the two 128px icons (see the icon
    // positions in scripts/package-release.sh); the shaft fills the gap between them.
    let arrowY: CGFloat = 210
    let x0: CGFloat = 256, x1: CGFloat = 404
    let shaft = NSBezierPath()
    shaft.lineWidth = 9
    shaft.lineCapStyle = .round
    shaft.move(to: NSPoint(x: x0, y: arrowY))
    shaft.line(to: NSPoint(x: x1, y: arrowY))
    ember.setStroke()
    shaft.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: x1 + 22, y: arrowY))
    head.line(to: NSPoint(x: x1 - 2, y: arrowY + 15))
    head.line(to: NSPoint(x: x1 - 2, y: arrowY - 15))
    head.close()
    emberHot.setFill()
    head.fill()

    // Step captions (below the icon labels).
    centered(attr("① 把 Stoker 拖进 Applications 文件夹   ·   Drag Stoker into Applications",
                  size: 13.5, weight: .semibold, color: secondary), y: 86)
    centered(attr("② 首次打开：系统设置 › 隐私与安全性 ›「仍要打开」   ·   First launch: Settings › Privacy & Security › Open Anyway",
                  size: 11, weight: .medium, color: muted), y: 52)
}

func makeRep(pixelsWide: Int, pixelsHigh: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixelsWide, pixelsHigh: pixelsHigh,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H) // point size; pixels = W*scale
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawScene()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func write(_ rep: NSBitmapImageRep, _ name: String) {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("failed to encode \(name)\n".utf8)); exit(1)
    }
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
    try? FileManager.default.createDirectory(at: URL(fileURLWithPath: outDir),
                                             withIntermediateDirectories: true)
    do { try data.write(to: url); print("wrote \(url.path)") }
    catch { FileHandle.standardError.write(Data("write failed: \(error)\n".utf8)); exit(1) }
}

write(makeRep(pixelsWide: Int(W), pixelsHigh: Int(H)), "dmg-background.png")
write(makeRep(pixelsWide: Int(W * 2), pixelsHigh: Int(H * 2)), "dmg-background@2x.png")
