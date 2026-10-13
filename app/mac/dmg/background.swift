// Draws the disk image window's background: the wordmark, a slot for the
// app and one for the Applications folder to sit in, with plates for their
// names, and an arrow from one to the other, saying to drag it there.
// scripts/make-dmg runs it, writing background.png and background@2x.png
// (for Retina screens) to the folder it's given. The layout matches the
// icon positions and label size in app/mac/dmg/settings.py.
//
// Usage: swift app/mac/dmg/background.swift <out dir>
import AppKit

let width = 640.0
let height = 400.0
let iconY = 200.0 // icon centres, from the top (as in settings.py)
let appX = 180.0
let applicationsX = 460.0

// brand/ colours (see brand/wordmark-dark.svg and brand/icon.svg).
func rgb(_ hex: Int) -> NSColor {
  NSColor(
    srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255,
    blue: CGFloat(hex & 0xff) / 255, alpha: 1)
}
let background = rgb(0x15181D)
let slotFill = rgb(0x1B1F25)
let slotBorder = rgb(0x2E343D)
let blue = rgb(0x3B7DF0)
let grey = rgb(0x8B95A3)
let plate = rgb(0xC3C9D2)

let root = URL(fileURLWithPath: #filePath).absoluteURL.deletingLastPathComponent()
  .appendingPathComponent("../../..").standardized
let wordmark = NSImage(contentsOf: root.appendingPathComponent("brand/wordmark-dark.svg"))!

// Points from the top-left, as Finder places icons; AppKit's y counts up.
func point(_ x: Double, _ y: Double) -> NSPoint { NSPoint(x: x, y: height - y) }

// A slot an icon sits in: the rounded square Finder highlights a selected
// icon with (at 128 points), so the highlight lines up with its border.
func slot(_ cx: Double, _ cy: Double) {
  let side = 143.0
  let path = NSBezierPath(
    roundedRect: NSRect(x: cx - side / 2, y: height - cy - side / 2, width: side, height: side),
    xRadius: 10, yRadius: 10)
  slotFill.setFill()
  path.fill()
  slotBorder.setStroke()
  path.lineWidth = 2
  path.stroke()
}

// A light plate behind an icon's name: Finder draws names in dark text over
// a background picture, whatever the appearance. It's the size and place of
// the pill Finder puts behind a selected name (13 point text, 4 points
// either side), so selecting a name just turns it blue.
func namePlate(_ name: String, _ cx: Double, _ cy: Double) {
  let textWidth = NSAttributedString(
    string: name, attributes: [.font: NSFont.systemFont(ofSize: 13)]
  ).size().width
  let width = textWidth.rounded(.up) + 8
  let top = cy + 74.5
  plate.setFill()
  NSBezierPath(
    roundedRect: NSRect(x: cx - width / 2, y: height - top - 17, width: width, height: 17),
    xRadius: 5, yRadius: 5
  ).fill()
}

func draw() {
  background.setFill()
  NSRect(x: 0, y: 0, width: width, height: height).fill()

  let markHeight = 30.0
  let markWidth = markHeight * wordmark.size.width / wordmark.size.height
  wordmark.draw(
    in: NSRect(
      x: (width - markWidth) / 2, y: height - 56 - markHeight / 2, width: markWidth,
      height: markHeight))

  slot(appX, iconY)
  slot(applicationsX, iconY)
  namePlate("openp41ge explorer", appX, iconY)
  namePlate("Applications", applicationsX, iconY)

  // The arrow, between the slots.
  let start = appX + 86
  let end = applicationsX - 86
  blue.setStroke()
  let arrow = NSBezierPath()
  arrow.move(to: point(start, iconY))
  arrow.line(to: point(end, iconY))
  arrow.move(to: point(end - 14, iconY - 13))
  arrow.line(to: point(end, iconY))
  arrow.line(to: point(end - 14, iconY + 13))
  arrow.lineWidth = 4
  arrow.lineCapStyle = .round
  arrow.lineJoinStyle = .round
  arrow.stroke()

  let paragraph = NSMutableParagraphStyle()
  paragraph.alignment = .center
  let text = NSAttributedString(
    string: "Drag to Applications to install",
    attributes: [
      .font: NSFont.systemFont(ofSize: 13, weight: .medium),
      .foregroundColor: grey,
      .paragraphStyle: paragraph,
    ])
  text.draw(in: NSRect(x: 0, y: height - 342, width: width, height: 18))
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
for scale in [1, 2] {
  let image = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(width) * scale, pixelsHigh: Int(height) * scale,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  image.size = NSSize(width: width, height: height)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: image)
  draw()
  NSGraphicsContext.restoreGraphicsState()
  let name = scale == 1 ? "background.png" : "background@\(scale)x.png"
  try! image.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(name))
}
