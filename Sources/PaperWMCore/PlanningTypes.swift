import Foundation

// MARK: - Display topology

/// A snapshot of a single physical display's geometry.
public struct DisplaySnapshot: Sendable {
    public let displayID: DisplayID
    /// The display's full frame in global screen coordinates.
    public let frame: CGRect
    /// The display's usable frame, excluding the Dock and menu bar.
    ///
    /// `nil` when the usable area cannot be determined. Callers should
    /// fall back to `frame` when this is absent.
    public let visibleFrame: CGRect?
    /// Retina scale factor (1.0 for non-Retina, 2.0 for @2x, etc.).
    public let scaleFactor: Double
    /// Whether this is the primary (main) display at snapshot time.
    ///
    /// Maps to `NSScreen.main`. `false` when the primary display cannot
    /// be determined or when this snapshot was constructed synthetically.
    public let isPrimary: Bool

    public init(
        displayID: DisplayID,
        frame: CGRect,
        visibleFrame: CGRect? = nil,
        scaleFactor: Double,
        isPrimary: Bool = false
    ) {
        self.displayID = displayID
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.scaleFactor = scaleFactor
        self.isPrimary = isPrimary
    }
}

/// All active displays observed at a point in time.
public struct DisplayTopology: Sendable {
    public let displays: [DisplaySnapshot]

    public init(displays: [DisplaySnapshot] = []) {
        self.displays = displays
    }

    public static let empty = DisplayTopology()

    /// Returns the snapshot for a specific display, if present.
    public func snapshot(for id: DisplayID) -> DisplaySnapshot? {
        displays.first { $0.displayID == id }
    }
}

// MARK: - Placement intents

/// The desired placement of a single window onto a screen.
///
/// Produced by `ProjectionPlanner`, consumed by `PlacementTransactionEngine`.
public struct PlacementIntent: Sendable {
    public let windowID: ManagedWindowID
    /// Target frame in global screen coordinates.
    public let targetFrame: CGRect
    public let targetDisplayID: DisplayID

    public init(windowID: ManagedWindowID, targetFrame: CGRect, targetDisplayID: DisplayID) {
        self.windowID = windowID
        self.targetFrame = targetFrame
        self.targetDisplayID = targetDisplayID
    }
}

/// A full set of placement intents computed for a single planning cycle.
public struct PlacementPlan: Sendable {
    public let intents: [PlacementIntent]

    public init(intents: [PlacementIntent] = []) {
        self.intents = intents
    }

    public static let empty = PlacementPlan()
}

// MARK: - Placement results

/// The outcome of executing a single placement intent.
public enum PlacementResult: Sendable {
    case success
    case resistedByApp(windowID: ManagedWindowID)
    case capabilityMissing(windowID: ManagedWindowID, capability: String)
    case failed(windowID: ManagedWindowID, reason: String)
}

/// A summary report produced after executing a `PlacementPlan`.
public struct PlacementExecutionReport: Sendable {
    public let results: [PlacementResult]
    public let appliedIntents: [PlacementIntent]
    public let failedIntents: [PlacementIntent]

    public init(
        results: [PlacementResult] = [],
        appliedIntents: [PlacementIntent] = [],
        failedIntents: [PlacementIntent] = []
    ) {
        self.results = results
        self.appliedIntents = appliedIntents
        self.failedIntents = failedIntents
    }
}

// MARK: - Visibility policy

/// How the window manager should treat a window relative to the active viewport.
public enum VisibilityPolicy: Sendable {
    /// Project windows that overlap the active viewport onto the display.
    case projectInViewport
    /// Do not move or hide this window; leave it wherever macOS placed it.
    case leaveUntouched
    /// Minimize the window when it moves off-viewport (opt-in).
    case minimizeOnExit
}

// MARK: - Events and commands

/// Semantic events emitted by the adapter layer into the domain runtime.
public enum WMEvent: Sendable {
    case windowAppeared(ManagedWindowID)
    case windowDisappeared(ManagedWindowID)
    case windowMoved(ManagedWindowID)
    case windowResized(ManagedWindowID)
    case windowFocused(ManagedWindowID)
    case windowMinimized(ManagedWindowID)
    case windowUnminimized(ManagedWindowID)
    case appLaunched(AppDescriptor)
    case appTerminated(AppDescriptor)
    case displayTopologyChanged
    case activeSpaceChanged
}

/// The reason a reconciliation pass was triggered.
public enum ReconcileReason: Sendable {
    case event(WMEvent)
    case userCommand(WMCommand)
    case startupInitialization
    case displayTopologyChanged
    case activeSpaceChanged
    case manualRefresh
}

/// Semantic commands initiated by the user or the UI layer.
public enum WMCommand: Sendable {
    case focusWindow(ManagedWindowID)
    case moveWindow(ManagedWindowID, direction: Direction)
    case resizeWindow(ManagedWindowID, to: PaperRect)
    case minimizeWindow(ManagedWindowID)
    case unminimizeWindow(ManagedWindowID)
    case cycleWindows(direction: Direction)
    case toggleFullscreen(ManagedWindowID)
    case refreshInventory
}

/// Cardinal direction used in movement and focus commands.
public enum Direction: Sendable {
    case left, right, up, down
}
