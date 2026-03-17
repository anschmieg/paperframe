import Foundation
import PaperWMCore

/// Stub implementation of `WorldStateProtocol`.
///
/// Stores paper-space metadata in memory and, when a persistence store is
/// supplied, reads the previous state on init and writes through on every
/// mutation so that workspace configuration survives app restarts.
///
/// Workspaces are stored by their `WorkspaceID`. Each display tracks its
/// currently-active workspace ID independently, enabling per-display
/// workspace switching without cross-display interference.
///
/// ### Restore behaviour
/// On init, if `persistenceStore` is provided and `load()` returns a non-nil
/// `PersistedWorldState`, that snapshot is applied in this order:
/// 1. Paper-window states are inserted into the in-memory map.
/// 2. All workspace entries are inserted into the workspace registry.
/// 3. Active workspace IDs are restored per display — but only when the
///    referenced workspace actually exists in the registry *and* belongs to
///    that display.  Invalid / missing entries are silently dropped (fail-safe).
///
/// ### Write-through behaviour
/// Every successful mutation calls `persistenceStore?.save(currentSnapshot())`
/// so the persisted data is always consistent with in-memory state.  Save
/// failures are silently swallowed to avoid interrupting normal operation; a
/// future diagnostic layer can hook in here if needed.
public final class WorldStateStub: WorldStateProtocol {

    // MARK: - Storage

    private var paperWindowStates: [ManagedWindowID: PaperWindowState] = [:]

    /// All registered workspaces keyed by their workspace ID.
    private var workspaceStorage: [WorkspaceID: WorkspaceState] = [:]

    /// The active workspace ID for each display.
    private var activeWorkspaceIDs: [DisplayID: WorkspaceID] = [:]

    // MARK: - Persistence

    private let persistenceStore: (any WorldStatePersistenceStoreProtocol)?

    // MARK: - Init

    /// Creates a `WorldStateStub`, optionally backed by a persistence store.
    ///
    /// When `persistenceStore` is supplied the previously persisted world state
    /// (if any) is restored immediately during init.
    ///
    /// - Parameter persistenceStore: An optional store to use for loading and
    ///   writing world state.  Pass `nil` (the default) for a purely in-memory,
    ///   non-persistent instance — as used in most unit tests.
    public init(persistenceStore: (any WorldStatePersistenceStoreProtocol)? = nil) {
        self.persistenceStore = persistenceStore
        if let stored = persistenceStore?.load() {
            restore(from: stored)
        }
    }

    // MARK: - WorldStateProtocol

    public func paperWindowState(for id: ManagedWindowID) -> PaperWindowState? {
        paperWindowStates[id]
    }

    public func updatePaperWindowState(_ state: PaperWindowState) {
        paperWindowStates[state.windowID] = state
        persist()
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
        persist()
    }

    /// Switches the active workspace for `displayID` to the workspace identified by `workspaceID`.
    ///
    /// The workspace must already be registered via `updateWorkspaceState(_:)` **and**
    /// must belong to `displayID`. Cross-display workspace activation is rejected.
    /// - Returns: `true` when the active workspace changed; `false` when the workspace is
    ///   unknown or registered for a different display.
    @discardableResult
    public func setActiveWorkspace(_ workspaceID: WorkspaceID, for displayID: DisplayID) -> Bool {
        guard let workspace = workspaceStorage[workspaceID],
              workspace.displayID == displayID else { return false }
        activeWorkspaceIDs[displayID] = workspaceID
        persist()
        return true
    }

    /// Returns all workspaces registered for `displayID`, in unspecified order.
    public func allWorkspaces(for displayID: DisplayID) -> [WorkspaceState] {
        workspaceStorage.values.filter { $0.displayID == displayID }
    }

    /// Renames the workspace identified by `workspaceID`.
    ///
    /// Normalises the label: whitespace-only strings are treated as `nil` so that
    /// display-layer fallback labelling ("Workspace N") remains deterministic.
    /// Renaming an unknown workspace is a safe no-op; workspace identity, active
    /// workspace tracking, display ownership, and viewport state are unaffected.
    public func renameWorkspace(_ workspaceID: WorkspaceID, newLabel: String?) {
        guard workspaceStorage[workspaceID] != nil else { return }
        let trimmed = newLabel?.trimmingCharacters(in: .whitespaces)
        workspaceStorage[workspaceID]?.label = (trimmed?.isEmpty == false) ? trimmed : nil
        persist()
    }

    /// Creates and registers a new workspace on `displayID`.
    ///
    /// The new workspace is registered but does **not** become active; the
    /// current active workspace for the display (if any) is preserved.
    /// The label is normalised: whitespace-only or `nil` becomes `nil`.
    @discardableResult
    public func createWorkspace(displayID: DisplayID, label: String?) -> WorkspaceState {
        let trimmed = label?.trimmingCharacters(in: .whitespaces)
        let normalizedLabel: String? = (trimmed?.isEmpty == false) ? trimmed : nil
        let newID = WorkspaceID()
        let state = WorkspaceState(
            workspaceID: newID,
            displayID: displayID,
            viewport: ViewportState(displayID: displayID),
            label: normalizedLabel
        )
        workspaceStorage[newID] = state
        // Do not change the active workspace; preserve existing active selection.
        persist()
        return state
    }

    /// Removes the workspace identified by `workspaceID`.
    ///
    /// - Removing an unknown workspace is a safe no-op.
    /// - Removing the final remaining workspace on a display is rejected.
    /// - If the removed workspace is active, the replacement is the remaining
    ///   workspace with the lexicographically smallest UUID string (deterministic).
    @discardableResult
    public func removeWorkspace(_ workspaceID: WorkspaceID) -> Bool {
        guard let target = workspaceStorage[workspaceID] else { return false }
        let displayID = target.displayID
        let remaining = workspaceStorage.values.filter {
            $0.displayID == displayID && $0.workspaceID != workspaceID
        }
        // Reject removal if this is the last workspace on the display.
        guard !remaining.isEmpty else { return false }

        // Promote a replacement before removing, if needed.
        if activeWorkspaceIDs[displayID] == workspaceID {
            let replacement = remaining.min { $0.workspaceID.rawValue.uuidString < $1.workspaceID.rawValue.uuidString }!
            activeWorkspaceIDs[displayID] = replacement.workspaceID
        }

        workspaceStorage.removeValue(forKey: workspaceID)
        persist()
        return true
    }

    // MARK: - Private helpers

    /// Restores in-memory state from a previously persisted snapshot.
    ///
    /// Active workspace IDs are applied only when the referenced workspace
    /// exists in the restored registry **and** belongs to the correct display.
    private func restore(from snapshot: PersistedWorldState) {
        for windowState in snapshot.paperWindowStates {
            paperWindowStates[windowState.windowID] = windowState
        }
        for workspace in snapshot.workspaces {
            workspaceStorage[workspace.workspaceID] = workspace
        }
        for entry in snapshot.activeWorkspaces {
            guard
                let workspace = workspaceStorage[entry.workspaceID],
                workspace.displayID == entry.displayID
            else { continue }
            activeWorkspaceIDs[entry.displayID] = entry.workspaceID
        }
    }

    /// Captures the current in-memory state as a `PersistedWorldState` snapshot.
    private func currentSnapshot() -> PersistedWorldState {
        let activeEntries = activeWorkspaceIDs.map { displayID, workspaceID in
            ActiveWorkspaceEntry(displayID: displayID, workspaceID: workspaceID)
        }
        return PersistedWorldState(
            workspaces: Array(workspaceStorage.values),
            activeWorkspaces: activeEntries,
            paperWindowStates: Array(paperWindowStates.values)
        )
    }

    /// Writes the current snapshot to the persistence store.
    ///
    /// Save failures are silently swallowed to keep mutations non-throwing.
    private func persist() {
        guard let store = persistenceStore else { return }
        try? store.save(currentSnapshot())
    }
}
