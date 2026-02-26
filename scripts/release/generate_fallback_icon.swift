import AppKit

enum IconGenError: Error {
    case usage
    case bitmapCreate
    case contextCreate
    case pngEncode
}

let args = CommandLine.arguments.dropFirst()
guard let outputPath = args.first else {
    fputs("usage: swift generate_fallback_icon.swift /path/to/output.png\n", stderr)
    throw IconGenError.usage
}

let size = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    throw IconGenError.bitmapCreate
}

guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    throw IconGenError.contextCreate
}

let canvas = NSRect(x: 0, y: 0, width: size, height: size)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

NSColor.clear.setFill()
canvas.fill()

let outer = canvas.insetBy(dx: 56, dy: 56)
let outerPath = NSBezierPath(roundedRect: outer, xRadius: 210, yRadius: 210)

let bgGradient = NSGradient(colorsAndLocations:
    (NSColor(calibratedRed: 0.06, green: 0.11, blue: 0.18, alpha: 1.0), 0.0),
    (NSColor(calibratedRed: 0.07, green: 0.29, blue: 0.42, alpha: 1.0), 0.55),
    (NSColor(calibratedRed: 0.14, green: 0.45, blue: 0.60, alpha: 1.0), 1.0)
)!
bgGradient.draw(in: outerPath, angle: -90)

// Soft vignette
NSColor.black.withAlphaComponent(0.14).setStroke()
outerPath.lineWidth = 18
outerPath.stroke()

// Top highlight
let highlightPath = NSBezierPath(roundedRect: outer.insetBy(dx: 18, dy: 18), xRadius: 180, yRadius: 180)
NSColor.white.withAlphaComponent(0.08).setStroke()
highlightPath.lineWidth = 4
highlightPath.stroke()

// Subtle grid / scan lines
NSColor.white.withAlphaComponent(0.035).setStroke()
for i in stride(from: Int(outer.minY) + 90, through: Int(outer.maxY) - 90, by: 48) {
    let p = NSBezierPath()
    p.move(to: CGPoint(x: outer.minX + 70, y: CGFloat(i)))
    p.line(to: CGPoint(x: outer.maxX - 70, y: CGFloat(i)))
    p.lineWidth = 2
    p.stroke()
}

// Main "image card" plate
let card = NSRect(x: 160, y: 186, width: 704, height: 652)
let cardPath = NSBezierPath(roundedRect: card, xRadius: 54, yRadius: 54)
NSColor(calibratedWhite: 1.0, alpha: 0.88).setFill()
cardPath.fill()
NSColor.white.withAlphaComponent(0.7).setStroke()
cardPath.lineWidth = 3
cardPath.stroke()

// Inner image area
let imageRect = card.insetBy(dx: 48, dy: 66)
let imagePath = NSBezierPath(roundedRect: imageRect, xRadius: 28, yRadius: 28)
let imageGradient = NSGradient(colorsAndLocations:
    (NSColor(calibratedRed: 0.95, green: 0.97, blue: 1.0, alpha: 1.0), 0.0),
    (NSColor(calibratedRed: 0.85, green: 0.92, blue: 0.98, alpha: 1.0), 1.0)
)!
imageGradient.draw(in: imagePath, angle: -90)

// Mountains / horizon motif
let horizon = imageRect.minY + imageRect.height * 0.56
NSColor(calibratedRed: 0.57, green: 0.79, blue: 0.88, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: imageRect.minX, y: imageRect.minY, width: imageRect.width, height: horizon - imageRect.minY)).fill()

let mountain1 = NSBezierPath()
mountain1.move(to: CGPoint(x: imageRect.minX + 18, y: imageRect.minY + 70))
mountain1.line(to: CGPoint(x: imageRect.minX + 205, y: imageRect.minY + 280))
mountain1.line(to: CGPoint(x: imageRect.minX + 338, y: imageRect.minY + 150))
mountain1.line(to: CGPoint(x: imageRect.minX + 455, y: imageRect.minY + 305))
mountain1.line(to: CGPoint(x: imageRect.minX + 590, y: imageRect.minY + 140))
mountain1.line(to: CGPoint(x: imageRect.maxX - 18, y: imageRect.minY + 240))
mountain1.line(to: CGPoint(x: imageRect.maxX - 18, y: imageRect.minY + 18))
mountain1.line(to: CGPoint(x: imageRect.minX + 18, y: imageRect.minY + 18))
mountain1.close()
NSColor(calibratedRed: 0.20, green: 0.55, blue: 0.54, alpha: 1.0).setFill()
mountain1.fill()

let mountain2 = NSBezierPath()
mountain2.move(to: CGPoint(x: imageRect.minX + 70, y: imageRect.minY + 20))
mountain2.line(to: CGPoint(x: imageRect.minX + 255, y: imageRect.minY + 200))
mountain2.line(to: CGPoint(x: imageRect.minX + 380, y: imageRect.minY + 100))
mountain2.line(to: CGPoint(x: imageRect.minX + 500, y: imageRect.minY + 215))
mountain2.line(to: CGPoint(x: imageRect.minX + 650, y: imageRect.minY + 75))
mountain2.line(to: CGPoint(x: imageRect.maxX - 20, y: imageRect.minY + 125))
mountain2.line(to: CGPoint(x: imageRect.maxX - 20, y: imageRect.minY + 20))
mountain2.close()
NSColor(calibratedRed: 0.10, green: 0.38, blue: 0.40, alpha: 1.0).setFill()
mountain2.fill()

let sun = NSBezierPath(ovalIn: NSRect(x: imageRect.minX + 92, y: imageRect.maxY - 190, width: 98, height: 98))
NSColor(calibratedRed: 0.99, green: 0.76, blue: 0.32, alpha: 1.0).setFill()
sun.fill()

// Annotation bounding box overlay (actual box)
let bbox = NSRect(x: imageRect.minX + 292, y: imageRect.minY + 172, width: 255, height: 190)
NSColor.systemOrange.withAlphaComponent(0.15).setFill()
NSBezierPath(rect: bbox).fill()
NSColor.systemOrange.setStroke()
let bboxPath = NSBezierPath(rect: bbox)
bboxPath.lineWidth = 14
bboxPath.stroke()

// Handles
for point in [
    CGPoint(x: bbox.minX, y: bbox.minY),
    CGPoint(x: bbox.maxX, y: bbox.minY),
    CGPoint(x: bbox.minX, y: bbox.maxY),
    CGPoint(x: bbox.maxX, y: bbox.maxY)
] {
    let handle = NSRect(x: point.x - 12, y: point.y - 12, width: 24, height: 24)
    NSColor.white.setFill()
    NSBezierPath(rect: handle).fill()
    NSColor.systemOrange.setStroke()
    let p = NSBezierPath(rect: handle)
    p.lineWidth = 4
    p.stroke()
}

// Label banner (separate from bbox)
let banner = NSRect(x: bbox.minX, y: bbox.maxY + 12, width: 230, height: 70)
let bannerPath = NSBezierPath(roundedRect: banner, xRadius: 18, yRadius: 18)
NSColor.systemOrange.setFill()
bannerPath.fill()

let label = "Object"
let para = NSMutableParagraphStyle()
para.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 34, weight: .bold),
    .foregroundColor: NSColor.white,
    .paragraphStyle: para
]
let labelRect = NSRect(x: banner.minX + 8, y: banner.minY + 16, width: banner.width - 16, height: banner.height - 22)
(label as NSString).draw(in: labelRect, withAttributes: attrs)

// Pencil/edit cue
let pencilShadow = NSBezierPath(roundedRect: NSRect(x: card.maxX - 148, y: card.maxY - 118, width: 92, height: 92), xRadius: 24, yRadius: 24)
NSColor(calibratedRed: 0.04, green: 0.12, blue: 0.22, alpha: 0.24).setFill()
pencilShadow.fill()

let pencilBody = NSBezierPath(roundedRect: NSRect(x: card.maxX - 214, y: card.maxY - 206, width: 186, height: 30), xRadius: 14, yRadius: 14)
var transform = AffineTransform()
transform.translate(x: card.maxX - 119, y: card.maxY - 159)
transform.rotate(byDegrees: 45)
transform.translate(x: -(card.maxX - 119), y: -(card.maxY - 159))
pencilBody.transform(using: transform)
NSColor(calibratedRed: 0.98, green: 0.85, blue: 0.33, alpha: 1).setFill()
pencilBody.fill()
NSColor(calibratedRed: 0.80, green: 0.58, blue: 0.10, alpha: 1).setStroke()
pencilBody.lineWidth = 4
pencilBody.stroke()

let nib = NSBezierPath()
nib.move(to: CGPoint(x: card.maxX - 36, y: card.maxY - 93))
nib.line(to: CGPoint(x: card.maxX - 14, y: card.maxY - 71))
nib.line(to: CGPoint(x: card.maxX - 8, y: card.maxY - 108))
nib.close()
NSColor(calibratedRed: 0.23, green: 0.22, blue: 0.23, alpha: 1).setFill()
nib.fill()

NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    throw IconGenError.pngEncode
}

try pngData.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
