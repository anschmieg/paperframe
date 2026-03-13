import ApplicationServices
import CoreGraphics
import PaperWMCore

/// Production implementation of `PermissionsServiceProtocol`.
///
/// Uses real macOS public APIs to probe and request system permissions:
/// - **Accessibility**: `AXIsProcessTrustedWithOptions` (ApplicationServices)
/// - **Input Monitoring**: `CGPreflightListenEventAccess` / `CGRequestListenEventAccess`
///   (CoreGraphics) — see `probeInputMonitoring()` for documented limitations.
///
/// Thread-safety: All mutations occur on the caller's thread. If `refresh()` is
/// called from multiple threads, guard calls externally. Typically called from
/// the main thread on launch and when returning from System Settings.
public final class PermissionsService: PermissionsServiceProtocol {

    // MARK: - State

    /// The last probed permission state. Updated by `refresh()`.
    public private(set) var currentState: PermissionsState

    // MARK: - Init

    /// Creates a new instance and performs an initial permission probe.
    public init() {
        // Start with the conservative default; probe immediately.
        currentState = .notDetermined
        refresh()
    }

    // MARK: - Convenience accessors

    public var accessibilityGranted: Bool { currentState.accessibility == .granted }
    public var inputMonitoringGranted: Bool { currentState.inputMonitoring == .granted }

    // MARK: - PermissionsServiceProtocol

    /// Re-probes all system permissions and updates `currentState`.
    ///
    /// Call this on app launch and whenever the user returns from System Settings.
    /// Does **not** show any system prompt.
    public func refresh() {
        currentState = PermissionsState(
            accessibility: probeAccessibility(),
            inputMonitoring: probeInputMonitoring()
        )
    }

    /// Triggers the Accessibility permission system prompt if the process is not yet trusted.
    ///
    /// Uses `AXIsProcessTrustedWithOptions` with `kAXTrustedCheckOptionPrompt: true`.
    /// On macOS 13+ this opens the Accessibility section in System Settings if needed.
    public func requestAccessibilityPermission() {
        // Passing the prompt option shows the system dialog when not trusted.
        // The return value is discarded here — call refresh() to read updated state.
        _ = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt: true] as CFDictionary
        )
    }

    /// Requests Input Monitoring permission.
    ///
    /// Uses `CGRequestListenEventAccess()` to trigger the system prompt.
    ///
    /// NOTE: On macOS 10.15+ the system may silently ignore this call if the
    /// TCC database already has a decision recorded. In that case, direct the
    /// user to System Settings > Privacy & Security > Input Monitoring.
    ///
    /// TODO: Evaluate whether `IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)`
    /// provides a more reliable prompt path across all macOS 13+ configurations.
    public func requestInputMonitoringPermission() {
        _ = CGRequestListenEventAccess()
    }

    // MARK: - Private probing

    /// Checks whether the process is trusted for Accessibility API operations.
    ///
    /// Calls `AXIsProcessTrustedWithOptions(nil)` — no prompt is shown.
    private func probeAccessibility() -> PermissionStatus {
        AXIsProcessTrustedWithOptions(nil) ? .granted : .denied
    }

    /// Checks whether the process may receive global Input Monitoring events.
    ///
    /// Uses `CGPreflightListenEventAccess()`, a public CoreGraphics API available
    /// since macOS 10.15.
    ///
    /// **Known limitation**: `CGPreflightListenEventAccess()` returns `false` both
    /// when the user has explicitly denied access *and* when the permission dialog
    /// has never been shown. The two states cannot be reliably distinguished without
    /// triggering a prompt or reading the TCC database (a private API).
    ///
    /// Conservative policy: map `false` to `.notDetermined` rather than `.denied`
    /// so that the UI can offer to request access rather than silently giving up.
    ///
    /// TODO: Investigate `IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)` from IOKit
    /// as a potential way to distinguish `denied` from `notDetermined` on macOS 13+.
    private func probeInputMonitoring() -> PermissionStatus {
        CGPreflightListenEventAccess() ? .granted : .notDetermined
    }
}
