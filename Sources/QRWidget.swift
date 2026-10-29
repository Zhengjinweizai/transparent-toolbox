import AppKit
import CoreImage

final class QRWidget: NSView, ToolboxWidget {
    let widgetTitle = "二维码"
    let symbolName = "qrcode"

    private let input = NSTextField()
    private let imageView = NSImageView()
    private var currentImage: NSImage?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        input.placeholderString = "输入文本或链接，回车生成"
        input.font = .systemFont(ofSize: 12)
        input.isBordered = true
        input.isBezeled = true
        input.bezelStyle = .roundedBezel
        input.focusRingType = .none
        input.target = self
        input.action = #selector(generate)
        input.widthAnchor.constraint(equalToConstant: 230).isActive = true

        let genBtn = Theme.makeIconButton("arrowtriangle.right.circle", tip: "生成") { [weak self] in
            self?.generate()
        }
        let copyBtn = Theme.makeIconButton("photo.on.rectangle", tip: "复制图片") { [weak self] in
            self?.copyImage()
        }

        let inputRow = NSStackView(views: [input, genBtn, copyBtn])
        inputRow.spacing = 6

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 4
        imageView.layer?.backgroundColor = NSColor.white.cgColor
        imageView.widthAnchor.constraint(equalToConstant: 120).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 120).isActive = true

        let stack = NSStackView(views: [inputRow, imageView])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.pin(to: self, insets: NSEdgeInsets(top: 2, left: 6, bottom: 6, right: 6))
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func generate() {
        let text = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let data = text.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else { return }

        let scale: CGFloat = 8
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let rep = NSCIImageRep(ciImage: scaled)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)

        imageView.image = image
        currentImage = image
    }

    private func copyImage() {
        guard let currentImage else {
            NSSound.beep()
            return
        }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([currentImage])
        NSSound(named: "Pop")?.play()
    }
}
