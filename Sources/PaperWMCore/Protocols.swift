import Foundation

// MARK: - PermissionsService

/// Manages Accessibility and Input Monitoring permission state.
///
/// Must be the single authority on trust checks throughout the runtime.
/// All other services should query this before performing AX operations.
public protocol PermissionsServiceProtocol: AnyObject {
    /// The full structured permission state for all tracked permissions.
    ///
    /// Consumers should read this once and pass it down rather than re-probing repeatedly.
    var currentState: PermissionsState { get }

    /// Convenience: `true` when Accessibility permission has been granted.
    var accessibilityGranted: Bool { get }
    /// Convenience: `true` when Input Monitoring permission has been granted.
    var inputMonitoringGranted: Bool { get }

    /// Re-probes all system permissions and updates `currentState`.
    ///
    /// Call this on app launch and whenever the user returns from System Settings.
    func refresh()

    /// Triggers the system prompt for Accessibility permission if not already granted.
    func requestAccessibilityPermission()
    /// Triggers the system prompt for Input Monitoring permission if not already granted.
    func requestInputMonitoringPermission()
}

// MARK: - WindowInventoryService

/// Discovers and snapshots all candidate windows via the AX layer.
///
/// Acts as the bridge between the live AX world and the domain runtime.
/// Must probe capabilities before returning any snapshot.
@MainActor
public protocol WindowInventoryServiceProtocol: AnyObject {
    /// The most recent set of window snapshots.
    var snapshots: [ManagedWindowSnapshot] { get }

    /// Performs a full refresh of the window inventory from the AX layer.
    func refreshSnapshot() async
}

// MARK: - WorldState

/// Stores user intent and paper-space metadata for all managed windows.
///
/// This is the mutable layer that persists between reconciliation cycles.
/// It is *not* a live snapshot — it reflects desired/planned state.
public protocol WorldStateProtocol: AnyObject {
    /// Returns the paper-space state for the given window, or nil if unknown.
    func paperWindowState(for id: ManagedWindowID) -> PaperWindowState?
    /// Upserts the paper-space state for a window.
    func updatePaperWindowState(_ state: PaperWindowState)

    /// The currently focused window ID, or nil if no window is focused.
    var focusedWindowID: ManagedWindowID? { get set }

    /// Returns the active workspace for the given display.
    func activeWorkspace(for displayID: DisplayID) -> WorkspaceState?
    /// Updates the workspace state for a display.
    func updateWorkspaceState(_ state: WorkspaceState)

    /// Switches the active workspace for `displayID` to the workspace identified by `workspaceID`.
    ///
    /// The workspace must already be registered via `updateWorkspaceState(_:)` **and**
    /// must belong to `displayID`. Cross-display workspace activation is explicitly rejected.
    /// - Returns: `true` when the switch succeeded; `false` when the workspace is unknown
    ///   or registered for a different display (no-op).
    @discardableResult
    func setActiveWorkspace(_ workspaceID: WorkspaceID, for displayID: DisplayID) -> Bool

    /// Returns all workspaces registered for `displayID`, in unspecified order.
    func allWorkspaces(for displayID: DisplayID) -> [WorkspaceState]

    /// Returns all display IDs that have at least one workspace registered.
    ///
    /// This is useful for iterating over displays in multi-display scenarios.
    func allDisplayIDs() -> [DisplayID]

    /// Renames the workspace identified by `workspaceID`.
    ///
    /// Labels are presentation-only and do not affect workspace identity,
    /// active workspace tracking, display ownership, or viewport state.
    ///
    /// - Parameters:
    ///   - workspaceID: The workspace to rename. Unknown IDs are silently ignored.
    ///   - newLabel: The new display label. Whitespace-only or `nil` clears the
    ///     label so callers fall back to deterministic labeling (e.g. "Workspace N").
    func renameWorkspace(_ workspaceID: WorkspaceID, newLabel: String?)

    /// Creates and registers a new workspace on `displayID`.
    ///
    /// A fresh `WorkspaceID` is allocated internally; callers must not supply
    /// one. The new workspace is registered but does **not** become active — the
    /// existing active workspace for the display remains unchanged.
    ///
    /// - Parameters:
    ///   - displayID: The display to attach the new workspace to.
    ///   - label: An optional display label. Whitespace-only or `nil` is
    ///     normalised to `nil` so the display layer falls back to "Workspace N".
    /// - Returns: The newly created `WorkspaceState`.
    @discardableResult
    func createWorkspace(displayID: DisplayID, label: String?) -> WorkspaceState

    /// Removes the workspace identified by `workspaceID`.
    ///
    /// - Removing an unknown workspace is a safe no-op (returns `false`).
    /// - Removing the final remaining workspace on a display is rejected as a
    ///   safe no-op (returns `false`).
    /// - If the removed workspace is not currently active, the active workspace
    ///   for its display remains unchanged.
    /// - If the removed workspace is currently active, a deterministic
    ///   replacement is promoted (lowest UUID string among remaining workspaces).
    ///
    /// - Returns: `true` when the workspace was removed; `false` otherwise.
    @discardableResult
    func removeWorkspace(_ workspaceID: WorkspaceID) -> Bool

    /// Returns all workspace IDs for a display, sorted by UUID string order.
    ///
    /// This provides a deterministic ordering for workspace navigation.
    /// - Parameter displayID: The display to get workspaces for.
    /// - Returns: Workspace IDs in sorted order.
    func orderedWorkspaceIDs(for displayID: DisplayID) -> [WorkspaceID]

    /// Moves a window from its current workspace to a target workspace.
    ///
    /// - Parameters:
    ///   - windowID: The window to move.
    ///   - targetWorkspaceID: The destination workspace.
    /// - Returns: `true` if the move succeeded; `false` if the window or target
    ///   workspace doesn't exist.
    @discardableResult
    func moveWindow(_ windowID: ManagedWindowID, toWorkspace targetWorkspaceID: WorkspaceID) -> Bool
}

// MARK: - ProjectionPlanner

/// Computes desired `PlacementPlan` from live snapshots and paper-space state.
///
/// Must be a pure function: same inputs → same outputs. No side effects.
public protocol ProjectionPlannerProtocol: AnyObject {
    /// Computes a placement plan for all eligible windows.
    func computePlan(
        snapshots: [ManagedWindowSnapshot],
        topology: DisplayTopology,
        worldState: any WorldStateProtocol
    ) -> PlacementPlan
}

// MARK: - WindowMutator

/// Applies a single placement intent to a live window using platform-specific APIs.
///
/// On macOS, the production implementation uses the Accessibility API (AX) to
/// move and resize windows. The abstraction allows the orchestration engine to
/// be tested independently of live platform APIs.
public protocol WindowMutatorProtocol: AnyObject {
    /// Attempts to apply the given intent to the window described by `snapshot`.
    ///
    /// Returns `.success` when the intent was fully applied, or an explicit
    /// failure case when the window could not be moved or resized.
    func applyPlacement(intent: PlacementIntent, snapshot: ManagedWindowSnapshot) -> PlacementResult
}

// MARK: - PlacementTransactionEngine

/// Applies a `PlacementPlan` to real windows using transactional AX writes.
///
/// Each intent follows: read → compute delta → write → verify → degrade if needed.
@MainActor
public protocol PlacementTransactionEngineProtocol: AnyObject {
    /// Executes all intents in the plan and returns a summary report.
    func execute(plan: PlacementPlan) async -> PlacementExecutionReport
}

// MARK: - ObserverAndReconcileHub

/// Listens for AX, app lifecycle, display, and Space change events.
///
/// On each relevant event it triggers a targeted inventory refresh and
/// planning/execution cycle.
public protocol ObserverAndReconcileHubProtocol: AnyObject {
    /// Starts all observers and enters the reconciliation loop.
    func start()
    /// Stops all observers and tears down the reconciliation loop.
    func stop()

    // TODO: Add a structured event subscription mechanism (callbacks / AsyncStream).
}

// MARK: - CommandRouter

/// Routes semantic commands from the UI and global hotkeys into the runtime.
@MainActor
public protocol CommandRouterProtocol: AnyObject {
    /// Processes a window management command.
    func route(command: WMCommand)
}

// MARK: - RuleEngine

/// Applies per-app and per-user policy during eligibility and visibility decisions.
public protocol RuleEngineProtocol: AnyObject {
    /// Determines whether a window should be managed.
    func eligibility(for snapshot: ManagedWindowSnapshot) -> WindowEligibility
    /// Determines the visibility policy for a window.
    func visibilityPolicy(for snapshot: ManagedWindowSnapshot) -> VisibilityPolicy
}

// MARK: - PersistenceStore

/// Persists user preferences and paper-space metadata across launches.
public protocol PersistenceStoreProtocol: AnyObject {
    /// Loads persisted data from disk. Throws on unrecoverable decode errors.
    func load() throws
    /// Persists the current state to disk.
    func save() throws
}

// MARK: - DisplayTopologyProvider

/// Provides the current display topology snapshot.
///
/// Abstracts over `DisplayAdapter` (PaperWMMacAdapters) so that the runtime
/// coordinator can be tested without a real screen environment.
public protocol DisplayTopologyProviderProtocol: AnyObject {
    /// Returns the current display topology.
    func currentTopology() -> DisplayTopology
}

// MARK: - DiagnosticsService

/// Provides visibility into runtime state, events, and failures.
///
/// Must be usable from the earliest stages of startup (before permissions).
public protocol DiagnosticsServiceProtocol: AnyObject {
    /// Records a runtime event.
    func record(event: WMEvent)
    /// Records a placement failure.
    func record(failure: PlacementResult)
    /// Returns the current diagnostics snapshot.
    func currentReport(
        permissionsState: PermissionsState,
        managedWindowCount: Int
    ) -> DiagnosticsReport
}
