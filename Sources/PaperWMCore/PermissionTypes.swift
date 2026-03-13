import Foundation

// MARK: - Permission status

/// The authorization state for a macOS system permission.
public enum PermissionStatus: Hashable, Sendable {
    /// The permission has been granted by the user.
    case granted
    /// The permission has been explicitly denied by the user.
    case denied
    /// The user has not yet been prompted, or the status cannot be reliably determined.
    case notDetermined
}

// MARK: - Permissions state

/// A point-in-time snapshot of all permission states relevant to the window manager.
///
/// Accessibility is required for all AX operations (window enumeration, move, resize, focus).
/// Input Monitoring is needed for global hotkey capture via event taps.
///
/// When Accessibility is not granted, the runtime enters reduced mode and cannot
/// perform any AX window operations. Input Monitoring is optional for core function.
public struct PermissionsState: Sendable {

    /// Whether the process is trusted for Accessibility API access.
    public let accessibility: PermissionStatus

    /// Whether the process may receive global Input Monitoring (keyboard/mouse) events.
    ///
    /// NOTE: Reliable detection of the "not determined" vs "denied" distinction is
    /// limited by available public APIs. Treat `.notDetermined` conservatively —
    /// see `PermissionsService.probeInputMonitoring()` in PaperWMMacAdapters for details.
    public let inputMonitoring: PermissionStatus

    public init(accessibility: PermissionStatus, inputMonitoring: PermissionStatus) {
        self.accessibility = accessibility
        self.inputMonitoring = inputMonitoring
    }

    // MARK: - Convenience

    /// `true` when Accessibility is granted — the minimum required for AX window operations.
    public var accessibilityAvailable: Bool { accessibility == .granted }

    /// `true` when both Accessibility and Input Monitoring are granted.
    public var isFullyGranted: Bool {
        accessibility == .granted && inputMonitoring == .granted
    }

    /// `true` when Accessibility is not granted.
    ///
    /// In this state the runtime operates in reduced mode: no AX window enumeration,
    /// placement, or focus operations are possible. Menu-bar fallback commands remain
    /// available; diagnostics remain active.
    public var isReducedMode: Bool { accessibility != .granted }

    // MARK: - Factory values

    /// Conservative safe default — all permissions unknown / not yet determined.
    public static let notDetermined = PermissionsState(
        accessibility: .notDetermined,
        inputMonitoring: .notDetermined
    )
}
