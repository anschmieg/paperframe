import Foundation
import PaperWMCore

/// Stub implementation of `WindowMutatorProtocol`.
///
/// Always reports the configured result without performing any real window mutations.
/// Used as a compile-time placeholder and as an injectable test double.
///
/// TODO (Phase 3): Wire `AXWindowMutator` (PaperWMMacAdapters) through AppDelegate.
public final class WindowMutatorStub: WindowMutatorProtocol {

    /// The result returned for every `applyPlacement` call.
    /// Defaults to `.success` so tests can assert applied counts without extra setup.
    public var stubbedResult: PlacementResult

    public init(stubbedResult: PlacementResult = .success) {
        self.stubbedResult = stubbedResult
    }

    public func applyPlacement(intent: PlacementIntent, snapshot: ManagedWindowSnapshot) -> PlacementResult {
        return stubbedResult
    }
}
