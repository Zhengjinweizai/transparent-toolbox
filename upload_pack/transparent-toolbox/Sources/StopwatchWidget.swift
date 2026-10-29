import AppKit

final class StopwatchWidget: NSView, ToolboxWidget {
    let widgetTitle = "秒表"
    let symbolName = "stopwatch"

    private var accumulated: TimeInterval = 0
    private var startDate: Date?
    private var laps: [TimeInterval] = []
    private var timer: Timer?

    private var running: Bool { startDate != nil }
    private var elapsed: TimeInterval {
        accumulated + (startDate.map { Date().timeIntervalSince($0) } ?? 0)
    }

    private let display = Theme.makeLabel("00:00.0", size: 24, weight: .semibold, mono: true)
    private let startBtn = NSButton(title: "", target: nil, action: nil)
    private let lapList = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        startBtn.bezelStyle = .rounded
        startBtn.controlSize = .small
        startBtn.title = "开始"
        ActionButtonBox.register(control: startBtn) { [weak self] in self?.toggleRun() }

        let lapBtn = NSButton(title: "计次", target: nil, action: nil)
        lapBtn.bezelStyle = .rounded
        lapBtn.controlSize = .small
        ActionButtonBox.register(control: lapBtn) { [weak self] in self?.addLap() }

        let resetBtn = Theme.makeIconButton("arrow.counterclockwise", tip: "重置") { [weak self] in
            self?.reset()
        }

        lapList.orientation = .vertical
        lapList.alignment = .leading
        lapList.spacing = 2

        let topRow = NSStackView(views: [startBtn, lapBtn, resetBtn])
        topRow.spacing = 8

        let stack = NSStackView(views: [display, topRow, lapList])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 5
        stack.pin(to: self, insets: NSEdgeInsets(top: 2, left: 8, bottom: 6, right: 8))
        lapList.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateUI()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit { timer?.invalidate() }

    private func toggleRun() {
        if running {
            accumulated = elapsed
            startDate = nil
            timer?.invalidate()
            timer = nil
        } else {
            startDate = Date()
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateUI()
            }
        }
        updateUI()
    }

    private func addLap() {
        guard running else { return }
        laps.insert(elapsed, at: 0)
        if laps.count > 5 { laps = Array(laps.prefix(5)) }
        rebuildLaps()
    }

    private func reset() {
        accumulated = 0
        startDate = nil
        laps = []
        timer?.invalidate()
        timer = nil
        rebuildLaps()
        updateUI()
    }

    private func rebuildLaps() {
        lapList.arrangedSubviews.forEach { $0.removeFromSuperview() }
        defer { NotificationCenter.default.post(name: .panelRefit, object: nil) }
        for (i, t) in laps.enumerated() {
            let label = Theme.makeLabel("计次 \(laps.count - i)   \(Self.format(t))",
                                        size: 11, color: .secondaryLabelColor, mono: true)
            lapList.addArrangedSubview(label)
        }
    }

    private func updateUI() {
        display.stringValue = Self.format(elapsed)
        startBtn.title = running ? "暂停" : "开始"
    }

    private static func format(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        let tenth = Int(t * 10) % 10
        return String(format: "%02d:%02d.%d", m, s, tenth)
    }
}
