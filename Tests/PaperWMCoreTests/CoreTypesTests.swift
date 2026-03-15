import Foundation
import CoreGraphics
import Testing
@testable import PaperWMCore

@Test("ManagedWindowID equality")
func managedWindowIDEquality() {
    let a = ManagedWindowID("win-1")
    let b = ManagedWindowID("win-1")
    let c = ManagedWindowID("win-2")
    #expect(a == b)
    #expect(a != c)
}

@Test("ManagedWindowID hashable semantics")
func managedWindowIDHashable() {
    let ids: Set<ManagedWindowID> = [ManagedWindowID("x"), ManagedWindowID("x"), ManagedWindowID("y")]
    #expect(ids.count == 2)
}

@Test("DisplayID equality")
func displayIDEquality() {
    #expect(DisplayID(1) == DisplayID(1))
    #expect(DisplayID(1) != DisplayID(2))
}

@Test("WorkspaceID equality")
func workspaceIDEquality() {
    let uuid = UUID()
    #expect(WorkspaceID(uuid) == WorkspaceID(uuid))
    #expect(WorkspaceID(UUID()) != WorkspaceID(UUID()))
}

@Test("WindowCapabilities explicit fields")
func windowCapabilitiesExplicitFields() {
    let caps = WindowCapabilities(canMove: true, canResize: true)
    #expect(caps.canMove)
    #expect(caps.canResize)
    #expect(!caps.canMinimize)
    #expect(!caps.canFocus)
    #expect(!caps.canClose)
}

@Test("WindowCapabilities.none")
func windowCapabilitiesNone() {
    let caps = WindowCapabilities.none
    #expect(!caps.canMove)
    #expect(!caps.canResize)
    #expect(!caps.canMinimize)
    #expect(!caps.canFocus)
    #expect(!caps.canClose)
}

@Test("WindowCapabilities all")
func windowCapabilitiesAll() {
    let all = WindowCapabilities(
        canMove: true,
        canResize: true,
        canMinimize: true,
        canFocus: true,
        canClose: true
    )
    #expect(all.canMove)
    #expect(all.canResize)
    #expect(all.canMinimize)
    #expect(all.canFocus)
    #expect(all.canClose)
}

@Test("ManagedWindowSnapshot init")
func managedWindowSnapshotInit() {
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
    #expect(snapshot.windowID == id)
    #expect(snapshot.app.bundleID == "com.test.App")
    #expect(!snapshot.isMinimized)
    #expect(!snapshot.isFocused)
}

@Test("PaperRect.zero")
func paperRectZero() {
    let r = PaperRect.zero
    #expect(r.x == 0)
    #expect(r.y == 0)
    #expect(r.width == 0)
    #expect(r.height == 0)
}

@Test("PaperRect equality")
func paperRectEquality() {
    let a = PaperRect(x: 10, y: 20, width: 300, height: 200)
    let b = PaperRect(x: 10, y: 20, width: 300, height: 200)
    #expect(a == b)
}

@Test("PaperPoint.zero")
func paperPointZero() {
    #expect(PaperPoint.zero.x == 0)
    #expect(PaperPoint.zero.y == 0)
}

@Test("WindowMode values")
func windowModeValues() {
    let modes: [WindowMode] = [.tiled, .floating, .fullscreen, .minimized]
    #expect(modes.count == 4)
}

@Test("ViewportState defaults")
func viewportStateDefaults() {
    let viewport = ViewportState(displayID: DisplayID(1))
    #expect(viewport.origin == PaperPoint.zero)
    #expect(viewport.scale == 1.0)
}

@Test("PlacementPlan.empty")
func placementPlanEmpty() {
    let plan = PlacementPlan.empty
    #expect(plan.intents.isEmpty)
}

@Test("PlacementIntent init")
func placementIntentInit() {
    let intent = PlacementIntent(
        windowID: ManagedWindowID("w-1"),
        targetFrame: CGRect(x: 0, y: 0, width: 800, height: 600),
        targetDisplayID: DisplayID(1)
    )
    #expect(intent.windowID == ManagedWindowID("w-1"))
    #expect(intent.targetDisplayID == DisplayID(1))
}

@Test("DisplayTopology.empty")
func displayTopologyEmpty() {
    let topology = DisplayTopology.empty
    #expect(topology.displays.isEmpty)
    #expect(topology.snapshot(for: DisplayID(1)) == nil)
}

@Test("DisplayTopology lookup")
func displayTopologyLookup() {
    let snap = DisplaySnapshot(
        displayID: DisplayID(42),
        frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
        scaleFactor: 2.0
    )
    let topology = DisplayTopology(displays: [snap])
    #expect(topology.snapshot(for: DisplayID(42)) != nil)
    #expect(topology.snapshot(for: DisplayID(99)) == nil)
}

@Test("Direction all cases")
func directionAllCases() {
    let directions: [Direction] = [.left, .right, .up, .down]
    #expect(directions.count == 4)
}

@Test("PlacementExecutionReport defaults")
func placementExecutionReportDefaults() {
    let report = PlacementExecutionReport()
    #expect(report.results.isEmpty)
    #expect(report.appliedIntents.isEmpty)
    #expect(report.failedIntents.isEmpty)
}

@Test("DiagnosticsReport defaults")
func diagnosticsReportDefaults() {
    let report = DiagnosticsReport()
    #expect(report.recentEvents.isEmpty)
    #expect(report.managedWindowCount == 0)
    #expect(!report.accessibilityGranted)
    #expect(!report.inputMonitoringGranted)
    #expect(report.recentFailures.isEmpty)
}
