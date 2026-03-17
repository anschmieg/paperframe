import Foundation
import PaperWMCore

/// JSON-backed implementation of `WorldStatePersistenceStoreProtocol`.
///
/// State is written atomically to a single JSON file inside the application's
/// Application Support directory.  This makes load/save safe against partial
/// writes and keeps the schema version-agnostic as long as only additive
/// changes are made to `PersistedWorldState`.
///
/// Failure policy:
/// - `load()` returns `nil` when the file does not exist yet.
/// - `load()` returns `nil` (and silently discards) when the file cannot be
///   decoded; this prevents a corrupt cache from crashing on startup.
/// - `save(_:)` throws on any encoding or write error so the caller can log or
///   recover appropriately.
public final class JSONWorldStatePersistenceStore: WorldStatePersistenceStoreProtocol {

    /// The URL at which the JSON snapshot is stored.
    public let fileURL: URL

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Creates a store that reads from and writes to `fileURL`.
    ///
    /// - Parameter fileURL: The file to use for persistence.  The parent
    ///   directory must already exist (or you may use
    ///   `JSONWorldStatePersistenceStore.defaultFileURL()` which creates it).
    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    // MARK: - WorldStatePersistenceStoreProtocol

    /// Loads the persisted snapshot from disk.
    ///
    /// Returns `nil` when the file does not exist or when the file content
    /// cannot be decoded (fail-safe for corrupt / incompatible data).
    public func load() -> PersistedWorldState? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(PersistedWorldState.self, from: data)
        } catch {
            // Corrupt or incompatible data: fail safe, treat as empty.
            return nil
        }
    }

    /// Persists `state` to disk as JSON, writing atomically.
    ///
    /// - Throws: `EncodingError` or any Foundation file I/O error on failure.
    public func save(_ state: PersistedWorldState) throws {
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Convenience factory

    /// Returns a `JSONWorldStatePersistenceStore` rooted in the standard
    /// Application Support directory for the running process.
    ///
    /// Creates the parent directory if it does not exist.
    ///
    /// - Parameter fileName: File name (default: `"world-state.json"`).
    /// - Returns: A store ready for use, or `nil` when the directory cannot be
    ///   determined.
    public static func applicationSupport(
        fileName: String = "world-state.json"
    ) -> JSONWorldStatePersistenceStore? {
        guard
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first
        else { return nil }

        let directory = appSupport.appendingPathComponent("PaperWM", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        return JSONWorldStatePersistenceStore(
            fileURL: directory.appendingPathComponent(fileName))
    }
}
