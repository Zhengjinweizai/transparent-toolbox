import AppKit
import ScreenCaptureKit

final class ColorPickerWidget: NSView, ToolboxWidget {
    var cardSpan: CardSpan { .full }
    let widgetTitle = "取色器"
    let symbolName = "eyedropper"

    private let swatch = NSView()
    private let hexLabel = Theme.makeLabel("点击「取色」开始", size: 12, mono: true)
    private var monitor: Any?
    private var pickBtn = NSButton(title: "", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        swatch.wantsLayer = true
        swatch.layer?.cornerRadius = 6
        swatch.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        swatch.layer?.borderWidth = 1
        swatch.layer?.borderColor = NSColor.separatorColor.cgColor
        swatch.widthAnchor.constraint(equalToConstant: 26).isActive = true
        swatch.heightAnchor.constraint(equalToConstant: 26).isActive = true

        pickBtn.bezelStyle = .rounded
        pickBtn.controlSize = .small
        pickBtn.title = "取色"
        ActionButtonBox.register(control: pickBtn) { [weak self] in self?.startPicking() }

        let copyBtn = Theme.makeIconButton("doc.on.doc", tip: "复制 HEX") { [weak self] in
            self?.copyHex()
        }

        let row = NSStackView(views: [swatch, hexLabel, NSView(), pickBtn, copyBtn])
        row.spacing = 8
        row.pin(to: self, insets: NSEdgeInsets(top: 2, left: 4, bottom: 6, right: 4))
        row.arrangedSubviews[2].setContentHuggingPriority(.init(1), for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func startPicking() {
        guard monitor == nil else { return }
        hexLabel.stringValue = "移动鼠标，点击采样…"
        pickBtn.title = "取消"
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.finish()
        }
        // 本地点击（点在自己窗口上）也要采样/取消
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            if self?.monitor != nil {
                let pt = NSEvent.mouseLocation
                self?.sample(at: pt)
                self?.finish()
                return nil // 吞掉事件
            }
            return event
        }
        // Esc 取消
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.monitor != nil, event.keyCode == 53 {
                self?.finish()
                return nil
            }
            return event
        }
        CursorTimer.start { [weak self] in
            self?.sampleLive(at: NSEvent.mouseLocation)
        }
    }

    private var localMonitor: Any?
    private var escMonitor: Any?

    private func sampleLive(at pt: NSPoint) {
        ColorSampler.color(at: pt) { [weak self] c in
            guard let c else { return }
            DispatchQueue.main.async { self?.show(color: c) }
        }
    }

    private func sample(at pt: NSPoint) {
        ColorSampler.color(at: pt) { [weak self] c in
            DispatchQueue.main.async {
                if let c { self?.show(color: c) } else {
                    self?.hexLabel.stringValue = "需要屏幕录制权限"
                }
            }
        }
    }

    private func show(color: NSColor) {
        let c = color.usingColorSpace(.sRGB) ?? color
        swatch.layer?.backgroundColor = c.cgColor
        let hex = String(format: "#%02X%02X%02X",
                         Int(round(c.redComponent * 255)),
                         Int(round(c.greenComponent * 255)),
                         Int(round(c.blueComponent * 255)))
        hexLabel.stringValue = hex
    }

    private func copyHex() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(hexLabel.stringValue, forType: .string)
        NSSound(named: "Pop")?.play()
    }

    private func finish() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let m = escMonitor { NSEvent.removeMonitor(m); escMonitor = nil }
        CursorTimer.stop()
        pickBtn.title = "取色"
        NSSound(named: "Tink")?.play()
    }
}

/// 取色预览用的轻量鼠标轮询
enum CursorTimer {
    private static var timer: Timer?

    static func start(_ block: @escaping () -> Void) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in block() }
    }

    static func stop() {
        timer?.invalidate()
        timer = nil
    }
}

enum ColorSampler {
    private static var cachedDisplays: [SCDisplay]?
    private static var permissionDenied = false

    static func color(at nsPoint: NSPoint, completion: @escaping (NSColor?) -> Void) {
        guard !permissionDenied else { completion(nil); return }
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(nsPoint) }),
              let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                  as? CGDirectDisplayID else { completion(nil); return }

        // NS 坐标（左下原点）→ CG 坐标（左上原点）
        let bounds = CGDisplayBounds(displayID)
        let localX = nsPoint.x - screen.frame.origin.x
        let localYFromTop = screen.frame.height - (nsPoint.y - screen.frame.origin.y)
        let cgRect = CGRect(x: bounds.origin.x + localX, y: bounds.origin.y + localYFromTop,
                            width: 1, height: 1)

        Task {
            do {
                var display: SCDisplay?
                if let cached = cachedDisplays?.first(where: { $0.displayID == displayID }) {
                    display = cached
                } else {
                    let content = try await SCShareableContent.excludingDesktopWindows(
                        false, onScreenWindowsOnly: true)
                    cachedDisplays = content.displays
                    display = content.displays.first { $0.displayID == displayID }
                }
                guard let display else { completion(nil); return }
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.sourceRect = cgRect
                config.width = 1
                config.height = 1
                config.showsCursor = false
                config.captureResolution = .best
                let img = try await SCScreenshotManager.captureImage(
                    contentFilter: filter, configuration: config)
                completion(pixelColor(of: img))
            } catch {
                // 无屏幕录制权限等错误：标记，避免反复弹错
                permissionDenied = true
                completion(nil)
            }
        }
    }

    static func resetPermissionFlag() { permissionDenied = false }

    private static func pixelColor(of image: CGImage) -> NSColor? {
        var pixel = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8,
                            bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        ctx?.interpolationQuality = .none
        ctx?.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return NSColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255,
                       blue: CGFloat(pixel[2]) / 255, alpha: 1)
    }
}
