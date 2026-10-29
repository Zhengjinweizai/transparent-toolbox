import AppKit

final class ClockWidget: NSView, ToolboxWidget {
    var cardSpan: CardSpan { .full }
    let widgetTitle = "时钟"
    let symbolName = "clock"

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日 EEEE"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    private let timeLabel: NSTextField
    private let dateLabel: NSTextField
    private let worldLabel = Theme.makeLabel("", size: 10, color: .tertiaryLabelColor, mono: true)
    private var timer: Timer?

    private static let worldFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let worldZones: [(String, String)] = [("纽约", "America/New_York"),
                                                          ("伦敦", "Europe/London"),
                                                          ("东京", "Asia/Tokyo")]

    override init(frame frameRect: NSRect) {
        timeLabel = Theme.makeLabel("--:--:--", size: 30, weight: .semibold, mono: true)
        dateLabel = Theme.makeLabel("", size: 12, color: .secondaryLabelColor)
        super.init(frame: frameRect)

        let stack = NSStackView(views: [timeLabel, dateLabel, worldLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 2
        stack.pin(to: self, insets: NSEdgeInsets(top: 2, left: 8, bottom: 4, right: 8))

        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit { timer?.invalidate() }

    private func tick() {
        let now = Date()
        timeLabel.stringValue = Self.timeFormatter.string(from: now)
        dateLabel.stringValue = Self.dateFormatter.string(from: now)
        worldLabel.stringValue = Self.worldZones.map { city, zone in
            Self.worldFormatter.timeZone = TimeZone(identifier: zone)
            return "\(city) \(Self.worldFormatter.string(from: now))"
        }.joined(separator: "   ")
    }
}
