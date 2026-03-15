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

    /// Returns `true` when `currentState.accessibility == .granted`.
    /// Can be set directly for testing purposes.
    public var accessibilityGranted: Bool {
        get { currentState.accessibility == .granted }
        set {
            if newValue {
                currentState = PermissionsState(accessibility: .granted, inputMonitoring: currentState.inputMonitoring)
            } else {
                currentState = PermissionsState(accessibility: .denied, inputMonitoring: currentState.inputMonitoring)
            }
        }
    }

    /// Returns `true` when `currentState.inputMonitoring == .granted`.
    /// Can be set directly for testing purposes.
    public var inputMonitoringGranted: Bool {
        get { currentState.inputMonitoring == .granted }
        set {
            if newValue {
                currentState = PermissionsState(accessibility: currentState.accessibility, inputMonitoring: .granted)
            } else {
                currentState = PermissionsState(accessibility: currentState.accessibility, inputMonitoring: .notDetermined)
            }
        }
    }

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
