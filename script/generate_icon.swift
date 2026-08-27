import AppKit
import Foundation

let destination = CommandLine.arguments.dropFirst().first ?? "Assets/TrackpadWizard-1024.png"
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()
guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("Unable to create icon graphics context")
}
context.setShouldAntialias(true)

let outerRect = NSRect(x: 54, y: 54, width: 916, height: 916)
let outer = NSBezierPath(roundedRect: outerRect, xRadius: 218, yRadius: 218)
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -22), blur: 40, color: NSColor.black.withAlphaComponent(0.22).cgColor)
NSGradient(
    colors: [
        NSColor(calibratedWhite: 0.94, alpha: 1),
        NSColor(calibratedWhite: 0.73, alpha: 1)
    ]
)?.draw(in: outer, angle: -72)
context.restoreGState()

NSColor.white.withAlphaComponent(0.58).setStroke()
outer.lineWidth = 7
outer.stroke()

let trackpadRect = NSRect(x: 187, y: 204, width: 650, height: 626)
let trackpad = NSBezierPath(roundedRect: trackpadRect, xRadius: 92, yRadius: 92)
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -14), blur: 25, color: NSColor.black.withAlphaComponent(0.16).cgColor)
NSGradient(
    colors: [
        NSColor(calibratedWhite: 1, alpha: 0.76),
        NSColor(calibratedWhite: 0.82, alpha: 0.58)
    ]
)?.draw(in: trackpad, angle: -90)
context.restoreGState()

NSColor(calibratedWhite: 0.18, alpha: 0.36).setStroke()
trackpad.lineWidth = 8
trackpad.stroke()

let topHighlight = NSBezierPath()
topHighlight.move(to: NSPoint(x: 270, y: 748))
topHighlight.curve(
    to: NSPoint(x: 754, y: 748),
    controlPoint1: NSPoint(x: 390, y: 794),
    controlPoint2: NSPoint(x: 630, y: 794)
)
NSColor.white.withAlphaComponent(0.64).setStroke()
topHighlight.lineWidth = 9
topHighlight.lineCapStyle = .round
topHighlight.stroke()

let dotCenters = [
    NSPoint(x: 378, y: 593),
    NSPoint(x: 512, y: 650),
    NSPoint(x: 646, y: 565)
]
for (index, center) in dotCenters.enumerated() {
    let radius: CGFloat = index == 1 ? 40 : 34
    let dot = NSBezierPath(ovalIn: NSRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
    ))
    NSColor(calibratedWhite: 0.16, alpha: 0.78).setFill()
    dot.fill()
    NSColor.white.withAlphaComponent(0.46).setStroke()
    dot.lineWidth = 5
    dot.stroke()
}

func drawWave(y: CGFloat, amplitude: CGFloat, alpha: CGFloat, width: CGFloat) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 326, y: y))
    path.curve(
        to: NSPoint(x: 512, y: y),
        controlPoint1: NSPoint(x: 390, y: y + amplitude),
        controlPoint2: NSPoint(x: 450, y: y - amplitude)
    )
    path.curve(
        to: NSPoint(x: 698, y: y),
        controlPoint1: NSPoint(x: 574, y: y + amplitude),
        controlPoint2: NSPoint(x: 636, y: y - amplitude)
    )
    path.lineWidth = width
    path.lineCapStyle = .round
    NSColor(calibratedWhite: 0.14, alpha: alpha).setStroke()
    path.stroke()
}

drawWave(y: 440, amplitude: 45, alpha: 0.82, width: 14)
drawWave(y: 380, amplitude: 31, alpha: 0.52, width: 11)
drawWave(y: 326, amplitude: 20, alpha: 0.30, width: 9)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode icon PNG")
}

try png.write(to: URL(fileURLWithPath: destination), options: .atomic)
