import CoreGraphics
import Foundation
import PaperWMCore

/// A concrete `ProjectionPlanner` that tiles eligible windows horizontally across
/// the primary display (or the first available display when no primary is known).
///
/// Strategy:
/// - Only windows marked `.eligible` with `canMove` and `canResize` are planned.
/// - Windows are sorted by their `windowID` raw value for deterministic ordering.
/// - A single display is chosen: the primary display, or the lowest-ID display.
/// - The display's `visibleFrame` (falling back to `frame`) defines the usable area.
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

    // 2. Choose a display deterministically.
    let display = chooseDisplay(from: topology)

    // 3. Sort windows by windowID for stable, deterministic ordering.
    let sorted = eligible.sorted { $0.windowID.rawValue < $1.windowID.rawValue }

    // 4. Compute the usable area for tiling.
    let usable = display.visibleFrame ?? display.frame

    guard usable.width > 0, usable.height > 0 else { return .empty }

    // 5. Tile horizontally: divide the usable width into equal columns.
    let count = CGFloat(sorted.count)
    let tileWidth = (usable.width / count).rounded(.down)

    var intents: [PlacementIntent] = []
    for (index, snapshot) in sorted.enumerated() {
      let x = usable.minX + CGFloat(index) * tileWidth
      // Last window takes the remaining width to absorb any rounding remainder.
      let width =
        index == sorted.count - 1 ? (usable.maxX - x) : tileWidth
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

    return PlacementPlan(intents: intents)
  }

  // MARK: - Private

  /// Returns `true` when the window is eligible and can be moved and resized.
  private func isEligible(_ snapshot: ManagedWindowSnapshot) -> Bool {
    guard case .eligible = snapshot.eligibility else { return false }
    return snapshot.capabilities.canMove && snapshot.capabilities.canResize
  }

  /// Picks the primary display; falls back to the display with the smallest ID.
  private func chooseDisplay(from topology: DisplayTopology) -> DisplaySnapshot {
    if let primary = topology.displays.first(where: { $0.isPrimary }) {
      return primary
    }
    return topology.displays.min(by: { $0.displayID.rawValue < $1.displayID.rawValue })!
  }
}
