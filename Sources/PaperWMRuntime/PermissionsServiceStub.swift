import Foundation
import PaperWMCore

/// Stub implementation of `PermissionsServiceProtocol`.
///
/// Returns safe conservative defaults (all permissions not determined).
/// Used in tests and as a compile-time placeholder before the real
/// `PermissionsService` from PaperWMMacAdapters is wired in.
///
/// TODO (Phase 1): Wire `PermissionsService` (PaperWMMacAdapters) into AppDelegate.
public final class PermissionsServiceStub: PermissionsServiceProtocol {

    /// The current permission state. Defaults to `.notDetermined` for all permissions.
    public private(set) var currentState: PermissionsState

    public init(initialState: PermissionsState = .notDetermined) {
        self.currentState = initialState
    }

    // MARK: - Convenience accessors

    /// Hard-coded to `false`; real implementation reads from the system.
    public var accessibilityGranted: Bool { currentState.accessibility == .granted }

    /// Hard-coded to `false`; real implementation reads from the system.
    public var inputMonitoringGranted: Bool { currentState.inputMonitoring == .granted }

    // MARK: - PermissionsServiceProtocol

    /// No-op in the stub — `currentState` is not updated.
    public func refresh() {
        // Stub: no system probe; state remains as initialised.
    }

    /// No-op in the stub; does not trigger any system dialog.
    public func requestAccessibilityPermission() {
        // TODO: Handled by PermissionsService in PaperWMMacAdapters.
    }

    /// No-op in the stub; does not trigger any system dialog.
    public func requestInputMonitoringPermission() {
        // TODO: Handled by PermissionsService in PaperWMMacAdapters.
    }
}
