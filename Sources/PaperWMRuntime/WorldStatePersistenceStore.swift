import Foundation
import PaperWMCore

// MARK: - Protocol

/// Typed persistence store for world state.
///
/// Implementations are responsible for serialising and deserialising a
/// `PersistedWorldState` snapshot.  The `load()` method returns `nil` when no
/// previously persisted data exists (first launch, cleared data, …), allowing
/// callers to treat that as a clean/empty starting state without throwing.
public protocol WorldStatePersistenceStoreProtocol: AnyObject {
    /// Returns the previously persisted world state, or `nil` when none exists.
    func load() -> PersistedWorldState?

    /// Persists the given world-state snapshot.
    ///
    /// - Throws: Any I/O or encoding error encountered while writing.
    func save(_ state: PersistedWorldState) throws
}

// MARK: - In-memory implementation (for tests and stubs)

/// In-memory implementation of `WorldStatePersistenceStoreProtocol`.
///
/// Stores the last saved snapshot in a property.  Suitable for unit tests and
/// as an injected stub in contexts where disk persistence is not needed.
public final class InMemoryWorldStatePersistenceStore: WorldStatePersistenceStoreProtocol {
    private var stored: PersistedWorldState?

    /// Creates an empty store, optionally pre-seeded with an existing snapshot.
    public init(initial: PersistedWorldState? = nil) {
        stored = initial
    }

    public func load() -> PersistedWorldState? {
        stored
    }

    public func save(_ state: PersistedWorldState) throws {
        stored = state
    }
}
