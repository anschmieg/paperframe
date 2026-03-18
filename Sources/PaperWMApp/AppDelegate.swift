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

  // MARK: - Init

  override init() {
    // Initialize world state with JSON persistence for cross-launch state.
    // Falls back to in-memory only if persistence cannot be set up.
    if let store = JSONWorldStatePersistenceStore.applicationSupport() {
      self.worldState = WorldStateStub(persistenceStore: store)
    } else {
      self.worldState = WorldStateStub()
    }
    super.init()
  }

  // MARK: - Runtime services

  private let permissions = PermissionsService()
  private let displayAdapter = DisplayAdapter()
  private let diagnostics = DiagnosticsServiceStub()
  private let worldState: WorldStateStub
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
    worldState: worldState,
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
    checkPermissionsAndShowOnboarding()
    diagnostics.record(event: .displayTopologyChanged)

    // Perform the initial reconciliation pass.
    Task { [self] in
      _ = await coordinator.reconcile(reason: .startupInitialization)
    }

    // TODO: Start the observer/reconcile hub.
  }

  /// Checks permissions on launch and shows onboarding if Accessibility is not granted.
  ///
  /// This provides a better first-run experience by proactively informing users
  /// that Accessibility permission is required for window management.
  private func checkPermissionsAndShowOnboarding() {
    let state = permissions.currentState

    // Only show onboarding if Accessibility is not granted.
    guard !state.accessibilityAvailable else { return }

    let alert = NSAlert()
    alert.messageText = "Accessibility Permission Required"
    alert.informativeText = """
      PaperWM needs Accessibility permission to manage windows.

      Without this permission, the app runs in reduced mode and cannot:
      • Discover or enumerate windows
      • Move, resize, or focus windows
      • Perform automatic tiling

      Grant permission in System Settings to enable full functionality.
      """
    alert.addButton(withTitle: "Open System Settings")
    alert.addButton(withTitle: "Later")

    if alert.runModal() == .alertFirstButtonReturn {
      permissions.requestAccessibilityPermission()
    }
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

    // Workspace management submenu — grouped by display, populated lazily via NSMenuDelegate.
    let workspaceMenuItem = NSMenuItem(
      title: "Workspaces", action: nil, keyEquivalent: "")
    workspaceMenuItem.submenu = workspaceSubmenu
    workspaceSubmenu.delegate = self
    menu.addItem(workspaceMenuItem)

    // Current workspace actions with keyboard shortcuts (Milestone 18).
    menu.addItem(withTitle: "New Workspace…", action: #selector(newWorkspace(_:)), keyEquivalent: "n")
    menu.addItem(
      withTitle: "Rename Current Workspace…", action: #selector(renameCurrentWorkspace(_:)), keyEquivalent: "R")
    menu.addItem(
      withTitle: "Remove Current Workspace",
      action: #selector(removeCurrentWorkspace(_:)),
      keyEquivalent: "\u{08}")  // Backspace key
    menu.addItem(.separator())

    // Permissions / onboarding (Milestone 19: validation pass)
    menu.addItem(withTitle: "Check Permissions…", action: #selector(showPermissions(_:)), keyEquivalent: "")

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

  /// Shows permissions status and allows user to request Accessibility permission.
  /// Also performs initial onboarding check on first launch.
  @objc private func showPermissions(_ sender: Any?) {
    // Refresh permission state to get current status
    permissions.refresh()
    let state = permissions.currentState

    var msg = "Accessibility: \(state.accessibility == .granted ? "✓ Granted" : "✗ Not Granted")\n"
    msg += "Input Monitoring: \(state.inputMonitoring == .granted ? "✓ Granted" : "⚠ Not Required for Basic Features")\n\n"

    if state.isReducedMode {
      msg += "PaperWM is running in reduced mode because Accessibility permission is not granted.\n\n"
      msg += "Without Accessibility permission, PaperWM cannot manage windows. Please grant permission to enable full functionality.\n\n"
      msg += "Click 'Open System Settings' to grant permission, then restart PaperWM."
    } else {
      msg += "All required permissions are granted. PaperWM is fully functional."
    }

    let alert = NSAlert()
    alert.messageText = "PaperWM Permissions"

    if state.isReducedMode {
      alert.informativeText = msg
      alert.addButton(withTitle: "Open System Settings")
      alert.addButton(withTitle: "Cancel")

      if alert.runModal() == .alertFirstButtonReturn {
        // Open Accessibility settings in System Settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
          NSWorkspace.shared.open(url)
        }
      }
    } else {
      alert.informativeText = msg
      alert.addButton(withTitle: "OK")
      _ = alert.runModal()
    }
  }

  /// Routes a workspace switch command through `CommandRouter`.
  @objc private func switchWorkspaceAction(_ sender: NSMenuItem) {
    guard let payload = sender.representedObject as? WorkspaceSwitchPayload else { return }
    commandRouter.route(
      command: .switchWorkspace(displayID: payload.displayID, to: payload.workspaceID))
  }

  /// Presents a rename dialog for a specific workspace identified by the menu item's payload.
  ///
  /// Pre-fills the current workspace label and routes the result through `commandRouter`
  /// so the rename goes through the standard runtime path rather than mutating world
  /// state directly from the app layer.
  @objc private func renameWorkspaceFromMenu(_ sender: NSMenuItem) {
    guard let payload = sender.representedObject as? WorkspaceRenamePayload else { return }

    // Look up the current label at action time so the dialog reflects any recent changes.
    let currentLabel = findWorkspace(byID: payload.workspaceID)?.label

    let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
    textField.stringValue = currentLabel ?? ""
    textField.placeholderString = "Workspace name"

    let alert = NSAlert()
    alert.messageText = "Rename Workspace"
    alert.informativeText = "Enter a new name for this workspace."
    alert.accessoryView = textField
    alert.addButton(withTitle: "Rename")
    alert.addButton(withTitle: "Cancel")

    guard alert.runModal() == .alertFirstButtonReturn else { return }

    let trimmed = textField.stringValue.trimmingCharacters(in: .whitespaces)
    let newLabel: String? = trimmed.isEmpty ? nil : trimmed
    commandRouter.route(
      command: .renameWorkspace(workspaceID: payload.workspaceID, newLabel: newLabel))
  }

  /// Presents a confirmation dialog and removes a specific workspace identified by the
  /// menu item's payload.
  ///
  /// Re-checks the workspace count at action time to guard against the workspace having
  /// disappeared between menu construction and the user confirming the action.
  /// Routes removal through `commandRouter` so the app layer does not mutate world
  /// state directly.
  @objc private func removeWorkspaceFromMenu(_ sender: NSMenuItem) {
    guard let payload = sender.representedObject as? WorkspaceRemovePayload else { return }

    // Re-check at action time: workspace may have disappeared or count may have changed.
    let workspaces = worldState.allWorkspaces(for: payload.displayID)
    guard workspaces.contains(where: { $0.workspaceID == payload.workspaceID }) else {
      // Workspace disappeared between menu construction and action — safe no-op.
      return
    }

    if workspaces.count <= 1 {
      let alert = NSAlert()
      alert.messageText = "Cannot Remove Workspace"
      alert.informativeText = "The last remaining workspace on a display cannot be removed."
      alert.addButton(withTitle: "OK")
      _ = alert.runModal()
      return
    }

    let confirm = NSAlert()
    confirm.messageText = "Remove \"\(payload.displayLabel)\"?"
    confirm.informativeText = "This workspace will be removed. This action cannot be undone."
    confirm.addButton(withTitle: "Remove")
    confirm.addButton(withTitle: "Cancel")
    guard confirm.runModal() == .alertFirstButtonReturn else { return }

    commandRouter.route(command: .removeWorkspace(workspaceID: payload.workspaceID))
  }

  /// Presents a label-prompt dialog and creates a new workspace on a specific display
  /// identified by the menu item's payload.
  ///
  /// Routes creation through `commandRouter` so the app layer does not mutate world
  /// state directly.
  @objc private func newWorkspaceOnDisplay(_ sender: NSMenuItem) {
    guard let payload = sender.representedObject as? DisplayCreatePayload else { return }

    let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
    textField.placeholderString = "Workspace name (optional)"

    let alert = NSAlert()
    alert.messageText = "New Workspace"
    alert.informativeText = "Enter an optional name for the new workspace."
    alert.accessoryView = textField
    alert.addButton(withTitle: "Create")
    alert.addButton(withTitle: "Cancel")

    guard alert.runModal() == .alertFirstButtonReturn else { return }

    let trimmed = textField.stringValue.trimmingCharacters(in: .whitespaces)
    let label: String? = trimmed.isEmpty ? nil : trimmed
    commandRouter.route(command: .createWorkspace(displayID: payload.displayID, label: label))
  }

  // MARK: - Keyboard shortcut actions (Milestone 18)

  /// Creates a new workspace on the main display via keyboard shortcut.
  ///
  /// Targets the main display (first display in topology) for workspace creation.
  /// Reuses the same dialog flow as the per-display menu action.
  @objc private func newWorkspace(_ sender: NSMenuItem) {
    let topology = displayAdapter.currentTopology()
    guard let mainDisplay = topology.displays.first else {
      // No displays available — cannot create workspace.
      return
    }

    let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
    textField.placeholderString = "Workspace name (optional)"

    let alert = NSAlert()
    alert.messageText = "New Workspace"
    alert.informativeText = "Enter an optional name for the new workspace."
    alert.accessoryView = textField
    alert.addButton(withTitle: "Create")
    alert.addButton(withTitle: "Cancel")

    guard alert.runModal() == .alertFirstButtonReturn else { return }

    let trimmed = textField.stringValue.trimmingCharacters(in: .whitespaces)
    let label: String? = trimmed.isEmpty ? nil : trimmed
    commandRouter.route(command: .createWorkspace(displayID: mainDisplay.displayID, label: label))
  }

  /// Renames the current (active) workspace via keyboard shortcut.
  ///
  /// Targets the active workspace on the main display. Reuses the same dialog flow
  /// as the per-workspace menu action.
  @objc private func renameCurrentWorkspace(_ sender: NSMenuItem) {
    let topology = displayAdapter.currentTopology()
    guard let mainDisplay = topology.displays.first else {
      // No displays available — cannot rename.
      return
    }

    guard let current = worldState.activeWorkspace(for: mainDisplay.displayID) else {
      // No active workspace — show informative alert.
      let alert = NSAlert()
      alert.messageText = "No Active Workspace"
      alert.informativeText = "There is no active workspace to rename."
      alert.addButton(withTitle: "OK")
      _ = alert.runModal()
      return
    }

    // Look up the current label at action time so the dialog reflects any recent changes.
    let currentLabel = findWorkspace(byID: current.workspaceID)?.label

    let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
    textField.stringValue = currentLabel ?? ""
    textField.placeholderString = "Workspace name"

    let alert = NSAlert()
    alert.messageText = "Rename Current Workspace"
    alert.informativeText = "Enter a new name for the current workspace."
    alert.accessoryView = textField
    alert.addButton(withTitle: "Rename")
    alert.addButton(withTitle: "Cancel")

    guard alert.runModal() == .alertFirstButtonReturn else { return }

    let trimmed = textField.stringValue.trimmingCharacters(in: .whitespaces)
    let newLabel: String? = trimmed.isEmpty ? nil : trimmed
    commandRouter.route(
      command: .renameWorkspace(workspaceID: current.workspaceID, newLabel: newLabel))
  }

  /// Removes the current (active) workspace via keyboard shortcut.
  ///
  /// Targets the active workspace on the main display. Reuses the same confirmation flow
  /// as the per-workspace menu action.
  @objc private func removeCurrentWorkspace(_ sender: NSMenuItem) {
    let topology = displayAdapter.currentTopology()
    guard let mainDisplay = topology.displays.first else {
      // No displays available — cannot remove.
      return
    }

    guard let current = worldState.activeWorkspace(for: mainDisplay.displayID) else {
      // No active workspace — show informative alert.
      let alert = NSAlert()
      alert.messageText = "No Active Workspace"
      alert.informativeText = "There is no active workspace to remove."
      alert.addButton(withTitle: "OK")
      _ = alert.runModal()
      return
    }

    // Re-check at action time: workspace may have disappeared or count may have changed.
    let workspaces = worldState.allWorkspaces(for: mainDisplay.displayID)
    guard workspaces.contains(where: { $0.workspaceID == current.workspaceID }) else {
      // Workspace disappeared between menu construction and action — safe no-op.
      return
    }

    if workspaces.count <= 1 {
      let alert = NSAlert()
      alert.messageText = "Cannot Remove Workspace"
      alert.informativeText = "The last remaining workspace on a display cannot be removed."
      alert.addButton(withTitle: "OK")
      _ = alert.runModal()
      return
    }

    let currentLabel = findWorkspace(byID: current.workspaceID)?.label ?? "this workspace"
    let confirm = NSAlert()
    confirm.messageText = "Remove \"\(currentLabel)\"?"
    confirm.informativeText = "This workspace will be removed. This action cannot be undone."
    confirm.addButton(withTitle: "Remove")
    confirm.addButton(withTitle: "Cancel")
    guard confirm.runModal() == .alertFirstButtonReturn else { return }

    commandRouter.route(command: .removeWorkspace(workspaceID: current.workspaceID))
  }

  // MARK: - Private helpers

  /// Returns the workspace state for the given workspace ID by searching across all
  /// displays in the current topology.  Returns `nil` if the workspace is not found.
  private func findWorkspace(byID workspaceID: WorkspaceID) -> WorkspaceState? {
    let topology = displayAdapter.currentTopology()
    for display in topology.displays {
      if let ws = worldState.allWorkspaces(for: display.displayID)
        .first(where: { $0.workspaceID == workspaceID })
      {
        return ws
      }
    }
    return nil
  }
}

// MARK: - Menu payload types

/// Carries the display and workspace identifiers for a workspace switch menu item.
private final class WorkspaceSwitchPayload: NSObject {
  let displayID: DisplayID
  let workspaceID: WorkspaceID

  init(displayID: DisplayID, workspaceID: WorkspaceID) {
    self.displayID = displayID
    self.workspaceID = workspaceID
  }
}

/// Carries the workspace identifier for a rename menu item.
private final class WorkspaceRenamePayload: NSObject {
  let workspaceID: WorkspaceID

  init(workspaceID: WorkspaceID) {
    self.workspaceID = workspaceID
  }
}

/// Carries the workspace identifier and display context for a remove menu item.
///
/// `displayID` is used to re-check the workspace count at action time.
/// `displayLabel` is the pre-computed human-readable label shown in the confirmation dialog.
private final class WorkspaceRemovePayload: NSObject {
  let workspaceID: WorkspaceID
  let displayID: DisplayID
  let displayLabel: String

  init(workspaceID: WorkspaceID, displayID: DisplayID, displayLabel: String) {
    self.workspaceID = workspaceID
    self.displayID = displayID
    self.displayLabel = displayLabel
  }
}

/// Carries the display identifier for a per-display workspace creation menu item.
private final class DisplayCreatePayload: NSObject {
  let displayID: DisplayID

  init(displayID: DisplayID) {
    self.displayID = displayID
  }
}

// MARK: - NSMenuDelegate (workspace submenu)

extension AppDelegate: NSMenuDelegate {
  /// Rebuilds the workspace submenu before it is displayed.
  ///
  /// Queries the current display topology and world state so that the menu always
  /// reflects live workspace configuration, including any persisted/restored state.
  ///
  /// Menu structure per display:
  /// - Display header (multi-display only)
  /// - Per workspace: label item with submenu containing Switch / Rename… / Remove…
  /// - New Workspace… (scoped to this display)
  /// - Separator (between displays, multi-display only)
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

    for (displayIndex, display) in displays.enumerated() {
      if multiDisplay {
        let header = NSMenuItem(
          title: "Display \(display.displayID.rawValue)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
      }

      let workspaces = worldState.allWorkspaces(for: display.displayID)
        .sorted { $0.workspaceID.rawValue.uuidString < $1.workspaceID.rawValue.uuidString }
      let activeID = worldState.activeWorkspace(for: display.displayID)?.workspaceID
      let indent = multiDisplay ? "  " : ""

      if workspaces.isEmpty {
        let none = NSMenuItem(
          title: "\(indent)No workspaces", action: nil, keyEquivalent: "")
        none.isEnabled = false
        menu.addItem(none)
      } else {
        for (index, ws) in workspaces.enumerated() {
          let label = workspaceMenuLabel(for: ws, index: index)
          let wsItem = NSMenuItem(title: "\(indent)\(label)", action: nil, keyEquivalent: "")
          wsItem.state = ws.workspaceID == activeID ? .on : .off

          // Per-workspace action submenu.
          let sub = buildWorkspaceActionSubmenu(
            for: ws,
            displayID: display.displayID,
            displayLabel: label)
          wsItem.submenu = sub

          menu.addItem(wsItem)
        }
      }

      // Per-display workspace creation action.
      let newItem = NSMenuItem(
        title: "\(indent)New Workspace…",
        action: #selector(newWorkspaceOnDisplay(_:)),
        keyEquivalent: "")
      newItem.target = self
      newItem.representedObject = DisplayCreatePayload(displayID: display.displayID)
      menu.addItem(newItem)

      if multiDisplay && displayIndex < displays.count - 1 {
        menu.addItem(.separator())
      }
    }
  }

  /// Builds the per-workspace action submenu containing Switch, Rename…, and Remove….
  private func buildWorkspaceActionSubmenu(
    for workspace: WorkspaceState,
    displayID: DisplayID,
    displayLabel: String
  ) -> NSMenu {
    let sub = NSMenu()

    let switchItem = NSMenuItem(
      title: "Switch",
      action: #selector(switchWorkspaceAction(_:)),
      keyEquivalent: "")
    switchItem.target = self
    switchItem.representedObject = WorkspaceSwitchPayload(
      displayID: displayID, workspaceID: workspace.workspaceID)
    sub.addItem(switchItem)

    let renameItem = NSMenuItem(
      title: "Rename…",
      action: #selector(renameWorkspaceFromMenu(_:)),
      keyEquivalent: "")
    renameItem.target = self
    renameItem.representedObject = WorkspaceRenamePayload(workspaceID: workspace.workspaceID)
    sub.addItem(renameItem)

    let removeItem = NSMenuItem(
      title: "Remove…",
      action: #selector(removeWorkspaceFromMenu(_:)),
      keyEquivalent: "")
    removeItem.target = self
    removeItem.representedObject = WorkspaceRemovePayload(
      workspaceID: workspace.workspaceID,
      displayID: displayID,
      displayLabel: displayLabel)
    sub.addItem(removeItem)

    return sub
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
