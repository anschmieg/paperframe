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

// MARK: - Milestone 9: Viewport projection test helpers

/// Builds a `WorldStateStub` with an active workspace (and optional paper window states)
/// for `displayID`.
private func makeWorldStateWithViewport(
  displayID: DisplayID = DisplayID(1),
  viewportOrigin: PaperPoint = .zero,
  viewportScale: Double = 1.0,
  paperWindows: [(id: String, x: Double, y: Double, width: Double, height: Double)] = []
) -> WorldStateStub {
  let ws = WorldStateStub()
  let viewport = ViewportState(displayID: displayID, origin: viewportOrigin, scale: viewportScale)
  let workspace = WorkspaceState(
    displayID: displayID,
    viewport: viewport,
    windowIDs: paperWindows.map { ManagedWindowID($0.id) }
  )
  ws.updateWorkspaceState(workspace)
  for pw in paperWindows {
    let paperState = PaperWindowState(
      windowID: ManagedWindowID(pw.id),
      paperRect: PaperRect(x: pw.x, y: pw.y, width: pw.width, height: pw.height)
    )
    ws.updatePaperWindowState(paperState)
  }
  return ws
}

// MARK: - Milestone 9: Viewport projection tests

@Test("Viewport planner: in-viewport window is projected")
func viewportWindowInViewportIsProjected() {
  let planner = TilingProjectionPlanner()
  let display = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
  let topology = DisplayTopology(displays: [display])
  // Viewport at origin covers paper [0, 1920) × [0, 1080). Window is fully inside.
  let worldState = makeWorldStateWithViewport(
    displayID: DisplayID(1),
    paperWindows: [("w-1", 0, 0, 800, 600)]
  )
  let plan = planner.computePlan(
    snapshots: [makeEligibleSnapshot(id: "w-1")],
    topology: topology,
    worldState: worldState
  )
  #expect(plan.intents.count == 1)
  #expect(plan.intents[0].windowID == ManagedWindowID("w-1"))
}

@Test("Viewport planner: out-of-viewport window is excluded")
func viewportWindowOutOfViewportIsExcluded() {
  let planner = TilingProjectionPlanner()
  let display = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
  let topology = DisplayTopology(displays: [display])
  // Window paper rect at x=5000 — well outside viewport [0, 1920).
  let worldState = makeWorldStateWithViewport(
    displayID: DisplayID(1),
    paperWindows: [("w-1", 5000, 0, 800, 600)]
  )
  let plan = planner.computePlan(
    snapshots: [makeEligibleSnapshot(id: "w-1")],
    topology: topology,
    worldState: worldState
  )
  #expect(plan.intents.isEmpty)
}

@Test("Viewport planner: partial overlap is included")
func viewportWindowPartialOverlapIsIncluded() {
  let planner = TilingProjectionPlanner()
  let display = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
  let topology = DisplayTopology(displays: [display])
  // Window starts at x=1800, width=500 → spans [1800, 2300). Viewport covers [0, 1920). Overlap.
  let worldState = makeWorldStateWithViewport(
    displayID: DisplayID(1),
    paperWindows: [("w-1", 1800, 0, 500, 600)]
  )
  let plan = planner.computePlan(
    snapshots: [makeEligibleSnapshot(id: "w-1")],
    topology: topology,
    worldState: worldState
  )
  #expect(plan.intents.count == 1)
  #expect(plan.intents[0].windowID == ManagedWindowID("w-1"))
}

@Test("Viewport planner: no workspace falls back to tiling all windows")
func viewportNoWorkspaceFallsBackToTilingAll() {
  let planner = TilingProjectionPlanner()
  let display = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
  let topology = DisplayTopology(displays: [display])
  // Empty world state — no workspace configured for any display.
  let plan = planner.computePlan(
    snapshots: [makeEligibleSnapshot(id: "w-1"), makeEligibleSnapshot(id: "w-2")],
    topology: topology,
    worldState: WorldStateStub()
  )
  #expect(plan.intents.count == 2)
}

@Test("Viewport planner: window without paper state is included in viewport mode")
func viewportWindowWithoutPaperStateIncluded() {
  let planner = TilingProjectionPlanner()
  let display = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
  let topology = DisplayTopology(displays: [display])
  // Workspace exists but w-1 has no registered PaperWindowState.
  let worldState = makeWorldStateWithViewport(
    displayID: DisplayID(1),
    paperWindows: []
  )
  let plan = planner.computePlan(
    snapshots: [makeEligibleSnapshot(id: "w-1")],
    topology: topology,
    worldState: worldState
  )
  // Window with no paper state is included by default.
  #expect(plan.intents.count == 1)
  #expect(plan.intents[0].windowID == ManagedWindowID("w-1"))
}

@Test("Viewport planner: viewport offset scrolls which windows are visible")
func viewportOffsetScrollsVisibleWindows() {
  let planner = TilingProjectionPlanner()
  let display = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
  let topology = DisplayTopology(displays: [display])
  // Viewport offset to paper x=2000 → visible range [2000, 3920).
  // w-left at paper [0, 800): outside. w-right at paper [2500, 3300): inside.
  let worldState = makeWorldStateWithViewport(
    displayID: DisplayID(1),
    viewportOrigin: PaperPoint(x: 2000, y: 0),
    viewportScale: 1.0,
    paperWindows: [
      ("w-left", 0, 0, 800, 600),
      ("w-right", 2500, 0, 800, 600),
    ]
  )
  let plan = planner.computePlan(
    snapshots: [
      makeEligibleSnapshot(id: "w-left"),
      makeEligibleSnapshot(id: "w-right"),
    ],
    topology: topology,
    worldState: worldState
  )
  #expect(plan.intents.count == 1)
  #expect(plan.intents[0].windowID == ManagedWindowID("w-right"))
}

@Test("Viewport planner: deterministic ordering preserved within viewport")
func viewportDeterministicOrdering() {
  let planner = TilingProjectionPlanner()
  let display = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
  let topology = DisplayTopology(displays: [display])
  // All three windows are inside the viewport (origin at 0, size 1920×1080).
  let worldState = makeWorldStateWithViewport(
    displayID: DisplayID(1),
    paperWindows: [
      ("w-z", 0, 0, 400, 600),
      ("w-a", 500, 0, 400, 600),
      ("w-m", 1000, 0, 400, 600),
    ]
  )
  // Supply snapshots in non-sorted order.
  let plan = planner.computePlan(
    snapshots: [
      makeEligibleSnapshot(id: "w-z"),
      makeEligibleSnapshot(id: "w-m"),
      makeEligibleSnapshot(id: "w-a"),
    ],
    topology: topology,
    worldState: worldState
  )
  #expect(plan.intents.count == 3)
  // Sorted by windowID: w-a, w-m, w-z.
  #expect(plan.intents[0].windowID == ManagedWindowID("w-a"))
  #expect(plan.intents[1].windowID == ManagedWindowID("w-m"))
  #expect(plan.intents[2].windowID == ManagedWindowID("w-z"))
}

@Test("Viewport planner: per-display viewports are independent")
func viewportPerDisplayIndependent() {
  let planner = TilingProjectionPlanner()
  let display1 = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
  let display2 = makeDisplay(id: 2, frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080))
  let topology = DisplayTopology(displays: [display1, display2])

  let ws = WorldStateStub()

  // Display 1: viewport at origin [0, 1920). w-1 in, w-2 out.
  let vp1 = ViewportState(displayID: DisplayID(1), origin: .zero, scale: 1.0)
  ws.updateWorkspaceState(WorkspaceState(displayID: DisplayID(1), viewport: vp1))
  ws.updatePaperWindowState(
    PaperWindowState(
      windowID: ManagedWindowID("w-1"),
      paperRect: PaperRect(x: 0, y: 0, width: 800, height: 600)
    ))
  ws.updatePaperWindowState(
    PaperWindowState(
      windowID: ManagedWindowID("w-2"),
      paperRect: PaperRect(x: 5000, y: 0, width: 800, height: 600)
    ))

  // Display 2: viewport offset to x=3000, covers [3000, 4920). w-3 out, w-4 in.
  let vp2 = ViewportState(
    displayID: DisplayID(2), origin: PaperPoint(x: 3000, y: 0), scale: 1.0)
  ws.updateWorkspaceState(WorkspaceState(displayID: DisplayID(2), viewport: vp2))
  ws.updatePaperWindowState(
    PaperWindowState(
      windowID: ManagedWindowID("w-3"),
      paperRect: PaperRect(x: 0, y: 0, width: 800, height: 600)
    ))
  ws.updatePaperWindowState(
    PaperWindowState(
      windowID: ManagedWindowID("w-4"),
      paperRect: PaperRect(x: 3500, y: 0, width: 800, height: 600)
    ))

  let plan = planner.computePlan(
    snapshots: [
      makeEligibleSnapshot(id: "w-1", displayID: 1),
      makeEligibleSnapshot(id: "w-2", displayID: 1),
      makeEligibleSnapshot(id: "w-3", displayID: 2),
      makeEligibleSnapshot(id: "w-4", displayID: 2),
    ],
    topology: topology,
    worldState: ws
  )
  // Only w-1 (display 1, in viewport) and w-4 (display 2, in viewport) are projected.
  #expect(plan.intents.count == 2)
  let projectedIDs = Set(plan.intents.map { $0.windowID.rawValue })
  #expect(projectedIDs.contains("w-1"))
  #expect(projectedIDs.contains("w-4"))
}

@Test("Viewport planner: all windows out of viewport returns empty plan")
func viewportAllWindowsOutReturnsEmpty() {
  let planner = TilingProjectionPlanner()
  let display = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
  let topology = DisplayTopology(displays: [display])
  let worldState = makeWorldStateWithViewport(
    displayID: DisplayID(1),
    paperWindows: [
      ("w-1", 5000, 0, 800, 600),
      ("w-2", 6000, 0, 800, 600),
    ]
  )
  let plan = planner.computePlan(
    snapshots: [
      makeEligibleSnapshot(id: "w-1"),
      makeEligibleSnapshot(id: "w-2"),
    ],
    topology: topology,
    worldState: worldState
  )
  #expect(plan.intents.isEmpty)
}

@Test("Viewport planner: frames stay within display bounds after filtering")
func viewportFilteredFramesStayInDisplayBounds() {
  let planner = TilingProjectionPlanner()
  let displayFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
  let display = makeDisplay(id: 1, frame: displayFrame)
  let topology = DisplayTopology(displays: [display])
  let worldState = makeWorldStateWithViewport(
    displayID: DisplayID(1),
    paperWindows: [
      ("w-a", 0, 0, 400, 600),
      ("w-b", 500, 0, 400, 600),
    ]
  )
  let plan = planner.computePlan(
    snapshots: [
      makeEligibleSnapshot(id: "w-a"),
      makeEligibleSnapshot(id: "w-b"),
    ],
    topology: topology,
    worldState: worldState
  )
  #expect(plan.intents.count == 2)
  for intent in plan.intents {
    #expect(intent.targetFrame.minX >= displayFrame.minX)
    #expect(intent.targetFrame.minY >= displayFrame.minY)
    #expect(intent.targetFrame.maxX <= displayFrame.maxX)
    #expect(intent.targetFrame.maxY <= displayFrame.maxY)
  }
}

@Test("Viewport planner: world-state viewport update changes planning output")
func viewportWorldStateUpdateChangesPlanOutput() {
  let planner = TilingProjectionPlanner()
  let display = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
  let topology = DisplayTopology(displays: [display])

  let ws = WorldStateStub()
  ws.updatePaperWindowState(
    PaperWindowState(
      windowID: ManagedWindowID("w-1"),
      paperRect: PaperRect(x: 0, y: 0, width: 800, height: 600)
    ))
  ws.updatePaperWindowState(
    PaperWindowState(
      windowID: ManagedWindowID("w-2"),
      paperRect: PaperRect(x: 3000, y: 0, width: 800, height: 600)
    ))

  let snapshots = [
    makeEligibleSnapshot(id: "w-1"),
    makeEligibleSnapshot(id: "w-2"),
  ]

  // Viewport at x=0 — viewport covers [0, 1920). Only w-1 is in range.
  ws.updateWorkspaceState(
    WorkspaceState(
      displayID: DisplayID(1),
      viewport: ViewportState(displayID: DisplayID(1), origin: PaperPoint(x: 0, y: 0))
    ))
  let plan1 = planner.computePlan(snapshots: snapshots, topology: topology, worldState: ws)
  #expect(plan1.intents.count == 1)
  #expect(plan1.intents[0].windowID == ManagedWindowID("w-1"))

  // Shift viewport to x=2500 — viewport covers [2500, 4420). Only w-2 is in range.
  ws.updateWorkspaceState(
    WorkspaceState(
      displayID: DisplayID(1),
      viewport: ViewportState(displayID: DisplayID(1), origin: PaperPoint(x: 2500, y: 0))
    ))
  let plan2 = planner.computePlan(snapshots: snapshots, topology: topology, worldState: ws)
  #expect(plan2.intents.count == 1)
  #expect(plan2.intents[0].windowID == ManagedWindowID("w-2"))
}

@Test("Viewport planner: ineligible windows are excluded even when inside viewport")
func viewportIneligibleWindowsExcluded() {
  let planner = TilingProjectionPlanner()
  let display = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
  let topology = DisplayTopology(displays: [display])
  let worldState = makeWorldStateWithViewport(
    displayID: DisplayID(1),
    paperWindows: [
      ("w-eligible", 0, 0, 800, 600),
      ("w-ineligible", 0, 0, 800, 600),
    ]
  )
  let plan = planner.computePlan(
    snapshots: [
      makeEligibleSnapshot(id: "w-eligible"),
      makeIneligibleSnapshot(id: "w-ineligible"),
    ],
    topology: topology,
    worldState: worldState
  )
  #expect(plan.intents.count == 1)
  #expect(plan.intents[0].windowID == ManagedWindowID("w-eligible"))
}

// MARK: - TilingProjectionPlanner: visible frame per display (existing)

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
