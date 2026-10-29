import AppKit

final class NotesWidget: NSView, ToolboxWidget, NSTextViewDelegate {
    let widgetTitle = "便签"
    let symbolName = "note.text"

    private var index = 0
    private let textView = NSTextView()
    private let pageLabel = Theme.makeLabel("1/1", size: 10, color: .secondaryLabelColor, mono: true)
    private var saveTimer: Timer?
    private var switching = false

    private var notes: [String] { Store.shared.state.notesList }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        let prevBtn = Theme.makeIconButton("chevron.left", tip: "上一张") { [weak self] in
            self?.switchPage(-1)
        }
        let nextBtn = Theme.makeIconButton("chevron.right", tip: "下一张") { [weak self] in
            self?.switchPage(1)
        }
        let addBtn = Theme.makeIconButton("plus.circle", tip: "新建便签") { [weak self] in
            self?.addNote()
        }
        let delBtn = Theme.makeIconButton("trash", tip: "删除当前便签") { [weak self] in
            self?.deleteNote()
        }
        let pageCenter = NSView()
        pageCenter.setContentHuggingPriority(.init(1), for: .horizontal)

        let header = NSStackView(views: [prevBtn, pageLabel, nextBtn, pageCenter, addBtn, delBtn])
        header.spacing = 4

        textView.isRichText = false
        textView.font = .systemFont(ofSize: 12)
        textView.textColor = .labelColor
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.delegate = self
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.scrollerStyle = .overlay

        let stack = NSStackView(views: [header, scroll])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 5
        stack.pin(to: self, insets: NSEdgeInsets(top: 0, left: 4, bottom: 4, right: 4))
        header.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 110).isActive = true

        reload()
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit { saveTimer?.invalidate() }

    // MARK: - Pages

    private func switchPage(_ delta: Int) {
        commitNow()
        let newIndex = index + delta
        guard notes.indices.contains(newIndex) else { return }
        index = newIndex
        reload()
    }

    private func addNote() {
        commitNow()
        Store.shared.state.notesList.append("")
        Store.shared.save()
        index = notes.count - 1
        reload()
    }

    private func deleteNote() {
        if notes.count > 1 {
            Store.shared.state.notesList.remove(at: index)
            index = min(index, notes.count - 1)
        } else {
            Store.shared.state.notesList = [""]
            index = 0
        }
        Store.shared.save()
        reload()
    }

    private func reload() {
        switching = true
        defer { switching = false }
        let list = notes
        index = min(index, list.count - 1)
        textView.string = list[index]
        pageLabel.stringValue = "\(index + 1)/\(list.count)"
    }

    // MARK: - Saving

    private func commitNow() {
        saveTimer?.invalidate()
        saveTimer = nil
        guard switching == false, notes.indices.contains(index) else { return }
        Store.shared.state.notesList[index] = textView.string
        Store.shared.save()
    }

    func textDidChange(_ notification: Notification) {
        guard !switching else { return }
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.commitNow()
        }
    }
}
