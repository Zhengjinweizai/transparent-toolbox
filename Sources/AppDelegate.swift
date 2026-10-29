import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panelController: PanelController!
    var statusBar: StatusBar!
    var settingsWindow: SettingsWindow!
    var hotKeyManager: HotKeyManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        Store.shared.load()
        panelController = PanelController()
        settingsWindow = SettingsWindow(panelController: panelController)
        statusBar = StatusBar(app: self)
        hotKeyManager = HotKeyManager()
        hotKeyManager.register(app: self)
        panelController.ensureFrameOnScreen()
        if Store.shared.state.collapsed {
            panelController.setCollapsed(true, animated: false)
        } else {
            panelController.show()
        }
    }

    func togglePanel() {
        if panelController.isCollapsed {
            panelController.setCollapsed(false)
        } else if panelController.isVisible {
            panelController.hide()
        } else {
            panelController.show()
        }
    }

    func toggleCollapse() {
        panelController.setCollapsed(!panelController.isCollapsed)
    }

    func showSettings() { settingsWindow.show() }

    func quit() { NSApp.terminate(nil) }

    func applicationWillTerminate(_ notification: Notification) {
        Store.shared.save()
    }
}
