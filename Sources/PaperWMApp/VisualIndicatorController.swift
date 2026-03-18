import AppKit
import PaperWMCore

/// Controls visual indicators for PaperWM:
/// - Workspace indicator in menu bar
/// - Action HUD (toast messages)
/// - Mini-map overlay
@MainActor
final class VisualIndicatorController {

    // MARK: - Components

    private let statusItem: NSStatusItem
    private var hudWindow: NSWindow?
    private var minimapWindow: NSWindow?

    private let worldState: WorldStateProtocol
    private let displayAdapter: any DisplayTopologyProviderProtocol

    // MARK: - Init

    init(statusItem: NSStatusItem, worldState: WorldStateProtocol, displayAdapter: any DisplayTopologyProviderProtocol) {
        self.statusItem = statusItem
        self.worldState = worldState
        self.displayAdapter = displayAdapter

        updateMenuBarIndicator()
    }

    // MARK: - Menu Bar Indicator

    /// Updates the menu bar to show current workspace info
    func updateMenuBarIndicator() {
        let topology = displayAdapter.currentTopology()
        guard let primaryDisplay = topology.displays.first else {
            statusItem.button?.title = "⬜"
            return
        }

        let workspaces = worldState.allWorkspaces(for: primaryDisplay.displayID)
        guard !workspaces.isEmpty else {
            statusItem.button?.title = "⬜"
            return
        }

        if let activeID = worldState.activeWorkspace(for: primaryDisplay.displayID) {
            let activeIndex = workspaces.firstIndex { $0.workspaceID == activeID.workspaceID } ?? 0
            let total = workspaces.count
            let index = activeIndex + 1

            // Try to get the workspace label
            let label = workspaces.first { $0.workspaceID == activeID.workspaceID }?.label

            if let label = label, !label.isEmpty {
                // Show custom label
                statusItem.button?.title = "⬜ \(label)"
            } else {
                // Show index
                statusItem.button?.title = "⬜ \(index)/\(total)"
            }
        } else {
            statusItem.button?.title = "⬜ \(workspaces.count)"
        }
    }

    // MARK: - Action HUD

    /// Shows a transient HUD message
    /// - Parameters:
    ///   - message: Primary message to show
    ///   - detail: Optional detail line
    ///   - duration: How long to show (default 1.5s)
    func showHUD(message: String, detail: String? = nil, duration: TimeInterval = 1.5) {
        // Remove existing HUD
        hudWindow?.close()
        hudWindow = nil

        // Create HUD window
        let hud = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: detail != nil ? 70 : 50),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        hud.level = .floating
        hud.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95)
        hud.isOpaque = false
        hud.hasShadow = true
        hud.collectionBehavior = [.canJoinAllSpaces, .stationary]

        // Position at bottom center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let hudFrame = hud.frame
            let x = screenFrame.midX - hudFrame.width / 2
            let y = screenFrame.minY + 50
            hud.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Create content view
        let content = NSView(frame: hud.contentView!.bounds)
        hud.contentView = content

        // Title label
        let titleLabel = NSTextField(labelWithString: message)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 10, y: detail != nil ? 35 : 15, width: 280, height: 20)
        content.addSubview(titleLabel)

        // Detail label
        if let detail = detail {
            let detailLabel = NSTextField(labelWithString: detail)
            detailLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
            detailLabel.textColor = NSColor.secondaryLabelColor
            detailLabel.alignment = .center
            detailLabel.frame = NSRect(x: 10, y: 10, width: 280, height: 16)
            content.addSubview(detailLabel)
        }

        // Add rounded corners
        hud.contentView?.wantsLayer = true
        hud.contentView?.layer?.cornerRadius = 10
        hud.contentView?.layer?.masksToBounds = true
        hud.contentView?.layer?.borderWidth = 1
        hud.contentView?.layer?.borderColor = NSColor.separatorColor.cgColor

        // Show and schedule hide
        hud.orderFront(nil)
        self.hudWindow = hud

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.hudWindow?.close()
            self?.hudWindow = nil
        }
    }

    // MARK: - Error/Warning HUD

    /// Shows a warning HUD (e.g., when window placement is resisted)
    func showWarning(message: String, detail: String? = nil) {
        // Remove existing HUD
        hudWindow?.close()
        hudWindow = nil

        // Create HUD window
        let hud = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: detail != nil ? 80 : 60),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        hud.level = .floating
        hud.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.95)
        hud.isOpaque = false
        hud.hasShadow = true

        // Position at bottom center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let hudFrame = hud.frame
            let x = screenFrame.midX - hudFrame.width / 2
            let y = screenFrame.minY + 50
            hud.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Create content
        let content = NSView(frame: hud.contentView!.bounds)
        hud.contentView = content

        // Warning icon
        let warningLabel = NSTextField(labelWithString: "⚠️")
        warningLabel.font = NSFont.systemFont(ofSize: 20)
        warningLabel.frame = NSRect(x: 15, y: 25, width: 30, height: 30)
        content.addSubview(warningLabel)

        // Title
        let titleLabel = NSTextField(labelWithString: message)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = NSColor.white
        titleLabel.frame = NSRect(x: 50, y: 40, width: 260, height: 20)
        content.addSubview(titleLabel)

        // Detail
        if let detail = detail {
            let detailLabel = NSTextField(labelWithString: detail)
            detailLabel.font = NSFont.systemFont(ofSize: 12)
            detailLabel.textColor = NSColor.white.withAlphaComponent(0.9)
            detailLabel.frame = NSRect(x: 50, y: 18, width: 260, height: 16)
            content.addSubview(detailLabel)
        }

        // Add rounded corners
        hud.contentView?.wantsLayer = true
        hud.contentView?.layer?.cornerRadius = 10

        // Show and schedule hide
        hud.orderFront(nil)
        self.hudWindow = hud

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.hudWindow?.close()
            self?.hudWindow = nil
        }
    }

    // MARK: - Mini-Map (Radar)

    func showMinimap() {
        // TODO: Implement full mini-map
        // For now, just show a placeholder
        showHUD(message: "Mini-Map", detail: "Coming soon")
    }

    func hideMinimap() {
        minimapWindow?.close()
        minimapWindow = nil
    }

    // MARK: - Workspace Switcher Overlay

    func showWorkspaceSwitcher() {
        // TODO: Implement workspace switcher overlay
        showHUD(message: "Workspace Switcher", detail: "Coming soon")
    }
}