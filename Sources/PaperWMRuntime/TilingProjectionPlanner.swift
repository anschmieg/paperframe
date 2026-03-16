import CoreGraphics
import Foundation
import PaperWMCore

/// A concrete `ProjectionPlanner` that tiles eligible windows horizontally,
/// independently per display.
///
/// Strategy:
/// - Only windows marked `.eligible` with `canMove` and `canResize` are planned.
/// - Windows are grouped by their current `displayID`.
/// - Within each group, windows are sorted by `windowID` raw value for deterministic ordering.
/// - Display groups are processed in ascending `displayID` order for determinism.
/// - Each group uses the matching `DisplaySnapshot`'s `visibleFrame` (falling back to `frame`)
///   as the usable area. When no matching snapshot exists, the lowest-ID display is used.
/// - Windows are divided into equal-width columns within the usable area.
/// - All generated frames stay within the chosen display's usable region.
///
/// Viewport-aware behavior (Milestone 9):
/// - When `worldState` has an active workspace for a display, only windows whose
///   `paperRect` overlaps the viewport are projected. Windows outside the viewport
///   receive no placement intent (`.leaveUntouched` semantics).
/// - When no active workspace exists for a display, all eligible windows are tiled
///   (backward-compatible fallback).
/// - Windows with no `PaperWindowState` in `worldState` are included by default
///   when a viewport is active (graceful fallback for newly discovered windows).
public final class TilingProjectionPlanner: ProjectionPlannerProtocol {

  public init() {}

  public func computePlan(
    snapshots: [ManagedWindowSnapshot],
    topology: DisplayTopology,
    worldState: any WorldStateProtocol
  ) -> PlacementPlan {
    // 1. Filter to eligible windows that can be moved and resized.
    let eligible = snapshots.filter { isEligible($0) }

    guard !eligible.isEmpty else { return .empty }
    guard !topology.displays.isEmpty else { return .empty }

    // 2. Group eligible windows by their current displayID.
    var groups: [DisplayID: [ManagedWindowSnapshot]] = [:]
    for snapshot in eligible {
      groups[snapshot.displayID, default: []].append(snapshot)
    }

    // 3. Process groups in deterministic (ascending displayID) order.
    let sortedGroupKeys = groups.keys.sorted { $0.rawValue < $1.rawValue }

    // 4. Tile each group within its display, filtered by active viewport when present.
    var intents: [PlacementIntent] = []
    for groupDisplayID in sortedGroupKeys {
      let windows = groups[groupDisplayID]!.sorted {
        $0.windowID.rawValue < $1.windowID.rawValue
      }

      // Resolve the display snapshot for this group, falling back to the lowest-ID display.
      let display =
        topology.snapshot(for: groupDisplayID) ?? topology.displays.min(by: {
          $0.displayID.rawValue < $1.displayID.rawValue
        })!

      let usable = display.visibleFrame ?? display.frame
      guard usable.width > 0, usable.height > 0 else { continue }

      // Apply viewport filtering when an active workspace exists for this display.
      // When no workspace is configured, all windows are tiled (backward-compatible).
      let windowsToTile = viewportFiltered(
        windows: windows,
        displayID: groupDisplayID,
        usableSize: usable.size,
        worldState: worldState
      )

      guard !windowsToTile.isEmpty else { continue }

      // Tile horizontally: divide the usable width into equal columns.
      let count = CGFloat(windowsToTile.count)
      let tileWidth = (usable.width / count).rounded(.down)

      for (index, snapshot) in windowsToTile.enumerated() {
        let x = usable.minX + CGFloat(index) * tileWidth
        // Last window takes the remaining width to absorb any rounding remainder.
        let width = index == windowsToTile.count - 1 ? (usable.maxX - x) : tileWidth
        let frame = CGRect(
          x: x,
          y: usable.minY,
          width: max(width, 1),
          height: usable.height
        )
        intents.append(
          PlacementIntent(
            windowID: snapshot.windowID,
            targetFrame: frame,
            targetDisplayID: display.displayID
          )
        )
      }
    }

    return PlacementPlan(intents: intents)
  }

  // MARK: - Viewport filtering

  /// Returns the subset of windows that should be projected into the active viewport.
  ///
  /// When no active workspace exists for `displayID`, returns `windows` unchanged
  /// (tile-everything fallback, preserves pre-Milestone-9 behavior).
  ///
  /// When a workspace exists, only windows whose `paperRect` overlaps the viewport
  /// are included. Windows with no recorded `PaperWindowState` are included by
  /// default (graceful fallback for newly discovered windows).
  private func viewportFiltered(
    windows: [ManagedWindowSnapshot],
    displayID: DisplayID,
    usableSize: CGSize,
    worldState: any WorldStateProtocol
  ) -> [ManagedWindowSnapshot] {
    guard let workspace = worldState.activeWorkspace(for: displayID) else {
      // No viewport configured for this display — include all windows.
      return windows
    }
    let viewport = workspace.viewport
    return windows.filter { snapshot in
      guard let paperState = worldState.paperWindowState(for: snapshot.windowID) else {
        // No paper-space position yet — include by default.
        return true
      }
      return paperRectOverlapsViewport(
        paperState.paperRect,
        viewport: viewport,
        displayUsableSize: usableSize
      )
    }
  }

  /// Returns `true` when `rect` intersects the visible viewport rectangle in paper space.
  ///
  /// The viewport rectangle is computed from the display's usable pixel dimensions and
  /// the viewport's scale factor:
  /// - viewport width  = `displayUsableSize.width  / scale`
  /// - viewport height = `displayUsableSize.height / scale`
  /// - viewport origin = `viewport.origin` (top-left corner in paper space)
  private func paperRectOverlapsViewport(
    _ rect: PaperRect,
    viewport: ViewportState,
    displayUsableSize: CGSize
  ) -> Bool {
    let scale = viewport.scale > 0 ? viewport.scale : 1.0
    let vpWidth = Double(displayUsableSize.width) / scale
    let vpHeight = Double(displayUsableSize.height) / scale
    let vpMinX = viewport.origin.x
    let vpMinY = viewport.origin.y
    let vpMaxX = vpMinX + vpWidth
    let vpMaxY = vpMinY + vpHeight

    // Standard axis-aligned bounding-box intersection test.
    return rect.x < vpMaxX
      && (rect.x + rect.width) > vpMinX
      && rect.y < vpMaxY
      && (rect.y + rect.height) > vpMinY
  }

  // MARK: - Private helpers

  /// Returns `true` when the window is eligible and can be moved and resized.
  private func isEligible(_ snapshot: ManagedWindowSnapshot) -> Bool {
    guard case .eligible = snapshot.eligibility else { return false }
    return snapshot.capabilities.canMove && snapshot.capabilities.canResize
  }
}
