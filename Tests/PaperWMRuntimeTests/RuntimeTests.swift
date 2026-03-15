import Testing
@testable import PaperWMRuntime
import PaperWMCore

@Test("PermissionsServiceStub defaults are not granted")
func permissionsServiceStubDefaultsAreNotGranted() {
    let svc = PermissionsServiceStub()
    #expect(!svc.accessibilityGranted)
    #expect(!svc.inputMonitoringGranted)
}

@Test("PermissionsServiceStub request methods do not crash")
func permissionsServiceStubRequestMethodsDoNotCrash() {
    let svc = PermissionsServiceStub()
    svc.requestAccessibilityPermission()
    svc.requestInputMonitoringPermission()
}

@Test("WindowInventoryServiceStub initial snapshots are empty")
func windowInventoryServiceStubInitialSnapshotsAreEmpty() {
    let svc = WindowInventoryServiceStub()
    #expect(svc.snapshots.isEmpty)
}

@Test("WindowInventoryServiceStub refreshSnapshot does not crash")
func windowInventoryServiceStubRefreshSnapshotDoesNotCrash() async {
    let svc = WindowInventoryServiceStub()
    await svc.refreshSnapshot()
    #expect(svc.snapshots.isEmpty)
}

@Test("WorldStateStub paper window state roundtrip")
func worldStateStubPaperWindowStateRoundtrip() {
    let state = WorldStateStub()
    let id = ManagedWindowID("w-1")
    #expect(state.paperWindowState(for: id) == nil)

    let pw = PaperWindowState(
        windowID: id,
        paperRect: PaperRect(x: 10, y: 20, width: 300, height: 200)
    )
    state.updatePaperWindowState(pw)

    let retrieved = state.paperWindowState(for: id)
    #expect(retrieved != nil)
    #expect(retrieved?.paperRect == pw.paperRect)
}

@Test("WorldStateStub workspace state roundtrip")
func worldStateStubWorkspaceStateRoundtrip() {
    let worldState = WorldStateStub()
    let displayID = DisplayID(1)
    #expect(worldState.activeWorkspace(for: displayID) == nil)

    let viewport = ViewportState(displayID: displayID)
    let ws = WorkspaceState(displayID: displayID, viewport: viewport)
    worldState.updateWorkspaceState(ws)

    #expect(worldState.activeWorkspace(for: displayID) != nil)
}

@Test("ProjectionPlannerStub returns empty plan")
func projectionPlannerStubReturnsEmptyPlan() {
    let planner = ProjectionPlannerStub()
    let worldState = WorldStateStub()
    let plan = planner.computePlan(
        snapshots: [],
        topology: .empty,
        worldState: worldState
    )
    #expect(plan.intents.isEmpty)
}

@Test("PlacementTransactionEngineStub execute returns empty report")
func placementTransactionEngineStubExecuteReturnsEmptyReport() async {
    let engine = PlacementTransactionEngineStub()
    let report = await engine.execute(plan: .empty)
    #expect(report.appliedIntents.isEmpty)
    #expect(report.failedIntents.isEmpty)
}

@Test("DiagnosticsServiceStub record event and report")
func diagnosticsServiceStubRecordEventAndReport() {
    let svc = DiagnosticsServiceStub(eventCapacity: 10)
    svc.record(event: .displayTopologyChanged)
    svc.record(event: .activeSpaceChanged)

    let report = svc.currentReport(
        permissionsState: PermissionsState(
            accessibility: .granted,
            inputMonitoring: .notDetermined
        ),
        managedWindowCount: 3
    )

    #expect(report.recentEvents.count == 2)
    #expect(report.accessibilityGranted)
    #expect(!report.inputMonitoringGranted)
    #expect(report.managedWindowCount == 3)
}

@Test("DiagnosticsServiceStub event capacity is capped")
func diagnosticsServiceStubEventCapacityIsCapped() {
    let svc = DiagnosticsServiceStub(eventCapacity: 3)
    for _ in 0..<10 {
        svc.record(event: .displayTopologyChanged)
    }

    let report = svc.currentReport(
        permissionsState: PermissionsState(
            accessibility: .denied,
            inputMonitoring: .notDetermined
        ),
        managedWindowCount: 0
    )

    #expect(report.recentEvents.count == 3)
}

@Test("DiagnosticsServiceStub record failure")
func diagnosticsServiceStubRecordFailure() {
    let svc = DiagnosticsServiceStub()
    let windowID = ManagedWindowID("w-fail")
    svc.record(failure: .failed(windowID: windowID, reason: "AX timeout"))

    let report = svc.currentReport(
        permissionsState: PermissionsState(
            accessibility: .denied,
            inputMonitoring: .notDetermined
        ),
        managedWindowCount: 0
    )

    #expect(report.recentFailures.count == 1)
}

@Test("PersistenceStoreStub load does not throw")
func persistenceStoreStubLoadDoesNotThrow() throws {
    let store = PersistenceStoreStub()
    try store.load()
}

@Test("PersistenceStoreStub save does not throw")
func persistenceStoreStubSaveDoesNotThrow() throws {
    let store = PersistenceStoreStub()
    try store.save()
}
