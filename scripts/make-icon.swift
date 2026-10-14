// Renders the AleTemizCache "Ale" logo as Resources/AppIcon.png (1024x1024).
// Run: swift scripts/make-icon.swift [output.png]
import AppKit

let size: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Rounded tile, teal to deep blue (AppKit origin is bottom-left).
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let bg = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
NSGradient(starting: NSColor(srgbRed: 18/255, green: 96/255, blue: 176/255, alpha: 1),
           ending: NSColor(srgbRed: 32/255, green: 201/255, blue: 170/255, alpha: 1))!
    .draw(in: bg, angle: 90)

// Soft inner highlight on the upper half for depth.
NSGraphicsContext.saveGraphicsState()
bg.addClip()
NSGradient(starting: NSColor.white.withAlphaComponent(0.16), ending: NSColor.white.withAlphaComponent(0))!
    .draw(in: NSRect(x: 100, y: 512, width: 824, height: 412), angle: -90)
NSGraphicsContext.restoreGraphicsState()

// "Ale" wordmark, heavy rounded type, centred slightly below the middle.
let baseFont = NSFont.systemFont(ofSize: 400, weight: .heavy)
let font = baseFont.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 400) } ?? baseFont
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.shadowBlurRadius = 24
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white,
    .kern: -12,
    .shadow: shadow
]
let word = NSAttributedString(string: "Ale", attributes: attrs)
let wordSize = word.size()
word.draw(at: NSPoint(x: (size - wordSize.width) / 2, y: (size - wordSize.height) / 2 - 40))

// Underline swoosh: the "clean" stroke beneath the wordmark.
let swoosh = NSBezierPath()
swoosh.move(to: NSPoint(x: 300, y: 290))
swoosh.curve(to: NSPoint(x: 724, y: 300), controlPoint1: NSPoint(x: 430, y: 240), controlPoint2: NSPoint(x: 600, y: 240))
swoosh.lineWidth = 34
swoosh.lineCapStyle = .round
NSColor.white.withAlphaComponent(0.85).setStroke()
swoosh.stroke()

// Four-point sparkles, top right.
func sparkle(_ cx: CGFloat, _ cyTop: CGFloat, _ r1: CGFloat, _ r2: CGFloat, alpha: CGFloat) {
    let cy = size - cyTop
    let p = NSBezierPath()
    for i in 0..<8 {
        let a = CGFloat(i) * .pi / 4
        let r = i % 2 == 0 ? r1 : r2
        let pt = NSPoint(x: cx + r * cos(a), y: cy + r * sin(a))
        i == 0 ? p.move(to: pt) : p.line(to: pt)
    }
    p.close()
    NSColor.white.withAlphaComponent(alpha).setFill()
    p.fill()
}
sparkle(760, 250, 78, 17, alpha: 1)
sparkle(665, 195, 36, 8, alpha: 0.85)

NSGraphicsContext.restoreGraphicsState()
let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.png")
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("Wrote \(out.path)")
