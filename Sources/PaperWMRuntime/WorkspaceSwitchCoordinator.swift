import Foundation
import PaperWMCore

/// Coordinates a workspace switch: updates world state then triggers reconciliation.
///
/// A workspace switch is represented as a `WMCommand.switchWorkspace` user command
/// so that the reconciliation coordinator's reason book-keeping and diagnostics flow
/// remain consistent with other user-initiated actions.
///
/// Usage:
/// ```swift
/// let switcher = WorkspaceSwitchCoordinator(
///     worldState: worldState,
///     reconciliationCoordinator: coordinator
/// )
/// await switcher.switchWorkspace(to: targetWorkspaceID, for: displayID)
/// ```
///
/// Safety guarantees:
/// - Switching to the already-active workspace is a no-op (idempotent).
/// - Switching to an unknown workspace (not registered in world state) is a no-op.
/// - Per-display workspace state is independent; switching on one display does not
///   affect workspace state on other displays.
@MainActor
public final class WorkspaceSwitchCoordinator {

    private let worldState: any WorldStateProtocol
    private let reconciliationCoordinator: any ReconciliationTriggering

    public init(
        worldState: any WorldStateProtocol,
        reconciliationCoordinator: any ReconciliationTriggering
    ) {
        self.worldState = worldState
        self.reconciliationCoordinator = reconciliationCoordinator
    }

    // MARK: - Switch

    /// Switches the active paper workspace for `displayID` to `workspaceID` and triggers
    /// a reconciliation pass so the new workspace state is projected onto the display.
    ///
    /// - Parameters:
    ///   - workspaceID: The target workspace. Must be registered via
    ///     `worldState.updateWorkspaceState(_:)` before calling this method.
    ///   - displayID: The display whose active workspace should change.
    /// - Returns: The `ReconcileResult` produced after the switch, or `nil` when the
    ///   switch was skipped (workspace already active or workspace not found).
    @discardableResult
    public func switchWorkspace(
        to workspaceID: WorkspaceID,
        for displayID: DisplayID
    ) async -> ReconcileResult? {
        // Idempotent: skip when the requested workspace is already active.
        if let current = worldState.activeWorkspace(for: displayID),
            current.workspaceID == workspaceID
        {
            return nil
        }

        // Attempt the switch. Returns false when the workspace is not registered.
        guard worldState.setActiveWorkspace(workspaceID, for: displayID) else {
            return nil
        }

        // Trigger reconciliation so the planner uses the updated world state.
        return await reconciliationCoordinator.reconcile(
            reason: .userCommand(.switchWorkspace(displayID: displayID, to: workspaceID))
        )
    }
}
