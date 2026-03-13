import Foundation
import PaperWMCore

/// Stub implementation of `DiagnosticsServiceProtocol`.
///
/// Keeps a bounded ring buffer of recent events and failures in memory.
/// In a real implementation this would also log to a file and expose an
/// inspector UI data source.
///
/// TODO (Phase 1): Expose diagnostics data to the inspector panel.
/// TODO (Phase 1): Add structured logging / os_log integration.
public final class DiagnosticsServiceStub: DiagnosticsServiceProtocol {

    private let eventCapacity: Int
    private var recentEvents: [WMEvent] = []
    private var recentFailures: [PlacementResult] = []

    public init(eventCapacity: Int = 50) {
        self.eventCapacity = eventCapacity
    }

    // MARK: - DiagnosticsServiceProtocol

    public func record(event: WMEvent) {
        recentEvents.insert(event, at: 0)
        if recentEvents.count > eventCapacity {
            recentEvents.removeLast()
        }
    }

    public func record(failure: PlacementResult) {
        recentFailures.insert(failure, at: 0)
        if recentFailures.count > eventCapacity {
            recentFailures.removeLast()
        }
    }

    public func currentReport(
        accessibilityGranted: Bool,
        inputMonitoringGranted: Bool,
        managedWindowCount: Int
    ) -> DiagnosticsReport {
        DiagnosticsReport(
            recentEvents: recentEvents,
            managedWindowCount: managedWindowCount,
            accessibilityGranted: accessibilityGranted,
            inputMonitoringGranted: inputMonitoringGranted,
            recentFailures: recentFailures
        )
    }
}
