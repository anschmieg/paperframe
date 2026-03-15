import Foundation
import PaperWMCore

/// Stub implementation of `PersistenceStoreProtocol`.
///
/// In a real implementation this would serialize `WorldState` and user preferences
/// to a JSON file in the Application Support directory and read them back on launch.
///
/// TODO (Phase 5): Implement JSON-backed persistence using Codable.
/// TODO (Phase 5): Decide on storage location (Application Support vs UserDefaults).
/// TODO (Phase 5): Handle migration when the schema changes between versions.
public final class PersistenceStoreStub: PersistenceStoreProtocol {

    public init() {}

    /// Loads persisted data from disk.
    ///
    /// TODO: Read JSON from the Application Support directory and decode it.
    public func load() throws {
        // TODO: Decode persisted world state and preferences from disk.
    }

    /// Persists the current state to disk.
    ///
    /// TODO: Encode world state and preferences as JSON and write atomically to disk.
    public func save() throws {
        // TODO: Encode and write to the Application Support directory.
    }
}
