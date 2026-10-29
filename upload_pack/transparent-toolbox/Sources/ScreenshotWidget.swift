import AppKit

final class PinWindow: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// 屏幕截图贴图窗口：置顶、可拖动、双击关闭
final class PinManager {
    static let shared = PinManager()
    private var pins: [PinWindow] = []
    private static let maxDimension: CGFloat = 520

    func pin(image: NSImage) {
        var size = image.size
        let scale = min(1, Self.maxDimension / max(size.width, size.height))
        size.width = max(120, size.width * scale)
        size.height = max(80, size.height * scale)

        let panel = PinWindow(contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
                              styleMask: [.borderless, .nonactivatingPanel],
                              backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false

        let imageView = NSImageView(image: image)
        imageView.frame = NSRect(origin: .zero, size: size)
        imageView.autoresizingMask = [.width, .height]
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 6
        imageView.layer?.masksToBounds = true
        imageView.layer?.borderWidth = 1
        imageView.layer?.borderColor = NSColor.separatorColor.cgColor
        panel.contentView = imageView

        let gr = NSClickGestureRecognizer(target: self, action: #selector(pinDoubleClicked(_:)))
        gr.numberOfClicksRequired = 2
        imageView.addGestureRecognizer(gr)
        objc_setAssociatedObject(imageView, &Self.pinKey, panel, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        if let screen = NSScreen.main {
            let v = screen.visibleFrame
            let offset = CGFloat(pins.count % 5) * 24
            panel.setFrameOrigin(NSPoint(x: v.midX - size.width / 2 + offset,
                                         y: v.midY - size.height / 2 - offset))
        }
        panel.orderFrontRegardless()
        pins.append(panel)
    }

    private static var pinKey: UInt8 = 0

    @objc private func pinDoubleClicked(_ gr: NSClickGestureRecognizer) {
        guard let view = gr.view, let panel = objc_getAssociatedObject(view, &Self.pinKey) as? PinWindow
        else { return }
        close(panel)
    }

    private func close(_ panel: PinWindow) {
        panel.orderOut(nil)
        pins.removeAll { $0 === panel }
    }

    func closeAll() {
        pins.forEach { $0.orderOut(nil) }
        pins.removeAll()
    }

    var count: Int { pins.count }
}

final class ScreenshotWidget: NSView, ToolboxWidget {
    let widgetTitle = "截图贴图"
    let symbolName = "camera.viewfinder"

    private let captureBtn = NSButton(title: "", target: nil, action: nil)
    private let statusLabel = Theme.makeLabel(" ", size: 11, color: .secondaryLabelColor)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        captureBtn.bezelStyle = .rounded
        captureBtn.controlSize = .small
        captureBtn.title = "框选截图并贴图"
        ActionButtonBox.register(control: captureBtn) { [weak self] in self?.capture() }

        let row = NSStackView(views: [captureBtn, statusLabel])
        row.spacing = 8
        row.pin(to: self, insets: NSEdgeInsets(top: 2, left: 4, bottom: 6, right: 4))
    }

    required init?(coder: NSCoder) { fatalError() }

    private func capture() {
        statusLabel.stringValue = "拖动框选区域（Esc 取消）…"
        captureBtn.isEnabled = false

        // 稍等面板让出焦点，再启动交互式截图
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            (NSApp.delegate as? AppDelegate)?.panelController.hide()
            let tmp = NSTemporaryDirectory() + "toolbox_pin_\(Int(Date().timeIntervalSince1970)).png"
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                task.arguments = ["-i", "-x", tmp]
                try? task.run()
                task.waitUntilExit()

                DispatchQueue.main.async {
                    guard let self else { return }
                    self.captureBtn.isEnabled = true
                    defer { self.statusLabel.stringValue = " " }
                    guard task.terminationStatus == 0, FileManager.default.fileExists(atPath: tmp),
                          let image = NSImage(contentsOfFile: tmp) else {
                        self.statusLabel.stringValue = "已取消或需要屏幕录制权限"
                        return
                    }
                    try? FileManager.default.removeItem(atPath: tmp)
                    PinManager.shared.pin(image: image)
                    self.statusLabel.stringValue = "已贴图（双击贴图关闭）"
                    (NSApp.delegate as? AppDelegate)?.panelController.show()
                }
            }
        }
    }
}
