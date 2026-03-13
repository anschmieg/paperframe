import XCTest
@testable import PaperWMRuntime
import PaperWMCore

/// Bootstrap tests for the Runtime layer.
///
/// These tests confirm the stubs compile, initialise, and return safe defaults.
/// Behavioral tests will be added when real implementations land.
final class PermissionsServiceStubTests: XCTestCase {

    func testDefaultStateIsNotDetermined() {
        let svc = PermissionsServiceStub()
        XCTAssertEqual(svc.currentState.accessibility, .notDetermined)
        XCTAssertEqual(svc.currentState.inputMonitoring, .notDetermined)
    }

    func testDefaultsAreNotGranted() {
        let svc = PermissionsServiceStub()
        XCTAssertFalse(svc.accessibilityGranted)
        XCTAssertFalse(svc.inputMonitoringGranted)
    }

    func testGrantedStateReflectsInConvenienceAccessors() {
        let grantedState = PermissionsState(accessibility: .granted, inputMonitoring: .granted)
        let svc = PermissionsServiceStub(initialState: grantedState)
        XCTAssertTrue(svc.accessibilityGranted)
        XCTAssertTrue(svc.inputMonitoringGranted)
    }

    func testReducedModeWhenAccessibilityNotGranted() {
        let svc = PermissionsServiceStub()
        XCTAssertTrue(svc.currentState.isReducedMode)
    }

    func testNotReducedModeWhenAccessibilityGranted() {
        let state = PermissionsState(accessibility: .granted, inputMonitoring: .notDetermined)
        let svc = PermissionsServiceStub(initialState: state)
        XCTAssertFalse(svc.currentState.isReducedMode)
    }

    func testRequestMethodsDoNotCrash() {
        let svc = PermissionsServiceStub()
        svc.requestAccessibilityPermission()
        svc.requestInputMonitoringPermission()
    }

    func testRefreshDoesNotCrash() {
        let svc = PermissionsServiceStub()
        svc.refresh()
        // Stub does not update state; it remains notDetermined.
        XCTAssertEqual(svc.currentState.accessibility, .notDetermined)
    }
}

final class WindowInventoryServiceStubTests: XCTestCase {

    func testInitialSnapshotsAreEmpty() {
        let svc = WindowInventoryServiceStub()
        XCTAssertTrue(svc.snapshots.isEmpty)
    }

    func testRefreshSnapshotDoesNotCrash() async {
        let svc = WindowInventoryServiceStub()
        await svc.refreshSnapshot()
        // Stub leaves snapshots empty; no crash is the assertion here.
        XCTAssertTrue(svc.snapshots.isEmpty)
    }
}

final class WorldStateStubTests: XCTestCase {

    func testPaperWindowStateRoundtrip() {
        let state = WorldStateStub()
        let id = ManagedWindowID("w-1")
        XCTAssertNil(state.paperWindowState(for: id))

        let pw = PaperWindowState(windowID: id, paperRect: PaperRect(x: 10, y: 20, width: 300, height: 200))
        state.updatePaperWindowState(pw)

        let retrieved = state.paperWindowState(for: id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.paperRect, pw.paperRect)
    }

    func testWorkspaceStateRoundtrip() {
        let worldState = WorldStateStub()
        let displayID = DisplayID(1)
        XCTAssertNil(worldState.activeWorkspace(for: displayID))

        let viewport = ViewportState(displayID: displayID)
        let ws = WorkspaceState(displayID: displayID, viewport: viewport)
        worldState.updateWorkspaceState(ws)

        XCTAssertNotNil(worldState.activeWorkspace(for: displayID))
    }
}

final class ProjectionPlannerStubTests: XCTestCase {

    func testReturnsEmptyPlan() {
        let planner = ProjectionPlannerStub()
        let worldState = WorldStateStub()
        let plan = planner.computePlan(
            snapshots: [],
            topology: .empty,
            worldState: worldState
        )
        XCTAssertTrue(plan.intents.isEmpty)
    }
}

final class PlacementTransactionEngineStubTests: XCTestCase {

    func testExecuteReturnsEmptyReport() async {
        let engine = PlacementTransactionEngineStub()
        let report = await engine.execute(plan: .empty)
        XCTAssertTrue(report.appliedIntents.isEmpty)
        XCTAssertTrue(report.failedIntents.isEmpty)
    }
}

final class DiagnosticsServiceStubTests: XCTestCase {

    func testRecordEventAndReport() {
        let svc = DiagnosticsServiceStub(eventCapacity: 10)
        svc.record(event: .displayTopologyChanged)
        svc.record(event: .activeSpaceChanged)

        let grantedState = PermissionsState(accessibility: .granted, inputMonitoring: .notDetermined)
        let report = svc.currentReport(
            permissionsState: grantedState,
            managedWindowCount: 3
        )

        XCTAssertEqual(report.recentEvents.count, 2)
        XCTAssertTrue(report.accessibilityGranted)
        XCTAssertFalse(report.inputMonitoringGranted)
        XCTAssertEqual(report.managedWindowCount, 3)
    }

    func testEventCapacityIsCapped() {
        let svc = DiagnosticsServiceStub(eventCapacity: 3)
        for _ in 0..<10 {
            svc.record(event: .displayTopologyChanged)
        }
        let report = svc.currentReport(
            permissionsState: .notDetermined,
            managedWindowCount: 0
        )
        XCTAssertEqual(report.recentEvents.count, 3)
    }

    func testRecordFailure() {
        let svc = DiagnosticsServiceStub()
        let windowID = ManagedWindowID("w-fail")
        svc.record(failure: .failed(windowID: windowID, reason: "AX timeout"))
        let report = svc.currentReport(
            permissionsState: .notDetermined,
            managedWindowCount: 0
        )
        XCTAssertEqual(report.recentFailures.count, 1)
    }

    func testPermissionsStateInReport() {
        let svc = DiagnosticsServiceStub()
        let state = PermissionsState(accessibility: .denied, inputMonitoring: .notDetermined)
        let report = svc.currentReport(permissionsState: state, managedWindowCount: 0)
        XCTAssertEqual(report.permissionsState.accessibility, .denied)
        XCTAssertTrue(report.permissionsState.isReducedMode)
    }
}

final class PersistenceStoreStubTests: XCTestCase {

    func testLoadDoesNotThrow() {
        let store = PersistenceStoreStub()
        XCTAssertNoThrow(try store.load())
    }

    func testSaveDoesNotThrow() {
        let store = PersistenceStoreStub()
        XCTAssertNoThrow(try store.save())
    }
}
