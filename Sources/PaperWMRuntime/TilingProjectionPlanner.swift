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

    // 4. Tile each group within its display.
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

      // Tile horizontally: divide the usable width into equal columns.
      let count = CGFloat(windows.count)
      let tileWidth = (usable.width / count).rounded(.down)

      for (index, snapshot) in windows.enumerated() {
        let x = usable.minX + CGFloat(index) * tileWidth
        // Last window takes the remaining width to absorb any rounding remainder.
        let width = index == windows.count - 1 ? (usable.maxX - x) : tileWidth
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

  // MARK: - Private

  /// Returns `true` when the window is eligible and can be moved and resized.
  private func isEligible(_ snapshot: ManagedWindowSnapshot) -> Bool {
    guard case .eligible = snapshot.eligibility else { return false }
    return snapshot.capabilities.canMove && snapshot.capabilities.canResize
  }
}
