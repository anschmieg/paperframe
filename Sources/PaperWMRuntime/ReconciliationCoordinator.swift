import Foundation
import PaperWMCore

/// Orchestrates a single deterministic reconciliation pass.
///
/// One call to `reconcile(reason:)` performs the full pipeline:
/// 1. Records the trigger in diagnostics (when mappable to a `WMEvent`).
/// 2. Refreshes the window inventory.
/// 3. Reads the current display topology.
/// 4. Asks the planner to compute a `PlacementPlan`.
/// 5. Executes the plan via the transaction engine.
/// 6. Records any placement failures in diagnostics.
/// 7. Returns a `ReconcileResult` capturing all key metrics.
///
/// This class is intentionally thin — it delegates all domain logic to its
/// injected collaborators. It has no event-driven wiring and no mutable state
/// of its own, making it easy to unit test in isolation.
///
/// TODO (Phase 4): Integrate with an `ObserverAndReconcileHubProtocol` so that
///                 AX and Space change events automatically trigger reconcile passes.
public final class ReconciliationCoordinator {

    private let inventoryService: any WindowInventoryServiceProtocol
    private let topologyProvider: any DisplayTopologyProviderProtocol
    private let planner: any ProjectionPlannerProtocol
    private let engine: any PlacementTransactionEngineProtocol
    private let worldState: any WorldStateProtocol
    private let diagnostics: any DiagnosticsServiceProtocol

    /// Creates the coordinator with all required collaborators.
    ///
    /// - Parameters:
    ///   - inventoryService: Refreshed at the start of every reconcile pass.
    ///   - topologyProvider: Queried once per pass for the current display layout.
    ///   - planner: Converts snapshots + topology + world state → placement plan.
    ///   - engine: Executes the placement plan against live windows.
    ///   - worldState: Paper-space metadata queried by the planner.
    ///   - diagnostics: Receives trigger events and placement failures.
    public init(
        inventoryService: any WindowInventoryServiceProtocol,
        topologyProvider: any DisplayTopologyProviderProtocol,
        planner: any ProjectionPlannerProtocol,
        engine: any PlacementTransactionEngineProtocol,
        worldState: any WorldStateProtocol,
        diagnostics: any DiagnosticsServiceProtocol
    ) {
        self.inventoryService = inventoryService
        self.topologyProvider = topologyProvider
        self.planner = planner
        self.engine = engine
        self.worldState = worldState
        self.diagnostics = diagnostics
    }

    // MARK: - Reconcile

    /// Performs one full reconciliation pass and returns a structured result.
    ///
    /// This method is `async` because both inventory refresh and plan execution
    /// may perform asynchronous AX operations.
    public func reconcile(reason: ReconcileReason) async -> ReconcileResult {
        // 1. Record trigger event in diagnostics where a WMEvent mapping exists.
        if let event = wmEvent(for: reason) {
            diagnostics.record(event: event)
        }

        // 2. Refresh window inventory so the planner sees current state.
        await inventoryService.refreshSnapshot()

        // 3. Capture the inventory snapshot and display topology at this instant.
        let snapshots = inventoryService.snapshots
        let topology = topologyProvider.currentTopology()

        // 4. Compute the placement plan (pure function — no side effects).
        let plan = planner.computePlan(
            snapshots: snapshots,
            topology: topology,
            worldState: worldState
        )

        // 5. Execute the plan; the engine handles permission gating and AX writes.
        let executionReport = await engine.execute(plan: plan)

        // 6. Record any placement failures so they appear in the diagnostics report.
        for result in executionReport.results {
            switch result {
            case .failed, .resistedByApp, .capabilityMissing:
                diagnostics.record(failure: result)
            case .success:
                break
            }
        }

        // 7. Return the structured result.
        return ReconcileResult(
            reason: reason,
            snapshotCount: snapshots.count,
            planIntentCount: plan.intents.count,
            executionReport: executionReport
        )
    }

    // MARK: - Private helpers

    /// Maps a `ReconcileReason` to a `WMEvent` for diagnostics recording.
    ///
    /// Cases that have no natural `WMEvent` equivalent (e.g. `startupInitialization`,
    /// `manualRefresh`, `userCommand`) return `nil` and are not recorded as events.
    private func wmEvent(for reason: ReconcileReason) -> WMEvent? {
        switch reason {
        case .event(let e):
            return e
        case .displayTopologyChanged:
            return .displayTopologyChanged
        case .activeSpaceChanged:
            return .activeSpaceChanged
        case .startupInitialization, .manualRefresh, .userCommand:
            return nil
        }
    }
}
