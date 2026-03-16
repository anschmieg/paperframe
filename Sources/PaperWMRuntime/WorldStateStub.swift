import Foundation
import PaperWMCore

/// Stub implementation of `WorldStateProtocol`.
///
/// Stores paper-space metadata in memory. In a real implementation this
/// delegates persistence to `PersistenceStoreProtocol`.
///
/// Workspaces are stored by their `WorkspaceID`. Each display tracks its
/// currently-active workspace ID independently, enabling per-display
/// workspace switching without cross-display interference.
///
/// TODO (Phase 5): Load initial state from `PersistenceStoreProtocol` on init.
/// TODO (Phase 5): Write through to persistence on every mutation.
public final class WorldStateStub: WorldStateProtocol {

    private var paperWindowStates: [ManagedWindowID: PaperWindowState] = [:]

    /// All registered workspaces keyed by their workspace ID.
    private var workspaceStorage: [WorkspaceID: WorkspaceState] = [:]

    /// The active workspace ID for each display.
    private var activeWorkspaceIDs: [DisplayID: WorkspaceID] = [:]

    public init() {}

    // MARK: - WorldStateProtocol

    public func paperWindowState(for id: ManagedWindowID) -> PaperWindowState? {
        paperWindowStates[id]
    }

    public func updatePaperWindowState(_ state: PaperWindowState) {
        paperWindowStates[state.windowID] = state
    }

    public func activeWorkspace(for displayID: DisplayID) -> WorkspaceState? {
        guard let activeID = activeWorkspaceIDs[displayID] else { return nil }
        return workspaceStorage[activeID]
    }

    /// Stores the workspace and makes it the active workspace for its display.
    ///
    /// If a workspace with the same `workspaceID` already exists it is replaced.
    /// This always sets the stored workspace as the active one for `state.displayID`,
    /// preserving the pre-Milestone-11 single-workspace-per-display semantics.
    public func updateWorkspaceState(_ state: WorkspaceState) {
        workspaceStorage[state.workspaceID] = state
        activeWorkspaceIDs[state.displayID] = state.workspaceID
    }

    /// Switches the active workspace for `displayID` to the workspace identified by `workspaceID`.
    ///
    /// The workspace must already be registered via `updateWorkspaceState(_:)`.
    /// - Returns: `true` when the active workspace changed; `false` when the workspace is unknown.
    @discardableResult
    public func setActiveWorkspace(_ workspaceID: WorkspaceID, for displayID: DisplayID) -> Bool {
        guard workspaceStorage[workspaceID] != nil else { return false }
        activeWorkspaceIDs[displayID] = workspaceID
        return true
    }

    /// Returns all workspaces registered for `displayID`, in unspecified order.
    public func allWorkspaces(for displayID: DisplayID) -> [WorkspaceState] {
        workspaceStorage.values.filter { $0.displayID == displayID }
    }
}
