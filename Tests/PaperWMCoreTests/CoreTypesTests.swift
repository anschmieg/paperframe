import XCTest
@testable import PaperWMCore

final class IdentityTests: XCTestCase {

    func testManagedWindowIDEquality() {
        let a = ManagedWindowID("win-1")
        let b = ManagedWindowID("win-1")
        let c = ManagedWindowID("win-2")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testManagedWindowIDHashable() {
        let ids: Set<ManagedWindowID> = [ManagedWindowID("x"), ManagedWindowID("x"), ManagedWindowID("y")]
        XCTAssertEqual(ids.count, 2)
    }

    func testDisplayIDEquality() {
        XCTAssertEqual(DisplayID(1), DisplayID(1))
        XCTAssertNotEqual(DisplayID(1), DisplayID(2))
    }

    func testWorkspaceIDEquality() {
        let uuid = UUID()
        XCTAssertEqual(WorkspaceID(uuid), WorkspaceID(uuid))
        XCTAssertNotEqual(WorkspaceID(UUID()), WorkspaceID(UUID()))
    }
}

final class SnapshotTypesTests: XCTestCase {

    func testWindowCapabilitiesExplicitFields() {
        let caps = WindowCapabilities(canMove: true, canResize: true)
        XCTAssertTrue(caps.canMove)
        XCTAssertTrue(caps.canResize)
        XCTAssertFalse(caps.canMinimize)
        XCTAssertFalse(caps.canFocus)
        XCTAssertFalse(caps.canClose)
    }

    func testWindowCapabilitiesNone() {
        let caps = WindowCapabilities.none
        XCTAssertFalse(caps.canMove)
        XCTAssertFalse(caps.canResize)
        XCTAssertFalse(caps.canMinimize)
        XCTAssertFalse(caps.canFocus)
        XCTAssertFalse(caps.canClose)
    }

    func testWindowCapabilitiesAll() {
        let all = WindowCapabilities(
            canMove: true, canResize: true, canMinimize: true, canFocus: true, canClose: true
        )
        XCTAssertTrue(all.canMove)
        XCTAssertTrue(all.canResize)
        XCTAssertTrue(all.canMinimize)
        XCTAssertTrue(all.canFocus)
        XCTAssertTrue(all.canClose)
    }

    func testManagedWindowSnapshotInit() {
        let id = ManagedWindowID("w-1")
        let app = AppDescriptor(bundleID: "com.test.App", displayName: "TestApp", pid: 1234)
        let snapshot = ManagedWindowSnapshot(
            windowID: id,
            app: app,
            frameOnDisplay: CGRect(x: 0, y: 0, width: 1280, height: 800),
            displayID: DisplayID(1),
            capabilities: WindowCapabilities(canMove: true, canResize: true),
            eligibility: .eligible
        )
        XCTAssertEqual(snapshot.windowID, id)
        XCTAssertEqual(snapshot.app.bundleID, "com.test.App")
        XCTAssertFalse(snapshot.isMinimized)
        XCTAssertFalse(snapshot.isFocused)
    }
}

final class PaperSpaceTypesTests: XCTestCase {

    func testPaperRectZero() {
        let r = PaperRect.zero
        XCTAssertEqual(r.x, 0)
        XCTAssertEqual(r.y, 0)
        XCTAssertEqual(r.width, 0)
        XCTAssertEqual(r.height, 0)
    }

    func testPaperRectEquality() {
        let a = PaperRect(x: 10, y: 20, width: 300, height: 200)
        let b = PaperRect(x: 10, y: 20, width: 300, height: 200)
        XCTAssertEqual(a, b)
    }

    func testPaperPointZero() {
        XCTAssertEqual(PaperPoint.zero.x, 0)
        XCTAssertEqual(PaperPoint.zero.y, 0)
    }

    func testWindowModeValues() {
        let modes: [WindowMode] = [.tiled, .floating, .fullscreen, .minimized]
        XCTAssertEqual(modes.count, 4)
    }

    func testViewportStateDefaults() {
        let viewport = ViewportState(displayID: DisplayID(1))
        XCTAssertEqual(viewport.origin, PaperPoint.zero)
        XCTAssertEqual(viewport.scale, 1.0)
    }
}

final class PlanningTypesTests: XCTestCase {

    func testPlacementPlanEmpty() {
        let plan = PlacementPlan.empty
        XCTAssertTrue(plan.intents.isEmpty)
    }

    func testPlacementIntentInit() {
        let intent = PlacementIntent(
            windowID: ManagedWindowID("w-1"),
            targetFrame: CGRect(x: 0, y: 0, width: 800, height: 600),
            targetDisplayID: DisplayID(1)
        )
        XCTAssertEqual(intent.windowID, ManagedWindowID("w-1"))
        XCTAssertEqual(intent.targetDisplayID, DisplayID(1))
    }

    func testDisplayTopologyEmpty() {
        let topology = DisplayTopology.empty
        XCTAssertTrue(topology.displays.isEmpty)
        XCTAssertNil(topology.snapshot(for: DisplayID(1)))
    }

    func testDisplayTopologyLookup() {
        let snap = DisplaySnapshot(
            displayID: DisplayID(42),
            frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
            scaleFactor: 2.0
        )
        let topology = DisplayTopology(displays: [snap])
        XCTAssertNotNil(topology.snapshot(for: DisplayID(42)))
        XCTAssertNil(topology.snapshot(for: DisplayID(99)))
    }

    func testDirectionAllCases() {
        let directions: [Direction] = [.left, .right, .up, .down]
        XCTAssertEqual(directions.count, 4)
    }

    func testPlacementExecutionReportDefaults() {
        let report = PlacementExecutionReport()
        XCTAssertTrue(report.results.isEmpty)
        XCTAssertTrue(report.appliedIntents.isEmpty)
        XCTAssertTrue(report.failedIntents.isEmpty)
    }
}

final class DiagnosticsTypesTests: XCTestCase {

    func testDiagnosticsReportDefaults() {
        let report = DiagnosticsReport()
        XCTAssertTrue(report.recentEvents.isEmpty)
        XCTAssertEqual(report.managedWindowCount, 0)
        XCTAssertFalse(report.accessibilityGranted)
        XCTAssertFalse(report.inputMonitoringGranted)
        XCTAssertTrue(report.recentFailures.isEmpty)
    }

    func testDiagnosticsReportPermissionsState() {
        let state = PermissionsState(accessibility: .granted, inputMonitoring: .denied)
        let report = DiagnosticsReport(permissionsState: state)
        XCTAssertTrue(report.accessibilityGranted)
        XCTAssertFalse(report.inputMonitoringGranted)
        XCTAssertEqual(report.permissionsState.accessibility, .granted)
    }
}

final class PermissionTypesTests: XCTestCase {

    func testNotDeterminedDefault() {
        let state = PermissionsState.notDetermined
        XCTAssertEqual(state.accessibility, .notDetermined)
        XCTAssertEqual(state.inputMonitoring, .notDetermined)
    }

    func testReducedModeWhenAccessibilityNotGranted() {
        let denied = PermissionsState(accessibility: .denied, inputMonitoring: .granted)
        XCTAssertTrue(denied.isReducedMode)

        let notDetermined = PermissionsState(accessibility: .notDetermined, inputMonitoring: .granted)
        XCTAssertTrue(notDetermined.isReducedMode)
    }

    func testNotReducedModeWhenAccessibilityGranted() {
        let state = PermissionsState(accessibility: .granted, inputMonitoring: .notDetermined)
        XCTAssertFalse(state.isReducedMode)
        XCTAssertTrue(state.accessibilityAvailable)
    }

    func testFullyGrantedRequiresBoth() {
        let bothGranted = PermissionsState(accessibility: .granted, inputMonitoring: .granted)
        XCTAssertTrue(bothGranted.isFullyGranted)

        let onlyAX = PermissionsState(accessibility: .granted, inputMonitoring: .denied)
        XCTAssertFalse(onlyAX.isFullyGranted)

        let neither = PermissionsState.notDetermined
        XCTAssertFalse(neither.isFullyGranted)
    }

    func testPermissionStatusHashable() {
        let statuses: Set<PermissionStatus> = [.granted, .denied, .notDetermined, .granted]
        XCTAssertEqual(statuses.count, 3)
    }
}
