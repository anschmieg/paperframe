import Foundation
import PaperWMCore

/// Configuration manager for PaperWM
/// Loads config from JSON file with schema validation
@MainActor
public final class PaperWMConfig: ObservableObject {

    /// Global config instance
    public static let shared = PaperWMConfig()

    /// Current configuration
    @Published public private(set) var config: Config

    /// Config file URL
    private let configURL: URL

    /// Default configuration
    public static let defaultConfig = Config(
        version: "1.0.0",
        shortcuts: ShortcutsConfig(
            modifier: .ctrlOption,
            switchWorkspaceLeft: KeyBinding(key: .leftArrow, modifiers: [.ctrl, .option]),
            switchWorkspaceRight: KeyBinding(key: .rightArrow, modifiers: [.ctrl, .option]),
            switchWorkspaceUp: KeyBinding(key: .upArrow, modifiers: [.ctrl, .option]),
            switchWorkspaceDown: KeyBinding(key: .downArrow, modifiers: [.ctrl, .option]),
            goToWorkspace1: KeyBinding(key: .one, modifiers: [.ctrl, .option]),
            goToWorkspace2: KeyBinding(key: .two, modifiers: [.ctrl, .option]),
            goToWorkspace3: KeyBinding(key: .three, modifiers: [.ctrl, .option]),
            goToWorkspace4: KeyBinding(key: .four, modifiers: [.ctrl, .option]),
            goToWorkspace5: KeyBinding(key: .five, modifiers: [.ctrl, .option]),
            goToWorkspace6: KeyBinding(key: .six, modifiers: [.ctrl, .option]),
            goToWorkspace7: KeyBinding(key: .seven, modifiers: [.ctrl, .option]),
            goToWorkspace8: KeyBinding(key: .eight, modifiers: [.ctrl, .option]),
            goToWorkspace9: KeyBinding(key: .nine, modifiers: [.ctrl, .option]),
            newWorkspace: KeyBinding(key: .n, modifiers: [.ctrl, .option]),
            renameWorkspace: KeyBinding(key: .r, modifiers: [.ctrl, .option]),
            removeWorkspace: KeyBinding(key: .delete, modifiers: [.ctrl, .option]),
            showMinimap: KeyBinding(key: .m, modifiers: [.ctrl, .option]),
            showSwitcher: KeyBinding(key: .slash, modifiers: [.ctrl, .option]),
            hideWindow: KeyBinding(key: .h, modifiers: [.ctrl, .option]),
            toggleFullscreen: KeyBinding(key: .f, modifiers: [.ctrl, .option]),
            toggleFloat: KeyBinding(key: .t, modifiers: [.ctrl, .option])
        ),
        behavior: BehaviorConfig(
            autoCreateWorkspace: false,
            animateTransitions: true,
            showHUD: true,
            hudDuration: 1.5,
            persistWorkspaceState: true,
            defaultLayout: .horizontal
        ),
        gestures: GesturesConfig(
            enabled: true,
            threeFingerSwipeLeft: .switchLeft,
            threeFingerSwipeRight: .switchRight,
            threeFingerSwipeUp: .showSwitcher,
            threeFingerSwipeDown: .minimap
        ),
        workspaces: WorkspacesConfig(
            maxWorkspaces: 10,
            defaultLabels: ["Main", "Work", "Chat", "Code", "Mail"]
        )
    )

    /// Initialize config from file or defaults
    public init() {
        // Determine config location: ~/.config/paperframe/config.json (XDG Base Directory spec)
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let configDir = homeDir.appendingPathComponent(".config/paperframe", isDirectory: true)
        self.configURL = configDir.appendingPathComponent("config.json")

        // Ensure config directory exists
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        // Load config or use defaults
        if let loaded = Self.loadConfig(from: configURL) {
            self.config = loaded
        } else {
            // No config file - use defaults and save them
            self.config = Self.defaultConfig
            save()
        }
    }

    private static func loadConfig(from url: URL) -> Config? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(Config.self, from: data)
        } catch {
            print("Warning: Failed to load config: \(error)")
            return nil
        }
    }

    /// Save current config to file
    public func save() {
        do {
            // Ensure directory exists
            let dir = configURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configURL)
        } catch {
            print("Error: Failed to save config: \(error)")
        }
    }

    /// Reset to defaults
    public func resetToDefaults() {
        config = Self.defaultConfig
        save()
    }

    /// Reload from file
    public func reload() {
        if let loaded = Self.loadConfig(from: configURL) {
            config = loaded
        }
    }
}

// MARK: - Config Models

public struct Config: Codable {
    public var version: String
    public var shortcuts: ShortcutsConfig
    public var behavior: BehaviorConfig
    public var gestures: GesturesConfig
    public var workspaces: WorkspacesConfig

    public init(
        version: String = "1.0.0",
        shortcuts: ShortcutsConfig = ShortcutsConfig(),
        behavior: BehaviorConfig = BehaviorConfig(),
        gestures: GesturesConfig = GesturesConfig(),
        workspaces: WorkspacesConfig = WorkspacesConfig()
    ) {
        self.version = version
        self.shortcuts = shortcuts
        self.behavior = behavior
        self.gestures = gestures
        self.workspaces = workspaces
    }
}

public struct ShortcutsConfig: Codable {
    public var modifier: ModifierMode
    public var switchWorkspaceLeft: KeyBinding
    public var switchWorkspaceRight: KeyBinding
    public var switchWorkspaceUp: KeyBinding
    public var switchWorkspaceDown: KeyBinding
    public var goToWorkspace1: KeyBinding
    public var goToWorkspace2: KeyBinding
    public var goToWorkspace3: KeyBinding
    public var goToWorkspace4: KeyBinding
    public var goToWorkspace5: KeyBinding
    public var goToWorkspace6: KeyBinding
    public var goToWorkspace7: KeyBinding
    public var goToWorkspace8: KeyBinding
    public var goToWorkspace9: KeyBinding
    public var newWorkspace: KeyBinding
    public var renameWorkspace: KeyBinding
    public var removeWorkspace: KeyBinding
    public var showMinimap: KeyBinding
    public var showSwitcher: KeyBinding
    public var hideWindow: KeyBinding
    public var toggleFullscreen: KeyBinding
    public var toggleFloat: KeyBinding

    public init(
        modifier: ModifierMode = .ctrlOption,
        switchWorkspaceLeft: KeyBinding = KeyBinding(key: .leftArrow, modifiers: [.ctrl, .option]),
        switchWorkspaceRight: KeyBinding = KeyBinding(key: .rightArrow, modifiers: [.ctrl, .option]),
        switchWorkspaceUp: KeyBinding = KeyBinding(key: .upArrow, modifiers: [.ctrl, .option]),
        switchWorkspaceDown: KeyBinding = KeyBinding(key: .downArrow, modifiers: [.ctrl, .option]),
        goToWorkspace1: KeyBinding = KeyBinding(key: .one, modifiers: [.ctrl, .option]),
        goToWorkspace2: KeyBinding = KeyBinding(key: .two, modifiers: [.ctrl, .option]),
        goToWorkspace3: KeyBinding = KeyBinding(key: .three, modifiers: [.ctrl, .option]),
        goToWorkspace4: KeyBinding = KeyBinding(key: .four, modifiers: [.ctrl, .option]),
        goToWorkspace5: KeyBinding = KeyBinding(key: .five, modifiers: [.ctrl, .option]),
        goToWorkspace6: KeyBinding = KeyBinding(key: .six, modifiers: [.ctrl, .option]),
        goToWorkspace7: KeyBinding = KeyBinding(key: .seven, modifiers: [.ctrl, .option]),
        goToWorkspace8: KeyBinding = KeyBinding(key: .eight, modifiers: [.ctrl, .option]),
        goToWorkspace9: KeyBinding = KeyBinding(key: .nine, modifiers: [.ctrl, .option]),
        newWorkspace: KeyBinding = KeyBinding(key: .n, modifiers: [.ctrl, .option]),
        renameWorkspace: KeyBinding = KeyBinding(key: .r, modifiers: [.ctrl, .option]),
        removeWorkspace: KeyBinding = KeyBinding(key: .delete, modifiers: [.ctrl, .option]),
        showMinimap: KeyBinding = KeyBinding(key: .m, modifiers: [.ctrl, .option]),
        showSwitcher: KeyBinding = KeyBinding(key: .slash, modifiers: [.ctrl, .option]),
        hideWindow: KeyBinding = KeyBinding(key: .h, modifiers: [.ctrl, .option]),
        toggleFullscreen: KeyBinding = KeyBinding(key: .f, modifiers: [.ctrl, .option]),
        toggleFloat: KeyBinding = KeyBinding(key: .t, modifiers: [.ctrl, .option])
    ) {
        self.modifier = modifier
        self.switchWorkspaceLeft = switchWorkspaceLeft
        self.switchWorkspaceRight = switchWorkspaceRight
        self.switchWorkspaceUp = switchWorkspaceUp
        self.switchWorkspaceDown = switchWorkspaceDown
        self.goToWorkspace1 = goToWorkspace1
        self.goToWorkspace2 = goToWorkspace2
        self.goToWorkspace3 = goToWorkspace3
        self.goToWorkspace4 = goToWorkspace4
        self.goToWorkspace5 = goToWorkspace5
        self.goToWorkspace6 = goToWorkspace6
        self.goToWorkspace7 = goToWorkspace7
        self.goToWorkspace8 = goToWorkspace8
        self.goToWorkspace9 = goToWorkspace9
        self.newWorkspace = newWorkspace
        self.renameWorkspace = renameWorkspace
        self.removeWorkspace = removeWorkspace
        self.showMinimap = showMinimap
        self.showSwitcher = showSwitcher
        self.hideWindow = hideWindow
        self.toggleFullscreen = toggleFullscreen
        self.toggleFloat = toggleFloat
    }
}

public struct BehaviorConfig: Codable {
    public var autoCreateWorkspace: Bool
    public var animateTransitions: Bool
    public var showHUD: Bool
    public var hudDuration: Double
    public var persistWorkspaceState: Bool
    public var defaultLayout: LayoutMode

    public init(
        autoCreateWorkspace: Bool = false,
        animateTransitions: Bool = true,
        showHUD: Bool = true,
        hudDuration: Double = 1.5,
        persistWorkspaceState: Bool = true,
        defaultLayout: LayoutMode = .horizontal
    ) {
        self.autoCreateWorkspace = autoCreateWorkspace
        self.animateTransitions = animateTransitions
        self.showHUD = showHUD
        self.hudDuration = hudDuration
        self.persistWorkspaceState = persistWorkspaceState
        self.defaultLayout = defaultLayout
    }
}

public struct GesturesConfig: Codable {
    public var enabled: Bool
    public var threeFingerSwipeLeft: GestureAction
    public var threeFingerSwipeRight: GestureAction
    public var threeFingerSwipeUp: GestureAction
    public var threeFingerSwipeDown: GestureAction

    public init(
        enabled: Bool = true,
        threeFingerSwipeLeft: GestureAction = .switchLeft,
        threeFingerSwipeRight: GestureAction = .switchRight,
        threeFingerSwipeUp: GestureAction = .showSwitcher,
        threeFingerSwipeDown: GestureAction = .minimap
    ) {
        self.enabled = enabled
        self.threeFingerSwipeLeft = threeFingerSwipeLeft
        self.threeFingerSwipeRight = threeFingerSwipeRight
        self.threeFingerSwipeUp = threeFingerSwipeUp
        self.threeFingerSwipeDown = threeFingerSwipeDown
    }
}

public struct WorkspacesConfig: Codable {
    public var maxWorkspaces: Int
    public var defaultLabels: [String]

    public init(maxWorkspaces: Int = 10, defaultLabels: [String] = ["Main", "Work", "Chat", "Code", "Mail"]) {
        self.maxWorkspaces = maxWorkspaces
        self.defaultLabels = defaultLabels
    }
}

// MARK: - Enums

public enum ModifierMode: String, Codable {
    case ctrlOption = "ctrlOption"
    case option = "option"
    case meh = "meh"
}

public enum LayoutMode: String, Codable {
    case horizontal
    case vertical
    case grid
    case full
}

public enum GestureAction: String, Codable {
    case switchLeft
    case switchRight
    case showSwitcher
    case minimap
    case none
}

public enum Key: String, Codable {
    case one, two, three, four, five, six, seven, eight, nine
    case a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z
    case leftArrow, rightArrow, upArrow, downArrow
    case delete, tab, escape, slash
    case space, enter
}

public struct KeyBinding: Codable {
    public var key: Key
    public var modifiers: [KeyModifier]

    public init(key: Key, modifiers: [KeyModifier] = []) {
        self.key = key
        self.modifiers = modifiers
    }
}

public enum KeyModifier: String, Codable {
    case ctrl
    case option
    case shift
    case command
}