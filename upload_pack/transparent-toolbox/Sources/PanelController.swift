import AppKit

enum CardSpan { case half, full }

protocol ToolboxWidget: NSView {
    var widgetTitle: String { get }
    var symbolName: String { get }
}

extension ToolboxWidget {
    var cardSpan: CardSpan { .half }   // 默认半宽，Bento 双列
}

func materialFor(_ name: String) -> (NSVisualEffectView.Material, NSAppearance.Name) {
    switch name {
    case "dark":  return (.underWindowBackground, .vibrantDark)
    case "light": return (.contentBackground, .vibrantLight)
    default:      return (.hudWindow, .vibrantDark)
    }
}

/// 可成为 key window 的无边框面板（便签等文本输入需要）。
/// 翻转坐标容器（Bento 自上而下排布）
final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

final class ToolPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class PanelController: NSObject, NSWindowDelegate {
    let panel: ToolPanel
    private let effectView = NSVisualEffectView()
    private let contentStack = NSStackView()
    private let cardsContainer = FlippedView()
    private let scroll = NSScrollView()
    private var scrollHeight: NSLayoutConstraint?
    private var scrollWidthConstraint: NSLayoutConstraint?
    private let expandButton = NSButton(title: "", target: nil, action: nil)
    private(set) var isCollapsed = false
    private var userResized = UserDefaults.standard.bool(forKey: "UserResizedHeight")
    private var lastDocHeight: CGFloat = 300

    static let panelWidth: CGFloat = 450
    static let maxHeight: CGFloat = 640

    override init() {
        panel = ToolPanel(contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: 300),
                          styleMask: [.borderless, .nonactivatingPanel, .utilityWindow],
                          backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.level = Store.shared.state.pinned ? .floating : .normal
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.styleMask.insert(.resizable)          // 无边框窗口的隐形拖拽缩放边缘
        panel.minSize = NSSize(width: 360, height: 260)
        panel.maxSize = NSSize(width: 900, height: 1200)
        super.init()
        panel.delegate = self
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 16
        effectView.layer?.masksToBounds = true
        applyMaterial(Store.shared.state.material)
        effectView.alphaValue = CGFloat(Store.shared.state.opacity)
        let wrapper = NSView(frame: NSRect(x: 0, y: 0, width: Self.panelWidth, height: 300))
        effectView.pin(to: wrapper)

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 8
        contentStack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        contentStack.pin(to: effectView)
        contentStack.addArrangedSubview(Self.buildHeader(controller: self))
        headerTrailing(for: contentStack.arrangedSubviews[0], in: contentStack)

        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.scrollerStyle = .overlay
        scroll.documentView = cardsContainer
        // Bento 文档视图：宽度跟随滚动区，高度由 layoutBento 计算
        cardsContainer.autoresizingMask = [.width]
        cardsContainer.frame = NSRect(x: 0, y: 0, width: Self.panelWidth - 26, height: 100)

        contentStack.addArrangedSubview(scroll)
        let hc = scroll.heightAnchor.constraint(equalToConstant: 300)
        hc.priority = .required
        scrollHeight = hc
        scrollWidthConstraint = scroll.widthAnchor.constraint(equalTo: contentStack.widthAnchor)
        scrollWidthConstraint?.isActive = true
        panel.contentView = wrapper
        registerDefaultWidgets()
        refit()

        // 部件内部内容变化（待办增删、启动器结果显隐）时重算面板高度
        NotificationCenter.default.addObserver(forName: .panelRefit, object: nil, queue: .main) { [weak self] _ in
            self?.refit()
        }
    }

    private func headerTrailing(for view: NSView, in stack: NSStackView) {
        view.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true
    }

    private static func buildHeader(controller: PanelController) -> NSStackView {
        let title = Theme.makeLabel("🧰 工具箱", size: 13, weight: .semibold)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let gear = Theme.makeIconButton("gearshape", tip: "设置") {
            (NSApp.delegate as? AppDelegate)?.showSettings()
        }
        let collapse = Theme.makeIconButton("minus.circle", tip: "折叠") { [weak controller] in
            controller?.setCollapsed(true)
        }
        let header = NSStackView(views: [title, spacer, gear, collapse])
        header.spacing = 6
        return header
    }

    // MARK: - Widgets

    private static let widgetFactories: [(id: String, make: () -> ToolboxWidget)] = [
        ("时钟", { ClockWidget() }),
        ("快捷开关", { QuickSwitchWidget() }),
        ("系统信息", { SysInfoWidget() }),
        ("番茄钟", { PomodoroWidget() }),
        ("倒计时", { CountdownWidget() }),
        ("秒表", { StopwatchWidget() }),
        ("待办", { TodoWidget() }),
        ("便签", { NotesWidget() }),
        ("剪贴板", { ClipboardWidget() }),
        ("取色器", { ColorPickerWidget() }),
        ("启动器", { LauncherWidget() }),
        ("计算器", { CalculatorWidget() }),
        ("二维码", { QRWidget() }),
        ("密码生成", { PasswordWidget() }),
        ("截图贴图", { ScreenshotWidget() }),
    ]

    private func registerDefaultWidgets() {
        rebuildWidgets()
    }

    func rebuildWidgets() {
        cardsContainer.subviews.forEach { $0.removeFromSuperview() }
        bentoCards.removeAll()
        let ordered = Store.shared.orderedWidgetIDs(Self.widgetFactories.map { $0.id })
        for id in ordered {
            guard let factory = Self.widgetFactories.first(where: { $0.id == id }),
                  Store.shared.isWidgetVisible(id) else { continue }
            addWidget(factory.make(), id: id, headerExtra: Self.headerExtra(for: id))
        }
        refit()
    }

    func moveWidget(_ id: String, up: Bool) {
        var order = Store.shared.orderedWidgetIDs(Self.widgetFactories.map { $0.id })
        guard let i = order.firstIndex(of: id) else { return }
        let j = up ? i - 1 : i + 1
        guard j >= 0, j < order.count else { return }
        order.swapAt(i, j)
        Store.shared.state.widgetOrder = order
        Store.shared.save()
        rebuildWidgets()
    }

    private static func headerExtra(for id: String) -> NSView? {
        switch id {
        case "剪贴板":
            return Theme.makeIconButton("trash", tip: "清空历史") {
                Store.shared.state.clips = []
                Store.shared.save()
            }
        case "截图贴图":
            return Theme.makeIconButton("xmark.circle", tip: "关闭所有贴图") {
                PinManager.shared.closeAll()
            }
        default:
            return nil
        }
    }

    private var bentoCards: [(card: CardView, span: CardSpan)] = []

    func addWidget(_ widget: ToolboxWidget, id: String, headerExtra: NSView? = nil) {
        let card = CardView(id: id, icon: widget.symbolName, title: widget.widgetTitle,
                            content: widget, headerExtra: headerExtra,
                            onRefit: { [weak self] in self?.refit() })
        cardsContainer.addSubview(card)
        bentoCards.append((card, widget.cardSpan))
    }

    // MARK: - Layout

    func refit() {
        layoutBento()
        if userResized { return }   // 用户手动定过高度：内容变化不改变面板高度（内部滚动）
        // 自动高度 = Bento 实测内容高 + 头部与边距
        let chrome: CGFloat = 12 + 22 + 8 + 12 + 2
        let targetHeight = min(lastDocHeight, Self.maxHeight) + chrome
        guard abs(panel.frame.height - targetHeight) > 1 else { return }
        let top = panel.frame.maxY
        panel.setContentSize(NSSize(width: panel.frame.width, height: targetHeight))
        panel.setFrameOrigin(NSPoint(x: panel.frame.minX, y: top - panel.frame.height))
    }

    /// Bento 双列瀑布流：半卡进较矮列，整卡横跨两列
    private func layoutBento(fillAvailable: Bool = false) {
        cardsContainer.layoutSubtreeIfNeeded()
        let contentW = max(scroll.contentSize.width, 340)
        let gap = Theme.Metrics.cardSpacing
        let colW = floor((contentW - gap) / 2)
        var colY: [CGFloat] = [0, 0]

        for (card, span) in bentoCards where card.superview === cardsContainer {
            let w = span == .full ? contentW : colW
            card.frame = NSRect(x: 0, y: 0, width: w, height: 20)
            card.layoutSubtreeIfNeeded()
            let h = max(card.fittingSize.height, 30)

            if span == .full {
                let y = max(colY[0], colY[1])
                card.frame = NSRect(x: 0, y: y, width: contentW, height: h)
                colY = [y + h + gap, y + h + gap]
            } else {
                let c = colY[0] <= colY[1] ? 0 : 1
                let x: CGFloat = c == 0 ? 0 : colW + gap
                card.frame = NSRect(x: x, y: colY[c], width: w, height: h)
                colY[c] += h + gap
            }
        }
        let docH = max(max(colY[0], colY[1]) - gap, 10)
        lastDocHeight = docH
        cardsContainer.frame = NSRect(x: 0, y: 0, width: contentW, height: docH)
        var target = min(docH, Self.maxHeight)
        if fillAvailable {
            // 用户拖高窗口时，滚动区跟随撑满窗口剩余空间
            let chrome: CGFloat = 12 + 22 + 8 + 12 + 2
            let available = panel.frame.height - chrome
            target = max(target, available)
        }
        scrollHeight?.constant = target
    }

    /// 启动后检查面板位置：不在任何屏幕可见区域内（或仍是初始 0,0）时重置到主屏右上角
    func ensureFrameOnScreen() {
        guard let screen = NSScreen.main else { return }
        let v = screen.visibleFrame
        var f = panel.frame
        f.size.width = max(min(f.width, 900), 360)
        f.size.height = min(max(f.height, 260), 1200)

        let defaultOrigin = NSPoint(x: v.maxX - f.width - 24, y: v.maxY - f.height - 24)
        f.origin = defaultOrigin

        // 恢复上次位置（应用自存，需完整落在可见区域内才采用）
        if let saved = UserDefaults.standard.string(forKey: "PanelFrame") {
            let r = NSRectFromString(saved)
            if r.width > 100 {
                let candidate = NSRect(x: r.origin.x, y: r.maxY - f.height, width: f.width, height: f.height)
                if v.contains(candidate) { f = candidate }
            }
        }
        panel.setFrame(f, display: true)
    }

    // MARK: - Visibility

    var isVisible: Bool { panel.isVisible }

    func show() {
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func setCollapsed(_ c: Bool, animated: Bool = true) {
        guard c != isCollapsed else { return }
        isCollapsed = c
        Store.shared.state.collapsed = c
        Store.shared.save()
        let old = panel.frame

        if c {
            contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            expandButton.bezelStyle = .regularSquare
            expandButton.isBordered = false
            expandButton.wantsLayer = true
            expandButton.layer?.cornerRadius = 18
            expandButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
            expandButton.image = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right",
                                         accessibilityDescription: "展开")?
                .withSymbolConfiguration(.init(pointSize: 11, weight: .medium))
            expandButton.contentTintColor = .labelColor
            expandButton.target = nil
            ActionButtonBox.register(control: expandButton) { [weak self] in
                self?.setCollapsed(false)
            }
            contentStack.edgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
            contentStack.addArrangedSubview(expandButton)
            panel.setContentSize(NSSize(width: 40, height: 40))
            panel.setFrameOrigin(NSPoint(x: old.maxX - 40, y: old.maxY - 40))
        } else {
            contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            contentStack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
            let header = Self.buildHeader(controller: self)
            contentStack.addArrangedSubview(header)
            headerTrailing(for: header, in: contentStack)
            contentStack.addArrangedSubview(scroll)
            scrollWidthConstraint?.isActive = true
            panel.setFrame(old, display: true)
            show()
            refit()
        }
    }

    // MARK: - Snap

    private static let snapMargin: CGFloat = 20

    func windowDidResize(_ notification: Notification) {
        guard panel.isVisible else { return }
        layoutBento(fillAvailable: true)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        userResized = true
        UserDefaults.standard.set(true, forKey: "UserResizedHeight")
        if !isCollapsed {
            UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "PanelFrame")
        }
    }

    func windowDidMove(_ notification: Notification) {
        if !isCollapsed {
            UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "PanelFrame")
        }
        guard panel.isVisible else { return }
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var f = panel.frame
        var snapped = false

        if abs(f.minX - visible.minX) < Self.snapMargin { f.origin.x = visible.minX; snapped = true }
        else if abs(f.maxX - visible.maxX) < Self.snapMargin { f.origin.x = visible.maxX - f.width; snapped = true }
        if abs(f.maxY - visible.maxY) < Self.snapMargin { f.origin.y = visible.maxY - f.height; snapped = true }
        else if abs(f.minY - visible.minY) < Self.snapMargin { f.origin.y = visible.minY; snapped = true }

        if snapped { panel.setFrameOrigin(f.origin) }
    }

    // MARK: - Appearance

    func setPinned(_ pinned: Bool) {
        Store.shared.state.pinned = pinned
        Store.shared.save()
        panel.level = pinned ? .floating : .normal
        if pinned { panel.orderFrontRegardless() }
    }

    func applyMaterial(_ name: String) {
        let (material, appearance) = materialFor(name)
        effectView.material = material
        effectView.appearance = NSAppearance(named: appearance)
    }

    func applyOpacity(_ value: Double) {
        effectView.alphaValue = CGFloat(value)
    }
}

// MARK: - Card

final class CardView: NSView {
    private let contentWrap: NSView
    private let chevron: NSButton
    private let cardID: String
    private(set) var isContentCollapsed = false
    private var onRefit: (() -> Void)?
    private var tracking: NSTrackingArea?

    init(id: String, icon: String, title: String, content: NSView,
         headerExtra: NSView? = nil, onRefit: (() -> Void)? = nil) {
        self.cardID = id
        self.contentWrap = NSView()
        self.onRefit = onRefit
        let chev = NSButton(title: "", target: nil, action: nil)
        self.chevron = chev
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = Theme.Metrics.cardRadius

        // 图标底衬：accent 15% 圆角块 + accent 图标
        let chip = NSView()
        chip.wantsLayer = true
        chip.layer?.cornerRadius = 5
        chip.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.16).cgColor
        let iconView = NSImageView(image: NSImage(systemSymbolName: icon,
                                                  accessibilityDescription: title)?
            .withSymbolConfiguration(.init(pointSize: 8.5, weight: .semibold)) ?? NSImage())
        iconView.contentTintColor = .controlAccentColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        chip.addSubview(iconView)
        NSLayoutConstraint.activate([
            chip.widthAnchor.constraint(equalToConstant: 16),
            chip.heightAnchor.constraint(equalToConstant: 16),
            iconView.centerXAnchor.constraint(equalTo: chip.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: chip.centerYAnchor),
        ])

        let titleLabel = Theme.makeLabel(title, size: 10.5, weight: .semibold,
                                         color: .secondaryLabelColor)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)

        let chevron = chev
        chevron.isBordered = false
        chevron.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "折叠")?
            .withSymbolConfiguration(.init(pointSize: 8, weight: .semibold))
        chevron.contentTintColor = .tertiaryLabelColor
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.widthAnchor.constraint(equalToConstant: 16).isActive = true
        chevron.heightAnchor.constraint(equalToConstant: 16).isActive = true
        ActionButtonBox.register(control: chevron) { [weak self] in
            self?.toggleContentCollapsed()
        }

        var headerItems: [NSView] = [chip, titleLabel, spacer]
        if let headerExtra { headerItems.append(headerExtra) }
        headerItems.append(chevron)
        let header = NSStackView(views: headerItems)
        header.spacing = 6

        // 折叠时隐藏内容但保留引用
        contentWrap.translatesAutoresizingMaskIntoConstraints = false
        contentWrap.addSubview(content)
        content.pin(to: contentWrap)

        let stack = NSStackView(views: [header, contentWrap])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Theme.Metrics.sectionSpacing
        stack.edgeInsets = Theme.Metrics.cardInset
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        header.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true
        content.trailingAnchor.constraint(equalTo: contentWrap.trailingAnchor).isActive = true
        contentWrap.widthAnchor.constraint(equalTo: stack.widthAnchor,
                                           constant: -(Theme.Metrics.cardInset.left
                                                     + Theme.Metrics.cardInset.right)).isActive = true

        // 恢复折叠记忆
        if Store.shared.state.collapsedCards.contains(id) { applyCollapse(true, save: false) }

        applyColors()
        let gr = NSClickGestureRecognizer(target: self, action: #selector(headerDoubleClicked))
        gr.numberOfClicksRequired = 2
        header.addGestureRecognizer(gr)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func headerDoubleClicked() { toggleContentCollapsed() }

    func toggleContentCollapsed() {
        applyCollapse(!isContentCollapsed, save: true)
    }

    private func applyCollapse(_ c: Bool, save: Bool) {
        isContentCollapsed = c
        contentWrap.isHidden = c
        chevron.image = NSImage(systemSymbolName: c ? "chevron.right" : "chevron.down",
                                accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 8, weight: .semibold))
        if save {
            if c { Store.shared.state.collapsedCards.append(cardID) }
            else { Store.shared.state.collapsedCards.removeAll { $0 == cardID } }
            Store.shared.save()
        }
        onRefit?()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let t = NSTrackingArea(rect: bounds,
                               options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                               owner: self)
        addTrackingArea(t)
        tracking = t
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.35).cgColor
    }

    override func mouseExited(with event: NSEvent) { applyColors() }

    private func applyColors() {
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.06).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
    }
}
