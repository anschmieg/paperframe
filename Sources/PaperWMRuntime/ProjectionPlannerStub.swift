import Foundation
import PaperWMCore

/// Stub implementation of `ProjectionPlannerProtocol`.
///
/// In a real implementation this converts paper-space coordinates to screen
/// coordinates using the display topology and viewport state, then produces
/// `PlacementIntent` values for each eligible window.
///
/// TODO (Phase 4): Implement projection from PaperRect → screen CGRect using
///                 DisplayTopology and ViewportState.
/// TODO (Phase 4): Respect VisibilityPolicy when deciding which windows to project.
public final class ProjectionPlannerStub: ProjectionPlannerProtocol {

    public init() {}

    /// Returns an empty plan. A real implementation computes screen-coordinate intents.
    public func computePlan(
        snapshots: [ManagedWindowSnapshot],
        topology: DisplayTopology,
        worldState: any WorldStateProtocol
    ) -> PlacementPlan {
        // TODO: For each eligible snapshot, look up its PaperWindowState,
        //       project paperRect → screenRect via the display's ViewportState,
        //       and emit a PlacementIntent.
        return .empty
    }
}
