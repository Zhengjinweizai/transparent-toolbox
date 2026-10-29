import AppKit

// 生成 App 图标：深色圆角底 + 2x2 彩色工具块
let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let bgRect = NSRect(x: 100, y: 100, width: 824, height: 824)
let bg = NSBezierPath(roundedRect: bgRect, xRadius: 190, yRadius: 190)
NSGradient(colors: [
    NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.24, alpha: 1),
    NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.13, alpha: 1),
])?.draw(in: bg, angle: -90)

if let ctx = NSGraphicsContext.current?.cgContext {
    ctx.setShadow(offset: CGSize(width: 0, height: 18), blur: 40,
                  color: NSColor.black.withAlphaComponent(0.45).cgColor)
}

let tiles: [(NSColor, NSRect)] = [
    (NSColor(calibratedRed: 0.30, green: 0.69, blue: 1.00, alpha: 0.95), NSRect(x: 240, y: 540, width: 250, height: 250)),
    (NSColor(calibratedRed: 1.00, green: 0.76, blue: 0.33, alpha: 0.95), NSRect(x: 530, y: 540, width: 250, height: 250)),
    (NSColor(calibratedRed: 0.45, green: 0.88, blue: 0.60, alpha: 0.95), NSRect(x: 240, y: 250, width: 250, height: 250)),
    (NSColor(calibratedRed: 0.95, green: 0.45, blue: 0.55, alpha: 0.95), NSRect(x: 530, y: 250, width: 250, height: 250)),
]
for (color, rect) in tiles {
    let p = NSBezierPath(roundedRect: rect, xRadius: 56, yRadius: 56)
    color.setFill()
    p.fill()
}
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    print("icon render failed"); exit(1)
}
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1] : "icon_1024.png"))
print("icon ok")
