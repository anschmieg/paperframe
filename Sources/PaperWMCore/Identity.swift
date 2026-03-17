import Foundation

// MARK: - Window identity

/// Stable identifier for a managed window.
///
/// Derived from AX-level attributes in a future implementation.
/// The raw string should encode enough information to survive app restarts.
public struct ManagedWindowID: Hashable, Sendable, Codable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension ManagedWindowID: CustomStringConvertible {
    public var description: String { rawValue }
}

// MARK: - Display identity

/// Identifier for a physical display, matching Core Graphics' `CGDirectDisplayID`.
public struct DisplayID: Hashable, Sendable, Codable {
    public let rawValue: UInt32

    public init(_ rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

extension DisplayID: CustomStringConvertible {
    public var description: String { "Display(\(rawValue))" }
}

// MARK: - Paper workspace identity

/// Identifier for a paper workspace (a user-defined logical grouping of windows).
///
/// Paper workspaces are independent of native macOS Spaces.
public struct WorkspaceID: Hashable, Sendable, Codable {
    public let rawValue: UUID

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

extension WorkspaceID: CustomStringConvertible {
    public var description: String { rawValue.uuidString }
}
