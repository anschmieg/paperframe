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
    /// Whether Accessibility permission is granted.
    public let accessibilityGranted: Bool
    /// Whether Input Monitoring permission is granted.
    public let inputMonitoringGranted: Bool
    /// Recent placement failures, if any.
    public let recentFailures: [PlacementResult]

    public init(
        recentEvents: [WMEvent] = [],
        managedWindowCount: Int = 0,
        accessibilityGranted: Bool = false,
        inputMonitoringGranted: Bool = false,
        recentFailures: [PlacementResult] = []
    ) {
        self.recentEvents = recentEvents
        self.managedWindowCount = managedWindowCount
        self.accessibilityGranted = accessibilityGranted
        self.inputMonitoringGranted = inputMonitoringGranted
        self.recentFailures = recentFailures
    }
}
