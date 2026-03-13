import Foundation
import PaperWMCore

/// Stub implementation of `PlacementTransactionEngineProtocol`.
///
/// In a real implementation this iterates over `PlacementPlan.intents`,
/// reads the current window state, computes the minimal delta, writes it via
/// the AX adapter, and verifies the result.
///
/// TODO (Phase 3): Inject real `AXAdapterStub` / adapter.
/// TODO (Phase 3): Implement read → delta → write → verify loop.
/// TODO (Phase 3): Implement retry-once policy and degradation on persistent failure.
public final class PlacementTransactionEngineStub: PlacementTransactionEngineProtocol {

    public init() {}

    /// Executes all intents in the plan. Currently returns an empty report.
    ///
    /// TODO: For each intent:
    ///   1. Read current AX frame.
    ///   2. If delta is meaningful, write position and size.
    ///   3. Verify the frame changed within tolerance.
    ///   4. Retry once if verification fails.
    ///   5. Record result (success / resisted / failed).
    public func execute(plan: PlacementPlan) async -> PlacementExecutionReport {
        // TODO: Real implementation performs AX writes.
        return PlacementExecutionReport()
    }
}
