import Foundation
import Carbon
import AppKit

final class ShortcutManager: ObservableObject {

    @Published var configuration: ShortcutConfiguration {
        didSet {
            saveConfiguration()
            registerShortcuts()
        }
    }

    var onShortcutTriggered: ((ShortcutAction) -> Void)?

    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRefs: [ShortcutAction: EventHotKeyRef] = [:]

    // System shortcuts to avoid (macOS reserved)
    private let reservedShortcuts: Set<String> = [
        "⌘Q", "⌘W", "⌘H", "⌘M", "⌘Tab", "⌘Space",
        "⌃⌘Q", "⌃⌘F", "⌃⌘Space",
        "⌥⌘Escape", "⌃⌥⌘8",
        "⇧⌘3", "⇧⌘4", "⇧⌘5", // macOS screenshot shortcuts
    ]

    init() {
        self.configuration = ShortcutManager.loadConfiguration()
        setupEventHandler()
    }

    deinit {
        unregisterAllShortcuts()
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    // MARK: - Public Methods

    func registerShortcuts() {
        unregisterAllShortcuts()

        if let shortcut = configuration.captureFullScreen {
            register(shortcut: shortcut, for: .captureFullScreen)
        }
        if let shortcut = configuration.captureArea {
            register(shortcut: shortcut, for: .captureArea)
        }
        if let shortcut = configuration.captureWindow {
            register(shortcut: shortcut, for: .captureWindow)
        }
        if let shortcut = configuration.startRecording {
            register(shortcut: shortcut, for: .startRecording)
        }
        if let shortcut = configuration.stopRecording {
            register(shortcut: shortcut, for: .stopRecording)
        }
    }

    func updateShortcut(_ shortcut: KeyboardShortcut?, for action: ShortcutAction) {
        switch action {
        case .captureFullScreen:
            configuration.captureFullScreen = shortcut
        case .captureArea:
            configuration.captureArea = shortcut
        case .captureWindow:
            configuration.captureWindow = shortcut
        case .startRecording:
            configuration.startRecording = shortcut
        case .stopRecording:
            configuration.stopRecording = shortcut
        }
    }

    func shortcut(for action: ShortcutAction) -> KeyboardShortcut? {
        switch action {
        case .captureFullScreen:
            return configuration.captureFullScreen
        case .captureArea:
            return configuration.captureArea
        case .captureWindow:
            return configuration.captureWindow
        case .startRecording:
            return configuration.startRecording
        case .stopRecording:
            return configuration.stopRecording
        }
    }

    func isShortcutReserved(_ shortcut: KeyboardShortcut) -> Bool {
        reservedShortcuts.contains(shortcut.displayString)
    }

    func hasConflict(_ shortcut: KeyboardShortcut, excluding action: ShortcutAction) -> ShortcutAction? {
        for checkAction in ShortcutAction.allCases where checkAction != action {
            if let existing = self.shortcut(for: checkAction),
               existing == shortcut {
                return checkAction
            }
        }
        return nil
    }

    // MARK: - Private Methods

    /// Returns a stable, positive ID for each action
    private func actionID(for action: ShortcutAction) -> UInt32 {
        switch action {
        case .captureFullScreen: return 1
        case .captureArea: return 2
        case .captureWindow: return 3
        case .startRecording: return 4
        case .stopRecording: return 5
        }
    }

    /// Returns action for a given ID
    private func action(forID id: UInt32) -> ShortcutAction? {
        switch id {
        case 1: return .captureFullScreen
        case 2: return .captureArea
        case 3: return .captureWindow
        case 4: return .startRecording
        case 5: return .stopRecording
        default: return nil
        }
    }

    private func setupEventHandler() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if let action = manager.action(forID: hotKeyID.id) {
                DispatchQueue.main.async {
                    manager.onShortcutTriggered?(action)
                }
            }

            return noErr
        }

        InstallEventHandler(
            GetEventDispatcherTarget(),
            handler,
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    private func register(shortcut: KeyboardShortcut, for action: ShortcutAction) {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x53555245) // "SURE"
        hotKeyID.id = actionID(for: action)

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.modifiers.carbonFlags,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            hotKeyRefs[action] = ref
        }
    }

    private func unregisterAllShortcuts() {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
    }

    // MARK: - Persistence

    private static func loadConfiguration() -> ShortcutConfiguration {
        guard let data = UserDefaults.standard.data(forKey: "ShortcutConfiguration"),
              let config = try? JSONDecoder().decode(ShortcutConfiguration.self, from: data) else {
            return .defaultConfiguration
        }
        return config
    }

    private func saveConfiguration() {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        UserDefaults.standard.set(data, forKey: "ShortcutConfiguration")
    }
}
