import AppKit
import PaperWMCore
import PaperWMMacAdapters
import PaperWMRuntime

/// Application delegate for the PaperWM menu-bar app.
///
/// This is the production composition point. It wires together the real macOS adapters
/// with the runtime reconciliation pipeline and exposes trigger paths for reconciliation.
///
/// Real adapters used:
/// - `PermissionsService` — probes live Accessibility and Input Monitoring state.
/// - `DisplayAdapter` — reads `NSScreen` for the current display topology.
/// - `WindowInventoryService` — enumerates live windows via the AX layer.
/// - `AXWindowMutator` — applies placement intents to live windows.
///
/// Stub dependencies (acceptable until the corresponding subsystems are implemented):
/// - `DiagnosticsServiceStub` — in-memory event and failure ring buffer.
/// - `WorldStateStub` — in-memory paper-space metadata store.
///
/// TODO (Phase 1): Add a Settings window and Onboarding / Permissions flow.
/// TODO (Phase 1): Add a Diagnostics inspector panel.
/// TODO (Phase 4): Start `ObserverAndReconcileHubProtocol` after permissions confirmed.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

  // MARK: - Runtime services

  private let permissions = PermissionsService()
  private let displayAdapter = DisplayAdapter()
  private let diagnostics = DiagnosticsServiceStub()
  private let worldState = WorldStateStub()
  private let planner = TilingProjectionPlanner()

  // MARK: - Runtime pipeline (lazy to allow ordered initialization)

  private lazy var inventory: WindowInventoryService = WindowInventoryService(
    permissionsService: permissions
  )
  private lazy var mutator: AXWindowMutator = AXWindowMutator()
  private lazy var engine: PlacementTransactionEngine = PlacementTransactionEngine(
    permissionsService: permissions,
    inventoryService: inventory,
    mutator: mutator
  )
  private lazy var coordinator: ReconciliationCoordinator = ReconciliationCoordinator(
    inventoryService: inventory,
    topologyProvider: displayAdapter,
    planner: planner,
    engine: engine,
    worldState: worldState,
    diagnostics: diagnostics
  )
  private lazy var workspaceSwitchCoordinator = WorkspaceSwitchCoordinator(
    worldState: worldState,
    reconciliationCoordinator: coordinator
  )
  private lazy var commandRouter = CommandRouter(
    workspaceSwitchCoordinator: workspaceSwitchCoordinator,
    reconciliationCoordinator: coordinator
  )

  // MARK: - UI

  private var statusItem: NSStatusItem?
  /// Submenu populated dynamically with one item per registered workspace.
  private let workspaceSubmenu = NSMenu()

  // MARK: - NSApplicationDelegate

  func applicationDidFinishLaunching(_ notification: Notification) {
    setupStatusItem()
    diagnostics.record(event: .displayTopologyChanged)

    // Perform the initial reconciliation pass.
    Task { [self] in
      _ = await coordinator.reconcile(reason: .startupInitialization)
    }

    // TODO: Check permissions and show onboarding if needed.
    // TODO: Start the observer/reconcile hub.
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // Keep the app alive even when all windows are closed (menu-bar app pattern).
    return false
  }

  // MARK: - Status bar

  private func setupStatusItem() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem?.button?.title = "⬜ PaperWM"
    statusItem?.button?.toolTip = "PaperWM window manager"

    let menu = NSMenu()
    menu.addItem(withTitle: "About PaperWM", action: #selector(showAbout), keyEquivalent: "")
    menu.addItem(.separator())
    menu.addItem(withTitle: "Refresh", action: #selector(refresh), keyEquivalent: "r")

    // Workspace switching submenu — populated lazily via NSMenuDelegate.
    let workspaceMenuItem = NSMenuItem(
      title: "Switch Workspace", action: nil, keyEquivalent: "")
    workspaceMenuItem.submenu = workspaceSubmenu
    workspaceSubmenu.delegate = self
    menu.addItem(workspaceMenuItem)

    // TODO: Add layout commands (move, resize, cycle, etc.)
    menu.addItem(withTitle: "Diagnostics…", action: #selector(showDiagnostics), keyEquivalent: "d")
    menu.addItem(.separator())
    menu.addItem(
      withTitle: "Quit PaperWM", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

    statusItem?.menu = menu
  }

  // MARK: - Actions

  @objc private func showAbout() {
    NSApp.orderFrontStandardAboutPanel(nil)
  }

  /// Triggers a manual reconciliation pass. Safe to call at any time; produces
  /// no placement work until the planner is implemented in Phase 4.
  @objc private func refresh() {
    Task { [self] in
      _ = await coordinator.reconcile(reason: .manualRefresh)
    }
  }

  @objc private func showDiagnostics() {
    // TODO: Open the diagnostics inspector panel.
    let report = diagnostics.currentReport(
      permissionsState: permissions.currentState,
      managedWindowCount: inventory.snapshots.count
    )
    let msg = """
      Accessibility: \(report.accessibilityGranted ? "✓" : "✗")
      Input Monitoring: \(report.inputMonitoringGranted ? "✓" : "✗")
      Managed windows: \(report.managedWindowCount)
      Recent events: \(report.recentEvents.count)
      Reduced mode: \(report.permissionsState.isReducedMode ? "yes" : "no")
      """
    let alert = NSAlert()
    alert.messageText = "PaperWM Diagnostics"
    alert.informativeText = msg
    alert.addButton(withTitle: "OK")
    _ = alert.runModal()
  }

  /// Routes a workspace switch command through `CommandRouter`.
  @objc private func switchWorkspaceAction(_ sender: NSMenuItem) {
    guard let payload = sender.representedObject as? WorkspaceSwitchPayload else { return }
    commandRouter.route(
      command: .switchWorkspace(displayID: payload.displayID, to: payload.workspaceID))
  }
}

// MARK: - WorkspaceSwitchPayload

/// Carries the display and workspace identifiers for a workspace switch menu item.
private final class WorkspaceSwitchPayload: NSObject {
  let displayID: DisplayID
  let workspaceID: WorkspaceID

  init(displayID: DisplayID, workspaceID: WorkspaceID) {
    self.displayID = displayID
    self.workspaceID = workspaceID
  }
}

// MARK: - NSMenuDelegate (workspace submenu)

extension AppDelegate: NSMenuDelegate {
  /// Rebuilds the workspace submenu before it is displayed.
  ///
  /// Queries the current display topology and world state so that the menu always
  /// reflects live workspace configuration, including any persisted/restored state.
  func menuNeedsUpdate(_ menu: NSMenu) {
    guard menu === workspaceSubmenu else { return }
    menu.removeAllItems()

    let topology = displayAdapter.currentTopology()
    let displays = topology.displays.sorted { $0.displayID.rawValue < $1.displayID.rawValue }
    let multiDisplay = displays.count > 1

    guard !displays.isEmpty else {
      let empty = NSMenuItem(title: "No displays detected", action: nil, keyEquivalent: "")
      empty.isEnabled = false
      menu.addItem(empty)
      return
    }

    for display in displays {
      let workspaces = worldState.allWorkspaces(for: display.displayID)
        .sorted { $0.workspaceID.rawValue.uuidString < $1.workspaceID.rawValue.uuidString }

      if multiDisplay {
        let header = NSMenuItem(
          title: "Display \(display.displayID.rawValue)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
      }

      if workspaces.isEmpty {
        let none = NSMenuItem(
          title: multiDisplay ? "  No workspaces" : "No workspaces",
          action: nil, keyEquivalent: "")
        none.isEnabled = false
        menu.addItem(none)
      } else {
        let activeID = worldState.activeWorkspace(for: display.displayID)?.workspaceID
        for (index, ws) in workspaces.enumerated() {
          let indent = multiDisplay ? "  " : ""
          let displayLabel = workspaceMenuLabel(for: ws, index: index)
          let item = NSMenuItem(
            title: "\(indent)\(displayLabel)",
            action: #selector(switchWorkspaceAction(_:)),
            keyEquivalent: "")
          item.target = self
          item.state = ws.workspaceID == activeID ? .on : .off
          item.representedObject = WorkspaceSwitchPayload(
            displayID: display.displayID, workspaceID: ws.workspaceID)
          menu.addItem(item)
        }
      }

      if multiDisplay {
        menu.addItem(.separator())
      }
    }
  }

  /// Returns the display label for a workspace menu item.
  ///
  /// Uses the workspace's explicit label when it is non-nil and non-blank.
  /// Falls back to "Workspace N" (1-based) using the sorted position in the menu.
  private func workspaceMenuLabel(for workspace: WorkspaceState, index: Int) -> String {
    if let label = workspace.label, !label.trimmingCharacters(in: .whitespaces).isEmpty {
      return label
    }
    return "Workspace \(index + 1)"
  }
}
