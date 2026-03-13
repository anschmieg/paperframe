import Foundation

// MARK: - App descriptor

/// Describes the macOS application that owns a window.
public struct AppDescriptor: Hashable, Sendable {
    /// The bundle identifier (e.g. "com.apple.Safari"). May be empty for agent processes.
    public let bundleID: String
    /// Human-readable display name.
    public let displayName: String
    /// Unix process identifier.
    public let pid: Int32

    public init(bundleID: String, displayName: String, pid: Int32) {
        self.bundleID = bundleID
        self.displayName = displayName
        self.pid = pid
    }
}

// MARK: - Window capabilities

/// Bitmask of operations the window manager can perform on a window.
///
/// Populated by capability probing (AX attribute reads) before any write attempt.
public struct WindowCapabilities: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Window position can be set via AX.
    public static let canMove     = WindowCapabilities(rawValue: 1 << 0)
    /// Window size can be set via AX.
    public static let canResize   = WindowCapabilities(rawValue: 1 << 1)
    /// Window can be minimized via AX.
    public static let canMinimize = WindowCapabilities(rawValue: 1 << 2)
    /// Window can be focused via AX.
    public static let canFocus    = WindowCapabilities(rawValue: 1 << 3)
    /// Window can be closed via AX.
    public static let canClose    = WindowCapabilities(rawValue: 1 << 4)
}

// MARK: - Window eligibility

/// Whether the window manager should manage this window.
public enum WindowEligibility: Sendable {
    /// Window passes all eligibility checks.
    case eligible
    /// Window is explicitly excluded from management.
    case ineligible(reason: String)
    /// Eligibility has not yet been determined.
    case unknown
}

// MARK: - Live window snapshot

/// Immutable point-in-time snapshot of a window as observed by the AX layer.
///
/// This is the runtime source of truth. All planning must be based on a recent
/// snapshot, never on cached or inferred state.
public struct ManagedWindowSnapshot: Sendable {
    /// Stable identifier for the window.
    public let windowID: ManagedWindowID
    /// The app that owns this window.
    public let app: AppDescriptor
    /// The window's current frame in screen (display) coordinates.
    public let frameOnDisplay: CGRect
    /// The display the window is primarily on.
    public let displayID: DisplayID
    /// AX-probed capability flags.
    public let capabilities: WindowCapabilities
    /// Whether the window passes eligibility checks.
    public let eligibility: WindowEligibility
    /// Whether the window is currently minimized.
    public let isMinimized: Bool
    /// Whether the window is currently the key/focused window.
    public let isFocused: Bool

    public init(
        windowID: ManagedWindowID,
        app: AppDescriptor,
        frameOnDisplay: CGRect,
        displayID: DisplayID,
        capabilities: WindowCapabilities,
        eligibility: WindowEligibility,
        isMinimized: Bool = false,
        isFocused: Bool = false
    ) {
        self.windowID = windowID
        self.app = app
        self.frameOnDisplay = frameOnDisplay
        self.displayID = displayID
        self.capabilities = capabilities
        self.eligibility = eligibility
        self.isMinimized = isMinimized
        self.isFocused = isFocused
    }
}
