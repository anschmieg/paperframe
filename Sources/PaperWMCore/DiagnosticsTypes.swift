import Foundation

// MARK: - Diagnostics

/// A point-in-time report of the window manager's runtime state.
///
/// Populated by `DiagnosticsServiceProtocol` and surfaced to the UI inspector.
public struct DiagnosticsReport: Sendable {
    /// Recent events observed by the runtime, newest first.
    public let recentEvents: [WMEvent]
    /// Number of currently managed windows.
    public let managedWindowCount: Int
    /// Structured permission state at the time this report was generated.
    public let permissionsState: PermissionsState
    /// Recent placement failures, if any.
    public let recentFailures: [PlacementResult]

    /// Convenience: `true` when Accessibility permission is granted.
    public var accessibilityGranted: Bool { permissionsState.accessibility == .granted }
    /// Convenience: `true` when Input Monitoring permission is granted.
    public var inputMonitoringGranted: Bool { permissionsState.inputMonitoring == .granted }

    public init(
        recentEvents: [WMEvent] = [],
        managedWindowCount: Int = 0,
        permissionsState: PermissionsState = .notDetermined,
        recentFailures: [PlacementResult] = []
    ) {
        self.recentEvents = recentEvents
        self.managedWindowCount = managedWindowCount
        self.permissionsState = permissionsState
        self.recentFailures = recentFailures
    }
}
