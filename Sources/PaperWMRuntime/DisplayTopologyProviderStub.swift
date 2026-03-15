import Foundation
import PaperWMCore

/// Stub implementation of `DisplayTopologyProviderProtocol`.
///
/// Returns a configurable `DisplayTopology`. Defaults to an empty topology
/// so tests that do not care about display geometry compile without extra setup.
///
/// TODO (Phase 4): Wire `DisplayAdapter` (PaperWMMacAdapters) into AppDelegate and pass it as
///                 the concrete `DisplayTopologyProviderProtocol` in production.
public final class DisplayTopologyProviderStub: DisplayTopologyProviderProtocol {

    /// The topology returned by `currentTopology()`.
    public var topology: DisplayTopology

    public init(topology: DisplayTopology = .empty) {
        self.topology = topology
    }

    // MARK: - DisplayTopologyProviderProtocol

    public func currentTopology() -> DisplayTopology {
        return topology
    }
}
