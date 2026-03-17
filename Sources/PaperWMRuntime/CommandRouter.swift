import Foundation
import PaperWMCore

/// Routes semantic commands from the UI and global hotkeys into the runtime.
///
/// This is the central dispatch point for user-initiated `WMCommand`s.  Each
/// command is matched to the appropriate runtime coordinator and executed
/// asynchronously on the main actor.
///
/// Currently handled commands:
/// - `.switchWorkspace(displayID:to:)` → `WorkspaceSwitchCoordinator`
/// - `.refreshInventory`               → `ReconciliationTriggering` (`.manualRefresh`)
///
/// All other commands are no-ops with TODO placeholders until the corresponding
/// coordinators are implemented.
@MainActor
public final class CommandRouter: CommandRouterProtocol {

    private let workspaceSwitchCoordinator: WorkspaceSwitchCoordinator
    private let reconciliationCoordinator: any ReconciliationTriggering

    public init(
        workspaceSwitchCoordinator: WorkspaceSwitchCoordinator,
        reconciliationCoordinator: any ReconciliationTriggering
    ) {
        self.workspaceSwitchCoordinator = workspaceSwitchCoordinator
        self.reconciliationCoordinator = reconciliationCoordinator
    }

    // MARK: - CommandRouterProtocol

    /// Routes `command` to the appropriate runtime coordinator.
    ///
    /// Returns immediately; the coordinator work is dispatched asynchronously on
    /// the main actor.  Use `handle(command:)` directly from async contexts (e.g.
    /// tests) when you need to await completion.
    public func route(command: WMCommand) {
        Task { [self] in
            await handle(command: command)
        }
    }

    // MARK: - Internal

    /// Dispatches `command` to the appropriate coordinator and awaits completion.
    ///
    /// This is the async entry point used by tests and by the fire-and-forget
    /// `route(command:)` implementation above.
    func handle(command: WMCommand) async {
        switch command {
        case .switchWorkspace(let displayID, let workspaceID):
            await workspaceSwitchCoordinator.switchWorkspace(to: workspaceID, for: displayID)

        case .refreshInventory:
            await reconciliationCoordinator.reconcile(reason: .manualRefresh)

        case .focusWindow, .moveWindow, .resizeWindow, .minimizeWindow,
            .unminimizeWindow, .cycleWindows, .toggleFullscreen:
            // TODO: Route to the appropriate coordinator when implemented.
            break
        }
    }
}
