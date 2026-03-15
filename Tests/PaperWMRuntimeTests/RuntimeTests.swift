import Testing
@testable import PaperWMRuntime
import PaperWMCore
import Foundation
import CoreGraphics

// MARK: - Test doubles for PlacementTransactionEngine tests

/// Configurable fake inventory service for engine tests.
private final class FakeWindowInventoryService: WindowInventoryServiceProtocol {
    var snapshots: [ManagedWindowSnapshot]
    init(snapshots: [ManagedWindowSnapshot] = []) {
        self.snapshots = snapshots
    }
    func refreshSnapshot() async {}
}

/// Spy mutator that records applied intents and returns configurable results.
private final class SpyWindowMutator: WindowMutatorProtocol {
    var resultsByWindowID: [ManagedWindowID: PlacementResult] = [:]
    var defaultResult: PlacementResult = .success
    var appliedIntents: [PlacementIntent] = []

    func applyPlacement(intent: PlacementIntent, snapshot: ManagedWindowSnapshot) -> PlacementResult {
        appliedIntents.append(intent)
        return resultsByWindowID[intent.windowID] ?? defaultResult
    }
}

// MARK: - Helpers

private func makeTestSnapshot(
    id: String,
    canMove: Bool = true,
    canResize: Bool = true,
    eligibility: WindowEligibility = .eligible
) -> ManagedWindowSnapshot {
    ManagedWindowSnapshot(
        windowID: ManagedWindowID(id),
        app: AppDescriptor(bundleID: "com.test.app", displayName: "TestApp", pid: 1234),
        frameOnDisplay: CoreGraphics.CGRect(x: 100, y: 100, width: 800, height: 600),
        displayID: DisplayID(1),
        capabilities: WindowCapabilities(canMove: canMove, canResize: canResize),
        eligibility: eligibility
    )
}

private func makeTestIntent(id: String) -> PlacementIntent {
    PlacementIntent(
        windowID: ManagedWindowID(id),
        targetFrame: CoreGraphics.CGRect(x: 0, y: 0, width: 1000, height: 700),
        targetDisplayID: DisplayID(1)
    )
}

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

// MARK: - WindowMutatorStub tests

@Test("WindowMutatorStub returns success by default")
func windowMutatorStubReturnsSuccessByDefault() {
    let mutator = WindowMutatorStub()
    let intent = makeTestIntent(id: "w-1")
    let snapshot = makeTestSnapshot(id: "w-1")
    let result = mutator.applyPlacement(intent: intent, snapshot: snapshot)
    guard case .success = result else {
        Issue.record("Expected .success, got \(result)")
        return
    }
}

@Test("WindowMutatorStub returns configured result")
func windowMutatorStubReturnsConfiguredResult() {
    let wid = ManagedWindowID("w-1")
    let mutator = WindowMutatorStub(stubbedResult: .resistedByApp(windowID: wid))
    let intent = makeTestIntent(id: "w-1")
    let snapshot = makeTestSnapshot(id: "w-1")
    let result = mutator.applyPlacement(intent: intent, snapshot: snapshot)
    guard case .resistedByApp = result else {
        Issue.record("Expected .resistedByApp, got \(result)")
        return
    }
}

// MARK: - PlacementTransactionEngine tests

@Test("PlacementTransactionEngine returns empty report for empty plan")
func engineReturnsEmptyReportForEmptyPlan() async {
    let permissions = PermissionsServiceStub(initialState: PermissionsState(
        accessibility: .granted, inputMonitoring: .notDetermined
    ))
    let inventory = FakeWindowInventoryService()
    let mutator = SpyWindowMutator()
    let engine = PlacementTransactionEngine(
        permissionsService: permissions,
        inventoryService: inventory,
        mutator: mutator
    )

    let report = await engine.execute(plan: .empty)
    #expect(report.appliedIntents.isEmpty)
    #expect(report.failedIntents.isEmpty)
    #expect(report.results.isEmpty)
    #expect(mutator.appliedIntents.isEmpty)
}

@Test("PlacementTransactionEngine fails all intents when accessibility denied")
func engineFailsAllIntentsWhenAccessibilityDenied() async {
    let permissions = PermissionsServiceStub(initialState: PermissionsState(
        accessibility: .denied, inputMonitoring: .notDetermined
    ))
    let inventory = FakeWindowInventoryService(snapshots: [makeTestSnapshot(id: "w-1")])
    let mutator = SpyWindowMutator()
    let engine = PlacementTransactionEngine(
        permissionsService: permissions,
        inventoryService: inventory,
        mutator: mutator
    )

    let plan = PlacementPlan(intents: [makeTestIntent(id: "w-1"), makeTestIntent(id: "w-2")])
    let report = await engine.execute(plan: plan)

    #expect(report.appliedIntents.isEmpty)
    #expect(report.failedIntents.count == 2)
    #expect(report.results.count == 2)
    // Mutator must never be called when permission is denied.
    #expect(mutator.appliedIntents.isEmpty)
}

@Test("PlacementTransactionEngine fails intent for missing window")
func engineFailsIntentForMissingWindow() async {
    let permissions = PermissionsServiceStub(initialState: PermissionsState(
        accessibility: .granted, inputMonitoring: .notDetermined
    ))
    // Inventory is empty: no snapshot for "w-missing".
    let inventory = FakeWindowInventoryService(snapshots: [])
    let mutator = SpyWindowMutator()
    let engine = PlacementTransactionEngine(
        permissionsService: permissions,
        inventoryService: inventory,
        mutator: mutator
    )

    let plan = PlacementPlan(intents: [makeTestIntent(id: "w-missing")])
    let report = await engine.execute(plan: plan)

    #expect(report.appliedIntents.isEmpty)
    #expect(report.failedIntents.count == 1)
    // Mutator must not be called when the window is not in inventory.
    #expect(mutator.appliedIntents.isEmpty)
}

@Test("PlacementTransactionEngine applies intent when mutator succeeds")
func engineAppliesIntentWhenMutatorSucceeds() async {
    let permissions = PermissionsServiceStub(initialState: PermissionsState(
        accessibility: .granted, inputMonitoring: .notDetermined
    ))
    let snapshot = makeTestSnapshot(id: "w-1")
    let inventory = FakeWindowInventoryService(snapshots: [snapshot])
    let mutator = SpyWindowMutator()
    mutator.defaultResult = .success
    let engine = PlacementTransactionEngine(
        permissionsService: permissions,
        inventoryService: inventory,
        mutator: mutator
    )

    let plan = PlacementPlan(intents: [makeTestIntent(id: "w-1")])
    let report = await engine.execute(plan: plan)

    #expect(report.appliedIntents.count == 1)
    #expect(report.failedIntents.isEmpty)
    #expect(mutator.appliedIntents.count == 1)
}

@Test("PlacementTransactionEngine reports partial success accurately")
func engineReportsPartialSuccess() async {
    let permissions = PermissionsServiceStub(initialState: PermissionsState(
        accessibility: .granted, inputMonitoring: .notDetermined
    ))
    let wid1 = ManagedWindowID("w-1")
    let wid2 = ManagedWindowID("w-2")
    let inventory = FakeWindowInventoryService(snapshots: [
        makeTestSnapshot(id: "w-1"),
        makeTestSnapshot(id: "w-2"),
    ])
    let mutator = SpyWindowMutator()
    mutator.resultsByWindowID[wid1] = .success
    mutator.resultsByWindowID[wid2] = .resistedByApp(windowID: wid2)

    let engine = PlacementTransactionEngine(
        permissionsService: permissions,
        inventoryService: inventory,
        mutator: mutator
    )

    let plan = PlacementPlan(intents: [makeTestIntent(id: "w-1"), makeTestIntent(id: "w-2")])
    let report = await engine.execute(plan: plan)

    #expect(report.appliedIntents.count == 1)
    #expect(report.failedIntents.count == 1)
    #expect(report.results.count == 2)
}

@Test("PlacementTransactionEngine continues executing remaining intents after one fails")
func engineContinuesAfterOneFailure() async {
    let permissions = PermissionsServiceStub(initialState: PermissionsState(
        accessibility: .granted, inputMonitoring: .notDetermined
    ))
    let wid_b = ManagedWindowID("w-b")
    let inventory = FakeWindowInventoryService(snapshots: [
        makeTestSnapshot(id: "w-a"),
        makeTestSnapshot(id: "w-b"),
        makeTestSnapshot(id: "w-c"),
    ])
    let mutator = SpyWindowMutator()
    mutator.resultsByWindowID[wid_b] = .failed(windowID: wid_b, reason: "test failure")

    let engine = PlacementTransactionEngine(
        permissionsService: permissions,
        inventoryService: inventory,
        mutator: mutator
    )

    let plan = PlacementPlan(intents: [
        makeTestIntent(id: "w-a"),
        makeTestIntent(id: "w-b"),
        makeTestIntent(id: "w-c"),
    ])
    let report = await engine.execute(plan: plan)

    // All three windows are in inventory, so mutator is called for all three.
    #expect(mutator.appliedIntents.count == 3)
    #expect(report.appliedIntents.count == 2)
    #expect(report.failedIntents.count == 1)
}

@Test("PlacementTransactionEngine result count equals intent count")
func engineResultCountEqualsIntentCount() async {
    let permissions = PermissionsServiceStub(initialState: PermissionsState(
        accessibility: .granted, inputMonitoring: .notDetermined
    ))
    // Two snapshots present, one intent for a missing window.
    let inventory = FakeWindowInventoryService(snapshots: [
        makeTestSnapshot(id: "w-x"),
        makeTestSnapshot(id: "w-y"),
    ])
    let mutator = SpyWindowMutator()
    let engine = PlacementTransactionEngine(
        permissionsService: permissions,
        inventoryService: inventory,
        mutator: mutator
    )

    let plan = PlacementPlan(intents: [
        makeTestIntent(id: "w-x"),
        makeTestIntent(id: "w-y"),
        makeTestIntent(id: "w-z"),  // missing
    ])
    let report = await engine.execute(plan: plan)

    // Total results must equal total intents.
    #expect(report.results.count == plan.intents.count)
    #expect(report.appliedIntents.count + report.failedIntents.count == plan.intents.count)
}

@Test("PlacementTransactionEngine permission denied does not call mutator")
func enginePermissionDeniedDoesNotCallMutator() async {
    let permissions = PermissionsServiceStub(initialState: PermissionsState(
        accessibility: .denied, inputMonitoring: .notDetermined
    ))
    let inventory = FakeWindowInventoryService(snapshots: [makeTestSnapshot(id: "w-1")])
    let mutator = SpyWindowMutator()
    let engine = PlacementTransactionEngine(
        permissionsService: permissions,
        inventoryService: inventory,
        mutator: mutator
    )

    _ = await engine.execute(plan: PlacementPlan(intents: [makeTestIntent(id: "w-1")]))
    #expect(mutator.appliedIntents.isEmpty)
}
