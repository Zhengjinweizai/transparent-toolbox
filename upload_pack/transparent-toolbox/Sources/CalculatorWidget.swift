import AppKit

final class CalculatorWidget: NSView, ToolboxWidget {
    let widgetTitle = "计算器"
    let symbolName = "plus.forwardslash.minus"

    private let display = Theme.makeLabel("0", size: 20, weight: .semibold, mono: true)
    private var current = "0"
    private var accumulator: Double?
    private var pendingOp: Character?
    private var justSet = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        display.alignment = .right
        display.widthAnchor.constraint(equalToConstant: 152).isActive = true

        let layout: [[String]] = [
            ["C", "±", "%", "÷"],
            ["7", "8", "9", "×"],
            ["4", "5", "6", "−"],
            ["1", "2", "3", "+"],
            ["0", ".", "="],
        ]
        let rows: [NSView] = layout.map { row in
            let s = NSStackView()
            s.orientation = .horizontal
            s.spacing = 4
            for key in row {
                let b = NSButton(title: key, target: nil, action: nil)
                b.bezelStyle = .rounded
                b.controlSize = .small
                b.font = .systemFont(ofSize: 12, weight: .medium)
                b.keyEquivalentModifierMask = []
                if key == "0" { b.widthAnchor.constraint(equalToConstant: 74).isActive = true }
                else { b.widthAnchor.constraint(equalToConstant: 35).isActive = true }
                ActionButtonBox.register(control: b) { [weak self] in self?.press(key) }
                s.addArrangedSubview(b)
            }
            return s
        }

        let stack = NSStackView(views: [display] + rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.pin(to: self, insets: NSEdgeInsets(top: 2, left: 8, bottom: 8, right: 8))
    }

    private var keyMonitor: Any?
    private var observingKeys = false

    required init?(coder: NSCoder) { fatalError() }

    deinit { if let keyMonitor { NSEvent.removeMonitor(keyMonitor) } }

    /// 面板成为 key window 时开始接收键盘；焦点在文本框时让路
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil, !observingKeys {
            observingKeys = true
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.window?.firstResponder is NSTextView == false else { return event }
                let ch = event.charactersIgnoringModifiers ?? ""
                let map: [String: String] = ["0":"0","1":"1","2":"2","3":"3","4":"4","5":"5","6":"6",
                                             "7":"7","8":"8","9":"9",".":".","+":"+","-":"−",
                                             "*":"×","/":"÷","%":"%","\r":"=","\n":"=","=":"=",
                                             "\u{7f}":"C"]
                guard let key = map[ch] else { return event }
                self.press(key)
                return nil
            }
        }
    }

    private func press(_ key: String) {
        switch key {
        case "C":
            current = "0"; accumulator = nil; pendingOp = nil; justSet = false
        case "±":
            if current.hasPrefix("-") { current.removeFirst() } else if current != "0" { current = "-" + current }
        case "%":
            current = format((Double(current) ?? 0) / 100)
        case "+", "−", "×", "÷":
            if let acc = accumulator, let op = pendingOp, !justSet {
                accumulator = calc(acc, Double(current) ?? 0, op)
            } else {
                accumulator = Double(current)
            }
            pendingOp = key.first
            current = format(accumulator ?? 0)
            justSet = true
        case "=":
            if let acc = accumulator, let op = pendingOp {
                current = format(calc(acc, Double(current) ?? 0, op))
                accumulator = nil
                pendingOp = nil
                justSet = true
            }
        case ".":
            if justSet { current = "0"; justSet = false }
            if !current.contains(".") { current += "." }
        default: // 数字
            if justSet { current = "0"; justSet = false }
            if current == "0" { current = key }
            else if current == "-0" { current = "-" + key }
            else if current.count < 12 { current += key }
        }
        display.stringValue = current
    }

    private func calc(_ a: Double, _ b: Double, _ op: Character) -> Double {
        switch op {
        case "+": return a + b
        case "−": return a - b
        case "×": return a * b
        case "÷": return b != 0 ? a / b : .nan
        default: return b
        }
    }

    private func format(_ v: Double) -> String {
        if v.isNaN || v.isInfinite { return "错误" }
        if v == v.rounded() && abs(v) < 1e12 {
            return String(format: "%lld", Int64(v))
        }
        return String(format: "%.8g", v)
    }
}
