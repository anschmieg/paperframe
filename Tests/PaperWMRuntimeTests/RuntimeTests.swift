import CoreGraphics
import Foundation
import PaperWMCore
import Testing

@testable import PaperWMRuntime

// MARK: - Test doubles for PlacementTransactionEngine tests

/// Configurable fake inventory service for engine tests.
private final class FakeWindowInventoryService: WindowInventoryServiceProtocol {
  var snapshots: [ManagedWindowSnapshot]
  var refreshCallCount: Int = 0

  init(snapshots: [ManagedWindowSnapshot] = []) {
    self.snapshots = snapshots
  }

  func refreshSnapshot() async { refreshCallCount += 1 }
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

// MARK: - Test doubles for ReconciliationCoordinator tests

/// Spy planner that returns a configurable plan and records call arguments.
private final class SpyProjectionPlanner: ProjectionPlannerProtocol {
  var stubbedPlan: PlacementPlan = .empty
  var lastSnapshots: [ManagedWindowSnapshot] = []
  var lastTopology: DisplayTopology = .empty
  var lastWorldState: (any WorldStateProtocol)?
  var callCount: Int = 0

  func computePlan(
    snapshots: [ManagedWindowSnapshot],
    topology: DisplayTopology,
    worldState: any WorldStateProtocol
  ) -> PlacementPlan {
    callCount += 1
    lastSnapshots = snapshots
    lastTopology = topology
    lastWorldState = worldState
    return stubbedPlan
  }
}

/// Spy engine that records the plan it received and returns a configurable report.
private final class SpyPlacementTransactionEngine: PlacementTransactionEngineProtocol {
  var stubbedReport: PlacementExecutionReport = PlacementExecutionReport()
  var receivedPlan: PlacementPlan?
  var callCount: Int = 0

  func execute(plan: PlacementPlan) async -> PlacementExecutionReport {
    callCount += 1
    receivedPlan = plan
    return stubbedReport
  }
}

/// Spy diagnostics service that records every call.
private final class SpyDiagnosticsService: DiagnosticsServiceProtocol {
  var recordedEvents: [WMEvent] = []
  var recordedFailures: [PlacementResult] = []

  func record(event: WMEvent) { recordedEvents.append(event) }

  func record(failure: PlacementResult) { recordedFailures.append(failure) }

  func currentReport(permissionsState: PermissionsState, managedWindowCount: Int)
    -> DiagnosticsReport
  {
    DiagnosticsReport(
      recentEvents: recordedEvents,
      managedWindowCount: managedWindowCount,
      permissionsState: permissionsState,
      recentFailures: recordedFailures
    )
  }
}

// MARK: - Test doubles for ObserverAndReconcileHub tests

/// Stub event source for testing the observer hub.
@MainActor
final class ObserverEventSourceStub: ObserverEventSourceProtocol {
  private var handler: (@MainActor @Sendable (ObservedSystemEvent) -> Void)?
  private(set) var startCallCount = 0
  private(set) var stopCallCount = 0

  func setEventHandler(_ handler: (@MainActor @Sendable (ObservedSystemEvent) -> Void)?) {
    self.handler = handler
  }

  func start() {
    startCallCount += 1
  }

  func stop() {
    stopCallCount += 1
  }

  func emit(_ event: ObservedSystemEvent) {
    handler?(event)
  }
}

/// Spy coordinator for testing the observer hub.
@MainActor
final class ReconciliationTriggerSpy: ReconciliationTriggering {
  private(set) var reasons: [ReconcileReason] = []

  var stubbedResult = ReconcileResult(
    reason: .manualRefresh,
    snapshotCount: 0,
    planIntentCount: 0,
    executionReport: PlacementExecutionReport()
  )

  @discardableResult
  func reconcile(reason: ReconcileReason) async -> ReconcileResult {
    reasons.append(reason)

    return ReconcileResult(
      reason: reason,
      snapshotCount: stubbedResult.snapshotCount,
      planIntentCount: stubbedResult.planIntentCount,
      executionReport: stubbedResult.executionReport
    )
  }
}

// MARK: - Helpers

@MainActor
private func eventually(
  timeoutNanoseconds: UInt64 = 1_000_000_000,
  pollIntervalNanoseconds: UInt64 = 10_000_000,
  condition: @escaping @MainActor () -> Bool
) async -> Bool {
  let deadline = ContinuousClock.now + .nanoseconds(Int(timeoutNanoseconds))

  while ContinuousClock.now < deadline {
    if condition() { return true }
    try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
  }

  return condition()
}

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

/// Creates a `ReconciliationCoordinator` wired with the given collaborators.
@MainActor
private func makeCoordinator(
  inventory: FakeWindowInventoryService = FakeWindowInventoryService(),
  topology: DisplayTopologyProviderStub = DisplayTopologyProviderStub(),
  planner: any ProjectionPlannerProtocol = SpyProjectionPlanner(),
  engine: SpyPlacementTransactionEngine = SpyPlacementTransactionEngine(),
  worldState: WorldStateStub = WorldStateStub(),
  diagnostics: SpyDiagnosticsService = SpyDiagnosticsService()
) -> ReconciliationCoordinator {
  ReconciliationCoordinator(
    inventoryService: inventory,
    topologyProvider: topology,
    planner: planner,
    engine: engine,
    worldState: worldState,
    diagnostics: diagnostics
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
@MainActor
func windowInventoryServiceStubInitialSnapshotsAreEmpty() {
  let svc = WindowInventoryServiceStub()
  #expect(svc.snapshots.isEmpty)
}

@Test("WindowInventoryServiceStub refreshSnapshot does not crash")
@MainActor
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
@MainActor
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
@MainActor
func engineReturnsEmptyReportForEmptyPlan() async {
  let permissions = PermissionsServiceStub(
    initialState: PermissionsState(
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
@MainActor
func engineFailsAllIntentsWhenAccessibilityDenied() async {
  let permissions = PermissionsServiceStub(
    initialState: PermissionsState(
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
@MainActor
func engineFailsIntentForMissingWindow() async {
  let permissions = PermissionsServiceStub(
    initialState: PermissionsState(
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
@MainActor
func engineAppliesIntentWhenMutatorSucceeds() async {
  let permissions = PermissionsServiceStub(
    initialState: PermissionsState(
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
@MainActor
func engineReportsPartialSuccess() async {
  let permissions = PermissionsServiceStub(
    initialState: PermissionsState(
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
@MainActor
func engineContinuesAfterOneFailure() async {
  let permissions = PermissionsServiceStub(
    initialState: PermissionsState(
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
@MainActor
func engineResultCountEqualsIntentCount() async {
  let permissions = PermissionsServiceStub(
    initialState: PermissionsState(
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
@MainActor
func enginePermissionDeniedDoesNotCallMutator() async {
  let permissions = PermissionsServiceStub(
    initialState: PermissionsState(
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

// MARK: - ReconciliationCoordinator tests

@Test("ReconciliationCoordinator empty inventory produces empty result")
@MainActor
func reconciliationCoordinatorEmptyInventoryProducesEmptyResult() async {
  let inventory = FakeWindowInventoryService(snapshots: [])
  let planner = SpyProjectionPlanner()
  let engine = SpyPlacementTransactionEngine()
  let coordinator = makeCoordinator(inventory: inventory, planner: planner, engine: engine)

  let result = await coordinator.reconcile(reason: .manualRefresh)

  #expect(result.snapshotCount == 0)
  #expect(result.planIntentCount == 0)
  #expect(result.executionReport.appliedIntents.isEmpty)
  #expect(result.executionReport.failedIntents.isEmpty)
  #expect(planner.callCount == 1)
  #expect(engine.callCount == 1)
}

@Test("ReconciliationCoordinator refreshes inventory before planning")
@MainActor
func reconciliationCoordinatorRefreshesInventoryBeforePlanning() async {
  let inventory = FakeWindowInventoryService(snapshots: [makeTestSnapshot(id: "w-1")])
  let coordinator = makeCoordinator(inventory: inventory)

  _ = await coordinator.reconcile(reason: .manualRefresh)

  #expect(inventory.refreshCallCount == 1)
}

@Test("ReconciliationCoordinator forwards snapshots and topology to planner")
@MainActor
func reconciliationCoordinatorForwardsSnapshotsAndTopologyToPlanner() async {
  let snapshot = makeTestSnapshot(id: "w-1")
  let display = DisplaySnapshot(
    displayID: DisplayID(42),
    frame: CoreGraphics.CGRect(x: 0, y: 0, width: 2560, height: 1440),
    scaleFactor: 2.0
  )
  let topology = DisplayTopology(displays: [display])
  let inventory = FakeWindowInventoryService(snapshots: [snapshot])
  let topologyProvider = DisplayTopologyProviderStub(topology: topology)
  let planner = SpyProjectionPlanner()
  let coordinator = makeCoordinator(
    inventory: inventory,
    topology: topologyProvider,
    planner: planner
  )

  _ = await coordinator.reconcile(reason: .manualRefresh)

  #expect(planner.lastSnapshots.count == 1)
  #expect(planner.lastTopology.displays.count == 1)
  #expect(planner.lastTopology.displays.first?.displayID == DisplayID(42))
}

@Test("ReconciliationCoordinator forwards planner output to engine")
@MainActor
func reconciliationCoordinatorForwardsPlannerOutputToEngine() async {
  let intent = makeTestIntent(id: "w-1")
  let planner = SpyProjectionPlanner()
  planner.stubbedPlan = PlacementPlan(intents: [intent])
  let engine = SpyPlacementTransactionEngine()
  let coordinator = makeCoordinator(planner: planner, engine: engine)

  let result = await coordinator.reconcile(reason: .manualRefresh)

  #expect(engine.callCount == 1)
  #expect(engine.receivedPlan?.intents.count == 1)
  #expect(result.planIntentCount == 1)
}

@Test("ReconciliationCoordinator result captures execution report")
@MainActor
func reconciliationCoordinatorResultCapturesExecutionReport() async {
  let intent = makeTestIntent(id: "w-1")
  let executionReport = PlacementExecutionReport(
    results: [.success],
    appliedIntents: [intent],
    failedIntents: []
  )
  let engine = SpyPlacementTransactionEngine()
  engine.stubbedReport = executionReport
  let coordinator = makeCoordinator(engine: engine)

  let result = await coordinator.reconcile(reason: .manualRefresh)

  #expect(result.executionReport.appliedIntents.count == 1)
  #expect(result.executionReport.failedIntents.isEmpty)
}

@Test("ReconciliationCoordinator records trigger event for WMEvent reason")
@MainActor
func reconciliationCoordinatorRecordsTriggerEventForWMEventReason() async {
  let diagnostics = SpyDiagnosticsService()
  let coordinator = makeCoordinator(diagnostics: diagnostics)

  _ = await coordinator.reconcile(reason: .event(.displayTopologyChanged))

  #expect(diagnostics.recordedEvents.count == 1)
  if case .displayTopologyChanged = diagnostics.recordedEvents.first {
    // expected
  } else {
    Issue.record(
      "Expected .displayTopologyChanged, got \(String(describing: diagnostics.recordedEvents.first))"
    )
  }
}

@Test("ReconciliationCoordinator records trigger event for displayTopologyChanged reason")
@MainActor
func reconciliationCoordinatorRecordsTriggerEventForTopologyReason() async {
  let diagnostics = SpyDiagnosticsService()
  let coordinator = makeCoordinator(diagnostics: diagnostics)

  _ = await coordinator.reconcile(reason: .displayTopologyChanged)

  #expect(diagnostics.recordedEvents.count == 1)
}

@Test("ReconciliationCoordinator does not record event for manualRefresh reason")
@MainActor
func reconciliationCoordinatorDoesNotRecordEventForManualRefresh() async {
  let diagnostics = SpyDiagnosticsService()
  let coordinator = makeCoordinator(diagnostics: diagnostics)

  _ = await coordinator.reconcile(reason: .manualRefresh)

  #expect(diagnostics.recordedEvents.isEmpty)
}

@Test("ReconciliationCoordinator records placement failures in diagnostics")
@MainActor
func reconciliationCoordinatorRecordsPlacementFailuresInDiagnostics() async {
  let windowID = ManagedWindowID("w-fail")
  let intent = makeTestIntent(id: "w-fail")
  let executionReport = PlacementExecutionReport(
    results: [.failed(windowID: windowID, reason: "AX timeout")],
    appliedIntents: [],
    failedIntents: [intent]
  )
  let engine = SpyPlacementTransactionEngine()
  engine.stubbedReport = executionReport
  let diagnostics = SpyDiagnosticsService()
  let coordinator = makeCoordinator(engine: engine, diagnostics: diagnostics)

  _ = await coordinator.reconcile(reason: .manualRefresh)

  #expect(diagnostics.recordedFailures.count == 1)
}

@Test("ReconciliationCoordinator records resistedByApp failure in diagnostics")
@MainActor
func reconciliationCoordinatorRecordsResistedByAppFailure() async {
  let windowID = ManagedWindowID("w-resist")
  let intent = makeTestIntent(id: "w-resist")
  let executionReport = PlacementExecutionReport(
    results: [.resistedByApp(windowID: windowID)],
    appliedIntents: [],
    failedIntents: [intent]
  )
  let engine = SpyPlacementTransactionEngine()
  engine.stubbedReport = executionReport
  let diagnostics = SpyDiagnosticsService()
  let coordinator = makeCoordinator(engine: engine, diagnostics: diagnostics)

  _ = await coordinator.reconcile(reason: .manualRefresh)

  #expect(diagnostics.recordedFailures.count == 1)
}

@Test("ReconciliationCoordinator does not record success results as failures")
@MainActor
func reconciliationCoordinatorDoesNotRecordSuccessAsFailure() async {
  let intent = makeTestIntent(id: "w-ok")
  let executionReport = PlacementExecutionReport(
    results: [.success],
    appliedIntents: [intent],
    failedIntents: []
  )
  let engine = SpyPlacementTransactionEngine()
  engine.stubbedReport = executionReport
  let diagnostics = SpyDiagnosticsService()
  let coordinator = makeCoordinator(engine: engine, diagnostics: diagnostics)

  _ = await coordinator.reconcile(reason: .manualRefresh)

  #expect(diagnostics.recordedFailures.isEmpty)
}

@Test("ReconciliationCoordinator result reason matches input reason")
@MainActor
func reconciliationCoordinatorResultReasonMatchesInput() async {
  let coordinator = makeCoordinator()

  let result = await coordinator.reconcile(reason: .startupInitialization)

  if case .startupInitialization = result.reason {
    // expected
  } else {
    Issue.record("Expected .startupInitialization, got \(result.reason)")
  }
}

@Test("ReconciliationCoordinator empty plan path executes engine with empty plan")
@MainActor
func reconciliationCoordinatorEmptyPlanPathExecutesEngineWithEmptyPlan() async {
  let planner = SpyProjectionPlanner()
  planner.stubbedPlan = .empty
  let engine = SpyPlacementTransactionEngine()
  let coordinator = makeCoordinator(planner: planner, engine: engine)

  let result = await coordinator.reconcile(reason: .manualRefresh)

  #expect(result.planIntentCount == 0)
  // Engine is always invoked, even for empty plans, so it can record its own metrics.
  #expect(engine.callCount == 1)
  #expect(engine.receivedPlan?.intents.isEmpty == true)
}

@Test("DisplayTopologyProviderStub default returns empty topology")
func displayTopologyProviderStubDefaultReturnsEmptyTopology() {
  let stub = DisplayTopologyProviderStub()
  #expect(stub.currentTopology().displays.isEmpty)
}

@Test("DisplayTopologyProviderStub returns configured topology")
func displayTopologyProviderStubReturnsConfiguredTopology() {
  let display = DisplaySnapshot(
    displayID: DisplayID(1),
    frame: CoreGraphics.CGRect(x: 0, y: 0, width: 1920, height: 1080),
    scaleFactor: 1.0
  )
  let topology = DisplayTopology(displays: [display])
  let stub = DisplayTopologyProviderStub(topology: topology)
  #expect(stub.currentTopology().displays.count == 1)
}

// MARK: - Startup and manual-refresh trigger tests

@Test("Startup trigger with stub planner produces zero intents and completes safely")
@MainActor
func startupTriggerWithStubPlannerCompletesSafely() async {
  // Mirrors the production bootstrap composition: stub planner returns empty plan.
  let inventory = FakeWindowInventoryService(snapshots: [])
  let planner = SpyProjectionPlanner()
  planner.stubbedPlan = .empty
  let engine = SpyPlacementTransactionEngine()
  let diagnostics = SpyDiagnosticsService()
  let coordinator = makeCoordinator(
    inventory: inventory,
    planner: planner,
    engine: engine,
    diagnostics: diagnostics
  )

  let result = await coordinator.reconcile(reason: .startupInitialization)

  #expect(result.planIntentCount == 0)
  #expect(result.executionReport.appliedIntents.isEmpty)
  #expect(result.executionReport.failedIntents.isEmpty)
  // .startupInitialization maps to nil WMEvent — no diagnostics event recorded.
  #expect(diagnostics.recordedEvents.isEmpty)
  // Engine is always invoked even for empty plans.
  #expect(engine.callCount == 1)
  guard case .startupInitialization = result.reason else {
    Issue.record("Expected .startupInitialization, got \(result.reason)")
    return
  }
}

@Test("Manual refresh trigger with stub planner produces zero intents and completes safely")
@MainActor
func manualRefreshTriggerWithStubPlannerCompletesSafely() async {
  // Mirrors the Refresh menu-item trigger path.
  let inventory = FakeWindowInventoryService(snapshots: [])
  let planner = SpyProjectionPlanner()
  planner.stubbedPlan = .empty
  let engine = SpyPlacementTransactionEngine()
  let diagnostics = SpyDiagnosticsService()
  let coordinator = makeCoordinator(
    inventory: inventory,
    planner: planner,
    engine: engine,
    diagnostics: diagnostics
  )

  let result = await coordinator.reconcile(reason: .manualRefresh)

  #expect(result.planIntentCount == 0)
  #expect(result.executionReport.appliedIntents.isEmpty)
  #expect(result.executionReport.failedIntents.isEmpty)
  // .manualRefresh maps to nil WMEvent — no diagnostics event recorded.
  #expect(diagnostics.recordedEvents.isEmpty)
  #expect(engine.callCount == 1)
  guard case .manualRefresh = result.reason else {
    Issue.record("Expected .manualRefresh, got \(result.reason)")
    return
  }
}

@Test("Startup trigger refreshes inventory exactly once")
@MainActor
func startupTriggerRefreshesInventoryExactlyOnce() async {
  let inventory = FakeWindowInventoryService(snapshots: [])
  let coordinator = makeCoordinator(inventory: inventory)

  _ = await coordinator.reconcile(reason: .startupInitialization)

  #expect(inventory.refreshCallCount == 1)
}

@Test("Manual refresh trigger refreshes inventory exactly once")
@MainActor
func manualRefreshTriggerRefreshesInventoryExactlyOnce() async {
  let inventory = FakeWindowInventoryService(snapshots: [])
  let coordinator = makeCoordinator(inventory: inventory)

  _ = await coordinator.reconcile(reason: .manualRefresh)

  #expect(inventory.refreshCallCount == 1)
}

// MARK: - ObserverAndReconcileHub tests

@Test("Observer hub start wires source and stop unwires it")
@MainActor
func observerHubStartAndStopLifecycle() async {
  let source = ObserverEventSourceStub()
  let spy = ReconciliationTriggerSpy()
  let hub = ObserverAndReconcileHub(eventSource: source, coordinator: spy)

  hub.start()
  #expect(source.startCallCount == 1)

  hub.stop()
  #expect(source.stopCallCount == 1)

  source.emit(.wmEvent)

  let completed = await eventually(timeoutNanoseconds: 100_000_000) {
    !spy.reasons.isEmpty
  }

  #expect(!completed)
  #expect(spy.reasons.isEmpty)
}

@Test("Observer hub maps wmEvent to wmEvent reconcile reason")
@MainActor
func observerHubMapsWMEvent() async {
  let source = ObserverEventSourceStub()
  let spy = ReconciliationTriggerSpy()
  let hub = ObserverAndReconcileHub(eventSource: source, coordinator: spy)

  hub.start()
  source.emit(.wmEvent)

  let completed = await eventually {
    spy.reasons.count == 1
  }

  #expect(completed)
  #expect(spy.reasons.count == 1)
  #expect(spy.reasons.first == .wmEvent)
}

@Test("Observer hub maps display topology event to displayTopologyChanged")
@MainActor
func observerHubMapsDisplayTopologyEvent() async {
  let source = ObserverEventSourceStub()
  let spy = ReconciliationTriggerSpy()
  let hub = ObserverAndReconcileHub(eventSource: source, coordinator: spy)

  hub.start()
  source.emit(.displayTopologyChanged)

  let completed = await eventually {
    spy.reasons.count == 1
  }

  #expect(completed)
  #expect(spy.reasons.count == 1)
  #expect(spy.reasons.first == .displayTopologyChanged)
}

@Test("Observer hub maps spaceChanged to wmEvent reconcile reason")
@MainActor
func observerHubMapsSpaceChanged() async {
  let source = ObserverEventSourceStub()
  let spy = ReconciliationTriggerSpy()
  let hub = ObserverAndReconcileHub(eventSource: source, coordinator: spy)

  hub.start()
  source.emit(.spaceChanged)

  let completed = await eventually {
    spy.reasons.count == 1
  }

  #expect(completed)
  #expect(spy.reasons.count == 1)
  #expect(spy.reasons.first == .wmEvent)
}

@Test("Observer hub coalesces repeated wm events into one reconcile")
@MainActor
func observerHubCoalescesRepeatedWMEvents() async {
  let source = ObserverEventSourceStub()
  let spy = ReconciliationTriggerSpy()
  let hub = ObserverAndReconcileHub(eventSource: source, coordinator: spy)

  hub.start()
  source.emit(.wmEvent)
  source.emit(.wmEvent)
  source.emit(.wmEvent)

  let completed = await eventually {
    spy.reasons.count == 1
  }

  #expect(completed)
  #expect(spy.reasons.count == 1)
  #expect(spy.reasons.first == .wmEvent)
}

@Test("Observer hub upgrades mixed burst to displayTopologyChanged")
@MainActor
func observerHubUpgradesMixedBurstToDisplayTopologyChanged() async {
  let source = ObserverEventSourceStub()
  let spy = ReconciliationTriggerSpy()
  let hub = ObserverAndReconcileHub(eventSource: source, coordinator: spy)

  hub.start()
  source.emit(.wmEvent)
  source.emit(.displayTopologyChanged)
  source.emit(.wmEvent)

  let completed = await eventually {
    spy.reasons.count == 1
  }

  #expect(completed)
  #expect(spy.reasons.count == 1)
  #expect(spy.reasons.first == .displayTopologyChanged)
}

// MARK: - Milestone 10: Viewport-aware reconciliation runtime tests

/// Creates a snapshot with a configurable displayID for multi-display viewport tests.
private func makeTestSnapshotOnDisplay(id: String, displayID: UInt32) -> ManagedWindowSnapshot {
  ManagedWindowSnapshot(
    windowID: ManagedWindowID(id),
    app: AppDescriptor(bundleID: "com.test.app", displayName: "TestApp", pid: 1234),
    frameOnDisplay: CoreGraphics.CGRect(x: 100, y: 100, width: 800, height: 600),
    displayID: DisplayID(displayID),
    capabilities: WindowCapabilities(canMove: true, canResize: true),
    eligibility: .eligible
  )
}

@Test("ReconciliationCoordinator passes worldState to planner during reconcile")
@MainActor
func reconciliationCoordinatorPassesWorldStateToPlannerDuringReconcile() async {
  let worldState = WorldStateStub()
  let planner = SpyProjectionPlanner()
  let coordinator = makeCoordinator(planner: planner, worldState: worldState)

  _ = await coordinator.reconcile(reason: .manualRefresh)

  // The planner must have been called and received the world state instance.
  #expect(planner.callCount == 1)
  #expect(planner.lastWorldState != nil)
}

@Test("ReconciliationCoordinator: in-viewport window produces plan intent through coordinator")
@MainActor
func reconciliationViewportStateConsumedDuringReconcile() async {
  let displayID = DisplayID(1)
  let worldState = WorldStateStub()

  // Viewport at origin covers paper [0, 1920) × [0, 1080).
  // w-in has paperRect inside the viewport; w-out is far outside.
  let viewport = ViewportState(displayID: displayID, origin: .zero, scale: 1.0)
  worldState.updateWorkspaceState(WorkspaceState(displayID: displayID, viewport: viewport))
  worldState.updatePaperWindowState(
    PaperWindowState(
      windowID: ManagedWindowID("w-in"),
      paperRect: PaperRect(x: 0, y: 0, width: 800, height: 600)
    ))
  worldState.updatePaperWindowState(
    PaperWindowState(
      windowID: ManagedWindowID("w-out"),
      paperRect: PaperRect(x: 5000, y: 0, width: 800, height: 600)
    ))

  let display = DisplaySnapshot(
    displayID: displayID,
    frame: CoreGraphics.CGRect(x: 0, y: 0, width: 1920, height: 1080),
    scaleFactor: 1.0
  )
  let inventory = FakeWindowInventoryService(snapshots: [
    makeTestSnapshot(id: "w-in"),
    makeTestSnapshot(id: "w-out"),
  ])
  let topology = DisplayTopologyProviderStub(topology: DisplayTopology(displays: [display]))
  let engine = SpyPlacementTransactionEngine()
  let coordinator = ReconciliationCoordinator(
    inventoryService: inventory,
    topologyProvider: topology,
    planner: TilingProjectionPlanner(),
    engine: engine,
    worldState: worldState,
    diagnostics: SpyDiagnosticsService()
  )

  let result = await coordinator.reconcile(reason: .manualRefresh)

  // Only w-in is inside the viewport — the coordinator should surface exactly 1 intent.
  #expect(result.planIntentCount == 1)
  #expect(engine.receivedPlan?.intents.count == 1)
  #expect(engine.receivedPlan?.intents.first?.windowID == ManagedWindowID("w-in"))
}

@Test("ReconciliationCoordinator: different viewport offsets produce different plans")
@MainActor
func reconciliationDifferentViewportOffsetsProduceDifferentPlans() async {
  let displayID = DisplayID(1)
  let worldState = WorldStateStub()

  // w-left at paper x=0 (inside viewport at origin), w-right at paper x=3000 (outside the
  // 1920-wide viewport at origin, but visible when viewport shifts to x=2500).
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

  let display = DisplaySnapshot(
    displayID: displayID,
    frame: CoreGraphics.CGRect(x: 0, y: 0, width: 1920, height: 1080),
    scaleFactor: 1.0
  )
  let snapshots = [makeTestSnapshot(id: "w-left"), makeTestSnapshot(id: "w-right")]
  let topology = DisplayTopologyProviderStub(topology: DisplayTopology(displays: [display]))

  // First reconcile: viewport at x=0 → only w-left is visible.
  let engine1 = SpyPlacementTransactionEngine()
  worldState.updateWorkspaceState(
    WorkspaceState(
      displayID: displayID,
      viewport: ViewportState(displayID: displayID, origin: .zero)
    ))
  let coordinator1 = ReconciliationCoordinator(
    inventoryService: FakeWindowInventoryService(snapshots: snapshots),
    topologyProvider: topology,
    planner: TilingProjectionPlanner(),
    engine: engine1,
    worldState: worldState,
    diagnostics: SpyDiagnosticsService()
  )
  let result1 = await coordinator1.reconcile(reason: .manualRefresh)

  // Second reconcile: shift viewport to x=2500 → only w-right is visible.
  let engine2 = SpyPlacementTransactionEngine()
  worldState.updateWorkspaceState(
    WorkspaceState(
      displayID: displayID,
      viewport: ViewportState(displayID: displayID, origin: PaperPoint(x: 2500, y: 0))
    ))
  let coordinator2 = ReconciliationCoordinator(
    inventoryService: FakeWindowInventoryService(snapshots: snapshots),
    topologyProvider: topology,
    planner: TilingProjectionPlanner(),
    engine: engine2,
    worldState: worldState,
    diagnostics: SpyDiagnosticsService()
  )
  let result2 = await coordinator2.reconcile(reason: .manualRefresh)

  // The two reconciliations must produce different plans.
  #expect(result1.planIntentCount == 1)
  #expect(engine1.receivedPlan?.intents.first?.windowID == ManagedWindowID("w-left"))

  #expect(result2.planIntentCount == 1)
  #expect(engine2.receivedPlan?.intents.first?.windowID == ManagedWindowID("w-right"))
}

@Test("ReconciliationCoordinator: per-display viewport behavior preserved through reconciliation")
@MainActor
func reconciliationPerDisplayViewportPreservedThroughCoordinator() async {
  let worldState = WorldStateStub()

  // Display 1: viewport at origin [0, 1920). w-1a inside, w-1b outside.
  let displayID1 = DisplayID(1)
  worldState.updateWorkspaceState(
    WorkspaceState(
      displayID: displayID1,
      viewport: ViewportState(displayID: displayID1, origin: .zero, scale: 1.0)
    ))
  worldState.updatePaperWindowState(
    PaperWindowState(
      windowID: ManagedWindowID("w-1a"),
      paperRect: PaperRect(x: 0, y: 0, width: 800, height: 600)
    ))
  worldState.updatePaperWindowState(
    PaperWindowState(
      windowID: ManagedWindowID("w-1b"),
      paperRect: PaperRect(x: 5000, y: 0, width: 800, height: 600)
    ))

  // Display 2: viewport offset to x=3000, covers [3000, 4920). w-2a outside, w-2b inside.
  let displayID2 = DisplayID(2)
  worldState.updateWorkspaceState(
    WorkspaceState(
      displayID: displayID2,
      viewport: ViewportState(displayID: displayID2, origin: PaperPoint(x: 3000, y: 0), scale: 1.0)
    ))
  worldState.updatePaperWindowState(
    PaperWindowState(
      windowID: ManagedWindowID("w-2a"),
      paperRect: PaperRect(x: 0, y: 0, width: 800, height: 600)
    ))
  worldState.updatePaperWindowState(
    PaperWindowState(
      windowID: ManagedWindowID("w-2b"),
      paperRect: PaperRect(x: 3500, y: 0, width: 800, height: 600)
    ))

  let display1 = DisplaySnapshot(
    displayID: displayID1,
    frame: CoreGraphics.CGRect(x: 0, y: 0, width: 1920, height: 1080),
    scaleFactor: 1.0
  )
  let display2 = DisplaySnapshot(
    displayID: displayID2,
    frame: CoreGraphics.CGRect(x: 1920, y: 0, width: 1920, height: 1080),
    scaleFactor: 1.0
  )
  let snapshots = [
    makeTestSnapshotOnDisplay(id: "w-1a", displayID: 1),
    makeTestSnapshotOnDisplay(id: "w-1b", displayID: 1),
    makeTestSnapshotOnDisplay(id: "w-2a", displayID: 2),
    makeTestSnapshotOnDisplay(id: "w-2b", displayID: 2),
  ]
  let topology = DisplayTopologyProviderStub(topology: DisplayTopology(displays: [display1, display2]))
  let engine = SpyPlacementTransactionEngine()
  let coordinator = ReconciliationCoordinator(
    inventoryService: FakeWindowInventoryService(snapshots: snapshots),
    topologyProvider: topology,
    planner: TilingProjectionPlanner(),
    engine: engine,
    worldState: worldState,
    diagnostics: SpyDiagnosticsService()
  )

  let result = await coordinator.reconcile(reason: .manualRefresh)

  // Only w-1a (display 1, in viewport) and w-2b (display 2, in viewport) should be projected.
  #expect(result.planIntentCount == 2)
  let projectedIDs = Set(engine.receivedPlan?.intents.map { $0.windowID.rawValue } ?? [])
  #expect(projectedIDs.contains("w-1a"))
  #expect(projectedIDs.contains("w-2b"))
  #expect(!projectedIDs.contains("w-1b"))
  #expect(!projectedIDs.contains("w-2a"))
}

@Test("ReconciliationCoordinator: all windows out of viewport produces empty plan safely")
@MainActor
func reconciliationAllWindowsOutOfViewportProducesEmptyPlan() async {
  let displayID = DisplayID(1)
  let worldState = WorldStateStub()

  // Both windows are far outside the viewport at origin [0, 1920).
  worldState.updateWorkspaceState(
    WorkspaceState(
      displayID: displayID,
      viewport: ViewportState(displayID: displayID, origin: .zero, scale: 1.0)
    ))
  worldState.updatePaperWindowState(
    PaperWindowState(
      windowID: ManagedWindowID("w-far-1"),
      paperRect: PaperRect(x: 5000, y: 0, width: 800, height: 600)
    ))
  worldState.updatePaperWindowState(
    PaperWindowState(
      windowID: ManagedWindowID("w-far-2"),
      paperRect: PaperRect(x: 8000, y: 0, width: 800, height: 600)
    ))

  let display = DisplaySnapshot(
    displayID: displayID,
    frame: CoreGraphics.CGRect(x: 0, y: 0, width: 1920, height: 1080),
    scaleFactor: 1.0
  )
  let engine = SpyPlacementTransactionEngine()
  let coordinator = ReconciliationCoordinator(
    inventoryService: FakeWindowInventoryService(snapshots: [
      makeTestSnapshot(id: "w-far-1"),
      makeTestSnapshot(id: "w-far-2"),
    ]),
    topologyProvider: DisplayTopologyProviderStub(topology: DisplayTopology(displays: [display])),
    planner: TilingProjectionPlanner(),
    engine: engine,
    worldState: worldState,
    diagnostics: SpyDiagnosticsService()
  )

  let result = await coordinator.reconcile(reason: .manualRefresh)

  #expect(result.planIntentCount == 0)
  #expect(engine.receivedPlan?.intents.isEmpty == true)
}
