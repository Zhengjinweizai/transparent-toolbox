import AppKit
import Security

final class PasswordWidget: NSView, ToolboxWidget {
    var cardSpan: CardSpan { .full }
    let widgetTitle = "密码生成"
    let symbolName = "key"

    private let display = Theme.makeLabel("", size: 13, mono: true)
    private let lengthLabel = Theme.makeLabel("16 位", size: 11, color: .secondaryLabelColor)
    private let lengthSlider = NSSlider(value: 16, minValue: 6, maxValue: 48, target: nil, action: nil)
    private let symbolsCheck = NSButton(title: "符号", target: nil, action: nil)
    private var current: String = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        display.lineBreakMode = .byTruncatingMiddle
        display.widthAnchor.constraint(lessThanOrEqualToConstant: 230).isActive = true

        lengthSlider.widthAnchor.constraint(equalToConstant: 140).isActive = true
        ActionButtonBox.register(control: lengthSlider) { [weak self] in
            self?.lengthLabel.stringValue = "\(self?.lengthSlider.integerValue ?? 16) 位"
            self?.generate()
        }

        symbolsCheck.setButtonType(.switch)
        symbolsCheck.controlSize = .small
        symbolsCheck.font = .systemFont(ofSize: 11)
        symbolsCheck.state = .on
        ActionButtonBox.register(control: symbolsCheck) { [weak self] in self?.generate() }

        let regenerate = Theme.makeIconButton("arrow.clockwise", tip: "换一个") { [weak self] in
            self?.generate()
        }
        let copy = Theme.makeIconButton("doc.on.doc", tip: "复制") { [weak self] in
            self?.copyPassword()
        }

        let optRow = NSStackView(views: [lengthSlider, lengthLabel, symbolsCheck, NSView(), regenerate, copy])
        optRow.spacing = 6
        optRow.arrangedSubviews[3].setContentHuggingPriority(.init(1), for: .horizontal)

        let stack = NSStackView(views: [display, optRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.pin(to: self, insets: NSEdgeInsets(top: 2, left: 6, bottom: 6, right: 6))

        generate()
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func generate() {
        var pool = Array("abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        if symbolsCheck.state == .on {
            pool += Array("!@#$%^&*-_=+?")
        }
        let length = max(6, lengthSlider.integerValue)
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        if status != errSecSuccess {
            for i in 0..<length { bytes[i] = UInt8.random(in: 0..<255) }
        }
        current = String(bytes.map { pool[Int($0) % pool.count] })
        display.stringValue = current
    }

    private func copyPassword() {
        guard !current.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(current, forType: .string)
        NSSound(named: "Pop")?.play()
    }
}
