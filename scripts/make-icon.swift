// Renders Resources/AppIcon.png (1024x1024). Run: swift scripts/make-icon.swift
import AppKit

let size: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Rounded square with a teal to blue gradient (AppKit origin is bottom-left).
let bg = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
NSGradient(starting: NSColor(srgbRed: 18/255, green: 96/255, blue: 176/255, alpha: 1),
           ending: NSColor(srgbRed: 32/255, green: 201/255, blue: 170/255, alpha: 1))!
    .draw(in: bg, angle: 90)

func bar(_ x: CGFloat, _ yTop: CGFloat, _ w: CGFloat, alpha: CGFloat) {
    NSColor.white.withAlphaComponent(alpha).setFill()
    NSBezierPath(roundedRect: NSRect(x: x, y: size - yTop - 80, width: w, height: 80), xRadius: 40, yRadius: 40).fill()
}
bar(290, 560, 444, alpha: 1)
bar(290, 680, 444, alpha: 0.92)
bar(330, 430, 444, alpha: 0.55)

func sparkle(_ cx: CGFloat, _ cyTop: CGFloat, _ r1: CGFloat, _ r2: CGFloat) {
    let cy = size - cyTop
    let p = NSBezierPath()
    for i in 0..<8 {
        let a = CGFloat(i) * .pi / 4
        let r = i % 2 == 0 ? r1 : r2
        let pt = NSPoint(x: cx + r * cos(a), y: cy + r * sin(a))
        i == 0 ? p.move(to: pt) : p.line(to: pt)
    }
    p.close()
    NSColor.white.setFill()
    p.fill()
}
sparkle(640, 300, 120, 26)
sparkle(430, 260, 55, 12)

NSGraphicsContext.restoreGraphicsState()
let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.png")
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("Wrote \(out.path)")
