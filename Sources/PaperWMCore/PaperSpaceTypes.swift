import Foundation

// MARK: - Paper-space geometry

/// A point in paper space (an infinite 2-D canvas, not screen coordinates).
public struct PaperPoint: Hashable, Sendable, Codable {
    public var x: Double
    public var y: Double

    public init(x: Double = 0, y: Double = 0) {
        self.x = x
        self.y = y
    }

    public static let zero = PaperPoint()
}

/// A rectangle in paper space.
///
/// Paper-space coordinates are independent of screen resolution and display layout.
/// They represent user intent; the projection layer converts them to screen frames.
public struct PaperRect: Hashable, Sendable, Codable {
    public var origin: PaperPoint
    public var width: Double
    public var height: Double

    public var x: Double { origin.x }
    public var y: Double { origin.y }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.origin = PaperPoint(x: x, y: y)
        self.width = width
        self.height = height
    }

    public init(origin: PaperPoint, width: Double, height: Double) {
        self.origin = origin
        self.width = width
        self.height = height
    }

    public static let zero = PaperRect(x: 0, y: 0, width: 0, height: 0)
}

// MARK: - Window mode

/// The layout mode for a managed window in paper space.
public enum WindowMode: Sendable, Codable {
    /// Window participates in the tiled layout grid.
    case tiled
    /// Window floats above the tiled layer; paper coordinates are still tracked.
    case floating
    /// Window fills the display (paper coordinates suspended while fullscreen).
    case fullscreen
    /// Window is minimized to the Dock.
    case minimized
}

// MARK: - Paper window state

/// The paper-space metadata the window manager keeps for a single managed window.
///
/// This is user intent / organizational state, not a live snapshot.
public struct PaperWindowState: Sendable, Codable {
    public let windowID: ManagedWindowID
    /// Desired position and size in paper space.
    public var paperRect: PaperRect
    /// The paper workspace this window belongs to.
    public var workspaceID: WorkspaceID
    /// Current layout mode.
    public var mode: WindowMode

    public init(
        windowID: ManagedWindowID,
        paperRect: PaperRect = .zero,
        workspaceID: WorkspaceID = WorkspaceID(),
        mode: WindowMode = .tiled
    ) {
        self.windowID = windowID
        self.paperRect = paperRect
        self.workspaceID = workspaceID
        self.mode = mode
    }
}

// MARK: - Viewport state

/// Represents the current visible window onto the paper canvas for a specific display.
public struct ViewportState: Sendable, Codable {
    /// The display this viewport is anchored to.
    public let displayID: DisplayID
    /// The paper-space origin of the viewport (top-left visible corner).
    public var origin: PaperPoint
    /// Zoom scale (1.0 = 1:1 paper unit to display point).
    public var scale: Double

    public init(displayID: DisplayID, origin: PaperPoint = .zero, scale: Double = 1.0) {
        self.displayID = displayID
        self.origin = origin
        self.scale = scale
    }
}

// MARK: - Workspace state

/// A named paper workspace — a user-defined grouping of windows on a display.
public struct WorkspaceState: Sendable, Codable {
    public let workspaceID: WorkspaceID
    /// The display this workspace is associated with.
    public let displayID: DisplayID
    /// The current viewport for this workspace.
    public var viewport: ViewportState
    /// Ordered list of window IDs belonging to this workspace.
    public var windowIDs: [ManagedWindowID]

    public init(
        workspaceID: WorkspaceID = WorkspaceID(),
        displayID: DisplayID,
        viewport: ViewportState,
        windowIDs: [ManagedWindowID] = []
    ) {
        self.workspaceID = workspaceID
        self.displayID = displayID
        self.viewport = viewport
        self.windowIDs = windowIDs
    }
}
