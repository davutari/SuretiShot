import SwiftUI
import Carbon

struct ShortcutRecorderView: View {
    let shortcut: KeyboardShortcut?
    @Binding var isRecording: Bool
    let onShortcutRecorded: (KeyboardShortcut) -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            ShortcutRecorderButton(
                shortcut: shortcut,
                isRecording: $isRecording,
                onShortcutRecorded: onShortcutRecorded
            )
            .frame(minWidth: 100)

            if shortcut != nil {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear shortcut")
            }
        }
    }
}

struct ShortcutRecorderButton: NSViewRepresentable {
    let shortcut: KeyboardShortcut?
    @Binding var isRecording: Bool
    let onShortcutRecorded: (KeyboardShortcut) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.shortcut = shortcut
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.shortcut = shortcut
        nsView.isRecording = isRecording
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: ShortcutRecorderDelegate {
        var parent: ShortcutRecorderButton

        init(_ parent: ShortcutRecorderButton) {
            self.parent = parent
        }

        func shortcutRecorderDidStartRecording() {
            parent.isRecording = true
        }

        func shortcutRecorderDidEndRecording() {
            parent.isRecording = false
        }

        func shortcutRecorderDidRecord(_ shortcut: KeyboardShortcut) {
            parent.onShortcutRecorded(shortcut)
        }
    }
}

protocol ShortcutRecorderDelegate: AnyObject {
    func shortcutRecorderDidStartRecording()
    func shortcutRecorderDidEndRecording()
    func shortcutRecorderDidRecord(_ shortcut: KeyboardShortcut)
}

class ShortcutRecorderNSView: NSView {
    weak var delegate: ShortcutRecorderDelegate?

    var shortcut: KeyboardShortcut? {
        didSet {
            updateDisplay()
        }
    }

    var isRecording = false {
        didSet {
            updateDisplay()
        }
    }

    private let button: NSButton

    override init(frame frameRect: NSRect) {
        button = NSButton(frame: .zero)
        super.init(frame: frameRect)
        setupButton()
    }

    required init?(coder: NSCoder) {
        button = NSButton(frame: .zero)
        super.init(coder: coder)
        setupButton()
    }

    private func setupButton() {
        button.bezelStyle = .rounded
        button.target = self
        button.action = #selector(buttonClicked)
        button.translatesAutoresizingMaskIntoConstraints = false

        addSubview(button)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        updateDisplay()
    }

    private func updateDisplay() {
        if isRecording {
            button.title = "Press shortcut..."
            button.contentTintColor = .systemBlue
        } else if let shortcut = shortcut {
            button.title = shortcut.displayString
            button.contentTintColor = nil
        } else {
            button.title = "Click to record"
            button.contentTintColor = .secondaryLabelColor
        }
    }

    @objc private func buttonClicked() {
        if isRecording {
            isRecording = false
            delegate?.shortcutRecorderDidEndRecording()
        } else {
            isRecording = true
            delegate?.shortcutRecorderDidStartRecording()
            window?.makeFirstResponder(self)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        // Ignore modifier-only presses
        if event.keyCode == 0xFF {
            return
        }

        // Escape cancels recording
        if event.keyCode == UInt16(kVK_Escape) {
            isRecording = false
            delegate?.shortcutRecorderDidEndRecording()
            return
        }

        let modifiers = ModifierFlags.from(nsModifiers: event.modifierFlags)

        // Require at least one modifier (except for function keys)
        let isFunctionKey = (event.keyCode >= UInt16(kVK_F1) && event.keyCode <= UInt16(kVK_F20))
        if modifiers.isEmpty && !isFunctionKey {
            return
        }

        let shortcut = KeyboardShortcut(keyCode: event.keyCode, modifiers: modifiers)

        isRecording = false
        delegate?.shortcutRecorderDidEndRecording()
        delegate?.shortcutRecorderDidRecord(shortcut)
    }

    override func flagsChanged(with event: NSEvent) {
        // Don't pass through while recording
        if !isRecording {
            super.flagsChanged(with: event)
        }
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            isRecording = false
            delegate?.shortcutRecorderDidEndRecording()
        }
        return super.resignFirstResponder()
    }
}
