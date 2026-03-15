import Foundation
import PaperWMCore

/// Production implementation of `PlacementTransactionEngineProtocol`.
///
/// Iterates over each intent in the plan, resolves the target window from the
/// current inventory, and applies position / size writes via the injected
/// `WindowMutatorProtocol`.
///
/// Behavior is conservative and explicit:
/// - Accessibility not granted → all intents fail immediately; no mutations attempted.
/// - Window absent from inventory → that intent fails; remaining intents continue.
/// - Window ineligible or missing capabilities → per-intent failure; others continue.
/// - AX write rejected by app → `resistedByApp` result; others continue.
/// - Partial success is accurately reported.
///
/// TODO: Add a retry-once policy for transient AX failures (Phase 4).
/// TODO: Integrate with the observer/reconciliation hub to drive planning cycles (Phase 4).
public final class PlacementTransactionEngine: PlacementTransactionEngineProtocol {

    private let permissionsService: any PermissionsServiceProtocol
    private let inventoryService: any WindowInventoryServiceProtocol
    private let mutator: any WindowMutatorProtocol

    /// Creates the engine with injectable dependencies.
    ///
    /// - Parameter permissionsService: Gates all AX operations. Must report
    ///   `accessibilityGranted == true` before any mutations are attempted.
    /// - Parameter inventoryService: Provides the current window snapshot list
    ///   used to resolve intent targets.
    /// - Parameter mutator: Applies individual intents to live windows.
    public init(
        permissionsService: any PermissionsServiceProtocol,
        inventoryService: any WindowInventoryServiceProtocol,
        mutator: any WindowMutatorProtocol
    ) {
        self.permissionsService = permissionsService
        self.inventoryService = inventoryService
        self.mutator = mutator
    }

    // MARK: - PlacementTransactionEngineProtocol

    public func execute(plan: PlacementPlan) async -> PlacementExecutionReport {
        // Permission gate: fail all intents cleanly without touching any window.
        guard permissionsService.accessibilityGranted else {
            let results = plan.intents.map {
                PlacementResult.failed(
                    windowID: $0.windowID,
                    reason: "Accessibility permission denied"
                )
            }
            return PlacementExecutionReport(
                results: results,
                appliedIntents: [],
                failedIntents: plan.intents
            )
        }

        // Fast path: nothing to do.
        guard !plan.intents.isEmpty else {
            return PlacementExecutionReport()
        }

        // Build a lookup table from the most-recent inventory snapshot.
        // O(n) construction; O(1) intent lookup.
        // When the inventory contains duplicate window IDs (which should not happen
        // in practice), the first occurrence wins to preserve deterministic behavior.
        var snapshotsByID: [ManagedWindowID: ManagedWindowSnapshot] = [:]
        for snapshot in inventoryService.snapshots {
            if snapshotsByID[snapshot.windowID] == nil {
                snapshotsByID[snapshot.windowID] = snapshot
            }
        }

        var results: [PlacementResult] = []
        var appliedIntents: [PlacementIntent] = []
        var failedIntents: [PlacementIntent] = []

        for intent in plan.intents {
            let result: PlacementResult

            if let snapshot = snapshotsByID[intent.windowID] {
                result = mutator.applyPlacement(intent: intent, snapshot: snapshot)
            } else {
                result = .failed(
                    windowID: intent.windowID,
                    reason: "Window not found in current inventory"
                )
            }

            results.append(result)
            if case .success = result {
                appliedIntents.append(intent)
            } else {
                failedIntents.append(intent)
            }
        }

        return PlacementExecutionReport(
            results: results,
            appliedIntents: appliedIntents,
            failedIntents: failedIntents
        )
    }
}
