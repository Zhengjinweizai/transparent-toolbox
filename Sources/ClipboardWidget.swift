import AppKit

/// 剪贴板 v2：搜索过滤、相对时间戳、置顶（Maccy 式体验）
final class ClipboardWidget: NSView, ToolboxWidget {
    var cardSpan: CardSpan { .full }
    let widgetTitle = "剪贴板"
    let symbolName = "doc.on.clipboard"

    private let searchField = NSTextField()
    private let listStack = NSStackView()
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var writingOwn = false
    private var timer: Timer?
    private var storeObserver: NSObjectProtocol?
    private var lastSeenClips: [ClipItem] = []
    private let emptyState = Theme.makeEmptyState(symbol: "doc.on.clipboard", text: "暂无剪贴板记录")

    private var items: [ClipItem] {
        Store.shared.state.clips2
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        searchField.placeholderString = "搜索记录"
        searchField.font = .systemFont(ofSize: 11)
        searchField.isBordered = true
        searchField.isBezeled = true
        searchField.bezelStyle = .roundedBezel
        searchField.focusRingType = .none
        searchField.delegate = self
        searchField.widthAnchor.constraint(equalToConstant: 200).isActive = true

        let searchIcon = NSImageView(image: NSImage(systemSymbolName: "magnifyingglass",
                                                    accessibilityDescription: "搜索")?
            .withSymbolConfiguration(.init(pointSize: 9, weight: .regular)) ?? NSImage())
        searchIcon.contentTintColor = .tertiaryLabelColor

        let searchRow = NSStackView(views: [searchIcon, searchField])
        searchRow.spacing = 4

        listStack.orientation = .vertical
        listStack.alignment = .leading
        listStack.spacing = 2

        let stack = NSStackView(views: [searchRow, listStack])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.pin(to: self, insets: NSEdgeInsets(top: 0, left: 2, bottom: 4, right: 4))
        searchRow.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true
        listStack.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -4).isActive = true

        rebuild()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.poll()
        }
        lastSeenClips = Store.shared.state.clips2
        storeObserver = NotificationCenter.default.addObserver(
            forName: .storeSaved, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            let now = Store.shared.state.clips2
            // 只有剪贴板数据本身变化才重建（其他部件保存不触发）
            if now.map(\.text) != lastSeenClips.map(\.text) {
                lastSeenClips = now
                rebuild()
            }
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        timer?.invalidate()
        if let storeObserver { NotificationCenter.default.removeObserver(storeObserver) }
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount
        guard !writingOwn, let str = pb.string(forType: .string),
              !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        var clips = Store.shared.state.clips2
        clips.removeAll { $0.text == str }
        clips.insert(ClipItem(text: str), at: 0)
        let unpinned = clips.filter { !$0.pinned }
        if unpinned.count > 50 {
            let maxTime = unpinned.prefix(50).last?.time ?? .distantPast
            clips.removeAll { !$0.pinned && $0.time < maxTime }
        }
        Store.shared.state.clips2 = clips
        Store.shared.save()
    }

    private func filtered() -> [ClipItem] {
        let q = searchField.stringValue.trimmingCharacters(in: .whitespaces)
        let base = items.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned }
            return a.time > b.time
        }
        guard !q.isEmpty else { return base }
        return base.filter { $0.text.localizedCaseInsensitiveContains(q) }
    }

    private func rebuild() {
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let clips = filtered()
        if clips.isEmpty {
            listStack.addArrangedSubview(emptyState)
            return
        }
        for item in clips.prefix(12) {
            listStack.addArrangedSubview(makeRow(item))
        }
        if clips.count > 12 {
            listStack.addArrangedSubview(Theme.makeLabel("共 \\(clips.count) 条，搜索以查看更多",
                                                         size: 10, color: .tertiaryLabelColor))
        }
    }

    private func makeRow(_ item: ClipItem) -> NSView {
        let oneLine = item.text.replacingOccurrences(of: "\\n", with: "⏎")
        let btn = NSButton(title: oneLine, target: nil, action: nil)
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 6
        btn.font = .systemFont(ofSize: 11)
        btn.contentTintColor = item.pinned ? Theme.Palette.accent : .labelColor
        btn.image = NSImage(systemSymbolName: item.pinned ? "pin.fill" : "doc.on.doc",
                            accessibilityDescription: "复制")?
            .withSymbolConfiguration(.init(pointSize: 8, weight: .regular))
        btn.imagePosition = .imageTrailing
        (btn.cell as? NSButtonCell)?.lineBreakMode = .byTruncatingTail
        btn.showsBorderOnlyWhileMouseInside = true
        btn.widthAnchor.constraint(lessThanOrEqualToConstant: 240).isActive = true

        ActionButtonBox.register(control: btn) { [weak self] in
            self?.copyToPasteboard(item.text)
        }

        let time = Theme.makeLabel(Theme.relativeTime(from: item.time), size: 9.5,
                                   color: .tertiaryLabelColor, mono: true)

        let pin = NSButton(title: "", target: nil, action: nil)
        pin.isBordered = false
        pin.image = NSImage(systemSymbolName: item.pinned ? "pin.slash" : "pin",
                            accessibilityDescription: "置顶")?
            .withSymbolConfiguration(.init(pointSize: 8.5, weight: .regular))
        pin.contentTintColor = item.pinned ? Theme.Palette.accent : .tertiaryLabelColor
        pin.showsBorderOnlyWhileMouseInside = true
        ActionButtonBox.register(control: pin) { [weak self] in
            if let i = Store.shared.state.clips2.firstIndex(where: { $0.text == item.text }) {
                Store.shared.state.clips2[i].pinned.toggle()
                Store.shared.save()
            }
        }

        let row = NSStackView(views: [btn, time, pin])
        row.spacing = 4
        row.alignment = .centerY
        return row
    }

    @objc private func copyToPasteboard(_ str: String) {
        writingOwn = true
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(str, forType: .string)
        lastChangeCount = pb.changeCount
        NSSound(named: "Pop")?.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.writingOwn = false
        }
    }
}

extension ClipboardWidget: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) { rebuild() }
}
