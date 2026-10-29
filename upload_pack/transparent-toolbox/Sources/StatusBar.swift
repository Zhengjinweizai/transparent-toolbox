import AppKit

final class StatusBar: NSObject {
    private let item: NSStatusItem
    private weak var app: AppDelegate?
    private var pinItem: NSMenuItem?

    init(app: AppDelegate) {
        self.app = app
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        item.button?.image = NSImage(systemSymbolName: "square.grid.2x2.fill",
                                     accessibilityDescription: "工具箱")?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .medium))

        let menu = NSMenu()
        menu.addItem(withTitle: "显示 / 隐藏工具箱", action: #selector(togglePanel), keyEquivalent: "t")
        menu.addItem(withTitle: "折叠 / 展开", action: #selector(toggleCollapse), keyEquivalent: "f")
        let pin = NSMenuItem(title: "窗口置顶", action: #selector(togglePin), keyEquivalent: "p")
        pin.state = Store.shared.state.pinned ? .on : .off
        menu.addItem(pin)
        pinItem = pin
        menu.addItem(withTitle: "关闭所有贴图", action: #selector(closeAllPins), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(quit), keyEquivalent: "q")
        for mi in menu.items where mi.action != nil { mi.target = self }
        item.menu = menu
    }

    @objc private func togglePanel() { app?.togglePanel() }
    @objc private func toggleCollapse() { app?.toggleCollapse() }
    @objc private func openSettings() { app?.showSettings() }
    @objc private func quit() { app?.quit() }

    @objc private func togglePin() {
        let newPinned = !Store.shared.state.pinned
        app?.panelController.setPinned(newPinned)
        pinItem?.state = newPinned ? .on : .off
    }

    @objc private func closeAllPins() { PinManager.shared.closeAll() }
}
