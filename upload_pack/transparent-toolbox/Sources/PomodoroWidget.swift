import AppKit

/// 番茄钟 v2：环形进度 + 今日完成轮数 + 阶段自动切换
final class PomodoroWidget: NSView, ToolboxWidget {
    let widgetTitle = "番茄钟"
    let symbolName = "timer"

    enum Mode { case work, breakTime }

    private var mode: Mode = .work
    private var remaining = 25 * 60
    private var running = false
    private var timer: Timer?
    private var storeObserver: NSObjectProtocol?
    private var isAutoSwitching = false

    private let modeLabel = Theme.makeLabel("专注", size: 10.5, weight: .medium,
                                            color: .secondaryLabelColor)
    private let ring = RingProgress()
    private let timeLabel = Theme.makeLabel("25:00", size: 17, weight: .semibold, mono: true)
    private let startBtn = NSButton(title: "", target: nil, action: nil)
    private let todayLabel = Theme.makeLabel("今日 0 轮 🍅", size: 10.5,
                                             color: .tertiaryLabelColor)

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var totalSeconds: Int {
        let s = Store.shared.state
        return (mode == .work ? s.pomodoroWork : s.pomodoroBreak) * 60
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        ring.translatesAutoresizingMaskIntoConstraints = false
        ring.widthAnchor.constraint(equalToConstant: 76).isActive = true
        ring.heightAnchor.constraint(equalToConstant: 76).isActive = true

        // 时间居中叠在圆环上
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(ring)
        ring.addSubview(timeLabel)
        NSLayoutConstraint.activate([
            timeLabel.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
            timeLabel.centerYAnchor.constraint(equalTo: ring.centerYAnchor),
        ])

        startBtn.bezelStyle = .rounded
        startBtn.controlSize = .small
        startBtn.title = "开始"
        ActionButtonBox.register(control: startBtn) { [weak self] in self?.toggleRun() }

        let resetBtn = Theme.makeIconButton("arrow.counterclockwise", tip: "重置") { [weak self] in
            self?.reset()
        }
        let skipBtn = Theme.makeIconButton("forward.end", tip: "切换阶段") { [weak self] in
            self?.switchMode()
        }

        let midRow = NSStackView(views: [startBtn, skipBtn, resetBtn])
        midRow.spacing = 8
        midRow.alignment = .centerY

        let stack = NSStackView(views: [modeLabel, ring, midRow, todayLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = Theme.Metrics.sectionSpacing
        stack.pin(to: self, insets: NSEdgeInsets(top: 0, left: 6, bottom: 4, right: 6))

        updateUI()

        storeObserver = NotificationCenter.default.addObserver(
            forName: .storeSaved, object: nil, queue: .main) { [weak self] _ in
            guard let self, !self.running, !self.isAutoSwitching else { return }
            self.remaining = self.totalSeconds
            self.updateUI()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        timer?.invalidate()
        if let storeObserver { NotificationCenter.default.removeObserver(storeObserver) }
    }

    private func toggleRun() {
        running.toggle()
        if running {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.tick()
            }
        } else {
            timer?.invalidate()
            timer = nil
        }
        updateUI()
    }

    private func reset() {
        running = false
        timer?.invalidate()
        timer = nil
        remaining = totalSeconds
        updateUI()
    }

    private func switchMode() {
        isAutoSwitching = true
        defer { isAutoSwitching = false }
        mode = mode == .work ? .breakTime : .work
        running = false
        timer?.invalidate()
        timer = nil
        remaining = totalSeconds
        updateUI()
    }

    private func tick() {
        remaining -= 1
        if remaining <= 0 {
            NSSound.beep()
            NSSound(named: "Glass")?.play()
            if mode == .work { bumpTodayCount() }
            switchMode()
            return
        }
        updateUI()
    }

    private func bumpTodayCount() {
        let today = Self.dayFormatter.string(from: Date())
        if Store.shared.state.pomodoroDay != today {
            Store.shared.state.pomodoroDay = today
            Store.shared.state.pomodoroDone = 0
        }
        Store.shared.state.pomodoroDone += 1
        Store.shared.save()
    }

    private func updateUI() {
        let m = remaining / 60, s = remaining % 60
        timeLabel.stringValue = String(format: "%02d:%02d", m, s)
        modeLabel.stringValue = mode == .work ? "专注" : "休息"
        startBtn.title = running ? "暂停" : "开始"
        let total = max(1, totalSeconds)
        ring.progress = CGFloat(1 - Double(remaining) / Double(total))
        ring.ringColor = mode == .work ? .controlAccentColor : Theme.Palette.success
        timeLabel.textColor = mode == .work ? .labelColor : Theme.Palette.success

        let done = Store.shared.state.pomodoroDay == Self.dayFormatter.string(from: Date())
            ? Store.shared.state.pomodoroDone : 0
        todayLabel.stringValue = "今日 \\(done) 轮 🍅"
    }
}
