import AppKit

final class LauncherWidget: NSView, ToolboxWidget {
    var cardSpan: CardSpan { .full }
    let widgetTitle = "启动器"
    let symbolName = "magnifyingglass"

    private let field = NSTextField()
    private let results = NSStackView()
    private var apps: [(name: String, url: URL)] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        loadApps()

        field.placeholderString = "搜索 App，回车打开第一个"
        field.font = .systemFont(ofSize: 12)
        field.isBordered = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.focusRingType = .none
        field.target = self
        field.action = #selector(launchFirst)
        field.delegate = self
        field.widthAnchor.constraint(equalToConstant: 250).isActive = true

        results.orientation = .vertical
        results.alignment = .leading
        results.spacing = 2

        let stack = NSStackView(views: [field, results])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.pin(to: self, insets: NSEdgeInsets(top: 0, left: 4, bottom: 4, right: 4))
        results.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true
    }

    required init?(coder: NSCoder) { fatalError() }

    private func loadApps() {
        var found: [(String, URL)] = []
        let dirs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask).first
                .map { $0.appendingPathComponent("/") } ?? URL(fileURLWithPath: "/Applications"),
        ]
        let home = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications")
        var allDirs = dirs.map { $0 as URL }
        allDirs.append(home)
        for dir in allDirs {
            guard let items = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil) else { continue }
            for url in items where url.pathExtension == "app" {
                found.append((url.deletingPathExtension().lastPathComponent, url))
            }
        }
        // 去重
        var seen = Set<String>()
        apps = found.filter { seen.insert($0.0).inserted }
    }

    private var matches: [(name: String, url: URL)] {
        let q = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(q) }
            .sorted { a, b in
                let aPrefix = a.name.lowercased().hasPrefix(q.lowercased())
                let bPrefix = b.name.lowercased().hasPrefix(q.lowercased())
                if aPrefix != bPrefix { return aPrefix }
                return a.name < b.name
            }
            .prefix(5)
            .map { (name: $0.name, url: $0.url) }
    }

    /// 输入是纯算式时本地求值（如 12*8、(3+5)/2），自写解析器避免 NSExpression 崩溃风险
    private var mathResult: (query: String, value: String)? {
        let q = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard q.count > 2, q.range(of: "^[0-9+\\-*/(). ]+$", options: .regularExpression) != nil,
              q.range(of: "[0-9]") != nil,
              let n = MathParser.evaluate(q) else { return nil }
        let text = n == n.rounded() && abs(n) < 1e12
            ? String(format: "%lld", Int64(n)) : String(format: "%.8g", n)
        return (q, text)
    }

    @objc private func launchFirst() {
        if let first = matches.first { launch(first) }
    }

    private func launch(_ app: (name: String, url: URL)) {
        field.stringValue = ""
        rebuild()
        NSWorkspace.shared.openApplication(at: app.url, configuration: .init())
    }

    private func rebuild() {
        results.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let ms = matches
        let math = mathResult
        defer { NotificationCenter.default.post(name: .panelRefit, object: nil) }
        if field.stringValue.isEmpty || (ms.isEmpty && math == nil) {
            results.isHidden = true
            return
        }
        results.isHidden = false

        if let math {
            let btn = NSButton(title: "= \(math.value)", target: nil, action: nil)
            btn.isBordered = false
            btn.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            btn.contentTintColor = .controlAccentColor
            btn.showsBorderOnlyWhileMouseInside = true
            ActionButtonBox.register(control: btn) {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(math.value, forType: .string)
                NSSound(named: "Pop")?.play()
            }
            results.addArrangedSubview(btn)
        }

        for app in ms {
            let btn = NSButton(title: app.name, target: nil, action: nil)
            btn.isBordered = false
            btn.font = .systemFont(ofSize: 12)
            btn.image = NSWorkspace.shared.icon(forFile: app.url.path)
            btn.image?.size = NSSize(width: 15, height: 15)
            btn.imagePosition = .imageLeading
            btn.imageScaling = .scaleProportionallyDown
            btn.showsBorderOnlyWhileMouseInside = true
            (btn.cell as? NSButtonCell)?.lineBreakMode = .byTruncatingTail
            btn.widthAnchor.constraint(lessThanOrEqualToConstant: 250).isActive = true
            ActionButtonBox.register(control: btn) { [weak self] in self?.launch(app) }
            results.addArrangedSubview(btn)
        }
        NotificationCenter.default.post(name: .panelRefit, object: nil)
    }
}

extension LauncherWidget: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        rebuild()
    }
}
