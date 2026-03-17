import Foundation
import PaperWMCore

// MARK: - Active workspace entry

/// A single display→workspace binding used in the persisted payload.
///
/// Encodes `[DisplayID: WorkspaceID]` as an array of flat entries so that the
/// outer struct can use synthesised `Codable` without a custom dictionary
/// encoder (JSON requires String keys, but `DisplayID` is a `UInt32` wrapper).
public struct ActiveWorkspaceEntry: Codable, Sendable {
    public let displayID: DisplayID
    public let workspaceID: WorkspaceID

    public init(displayID: DisplayID, workspaceID: WorkspaceID) {
        self.displayID = displayID
        self.workspaceID = workspaceID
    }
}

// MARK: - Persisted world state

/// A complete, serialisable snapshot of world state.
///
/// Captures:
/// - All registered workspaces (with their viewport state and window lists)
/// - The active workspace ID per display
/// - Paper-space metadata for every managed window
///
/// The snapshot is intentionally flat and append-only: new optional fields may
/// be added without breaking existing stored data.
public struct PersistedWorldState: Codable, Sendable {
    /// All registered workspaces.
    public var workspaces: [WorkspaceState]

    /// The active workspace for each display, encoded as an array of entries
    /// instead of a dictionary so that synthesised Codable works with non-String
    /// dictionary keys.
    public var activeWorkspaces: [ActiveWorkspaceEntry]

    /// Paper-space metadata for each managed window.
    public var paperWindowStates: [PaperWindowState]

    public init(
        workspaces: [WorkspaceState] = [],
        activeWorkspaces: [ActiveWorkspaceEntry] = [],
        paperWindowStates: [PaperWindowState] = []
    ) {
        self.workspaces = workspaces
        self.activeWorkspaces = activeWorkspaces
        self.paperWindowStates = paperWindowStates
    }

    /// Convenience empty state; equivalent to `init()`.
    public static let empty = PersistedWorldState()
}
