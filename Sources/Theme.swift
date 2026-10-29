import AppKit

enum Theme {
    static func makeLabel(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular,
                          color: NSColor = .labelColor, mono: Bool = false) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = mono ? .monospacedDigitSystemFont(ofSize: size, weight: weight)
                      : .systemFont(ofSize: size, weight: weight)
        l.textColor = color
        l.lineBreakMode = .byTruncatingTail
        return l
    }

    static func makeIconButton(_ symbol: String, tip: String, action: @escaping () -> Void) -> NSButton {
        let b = NSButton(title: "", target: nil, action: nil)
        b.bezelStyle = .regularSquare
        b.isBordered = false
        b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .medium))
        b.contentTintColor = .secondaryLabelColor
        b.translatesAutoresizingMaskIntoConstraints = false
        b.widthAnchor.constraint(equalToConstant: 22).isActive = true
        b.heightAnchor.constraint(equalToConstant: 22).isActive = true
        b.showsBorderOnlyWhileMouseInside = true
        ActionButtonBox.register(control: b, action: action)
        return b
    }
}

/// NSButton 的 target/action 需要 NSObject 持有；用单例转发闭包。
final class ActionButtonBox: NSObject {
    static let shared = ActionButtonBox()
    private var map: [ObjectIdentifier: () -> Void] = [:]

    static func register(control: NSControl, action: @escaping () -> Void) {
        let box = shared
        control.target = box
        control.action = #selector(box.fire(_:))
        objc_setAssociatedObject(control, &mapKey, action, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private static var mapKey: UInt8 = 0

    @objc func fire(_ sender: NSControl) {
        guard let action = objc_getAssociatedObject(sender, &Self.mapKey) as? () -> Void else { return }
        action()
    }
}

extension NSView {
    func pin(to parent: NSView, insets: NSEdgeInsets = .init(top: 0, left: 0, bottom: 0, right: 0)) {
        // 约束前必须先建立视图层级，否则 AppKit 会在无父视图的约束上挂起
        if superview !== parent { parent.addSubview(self) }
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: parent.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: insets.left),
            bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -insets.bottom),
            trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -insets.right),
        ])
    }
}

extension Theme {
    /// 语义色板（全部系统语义色，自动适配深浅色）
    enum Palette {
        static let accent = NSColor.controlAccentColor
        static let success = NSColor.systemGreen
        static let warning = NSColor.systemOrange
        static let danger = NSColor.systemRed
    }

    /// v2 度量系统：内边距 ≈ 外边距的 60%（HIG）
    enum Metrics {
        static let cardRadius: CGFloat = 14
        static let cardInset = NSEdgeInsets(top: 11, left: 14, bottom: 12, right: 14)
        static let cardSpacing: CGFloat = 10
        static let sectionSpacing: CGFloat = 7
    }

    /// 空状态：图标 + 文案
    static func makeEmptyState(symbol: String, text: String) -> NSView {
        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: text)?
            .withSymbolConfiguration(.init(pointSize: 18, weight: .light)) ?? NSImage())
        icon.contentTintColor = .tertiaryLabelColor
        let label = makeLabel(text, size: 11, color: .tertiaryLabelColor)
        let stack = NSStackView(views: [icon, label])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 5
        return stack
    }
}

extension Theme {
    static func relativeTime(from date: Date) -> String {
        let d = Date().timeIntervalSince(date)
        if d < 60 { return "刚刚" }
        if d < 3600 { return "\(Int(d / 60)) 分钟前" }
        if d < 86400 { return "\(Int(d / 3600)) 小时前" }
        if d < 86400 * 7 { return "\(Int(d / 86400)) 天前" }
        let f = DateFormatter(); f.dateFormat = "M/d"; return f.string(from: date)
    }
}
