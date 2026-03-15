import Foundation
import PaperWMCore

/// Stub implementation of `WorldStateProtocol`.
///
/// Stores paper-space metadata in memory. In a real implementation this
/// delegates persistence to `PersistenceStoreProtocol`.
///
/// TODO (Phase 5): Load initial state from `PersistenceStoreProtocol` on init.
/// TODO (Phase 5): Write through to persistence on every mutation.
public final class WorldStateStub: WorldStateProtocol {

    private var paperWindowStates: [ManagedWindowID: PaperWindowState] = [:]
    private var workspaceStates: [DisplayID: WorkspaceState] = [:]

    public init() {}

    // MARK: - WindowStateProtocol

    public func paperWindowState(for id: ManagedWindowID) -> PaperWindowState? {
        paperWindowStates[id]
    }

    public func updatePaperWindowState(_ state: PaperWindowState) {
        paperWindowStates[state.windowID] = state
    }

    public func activeWorkspace(for displayID: DisplayID) -> WorkspaceState? {
        workspaceStates[displayID]
    }

    public func updateWorkspaceState(_ state: WorkspaceState) {
        workspaceStates[state.displayID] = state
    }
}
