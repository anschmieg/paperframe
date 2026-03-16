import CoreGraphics
import Foundation
import PaperWMCore
import Testing

@testable import PaperWMRuntime

// MARK: - Test helpers

private func makeDisplay(
  id: UInt32 = 1,
  frame: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080),
  visibleFrame: CGRect? = nil,
  isPrimary: Bool = false
) -> DisplaySnapshot {
  DisplaySnapshot(
    displayID: DisplayID(id),
    frame: frame,
    visibleFrame: visibleFrame,
    scaleFactor: 1.0,
    isPrimary: isPrimary
  )
}

private func makeEligibleSnapshot(
  id: String,
  displayID: UInt32 = 1
) -> ManagedWindowSnapshot {
  ManagedWindowSnapshot(
    windowID: ManagedWindowID(id),
    app: AppDescriptor(bundleID: "com.test.app", displayName: "TestApp", pid: 1234),
    frameOnDisplay: CGRect(x: 100, y: 100, width: 800, height: 600),
    displayID: DisplayID(displayID),
    capabilities: WindowCapabilities(canMove: true, canResize: true),
    eligibility: .eligible
  )
}

private func makeIneligibleSnapshot(id: String) -> ManagedWindowSnapshot {
  ManagedWindowSnapshot(
    windowID: ManagedWindowID(id),
    app: AppDescriptor(bundleID: "com.test.app", displayName: "TestApp", pid: 1234),
    frameOnDisplay: CGRect(x: 0, y: 0, width: 800, height: 600),
    displayID: DisplayID(1),
    capabilities: WindowCapabilities(canMove: true, canResize: true),
    eligibility: .ineligible(reason: "system window")
  )
}

private func makeUnmovableSnapshot(id: String) -> ManagedWindowSnapshot {
  ManagedWindowSnapshot(
    windowID: ManagedWindowID(id),
    app: AppDescriptor(bundleID: "com.test.app", displayName: "TestApp", pid: 1234),
    frameOnDisplay: CGRect(x: 0, y: 0, width: 800, height: 600),
    displayID: DisplayID(1),
    capabilities: WindowCapabilities(canMove: false, canResize: false),
    eligibility: .eligible
  )
}

// MARK: - TilingProjectionPlanner tests

@Test("TilingProjectionPlanner empty snapshots returns empty plan")
func tilingPlannerEmptySnapshotsReturnsEmptyPlan() {
  let planner = TilingProjectionPlanner()
  let topology = DisplayTopology(displays: [makeDisplay()])
  let plan = planner.computePlan(
    snapshots: [],
    topology: topology,
    worldState: WorldStateStub()
  )
  #expect(plan.intents.isEmpty)
}

@Test("TilingProjectionPlanner empty topology returns empty plan")
func tilingPlannerEmptyTopologyReturnsEmptyPlan() {
  let planner = TilingProjectionPlanner()
  let plan = planner.computePlan(
    snapshots: [makeEligibleSnapshot(id: "w-1")],
    topology: .empty,
    worldState: WorldStateStub()
  )
  #expect(plan.intents.isEmpty)
}

@Test("TilingProjectionPlanner one eligible window produces one intent")
func tilingPlannerOneEligibleWindowProducesOneIntent() {
  let planner = TilingProjectionPlanner()
  let display = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
  let topology = DisplayTopology(displays: [display])
  let plan = planner.computePlan(
    snapshots: [makeEligibleSnapshot(id: "w-1")],
    topology: topology,
    worldState: WorldStateStub()
  )
  #expect(plan.intents.count == 1)
  #expect(plan.intents[0].windowID == ManagedWindowID("w-1"))
  #expect(plan.intents[0].targetDisplayID == DisplayID(1))
}

@Test("TilingProjectionPlanner one eligible window frame fills display")
func tilingPlannerOneWindowFrameFillsDisplay() {
  let planner = TilingProjectionPlanner()
  let display = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
  let topology = DisplayTopology(displays: [display])
  let plan = planner.computePlan(
    snapshots: [makeEligibleSnapshot(id: "w-1")],
    topology: topology,
    worldState: WorldStateStub()
  )
  let frame = plan.intents[0].targetFrame
  #expect(frame.width == 1920)
  #expect(frame.height == 1080)
}

@Test("TilingProjectionPlanner multiple eligible windows produces deterministic intents")
func tilingPlannerMultipleWindowsProducesDeterministicIntents() {
  let planner = TilingProjectionPlanner()
  let display = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1200, height: 800))
  let topology = DisplayTopology(displays: [display])
  // Provide snapshots out of order to verify stable sort.
  let snapshots = [
    makeEligibleSnapshot(id: "w-c"),
    makeEligibleSnapshot(id: "w-a"),
    makeEligibleSnapshot(id: "w-b"),
  ]
  let plan = planner.computePlan(
    snapshots: snapshots,
    topology: topology,
    worldState: WorldStateStub()
  )
  #expect(plan.intents.count == 3)
  // Sorted by windowID: w-a, w-b, w-c
  #expect(plan.intents[0].windowID == ManagedWindowID("w-a"))
  #expect(plan.intents[1].windowID == ManagedWindowID("w-b"))
  #expect(plan.intents[2].windowID == ManagedWindowID("w-c"))
}

@Test("TilingProjectionPlanner generates deterministic output for same input")
func tilingPlannerIsDeterministic() {
  let planner = TilingProjectionPlanner()
  let display = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
  let topology = DisplayTopology(displays: [display])
  let snapshots = [
    makeEligibleSnapshot(id: "w-2"),
    makeEligibleSnapshot(id: "w-1"),
  ]
  let plan1 = planner.computePlan(
    snapshots: snapshots,
    topology: topology,
    worldState: WorldStateStub()
  )
  let plan2 = planner.computePlan(
    snapshots: snapshots,
    topology: topology,
    worldState: WorldStateStub()
  )
  #expect(plan1.intents.count == plan2.intents.count)
  for (i1, i2) in zip(plan1.intents, plan2.intents) {
    #expect(i1.windowID == i2.windowID)
    #expect(i1.targetFrame == i2.targetFrame)
    #expect(i1.targetDisplayID == i2.targetDisplayID)
  }
}

@Test("TilingProjectionPlanner filters out ineligible windows")
func tilingPlannerFiltersOutIneligibleWindows() {
  let planner = TilingProjectionPlanner()
  let display = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
  let topology = DisplayTopology(displays: [display])
  let snapshots = [
    makeEligibleSnapshot(id: "w-eligible"),
    makeIneligibleSnapshot(id: "w-ineligible"),
  ]
  let plan = planner.computePlan(
    snapshots: snapshots,
    topology: topology,
    worldState: WorldStateStub()
  )
  #expect(plan.intents.count == 1)
  #expect(plan.intents[0].windowID == ManagedWindowID("w-eligible"))
}

@Test("TilingProjectionPlanner filters out windows without move/resize capability")
func tilingPlannerFiltersOutUnmovableWindows() {
  let planner = TilingProjectionPlanner()
  let display = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
  let topology = DisplayTopology(displays: [display])
  let snapshots = [
    makeEligibleSnapshot(id: "w-movable"),
    makeUnmovableSnapshot(id: "w-fixed"),
  ]
  let plan = planner.computePlan(
    snapshots: snapshots,
    topology: topology,
    worldState: WorldStateStub()
  )
  #expect(plan.intents.count == 1)
  #expect(plan.intents[0].windowID == ManagedWindowID("w-movable"))
}

@Test("TilingProjectionPlanner all ineligible windows returns empty plan")
func tilingPlannerAllIneligibleReturnsEmptyPlan() {
  let planner = TilingProjectionPlanner()
  let display = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
  let topology = DisplayTopology(displays: [display])
  let snapshots = [
    makeIneligibleSnapshot(id: "w-1"),
    makeIneligibleSnapshot(id: "w-2"),
  ]
  let plan = planner.computePlan(
    snapshots: snapshots,
    topology: topology,
    worldState: WorldStateStub()
  )
  #expect(plan.intents.isEmpty)
}

@Test("TilingProjectionPlanner frames stay within display bounds")
func tilingPlannerFramesStayWithinDisplayBounds() {
  let planner = TilingProjectionPlanner()
  let displayFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
  let display = makeDisplay(id: 1, frame: displayFrame)
  let topology = DisplayTopology(displays: [display])
  let snapshots = [
    makeEligibleSnapshot(id: "w-a"),
    makeEligibleSnapshot(id: "w-b"),
    makeEligibleSnapshot(id: "w-c"),
  ]
  let plan = planner.computePlan(
    snapshots: snapshots,
    topology: topology,
    worldState: WorldStateStub()
  )
  for intent in plan.intents {
    #expect(intent.targetFrame.minX >= displayFrame.minX)
    #expect(intent.targetFrame.minY >= displayFrame.minY)
    #expect(intent.targetFrame.maxX <= displayFrame.maxX)
    #expect(intent.targetFrame.maxY <= displayFrame.maxY)
  }
}

@Test("TilingProjectionPlanner uses visible frame when available")
func tilingPlannerUsesVisibleFrameWhenAvailable() {
  let planner = TilingProjectionPlanner()
  let visibleFrame = CGRect(x: 0, y: 25, width: 1920, height: 1055)
  let display = makeDisplay(
    id: 1,
    frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
    visibleFrame: visibleFrame
  )
  let topology = DisplayTopology(displays: [display])
  let plan = planner.computePlan(
    snapshots: [makeEligibleSnapshot(id: "w-1")],
    topology: topology,
    worldState: WorldStateStub()
  )
  #expect(plan.intents.count == 1)
  #expect(plan.intents[0].targetFrame == visibleFrame)
}

@Test("TilingProjectionPlanner tiles windows on their originating display, not primary")
func tilingPlannerWindowsStayOnOriginatingDisplay() {
  let planner = TilingProjectionPlanner()
  let primary = makeDisplay(
    id: 2,
    frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
    isPrimary: true
  )
  let secondary = makeDisplay(
    id: 1,
    frame: CGRect(x: 2560, y: 0, width: 1920, height: 1080),
    isPrimary: false
  )
  let topology = DisplayTopology(displays: [secondary, primary])
  // Window is on display 1 (secondary), should stay there even though display 2 is primary.
  let plan = planner.computePlan(
    snapshots: [makeEligibleSnapshot(id: "w-1", displayID: 1)],
    topology: topology,
    worldState: WorldStateStub()
  )
  #expect(plan.intents.count == 1)
  #expect(plan.intents[0].targetDisplayID == DisplayID(1))
}

@Test("TilingProjectionPlanner falls back to lowest-ID display when no primary")
func tilingPlannerFallsBackToLowestIDDisplay() {
  let planner = TilingProjectionPlanner()
  let displayA = makeDisplay(
    id: 3,
    frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
    isPrimary: false
  )
  let displayB = makeDisplay(
    id: 1,
    frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
    isPrimary: false
  )
  let topology = DisplayTopology(displays: [displayA, displayB])
  let plan = planner.computePlan(
    snapshots: [makeEligibleSnapshot(id: "w-1")],
    topology: topology,
    worldState: WorldStateStub()
  )
  #expect(plan.intents.count == 1)
  #expect(plan.intents[0].targetDisplayID == DisplayID(1))
}

@Test("TilingProjectionPlanner tiles two windows covering full display width")
func tilingPlannerTilesTwoWindowsCoveringFullWidth() {
  let planner = TilingProjectionPlanner()
  let display = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 2000, height: 1000))
  let topology = DisplayTopology(displays: [display])
  let snapshots = [
    makeEligibleSnapshot(id: "w-a"),
    makeEligibleSnapshot(id: "w-b"),
  ]
  let plan = planner.computePlan(
    snapshots: snapshots,
    topology: topology,
    worldState: WorldStateStub()
  )
  #expect(plan.intents.count == 2)
  let first = plan.intents[0].targetFrame
  let second = plan.intents[1].targetFrame
  // First window starts at the left edge.
  #expect(first.minX == 0)
  // Second window immediately follows the first.
  #expect(second.minX == first.maxX)
  // Together they span the full display width.
  #expect(second.maxX == 2000)
  // Both windows have full display height.
  #expect(first.height == 1000)
  #expect(second.height == 1000)
}

// MARK: - Multi-display tests

@Test("TilingProjectionPlanner tiles windows independently per display")
func tilingPlannerTilesIndependentlyPerDisplay() {
  let planner = TilingProjectionPlanner()
  let display1 = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
  let display2 = makeDisplay(id: 2, frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440))
  let topology = DisplayTopology(displays: [display1, display2])
  let snapshots = [
    makeEligibleSnapshot(id: "w-a", displayID: 1),
    makeEligibleSnapshot(id: "w-b", displayID: 2),
  ]
  let plan = planner.computePlan(
    snapshots: snapshots,
    topology: topology,
    worldState: WorldStateStub()
  )
  #expect(plan.intents.count == 2)
  // Windows are emitted in display-ID order: display 1 first, display 2 second.
  let intentForA = plan.intents.first { $0.windowID == ManagedWindowID("w-a") }
  let intentForB = plan.intents.first { $0.windowID == ManagedWindowID("w-b") }
  #expect(intentForA?.targetDisplayID == DisplayID(1))
  #expect(intentForB?.targetDisplayID == DisplayID(2))
  // Each window should fill its own display (one window per display).
  #expect(intentForA?.targetFrame.width == 1920)
  #expect(intentForB?.targetFrame.width == 2560)
}

@Test("TilingProjectionPlanner emits intents in deterministic display-then-window order")
func tilingPlannerDeterministicMultiDisplayOrdering() {
  let planner = TilingProjectionPlanner()
  let display1 = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
  let display2 = makeDisplay(id: 2, frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080))
  let topology = DisplayTopology(displays: [display2, display1])  // Note: reversed order in array.
  let snapshots = [
    makeEligibleSnapshot(id: "w-z", displayID: 2),
    makeEligibleSnapshot(id: "w-a", displayID: 1),
    makeEligibleSnapshot(id: "w-m", displayID: 2),
  ]
  let plan = planner.computePlan(
    snapshots: snapshots,
    topology: topology,
    worldState: WorldStateStub()
  )
  #expect(plan.intents.count == 3)
  // Display 1 comes first (lowest ID), then display 2.
  #expect(plan.intents[0].targetDisplayID == DisplayID(1))
  #expect(plan.intents[0].windowID == ManagedWindowID("w-a"))
  // Within display 2, windows sorted by windowID: w-m before w-z.
  #expect(plan.intents[1].targetDisplayID == DisplayID(2))
  #expect(plan.intents[1].windowID == ManagedWindowID("w-m"))
  #expect(plan.intents[2].targetDisplayID == DisplayID(2))
  #expect(plan.intents[2].windowID == ManagedWindowID("w-z"))
}

@Test("TilingProjectionPlanner frames stay within their respective display bounds")
func tilingPlannerFramesStayWithinPerDisplayBounds() {
  let planner = TilingProjectionPlanner()
  let frame1 = CGRect(x: 0, y: 0, width: 1920, height: 1080)
  let frame2 = CGRect(x: 1920, y: 0, width: 2560, height: 1440)
  let display1 = makeDisplay(id: 1, frame: frame1)
  let display2 = makeDisplay(id: 2, frame: frame2)
  let topology = DisplayTopology(displays: [display1, display2])
  let snapshots = [
    makeEligibleSnapshot(id: "w-a", displayID: 1),
    makeEligibleSnapshot(id: "w-b", displayID: 1),
    makeEligibleSnapshot(id: "w-c", displayID: 2),
  ]
  let plan = planner.computePlan(
    snapshots: snapshots,
    topology: topology,
    worldState: WorldStateStub()
  )
  for intent in plan.intents {
    let bounds = intent.targetDisplayID == DisplayID(1) ? frame1 : frame2
    #expect(intent.targetFrame.minX >= bounds.minX)
    #expect(intent.targetFrame.minY >= bounds.minY)
    #expect(intent.targetFrame.maxX <= bounds.maxX)
    #expect(intent.targetFrame.maxY <= bounds.maxY)
  }
}

@Test("TilingProjectionPlanner uses visible frame per display when available")
func tilingPlannerUsesVisibleFramePerDisplay() {
  let planner = TilingProjectionPlanner()
  let visibleFrame1 = CGRect(x: 0, y: 25, width: 1920, height: 1055)
  let display1 = makeDisplay(
    id: 1,
    frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
    visibleFrame: visibleFrame1
  )
  let visibleFrame2 = CGRect(x: 1920, y: 25, width: 2560, height: 1415)
  let display2 = makeDisplay(
    id: 2,
    frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440),
    visibleFrame: visibleFrame2
  )
  let topology = DisplayTopology(displays: [display1, display2])
  let snapshots = [
    makeEligibleSnapshot(id: "w-1", displayID: 1),
    makeEligibleSnapshot(id: "w-2", displayID: 2),
  ]
  let plan = planner.computePlan(
    snapshots: snapshots,
    topology: topology,
    worldState: WorldStateStub()
  )
  let intent1 = plan.intents.first { $0.windowID == ManagedWindowID("w-1") }
  let intent2 = plan.intents.first { $0.windowID == ManagedWindowID("w-2") }
  #expect(intent1?.targetFrame == visibleFrame1)
  #expect(intent2?.targetFrame == visibleFrame2)
}
