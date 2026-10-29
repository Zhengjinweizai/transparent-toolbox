import AppKit

final class CountdownWidget: NSView, ToolboxWidget {
    let widgetTitle = "倒计时"
    let symbolName = "hourglass"

    private var remaining = 5 * 60
    private var total = 5 * 60
    private var running = false
    private var timer: Timer?

    private let timeLabel: NSTextField
    private let startBtn = NSButton(title: "", target: nil, action: nil)
    private let bar = MiniBar(frame: NSRect(x: 0, y: 0, width: 100, height: 5))

    override init(frame frameRect: NSRect) {
        timeLabel = Theme.makeLabel("05:00", size: 24, weight: .semibold, mono: true)
        super.init(frame: frameRect)

        startBtn.bezelStyle = .rounded
        startBtn.controlSize = .small
        startBtn.title = "开始"
        ActionButtonBox.register(control: startBtn) { [weak self] in self?.toggleRun() }

        let resetBtn = Theme.makeIconButton("arrow.counterclockwise", tip: "重置") { [weak self] in
            self?.setMinutes()
        }

        let presets = NSStackView()
        presets.spacing = 5
        for m in [1, 3, 5, 10, 25] {
            let b = NSButton(title: "\(m)分", target: nil, action: nil)
            b.bezelStyle = .rounded
            b.controlSize = .mini
            b.font = .systemFont(ofSize: 10)
            ActionButtonBox.register(control: b) { [weak self] in self?.setMinutes(m) }
            presets.addArrangedSubview(b)
        }

        bar.widthAnchor.constraint(equalToConstant: 180).isActive = true
        bar.heightAnchor.constraint(equalToConstant: 5).isActive = true

        let btnRow = NSStackView(views: [startBtn, presets, resetBtn])
        btnRow.spacing = 8
        btnRow.alignment = .centerY

        let stack = NSStackView(views: [timeLabel, bar, btnRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.pin(to: self, insets: NSEdgeInsets(top: 0, left: 6, bottom: 4, right: 6))

        updateUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit { timer?.invalidate() }

    private var selectedMinutes = 5

    private func setMinutes(_ m: Int? = nil) {
        let minutes = m ?? selectedMinutes
        selectedMinutes = minutes
        running = false
        timer?.invalidate()
        timer = nil
        total = minutes * 60
        remaining = total
        updateUI()
    }

    private func toggleRun() {
        running.toggle()
        if running {
            guard remaining > 0 else { running = false; return }
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.tick()
            }
        } else {
            timer?.invalidate()
            timer = nil
        }
        updateUI()
    }

    private func tick() {
        remaining -= 1
        if remaining <= 0 {
            NSSound.beep()
            NSSound(named: "Glass")?.play()
            running = false
            timer?.invalidate()
            timer = nil
        }
        updateUI()
    }

    private func updateUI() {
        let m = remaining / 60, s = remaining % 60
        timeLabel.stringValue = String(format: "%02d:%02d", m, s)
        startBtn.title = running ? "暂停" : "开始"
        bar.ratio = total > 0 ? CGFloat(1 - Double(remaining) / Double(total)) : 0
        timeLabel.textColor = remaining <= 10 && running ? .systemOrange : .labelColor
    }
}
