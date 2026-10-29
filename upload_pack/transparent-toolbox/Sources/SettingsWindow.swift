import AppKit
import ServiceManagement

final class SettingsWindow: NSObject {
    private weak var panelController: PanelController?
    private var window: NSWindow?
    private var opacitySlider: NSSlider?
    private var materialPopup: NSPopUpButton?
    private var opacitySaveTimer: Timer?

    init(panelController: PanelController) {
        self.panelController = panelController
        super.init()
    }

    func show() {
        if window == nil { build() }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// 排序等结构性变化后重建整个设置窗
    private func rebuild() {
        window?.orderOut(nil)
        window = nil
        build()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 170),
                           styleMask: [.titled, .closable],
                           backing: .buffered, defer: false)
        win.title = "工具箱设置"
        win.isReleasedWhenClosed = false
        win.center()

        let opacityLabel = Theme.makeLabel("面板透明度", size: 13)
        let slider = NSSlider(value: Store.shared.state.opacity, minValue: 0.3, maxValue: 1.0,
                              target: nil, action: nil)
        slider.widthAnchor.constraint(equalToConstant: 200).isActive = true
        ActionButtonBox.register(control: slider) { [weak self] in
            guard let v = self?.opacitySlider?.doubleValue else { return }
            Store.shared.state.opacity = v
            self?.panelController?.applyOpacity(v)
            // 拖动时防抖保存
            self?.opacitySaveTimer?.invalidate()
            self?.opacitySaveTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                Store.shared.save()
            }
        }

        let materialLabel = Theme.makeLabel("材质", size: 13)
        let popup = NSPopUpButton()
        popup.addItems(withTitles: ["深色毛玻璃", "纯深色", "浅色"])
        switch Store.shared.state.material {
        case "dark": popup.selectItem(at: 1)
        case "light": popup.selectItem(at: 2)
        default: popup.selectItem(at: 0)
        }
        ActionButtonBox.register(control: popup) { [weak self] in
            guard let idx = self?.materialPopup?.indexOfSelectedItem else { return }
            let names = ["hud", "dark", "light"]
            let name = names[idx]
            Store.shared.state.material = name
            Store.shared.save()
            self?.panelController?.applyMaterial(name)
        }

        let hint = Theme.makeLabel("面板可拖动；状态栏图标可显示/隐藏。", size: 11,
                                   color: .secondaryLabelColor)

        // 番茄钟时长
        let pomLabel = Theme.makeLabel("番茄钟", size: 13)
        let workStepper = NSStepper()
        workStepper.minValue = 1; workStepper.maxValue = 90
        workStepper.integerValue = Store.shared.state.pomodoroWork
        workStepper.widthAnchor.constraint(equalToConstant: 52).isActive = true
        let workField = Theme.makeLabel("\(Store.shared.state.pomodoroWork) 分", size: 12, mono: true)
        ActionButtonBox.register(control: workStepper) {
            Store.shared.state.pomodoroWork = workStepper.integerValue
            Store.shared.save()
            workField.stringValue = "\(workStepper.integerValue) 分"
        }
        let breakStepper = NSStepper()
        breakStepper.minValue = 1; breakStepper.maxValue = 60
        breakStepper.integerValue = Store.shared.state.pomodoroBreak
        breakStepper.widthAnchor.constraint(equalToConstant: 52).isActive = true
        let breakField = Theme.makeLabel("\(Store.shared.state.pomodoroBreak) 分", size: 12, mono: true)
        ActionButtonBox.register(control: breakStepper) {
            Store.shared.state.pomodoroBreak = breakStepper.integerValue
            Store.shared.save()
            breakField.stringValue = "\(breakStepper.integerValue) 分"
        }
        let pomRow = NSStackView(views: [workStepper, workField,
                                         Theme.makeLabel("/", size: 12), breakStepper, breakField])
        pomRow.spacing = 6
        pomRow.orientation = .horizontal

        // 部件显隐
        let visLabel = Theme.makeLabel("显示部件", size: 13)
        let widgetIds = ["时钟", "快捷开关", "系统信息", "番茄钟", "倒计时", "秒表", "待办", "便签", "剪贴板", "计算器", "二维码", "密码生成", "取色器", "启动器", "截图贴图"]
        let orderedIds = Store.shared.orderedWidgetIDs(widgetIds)
        var rows: [NSView] = []
        for id in orderedIds {
            let c = NSButton(title: id, target: nil, action: nil)
            c.setButtonType(.switch)
            c.controlSize = .small
            c.font = .systemFont(ofSize: 11)
            c.state = Store.shared.isWidgetVisible(id) ? .on : .off
            ActionButtonBox.register(control: c) { [weak self] in
                Store.shared.setWidgetVisible(id, visible: c.state == .on)
                self?.panelController?.rebuildWidgets()
            }

            let spacer = NSView()
            spacer.setContentHuggingPriority(.init(1), for: .horizontal)
            let up = Theme.makeIconButton("chevron.up", tip: "上移") { [weak self] in
                self?.panelController?.moveWidget(id, up: true)
                self?.rebuild()
            }
            let down = Theme.makeIconButton("chevron.down", tip: "下移") { [weak self] in
                self?.panelController?.moveWidget(id, up: false)
                self?.rebuild()
            }
            let row = NSStackView(views: [c, spacer, up, down])
            row.spacing = 4
            rows.append(row)
        }
        let visCol = NSStackView(views: rows)
        visCol.orientation = .vertical
        visCol.alignment = .leading
        visCol.spacing = 4

        // 开机自启
        let autoBtn = NSButton(title: "开机自启（以 .app 方式运行时生效）", target: nil, action: nil)
        autoBtn.setButtonType(.switch)
        autoBtn.font = .systemFont(ofSize: 12)
        autoBtn.state = SMAppService.mainApp.status == .enabled ? .on : .off
        ActionButtonBox.register(control: autoBtn) {
            do {
                if autoBtn.state == .on {
                    if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
                } else {
                    if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
                }
            } catch {
                autoBtn.state = SMAppService.mainApp.status == .enabled ? .on : .off
                NSSound.beep()
            }
        }

        let grid = NSGridView(views: [
            [opacityLabel, slider],
            [materialLabel, popup],
            [pomLabel, pomRow],
            [visLabel, visCol],
            [NSView(), autoBtn],
        ])
        grid.rowSpacing = 14
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .trailing

        let stack = NSStackView(views: [grid, hint])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        win.contentView = stack
        win.setContentSize(stack.fittingSize)

        opacitySlider = slider
        materialPopup = popup
        window = win
    }
}
