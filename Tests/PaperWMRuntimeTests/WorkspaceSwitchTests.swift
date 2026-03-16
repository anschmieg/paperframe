import CoreGraphics
import Foundation
import PaperWMCore
import Testing

@testable import PaperWMRuntime

// MARK: - Test helpers (file-private to this test file)

/// Minimal fake inventory service for workspace-switch tests.
private final class WSFakeInventoryService: WindowInventoryServiceProtocol {
    var snapshots: [ManagedWindowSnapshot]
    init(snapshots: [ManagedWindowSnapshot] = []) {
        self.snapshots = snapshots
    }
    func refreshSnapshot() async {}
}

/// Spy engine that captures the plans it receives.
private final class WSSpyEngine: PlacementTransactionEngineProtocol {
    var receivedPlan: PlacementPlan?
    func execute(plan: PlacementPlan) async -> PlacementExecutionReport {
        receivedPlan = plan
        return PlacementExecutionReport()
    }
}

/// Minimal diagnostics for wiring up a real ReconciliationCoordinator.
private final class WSDiagnosticsStub: DiagnosticsServiceProtocol {
    func record(event: WMEvent) {}
    func record(failure: PlacementResult) {}
    func currentReport(permissionsState: PermissionsState, managedWindowCount: Int) -> DiagnosticsReport {
        DiagnosticsReport(
            recentEvents: [],
            managedWindowCount: managedWindowCount,
            permissionsState: permissionsState,
            recentFailures: []
        )
    }
}

/// Builds an eligible window snapshot on the given display.
private func wsSnapshot(id: String, displayID: UInt32 = 1) -> ManagedWindowSnapshot {
    ManagedWindowSnapshot(
        windowID: ManagedWindowID(id),
        app: AppDescriptor(bundleID: "com.test.ws", displayName: "WSApp", pid: 9999),
        frameOnDisplay: CGRect(x: 0, y: 0, width: 800, height: 600),
        displayID: DisplayID(displayID),
        capabilities: WindowCapabilities(canMove: true, canResize: true),
        eligibility: .eligible
    )
}

// MARK: - WorldStateStub multi-workspace tests

@Test("WorldStateStub updateWorkspaceState registers and activates workspace")
func worldStateStubUpdateWorkspaceStateRegistersAndActivates() {
    let worldState = WorldStateStub()
    let displayID = DisplayID(1)
    let ws = WorkspaceState(
        displayID: displayID,
        viewport: ViewportState(displayID: displayID)
    )
    worldState.updateWorkspaceState(ws)
    let active = worldState.activeWorkspace(for: displayID)
    #expect(active?.workspaceID == ws.workspaceID)
}

@Test("WorldStateStub setActiveWorkspace switches to a registered workspace")
func worldStateStubSetActiveWorkspaceSwitchesToRegistered() {
    let worldState = WorldStateStub()
    let displayID = DisplayID(1)

    let ws1 = WorkspaceState(displayID: displayID, viewport: ViewportState(displayID: displayID))
    let ws2 = WorkspaceState(displayID: displayID, viewport: ViewportState(displayID: displayID))

    worldState.updateWorkspaceState(ws1)
    worldState.updateWorkspaceState(ws2)

    // ws2 should be active since it was registered last.
    #expect(worldState.activeWorkspace(for: displayID)?.workspaceID == ws2.workspaceID)

    // Switch back to ws1.
    let switched = worldState.setActiveWorkspace(ws1.workspaceID, for: displayID)
    #expect(switched)
    #expect(worldState.activeWorkspace(for: displayID)?.workspaceID == ws1.workspaceID)
}

@Test("WorldStateStub setActiveWorkspace returns false for unknown workspaceID")
func worldStateStubSetActiveWorkspaceReturnsFalseForUnknown() {
    let worldState = WorldStateStub()
    let displayID = DisplayID(1)
    let unknownID = WorkspaceID()

    let result = worldState.setActiveWorkspace(unknownID, for: displayID)
    #expect(!result)
    #expect(worldState.activeWorkspace(for: displayID) == nil)
}

@Test("WorldStateStub setActiveWorkspace is idempotent for already-active workspace")
func worldStateStubSetActiveWorkspaceIsIdempotent() {
    let worldState = WorldStateStub()
    let displayID = DisplayID(1)
    let ws = WorkspaceState(displayID: displayID, viewport: ViewportState(displayID: displayID))
    worldState.updateWorkspaceState(ws)

    // Switching to the same workspace must succeed and not corrupt state.
    let result = worldState.setActiveWorkspace(ws.workspaceID, for: displayID)
    #expect(result)
    #expect(worldState.activeWorkspace(for: displayID)?.workspaceID == ws.workspaceID)
}

@Test("WorldStateStub allWorkspaces returns all workspaces for a display")
func worldStateStubAllWorkspacesReturnsAllForDisplay() {
    let worldState = WorldStateStub()
    let displayID = DisplayID(1)
    let otherDisplayID = DisplayID(2)

    let ws1 = WorkspaceState(displayID: displayID, viewport: ViewportState(displayID: displayID))
    let ws2 = WorkspaceState(displayID: displayID, viewport: ViewportState(displayID: displayID))
    let ws3 = WorkspaceState(
        displayID: otherDisplayID, viewport: ViewportState(displayID: otherDisplayID))

    worldState.updateWorkspaceState(ws1)
    worldState.updateWorkspaceState(ws2)
    worldState.updateWorkspaceState(ws3)

    let display1Workspaces = worldState.allWorkspaces(for: displayID)
    #expect(display1Workspaces.count == 2)

    let display2Workspaces = worldState.allWorkspaces(for: otherDisplayID)
    #expect(display2Workspaces.count == 1)
}

@Test("WorldStateStub per-display workspace state is independent")
func worldStateStubPerDisplayWorkspaceStateIsIndependent() {
    let worldState = WorldStateStub()
    let d1 = DisplayID(1)
    let d2 = DisplayID(2)

    let ws1a = WorkspaceState(displayID: d1, viewport: ViewportState(displayID: d1))
    let ws1b = WorkspaceState(displayID: d1, viewport: ViewportState(displayID: d1))
    let ws2a = WorkspaceState(displayID: d2, viewport: ViewportState(displayID: d2))

    worldState.updateWorkspaceState(ws1a)
    worldState.updateWorkspaceState(ws1b)
    worldState.updateWorkspaceState(ws2a)

    // Switch d1 to ws1a without touching d2.
    let switched = worldState.setActiveWorkspace(ws1a.workspaceID, for: d1)
    #expect(switched)
    #expect(worldState.activeWorkspace(for: d1)?.workspaceID == ws1a.workspaceID)

    // d2 must remain unaffected.
    #expect(worldState.activeWorkspace(for: d2)?.workspaceID == ws2a.workspaceID)
}

// MARK: - WorkspaceSwitchCoordinator tests

@Test("WorkspaceSwitchCoordinator switches workspace and triggers reconcile")
@MainActor
func workspaceSwitchCoordinatorSwitchesAndTriggersReconcile() async {
    let worldState = WorldStateStub()
    let displayID = DisplayID(1)

    let ws1 = WorkspaceState(displayID: displayID, viewport: ViewportState(displayID: displayID))
    let ws2 = WorkspaceState(displayID: displayID, viewport: ViewportState(displayID: displayID))
    worldState.updateWorkspaceState(ws1)
    worldState.updateWorkspaceState(ws2)

    // ws2 is active after the two updateWorkspaceState calls. Switch back to ws1.
    let spy = ReconciliationTriggerSpy()
    let switcher = WorkspaceSwitchCoordinator(
        worldState: worldState, reconciliationCoordinator: spy)

    let result = await switcher.switchWorkspace(to: ws1.workspaceID, for: displayID)

    // Active workspace must have changed.
    #expect(worldState.activeWorkspace(for: displayID)?.workspaceID == ws1.workspaceID)

    // Reconciliation must have been triggered once.
    #expect(spy.reasons.count == 1)
    if let reason = spy.reasons.first,
        case .userCommand(.switchWorkspace(let did, let wid)) = reason
    {
        #expect(did == displayID)
        #expect(wid == ws1.workspaceID)
    } else {
        Issue.record(
            "Expected .userCommand(.switchWorkspace(...)), got \(String(describing: spy.reasons.first))"
        )
    }

    // Result must be non-nil since the switch succeeded.
    #expect(result != nil)
}

@Test("WorkspaceSwitchCoordinator switching to already-active workspace is a no-op")
@MainActor
func workspaceSwitchCoordinatorAlreadyActiveIsNoop() async {
    let worldState = WorldStateStub()
    let displayID = DisplayID(1)
    let ws = WorkspaceState(displayID: displayID, viewport: ViewportState(displayID: displayID))
    worldState.updateWorkspaceState(ws)

    let spy = ReconciliationTriggerSpy()
    let switcher = WorkspaceSwitchCoordinator(
        worldState: worldState, reconciliationCoordinator: spy)

    let result = await switcher.switchWorkspace(to: ws.workspaceID, for: displayID)

    // No reconciliation should have been triggered.
    #expect(spy.reasons.isEmpty)
    // Return value must be nil for a no-op switch.
    #expect(result == nil)
    // Active workspace must remain unchanged.
    #expect(worldState.activeWorkspace(for: displayID)?.workspaceID == ws.workspaceID)
}

@Test("WorkspaceSwitchCoordinator switching to unknown workspace is safe")
@MainActor
func workspaceSwitchCoordinatorUnknownWorkspaceIsSafe() async {
    let worldState = WorldStateStub()
    let displayID = DisplayID(1)
    let unknownID = WorkspaceID()

    let spy = ReconciliationTriggerSpy()
    let switcher = WorkspaceSwitchCoordinator(
        worldState: worldState, reconciliationCoordinator: spy)

    let result = await switcher.switchWorkspace(to: unknownID, for: displayID)

    // No reconciliation must be triggered for an unknown workspace.
    #expect(spy.reasons.isEmpty)
    #expect(result == nil)
    #expect(worldState.activeWorkspace(for: displayID) == nil)
}

@Test("WorkspaceSwitchCoordinator switching to unknown workspace when no prior state is safe")
@MainActor
func workspaceSwitchCoordinatorNoPriorStateIsSafe() async {
    // No workspace state registered at all.
    let worldState = WorldStateStub()
    let displayID = DisplayID(1)
    let spy = ReconciliationTriggerSpy()
    let switcher = WorkspaceSwitchCoordinator(
        worldState: worldState, reconciliationCoordinator: spy)

    let result = await switcher.switchWorkspace(to: WorkspaceID(), for: displayID)

    #expect(spy.reasons.isEmpty)
    #expect(result == nil)
}

@Test("WorkspaceSwitchCoordinator per-display switches are independent")
@MainActor
func workspaceSwitchCoordinatorPerDisplayIndependence() async {
    let worldState = WorldStateStub()
    let d1 = DisplayID(1)
    let d2 = DisplayID(2)

    let ws1a = WorkspaceState(displayID: d1, viewport: ViewportState(displayID: d1))
    let ws1b = WorkspaceState(displayID: d1, viewport: ViewportState(displayID: d1))
    let ws2a = WorkspaceState(displayID: d2, viewport: ViewportState(displayID: d2))

    worldState.updateWorkspaceState(ws1a)
    worldState.updateWorkspaceState(ws1b)  // d1 active = ws1b
    worldState.updateWorkspaceState(ws2a)  // d2 active = ws2a

    let spy = ReconciliationTriggerSpy()
    let switcher = WorkspaceSwitchCoordinator(
        worldState: worldState, reconciliationCoordinator: spy)

    // Switch d1 to ws1a — d2 must be unaffected.
    _ = await switcher.switchWorkspace(to: ws1a.workspaceID, for: d1)

    #expect(worldState.activeWorkspace(for: d1)?.workspaceID == ws1a.workspaceID)
    #expect(worldState.activeWorkspace(for: d2)?.workspaceID == ws2a.workspaceID)

    // Only one reconcile should have been triggered (for d1).
    #expect(spy.reasons.count == 1)
}

// MARK: - Viewport behavior after workspace switch (reconciliation integration)

@Test("WorkspaceSwitchCoordinator: reconcile after switch uses new workspace viewport")
@MainActor
func workspaceSwitchCoordinatorReconcileUsesNewWorkspaceViewport() async {
    let displayID = DisplayID(1)
    let worldState = WorldStateStub()

    // Two windows: w-left at paper x=0, w-right at paper x=3000.
    worldState.updatePaperWindowState(
        PaperWindowState(
            windowID: ManagedWindowID("w-left"),
            paperRect: PaperRect(x: 0, y: 0, width: 800, height: 600)
        ))
    worldState.updatePaperWindowState(
        PaperWindowState(
            windowID: ManagedWindowID("w-right"),
            paperRect: PaperRect(x: 3000, y: 0, width: 800, height: 600)
        ))

    // Workspace A: viewport at x=0 (shows w-left only in a 1920-wide display).
    let wsA = WorkspaceState(
        displayID: displayID,
        viewport: ViewportState(displayID: displayID, origin: .zero, scale: 1.0)
    )
    // Workspace B: viewport at x=2500 (shows w-right only).
    let wsB = WorkspaceState(
        displayID: displayID,
        viewport: ViewportState(
            displayID: displayID, origin: PaperPoint(x: 2500, y: 0), scale: 1.0)
    )

    worldState.updateWorkspaceState(wsA)  // A is now active
    worldState.updateWorkspaceState(wsB)  // B becomes active

    let display = DisplaySnapshot(
        displayID: displayID,
        frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        scaleFactor: 1.0
    )
    let inventory = WSFakeInventoryService(snapshots: [
        wsSnapshot(id: "w-left"),
        wsSnapshot(id: "w-right"),
    ])
    let spyEngine = WSSpyEngine()
    let coordinator = ReconciliationCoordinator(
        inventoryService: inventory,
        topologyProvider: DisplayTopologyProviderStub(topology: DisplayTopology(displays: [display])),
        planner: TilingProjectionPlanner(),
        engine: spyEngine,
        worldState: worldState,
        diagnostics: WSDiagnosticsStub()
    )
    let switcher = WorkspaceSwitchCoordinator(
        worldState: worldState, reconciliationCoordinator: coordinator)

    // Switch to workspace A (viewport at x=0) → only w-left should be tiled.
    let resultA = await switcher.switchWorkspace(to: wsA.workspaceID, for: displayID)
    let planA = spyEngine.receivedPlan
    #expect(resultA != nil)
    #expect(resultA?.planIntentCount == 1)
    #expect(planA?.intents.first?.windowID == ManagedWindowID("w-left"))

    // Switch to workspace B (viewport at x=2500) → only w-right should be tiled.
    let resultB = await switcher.switchWorkspace(to: wsB.workspaceID, for: displayID)
    let planB = spyEngine.receivedPlan
    #expect(resultB != nil)
    #expect(resultB?.planIntentCount == 1)
    #expect(planB?.intents.first?.windowID == ManagedWindowID("w-right"))
}

@Test("WMCommand switchWorkspace equality")
func wmCommandSwitchWorkspaceEquality() {
    let displayID = DisplayID(1)
    let workspaceID = WorkspaceID()
    let cmd1 = WMCommand.switchWorkspace(displayID: displayID, to: workspaceID)
    let cmd2 = WMCommand.switchWorkspace(displayID: displayID, to: workspaceID)
    let cmd3 = WMCommand.switchWorkspace(displayID: DisplayID(2), to: workspaceID)
    let cmd4 = WMCommand.switchWorkspace(displayID: displayID, to: WorkspaceID())

    #expect(cmd1 == cmd2)
    #expect(cmd1 != cmd3)
    #expect(cmd1 != cmd4)
    #expect(cmd1 != .refreshInventory)
}
