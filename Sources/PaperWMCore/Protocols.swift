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

    /// Returns the active workspace for the given display.
    func activeWorkspace(for displayID: DisplayID) -> WorkspaceState?
    /// Updates the workspace state for a display.
    func updateWorkspaceState(_ state: WorkspaceState)
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

// MARK: - PlacementTransactionEngine

/// Applies a `PlacementPlan` to real windows using transactional AX writes.
///
/// Each intent follows: read → compute delta → write → verify → degrade if needed.
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
