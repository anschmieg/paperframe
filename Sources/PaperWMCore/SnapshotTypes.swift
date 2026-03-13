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

/// The set of operations the window manager can perform on a window.
///
/// Each field is independently probed via AX attribute reads before any write attempt.
/// Explicit Bool fields are preferred over a bitmask OptionSet here because:
/// - individual fields are directly readable in the debugger and diagnostic reports
/// - there is no semantic benefit from set-combination arithmetic on capabilities
/// - AX probing checks each attribute independently, mirroring this one-field-per-check layout
public struct WindowCapabilities: Sendable {
    /// Window position can be set via AX.
    public var canMove: Bool
    /// Window size can be set via AX.
    public var canResize: Bool
    /// Window can be minimized via AX.
    public var canMinimize: Bool
    /// Window can be focused via AX.
    public var canFocus: Bool
    /// Window can be closed via AX.
    public var canClose: Bool

    public init(
        canMove: Bool = false,
        canResize: Bool = false,
        canMinimize: Bool = false,
        canFocus: Bool = false,
        canClose: Bool = false
    ) {
        self.canMove = canMove
        self.canResize = canResize
        self.canMinimize = canMinimize
        self.canFocus = canFocus
        self.canClose = canClose
    }

    /// All capabilities set to false — the safe default before probing.
    public static let none = WindowCapabilities()
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
