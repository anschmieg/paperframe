import AppKit
import PaperWMCore

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
