import AppKit
import PaperWMCore
import PaperWMRuntime

/// Application delegate for the PaperWM menu-bar app.
///
/// This is a minimal Phase 1 shell. It sets up the status bar item and
/// wires together the core runtime stubs.
///
/// TODO (Phase 1): Add a Settings window and Onboarding / Permissions flow.
/// TODO (Phase 1): Add a Diagnostics inspector panel.
/// TODO (Phase 4): Start `ObserverAndReconcileHubProtocol` after permissions confirmed.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Runtime services (stubs)

    private let permissions = PermissionsServiceStub()
    private let diagnostics = DiagnosticsServiceStub()
    private let inventory   = WindowInventoryServiceStub()
    private let worldState  = WorldStateStub()
    private let planner     = ProjectionPlannerStub()
    private let engine      = PlacementTransactionEngineStub()

    // MARK: - UI

    private var statusItem: NSStatusItem?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        diagnostics.record(event: .displayTopologyChanged)

        // TODO: Check permissions and show onboarding if needed.
        // TODO: Start the observer/reconcile hub.
        // TODO: Perform initial inventory refresh.
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
        // TODO: Add layout commands (move, resize, cycle, etc.)
        menu.addItem(withTitle: "Diagnostics…", action: #selector(showDiagnostics), keyEquivalent: "d")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit PaperWM", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem?.menu = menu
    }

    // MARK: - Actions

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
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
}
