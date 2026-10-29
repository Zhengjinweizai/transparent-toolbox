import AppKit

/// 快捷开关（One Switch 风格）：深浅色 / 屏保 / 桌面图标 / 废纸篓
final class QuickSwitchWidget: NSView, ToolboxWidget {
    let widgetTitle = "快捷开关"
    let symbolName = "switch.2"

    private let desktopStateLabel = Theme.makeLabel("", size: 9.5, color: .tertiaryLabelColor)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        let darkBtn = makeSwitchButton(symbol: "circle.lefthalf.filled", title: "深浅色",
                                       tip: "切换系统深浅色外观") { [weak self] in self?.toggleDarkMode() }
        let saverBtn = makeSwitchButton(symbol: "display", title: "屏保",
                                        tip: "立即启动屏幕保护") { [weak self] in self?.startScreenSaver() }
        let desktopBtn = makeSwitchButton(symbol: "menubar.dock.rectangle", title: "桌面图标",
                                          tip: "显示/隐藏桌面图标") { [weak self] in self?.toggleDesktopIcons() }
        let trashBtn = makeSwitchButton(symbol: "trash", title: "废纸篓",
                                        tip: "清倒废纸篓") { [weak self] in self?.emptyTrash() }

        let row1 = NSStackView(views: [darkBtn, saverBtn])
        let row2 = NSStackView(views: [desktopBtn, trashBtn])
        [row1, row2].forEach { $0.spacing = 8; $0.alignment = .centerY }

        let stack = NSStackView(views: [row1, row2, desktopStateLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = Theme.Metrics.sectionSpacing
        stack.pin(to: self, insets: NSEdgeInsets(top: 0, left: 4, bottom: 4, right: 4))

        refreshDesktopState()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func makeSwitchButton(symbol: String, title: String, tip: String,
                                  action: @escaping () -> Void) -> NSView {
        let icon = NSImageView(image: NSImage(systemSymbolName: symbol,
                                              accessibilityDescription: tip)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .medium)) ?? NSImage())
        icon.contentTintColor = .controlAccentColor

        let label = Theme.makeLabel(title, size: 11.5)

        let btn = NSButton(title: "", target: nil, action: nil)
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 9
        btn.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.07).cgColor
        btn.showsBorderOnlyWhileMouseInside = true

        let inner = NSStackView(views: [icon, label])
        inner.spacing = 5
        btn.addSubview(inner)
        inner.pin(to: btn, insets: NSEdgeInsets(top: 7, left: 12, bottom: 7, right: 12))

        ActionButtonBox.register(control: btn) { action() }
        return btn
    }

    // MARK: - Actions

    private func run(_ launchPath: String, _ args: [String]) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: launchPath)
            task.arguments = args
            try? task.run()
            task.waitUntilExit()
        }
    }

    private func toggleDarkMode() {
        run("/usr/bin/osascript",
            ["-e", "tell app \"System Events\" to tell appearance preferences to set dark mode to not dark mode"])
    }

    private func startScreenSaver() {
        run("/System/Library/CoreServices/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine", [])
    }

    private func toggleDesktopIcons() {
        let show = desktopIconsVisible()
        run("/usr/bin/defaults", ["write", "com.apple.finder", "CreateDesktop",
                                  "-bool", show ? "false" : "true"])
        run("/usr/bin/killall", ["Finder"])
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.refreshDesktopState()
        }
    }

    private func desktopIconsVisible() -> Bool {
        let out = Process()
        out.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        out.arguments = ["read", "com.apple.finder", "CreateDesktop"]
        let pipe = Pipe()
        out.standardOutput = pipe
        out.standardError = Pipe()
        do {
            try out.run()
            out.waitUntilExit()
        } catch { return true }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) != "0"
    }

    private func refreshDesktopState() {
        desktopStateLabel.stringValue = desktopIconsVisible() ? "桌面图标：显示" : "桌面图标：已隐藏"
    }

    private func emptyTrash() {
        run("/usr/bin/osascript", ["-e", "tell app \"Finder\" to empty trash"])
    }
}
