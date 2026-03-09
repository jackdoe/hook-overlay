import AppKit
import CoreText

class OverlayPanel: NSPanel {
    private static let width: CGFloat = 440
    private static let padding: CGFloat = 20
    private static var innerWidth: CGFloat { width - padding * 2 }

    private let projectLabel = NSTextField(labelWithString: "")
    private let cwdLabel = NSTextField(labelWithString: "")
    private let toolLabel = NSTextField(labelWithString: "")
    private let summaryScroll = NSScrollView()
    private let summaryLabel = NSTextField(wrappingLabelWithString: "")
    private let sessionLabel = NSTextField(labelWithString: "")
    private let queueLabel = NSTextField(labelWithString: "")
    private let dangerBadge = NSTextField(labelWithString: "")
    private let optionStack = NSStackView()
    private let accentBar = NSView()
    private var summaryHeightConstraint: NSLayoutConstraint!
    private var optionWidthConstraint: NSLayoutConstraint!

    private static var fontLoaded = false

    static func mono(size: CGFloat) -> NSFont {
        if !fontLoaded {
            fontLoaded = true
            if let url = Bundle.main.url(forResource: "DepartureMonoNerdFont-Regular", withExtension: "otf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
        return NSFont(name: "DepartureMonoNerdFont", size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask,
                  backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = .screenSaver
        isFloatingPanel = true
        hidesOnDeactivate = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = true
        animationBehavior = .alertPanel
        appearance = NSAppearance(named: .darkAqua)
        setupUI()
    }

    private func setupUI() {
        let bg = NSVisualEffectView(frame: .zero)
        bg.material = .hudWindow
        bg.blendingMode = .behindWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 0
        bg.layer?.masksToBounds = true
        bg.appearance = NSAppearance(named: .darkAqua)
        contentView = bg

        accentBar.wantsLayer = true
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(accentBar)

        let title = NSTextField(labelWithString: "PERMISSION REQUEST")
        title.font = OverlayPanel.mono(size: 11)
        title.textColor = NSColor.white.withAlphaComponent(0.5)

        projectLabel.font = OverlayPanel.mono(size: 14)
        projectLabel.maximumNumberOfLines = 1

        cwdLabel.font = OverlayPanel.mono(size: 10)
        cwdLabel.textColor = NSColor.white.withAlphaComponent(0.35)
        cwdLabel.maximumNumberOfLines = 1
        cwdLabel.lineBreakMode = .byTruncatingMiddle
        cwdLabel.preferredMaxLayoutWidth = OverlayPanel.innerWidth

        toolLabel.font = OverlayPanel.mono(size: 20)
        toolLabel.textColor = .white
        toolLabel.maximumNumberOfLines = 1

        dangerBadge.wantsLayer = true
        dangerBadge.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.25).cgColor
        dangerBadge.layer?.borderColor = NSColor.systemRed.cgColor
        dangerBadge.layer?.borderWidth = 1
        dangerBadge.font = OverlayPanel.mono(size: 11)
        dangerBadge.textColor = .systemRed
        dangerBadge.stringValue = "  DESTRUCTIVE  "
        dangerBadge.isHidden = true

        summaryLabel.font = OverlayPanel.mono(size: 12)
        summaryLabel.textColor = NSColor.white.withAlphaComponent(0.75)
        summaryLabel.maximumNumberOfLines = 0
        summaryLabel.lineBreakMode = .byWordWrapping
        summaryLabel.isSelectable = true
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.preferredMaxLayoutWidth = OverlayPanel.innerWidth
        summaryLabel.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        let clipView = NSClipView()
        clipView.documentView = summaryLabel
        clipView.drawsBackground = false
        clipView.translatesAutoresizingMaskIntoConstraints = false

        summaryScroll.contentView = clipView
        summaryScroll.translatesAutoresizingMaskIntoConstraints = false
        summaryScroll.hasVerticalScroller = true
        summaryScroll.hasHorizontalScroller = false
        summaryScroll.autohidesScrollers = true
        summaryScroll.borderType = .noBorder
        summaryScroll.drawsBackground = false
        summaryScroll.scrollerStyle = .overlay

        sessionLabel.font = OverlayPanel.mono(size: 10)
        sessionLabel.textColor = NSColor.white.withAlphaComponent(0.3)

        let sep = NSBox()
        sep.boxType = .separator

        optionStack.orientation = .vertical
        optionStack.alignment = .leading
        optionStack.spacing = 4
        optionStack.translatesAutoresizingMaskIntoConstraints = false

        queueLabel.font = OverlayPanel.mono(size: 10)
        queueLabel.textColor = NSColor.white.withAlphaComponent(0.35)
        queueLabel.alignment = .center

        let stack = NSStackView(views: [
            title, projectLabel, cwdLabel, toolLabel, dangerBadge, summaryScroll, sessionLabel,
            sep, optionStack, queueLabel
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.setCustomSpacing(2, after: projectLabel)
        stack.setCustomSpacing(12, after: cwdLabel)
        stack.setCustomSpacing(4, after: toolLabel)
        stack.setCustomSpacing(10, after: sessionLabel)
        stack.edgeInsets = NSEdgeInsets(top: OverlayPanel.padding, left: OverlayPanel.padding + 6,
                                        bottom: OverlayPanel.padding, right: OverlayPanel.padding)
        stack.translatesAutoresizingMaskIntoConstraints = false
        sep.translatesAutoresizingMaskIntoConstraints = false
        queueLabel.translatesAutoresizingMaskIntoConstraints = false

        summaryHeightConstraint = summaryScroll.heightAnchor.constraint(equalToConstant: 60)
        optionWidthConstraint = optionStack.widthAnchor.constraint(equalToConstant: OverlayPanel.innerWidth - 6)

        bg.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: bg.topAnchor),
            stack.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bg.bottomAnchor),
            stack.widthAnchor.constraint(equalToConstant: OverlayPanel.width),
            summaryScroll.widthAnchor.constraint(equalToConstant: OverlayPanel.innerWidth),
            summaryHeightConstraint,
            optionWidthConstraint,
            sep.widthAnchor.constraint(equalToConstant: OverlayPanel.innerWidth - 6),
            queueLabel.widthAnchor.constraint(equalToConstant: OverlayPanel.innerWidth - 6),
            accentBar.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            accentBar.topAnchor.constraint(equalTo: bg.topAnchor),
            accentBar.bottomAnchor.constraint(equalTo: bg.bottomAnchor),
            accentBar.widthAnchor.constraint(equalToConstant: 4),
        ])
    }

    func update(request: HookRequest, queueCount: Int) {
        let color = request.projectColor
        accentBar.layer?.backgroundColor = color.cgColor
        projectLabel.stringValue = request.projectName
        projectLabel.textColor = color
        cwdLabel.stringValue = request.cwd
        toolLabel.stringValue = request.toolName
        dangerBadge.isHidden = !request.isDangerous
        sessionLabel.stringValue = request.shortSession
        summaryLabel.stringValue = request.summary

        rebuildOptions(request: request)

        let textHeight = summaryLabel.sizeThatFits(
            NSSize(width: OverlayPanel.innerWidth, height: .greatestFiniteMagnitude)
        ).height
        summaryHeightConstraint.constant = min(max(textHeight, 30), 200)
        summaryLabel.frame = NSRect(x: 0, y: 0, width: OverlayPanel.innerWidth, height: textHeight)

        queueLabel.stringValue = "+\(queueCount - 1) pending"
        queueLabel.isHidden = queueCount <= 1

        if let contentView = contentView {
            contentView.layoutSubtreeIfNeeded()
            let fitted = contentView.fittingSize
            let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            setFrame(NSRect(x: screen.maxX - fitted.width - 20, y: screen.maxY - fitted.height - 20,
                            width: fitted.width, height: fitted.height), display: true)
        }
    }

    var optionCount: Int { optionStack.arrangedSubviews.count }

    func show() {
        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            animator().alphaValue = 1
        }
    }

    func dismiss(completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            completion?()
        })
    }

    private func rebuildOptions(request: HookRequest) {
        optionStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        optionStack.addArrangedSubview(
            makeOptionLabel(key: "^1", text: "ALLOW", color: .systemGreen))

        if let always = request.alwaysLabel {
            optionStack.addArrangedSubview(
                makeOptionLabel(key: "^2", text: always, color: .systemBlue))
            optionStack.addArrangedSubview(
                makeOptionLabel(key: "^3", text: "DENY", color: .systemRed))
        } else {
            optionStack.addArrangedSubview(
                makeOptionLabel(key: "^2", text: "DENY", color: .systemRed))
        }
    }

    private func makeOptionLabel(key: String, text: String, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        let attributed = NSMutableAttributedString()
        attributed.append(NSAttributedString(string: key + " ",
            attributes: [.font: OverlayPanel.mono(size: 12), .foregroundColor: color]))
        attributed.append(NSAttributedString(string: text,
            attributes: [.font: OverlayPanel.mono(size: 12), .foregroundColor: NSColor.white.withAlphaComponent(0.85)]))
        label.attributedStringValue = attributed
        label.alignment = .center
        return label
    }
}
