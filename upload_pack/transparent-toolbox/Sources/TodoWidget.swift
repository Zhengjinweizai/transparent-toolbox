import AppKit

final class TodoWidget: NSView, ToolboxWidget {
    let widgetTitle = "待办"
    let symbolName = "checklist"

    private let listStack = NSStackView()
    private let inputField = NSTextField()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        let outer = NSStackView()
        outer.orientation = .vertical
        outer.alignment = .leading
        outer.spacing = 6
        outer.pin(to: self, insets: NSEdgeInsets(top: 0, left: 2, bottom: 2, right: 2))

        inputField.placeholderString = "添加待办，回车确认"
        inputField.font = .systemFont(ofSize: 12)
        inputField.isBordered = true
        inputField.isBezeled = true
        inputField.bezelStyle = .roundedBezel
        inputField.focusRingType = .none
        inputField.target = self
        inputField.action = #selector(addTodo)
        inputField.widthAnchor.constraint(equalToConstant: 150).isActive = true

        let addBtn = Theme.makeIconButton("plus.circle.fill", tip: "添加") { [weak self] in
            self?.addTodo()
        }

        let inputRow = NSStackView(views: [inputField, addBtn])
        inputRow.spacing = 6
        outer.addArrangedSubview(inputRow)

        listStack.orientation = .vertical
        listStack.alignment = .leading
        listStack.spacing = 4
        outer.addArrangedSubview(listStack)
        listStack.trailingAnchor.constraint(equalTo: outer.trailingAnchor).isActive = true

        rebuild()
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func addTodo() {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputField.stringValue = ""
        Store.shared.state.todos.append(TodoItem(text: text))
        Store.shared.save()
        rebuild()
    }

    private func rebuild() {
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        // 未完成在前，已完成后置；各自保持原顺序
        let todos = Store.shared.state.todos.enumerated()
            .sorted { a, b in (a.element.done ? 1 : 0, a.offset) < (b.element.done ? 1 : 0, b.offset) }
        if todos.isEmpty {
            listStack.addArrangedSubview(Theme.makeLabel("暂无待办 ✨", size: 11,
                                                         color: .tertiaryLabelColor))
        }
        for (i, item) in todos {
            let row = NSStackView()
            row.spacing = 5

            let check = NSButton(title: "", target: nil, action: nil)
            check.setButtonType(.switch)
            check.title = ""
            check.state = item.done ? .on : .off
            check.contentTintColor = .controlAccentColor
            ActionButtonBox.register(control: check) { [weak self] in
                Store.shared.state.todos[i].done = check.state == .on
                Store.shared.save()
                self?.rebuild()
            }

            let label = Theme.makeLabel(item.text, size: 12)
            label.attributedStringValue = NSAttributedString(
                string: item.text,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: item.done ? NSColor.tertiaryLabelColor : NSColor.labelColor,
                    .strikethroughStyle: item.done ? NSUnderlineStyle.single.rawValue : 0,
                ])
            label.lineBreakMode = .byTruncatingTail
            label.widthAnchor.constraint(lessThanOrEqualToConstant: 200).isActive = true

            let del = Theme.makeIconButton("xmark.circle", tip: "删除") { [weak self] in
                Store.shared.state.todos.remove(at: i)
                Store.shared.save()
                self?.rebuild()
            }

            row.addArrangedSubview(check)
            row.addArrangedSubview(label)
            row.addArrangedSubview(del)
            listStack.addArrangedSubview(row)
            row.trailingAnchor.constraint(equalTo: listStack.trailingAnchor).isActive = true
        }
        NotificationCenter.default.post(name: .panelRefit, object: nil)
    }
}
