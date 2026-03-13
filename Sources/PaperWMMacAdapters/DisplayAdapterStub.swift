import AppKit
import PaperWMCore

/// Stub for building `DisplayTopology` snapshots from the live NSScreen list.
///
/// In a real implementation this also registers for
/// `NSApplication.didChangeScreenParametersNotification` to detect display changes.
///
/// TODO (Phase 1): Wire up `NSApplication.didChangeScreenParametersNotification`.
/// TODO (Phase 1): Map `CGDirectDisplayID` from `NSScreen` to `DisplayID`.
public final class DisplayAdapterStub {

    public init() {}

    // MARK: - Topology snapshot

    /// Builds a `DisplayTopology` from the currently connected screens.
    ///
    /// TODO: Use `NSScreen.screens` and extract `CGDirectDisplayID` via
    ///       `screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]`.
    public func currentTopology() -> DisplayTopology {
        // TODO: Real implementation:
        //   let snapshots = NSScreen.screens.compactMap { screen -> DisplaySnapshot? in
        //       guard let number = screen.deviceDescription[
        //           NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        //       else { return nil }
        //       let id = DisplayID(number.uint32Value)
        //       return DisplaySnapshot(
        //           displayID: id,
        //           frame: screen.frame,
        //           scaleFactor: screen.backingScaleFactor
        //       )
        //   }
        //   return DisplayTopology(displays: snapshots)
        return .empty
    }
}

/// Stub for observing `NSWorkspace` events (active Space, app launch/quit).
///
/// TODO (Phase 4): Implement AX observer registration per running app.
/// TODO (Phase 4): Subscribe to NSWorkspace notifications for app lifecycle events.
public final class WorkspaceAdapterStub {

    public init() {}

    // MARK: - Active app

    /// Returns the descriptor for the currently frontmost application.
    ///
    /// TODO: Use `NSWorkspace.shared.frontmostApplication`.
    public func frontmostApp() -> AppDescriptor? {
        // TODO: NSWorkspace.shared.frontmostApplication
        return nil
    }

    // MARK: - Running apps

    /// Returns descriptors for all currently running GUI applications.
    ///
    /// TODO: Use `NSWorkspace.shared.runningApplications`.
    public func runningApps() -> [AppDescriptor] {
        // TODO: NSWorkspace.shared.runningApplications.map { ... }
        return []
    }
}
