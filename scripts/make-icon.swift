// Draws the app icon (a gold die on dark leather) and writes an .icns to the given path.
import AppKit

func draw(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    let r = NSRect(x: 0, y: 0, width: size, height: size)
    let bg = NSBezierPath(roundedRect: r.insetBy(dx: size * 0.06, dy: size * 0.06), xRadius: size * 0.2, yRadius: size * 0.2)
    NSGradient(starting: NSColor(red: 0.25, green: 0.18, blue: 0.11, alpha: 1), ending: NSColor(red: 0.07, green: 0.055, blue: 0.04, alpha: 1))!
        .draw(in: bg, angle: -90)
    let dieRect = r.insetBy(dx: size * 0.22, dy: size * 0.22)
    let die = NSBezierPath(roundedRect: dieRect, xRadius: size * 0.1, yRadius: size * 0.1)
    NSGradient(starting: NSColor(red: 0.93, green: 0.78, blue: 0.45, alpha: 1), ending: NSColor(red: 0.70, green: 0.52, blue: 0.25, alpha: 1))!
        .draw(in: die, angle: -60)
    NSColor(red: 0.18, green: 0.13, blue: 0.08, alpha: 1).setFill()
    for (x, y) in [(0.25, 0.25), (0.75, 0.25), (0.5, 0.5), (0.25, 0.75), (0.75, 0.75)] {
        let d = size * 0.09
        NSBezierPath(ovalIn: NSRect(x: dieRect.minX + dieRect.width * x - d / 2, y: dieRect.minY + dieRect.height * y - d / 2, width: d, height: d)).fill()
    }
    img.unlockFocus()
    return img
}

let out = CommandLine.arguments[1]
let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: tmp)
try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    let img = draw(size: CGFloat(px))
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: tmp.appendingPathComponent("icon_\(name).png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", tmp.path, "-o", out]
try p.run(); p.waitUntilExit()
exit(p.terminationStatus)
