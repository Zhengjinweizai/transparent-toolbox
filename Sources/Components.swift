import AppKit

/// 历史曲线（iStat 风格）：数据已归一化 0…1，画渐变填充 + 折线
final class Sparkline: NSView {
    private var values: [Double] = []
    var lineColor: NSColor = .controlAccentColor { didSet { needsDisplay = true } }
    var capacity = 60 { didSet { if values.count > capacity { values.removeFirst(values.count - capacity) } } }

    func push(_ normalized: Double) {
        values.append(max(0, min(1, normalized)))
        if values.count > capacity { values.removeFirst(values.count - capacity) }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard values.count > 1, let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width, h = bounds.height
        let stepX = w / CGFloat(capacity - 1)
        let startIdx = capacity - values.count
        var pts: [CGPoint] = []
        for (i, v) in values.enumerated() {
            pts.append(CGPoint(x: CGFloat(startIdx + i) * stepX, y: CGFloat(v) * (h - 2) + 1))
        }

        let fill = CGMutablePath()
        fill.move(to: CGPoint(x: pts[0].x, y: 0))
        pts.forEach { fill.addLine(to: $0) }
        fill.addLine(to: CGPoint(x: pts[pts.count - 1].x, y: 0))
        fill.closeSubpath()
        ctx.saveGState()
        ctx.addPath(fill)
        ctx.clip()
        let colors = [lineColor.withAlphaComponent(0.35).cgColor,
                      lineColor.withAlphaComponent(0.02).cgColor]
        if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: colors as CFArray, locations: [0, 1]) {
            ctx.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: h), options: [])
        }
        ctx.restoreGState()

        let line = CGMutablePath()
        line.move(to: pts[0])
        pts.dropFirst().forEach { line.addLine(to: $0) }
        ctx.addPath(line)
        ctx.setStrokeColor(lineColor.withAlphaComponent(0.95).cgColor)
        ctx.setLineWidth(1.2)
        ctx.strokePath()
    }
}

/// 环形进度（番茄钟 v2）
final class RingProgress: NSView {
    var progress: CGFloat = 0 { didSet { needsDisplay = true } }
    var ringColor: NSColor = .controlAccentColor { didSet { needsDisplay = true } }
    var lineWidth: CGFloat = 5 { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let r = min(bounds.width, bounds.height) / 2 - lineWidth / 2 - 1

        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: r, startAngle: 0, endAngle: 360)
        track.lineWidth = lineWidth
        NSColor.labelColor.withAlphaComponent(0.10).setStroke()
        track.stroke()

        let p = max(0.001, min(1, progress))
        let arc = NSBezierPath()
        arc.appendArc(withCenter: center, radius: r, startAngle: 90,
                      endAngle: 90 - 360 * p, clockwise: true)
        arc.lineWidth = lineWidth
        arc.lineCapStyle = .round
        ringColor.setStroke()
        arc.stroke()
    }
}

/// 迷你进度条：数值越高颜色越暖（CPU/内存/磁盘共用）
final class MiniBar: NSView {
    private let fill = CALayer()
    var autoColor = false
    var ratio: CGFloat = 0 {
        didSet {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            fill.frame = bounds(ratio: ratio)
            if autoColor {
                let c: NSColor = ratio < 0.55 ? Theme.Palette.success
                    : (ratio < 0.8 ? Theme.Palette.warning : Theme.Palette.danger)
                fill.backgroundColor = c.withAlphaComponent(0.9).cgColor
            }
            CATransaction.commit()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 3
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.12).cgColor
        fill.cornerRadius = 3
        fill.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.9).cgColor
        layer?.addSublayer(fill)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func bounds(ratio: CGFloat) -> CGRect {
        let w = max(0, min(1, ratio)) * bounds.width
        return CGRect(x: 0, y: 0, width: w, height: bounds.height)
    }

    override func layout() {
        super.layout()
        fill.frame = bounds(ratio: ratio)
    }
}
