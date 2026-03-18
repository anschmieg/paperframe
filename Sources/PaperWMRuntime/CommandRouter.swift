import Foundation
import PaperWMCore

/// Routes semantic commands from the UI and global hotkeys into the runtime.
///
/// This is the central dispatch point for user-initiated `WMCommand`s.  Each
/// command is matched to the appropriate runtime coordinator and executed
/// asynchronously on the main actor.
///
/// Currently handled commands:
/// - `.switchWorkspace(displayID:to:)`  → `WorkspaceSwitchCoordinator`
/// - `.renameWorkspace(workspaceID:newLabel:)` → `WorldStateProtocol`
/// - `.createWorkspace(displayID:label:)` → `WorldStateProtocol`
/// - `.removeWorkspace(workspaceID:)` → `WorldStateProtocol`
/// - `.refreshInventory`                → `ReconciliationTriggering` (`.manualRefresh`)
///
/// All other commands are no-ops with TODO placeholders until the corresponding
/// coordinators are implemented.
@MainActor
public final class CommandRouter: CommandRouterProtocol {

    private let worldState: any WorldStateProtocol
    private let workspaceSwitchCoordinator: WorkspaceSwitchCoordinator
    private let reconciliationCoordinator: any ReconciliationTriggering

    public init(
        worldState: any WorldStateProtocol,
        workspaceSwitchCoordinator: WorkspaceSwitchCoordinator,
        reconciliationCoordinator: any ReconciliationTriggering
    ) {
        self.worldState = worldState
        self.workspaceSwitchCoordinator = workspaceSwitchCoordinator
        self.reconciliationCoordinator = reconciliationCoordinator
    }

    // MARK: - CommandRouterProtocol

    /// Routes `command` to the appropriate runtime coordinator.
    ///
    /// Returns immediately; the coordinator work is dispatched asynchronously on
    /// the main actor.  Use `handle(command:)` directly from async contexts (e.g.
    /// tests) when you need to await completion.
    public func route(command: WMCommand) {
        Task { [self] in
            await handle(command: command)
        }
    }

    // MARK: - Internal

    /// Dispatches `command` to the appropriate coordinator and awaits completion.
    ///
    /// This is the async entry point used by tests and by the fire-and-forget
    /// `route(command:)` implementation above.
    func handle(command: WMCommand) async {
        switch command {
        case .switchWorkspace(let displayID, let workspaceID):
            await workspaceSwitchCoordinator.switchWorkspace(to: workspaceID, for: displayID)

        case .renameWorkspace(let workspaceID, let newLabel):
            worldState.renameWorkspace(workspaceID, newLabel: newLabel)

        case .createWorkspace(let displayID, let label):
            worldState.createWorkspace(displayID: displayID, label: label)

        case .removeWorkspace(let workspaceID):
            worldState.removeWorkspace(workspaceID)

        case .refreshInventory:
            await reconciliationCoordinator.reconcile(reason: .manualRefresh)

        case .moveWindow(let windowID, let direction):
            await moveWindow(windowID: windowID, direction: direction)

        case .focusWindow:
            // TODO: Implement focus window tracking
            break

        case .resizeWindow, .minimizeWindow, .unminimizeWindow, .cycleWindows, .toggleFullscreen:
            // TODO: Route to the appropriate coordinator when implemented.
            break
        }
    }

    // MARK: - Window Movement

    /// Moves a window to an adjacent workspace in the given direction.
    ///
    /// The window is removed from its current workspace and added to the target workspace.
    /// Workspaces are ordered by UUID string; "left" moves to the previous workspace,
    /// "right" moves to the next workspace.
    ///
    /// - Parameters:
    ///   - windowID: The window to move.
    ///   - direction: The direction to move (left/right for workspace navigation).
    private func moveWindow(windowID: ManagedWindowID, direction: Direction) async {
        // Get the window's current state to find which workspace it belongs to
        guard let windowState = worldState.paperWindowState(for: windowID) else { return }

        let currentWorkspaceID = windowState.workspaceID

        // Get all displays that have workspaces
        let displayIDs = worldState.allDisplayIDs()

        // For Phase 1 (single display), use the first display
        // TODO: In multi-display mode, determine which display the window is on
        guard let displayID = displayIDs.first else { return }

        // Get ordered workspaces for this display
        let orderedWorkspaceIDs = worldState.orderedWorkspaceIDs(for: displayID)

        // Find current workspace index
        guard let currentIndex = orderedWorkspaceIDs.firstIndex(of: currentWorkspaceID) else {
            return
        }

        // Calculate target index based on direction
        let targetIndex: Int
        switch direction {
        case .left, .up:
            targetIndex = max(0, currentIndex - 1)
        case .right, .down:
            targetIndex = min(orderedWorkspaceIDs.count - 1, currentIndex + 1)
        }

        // If same workspace, no-op
        guard targetIndex != currentIndex else { return }

        let targetWorkspaceID = orderedWorkspaceIDs[targetIndex]

        // Move the window
        worldState.moveWindow(windowID, toWorkspace: targetWorkspaceID)

        // Trigger reconciliation to apply the change
        await reconciliationCoordinator.reconcile(reason: .userCommand(.moveWindow(windowID, direction: direction)))
    }
}
