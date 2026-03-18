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

    /// Shows the mini-map overlay showing all workspaces and current viewport
    func showMinimap() {
        // Close existing if any
        minimapWindow?.close()

        // Get topology and world state
        let topology = displayAdapter.currentTopology()
        guard let primaryDisplay = topology.displays.first else { return }

        let workspaces = worldState.allWorkspaces(for: primaryDisplay.displayID)
        guard !workspaces.isEmpty else { return }

        // Calculate window size based on workspace count
        let cols = min(workspaces.count, 4)
        let rows = (workspaces.count + cols - 1) / cols
        let cellWidth: CGFloat = 100
        let cellHeight: CGFloat = 70
        let padding: CGFloat = 10
        let headerHeight: CGFloat = 40

        let windowWidth = CGFloat(cols) * (cellWidth + padding) + padding
        let windowHeight = CGFloat(rows) * (cellHeight + padding) + padding + headerHeight + 40

        // Create window
        let minimap = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless, .titled],
            backing: .buffered,
            defer: false
        )
        minimap.level = .floating
        minimap.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95)
        minimap.isOpaque = false
        minimap.title = "Workspace Overview"
        minimap.titlebarAppearsTransparent = true

        // Center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - windowWidth / 2
            let y = screenFrame.midY - windowHeight / 2 + 50
            minimap.setFrameOrigin(NSPoint(x: x, y: y))
        }

        let content = NSView(frame: minimap.contentView!.bounds)
        content.wantsLayer = true
        content.layer?.cornerRadius = 12
        content.layer?.masksToBounds = true
        content.layer?.borderWidth = 1
        content.layer?.borderColor = NSColor.separatorColor.cgColor
        minimap.contentView = content

        // Title label
        let titleLabel = NSTextField(labelWithString: "PaperWM Workspaces")
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.frame = NSRect(x: padding, y: windowHeight - 30, width: windowWidth - padding * 2, height: 20)
        content.addSubview(titleLabel)

        // Current workspace info
        let activeWorkspace = worldState.activeWorkspace(for: primaryDisplay.displayID)
        let activeIndex = workspaces.firstIndex { $0.workspaceID == activeWorkspace?.workspaceID } ?? 0
        let infoText = "Current: \(workspaces[activeIndex].label ?? "Workspace \(activeIndex + 1)") (\(activeIndex + 1)/\(workspaces.count))"
        let infoLabel = NSTextField(labelWithString: infoText)
        infoLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        infoLabel.textColor = NSColor.secondaryLabelColor
        infoLabel.frame = NSRect(x: padding, y: windowHeight - 48, width: windowWidth - padding * 2, height: 16)
        content.addSubview(infoLabel)

        // Draw workspace cells
        for (index, workspace) in workspaces.enumerated() {
            let col = index % cols
            let row = index / cols
            let cellX = padding + CGFloat(col) * (cellWidth + padding)
            let cellY = padding + CGFloat(rows - 1 - row) * (cellHeight + padding)

            let isActive = workspace.workspaceID == activeWorkspace?.workspaceID
            drawWorkspaceCell(
                in: content,
                workspace: workspace,
                index: index,
                frame: NSRect(x: cellX, y: cellY, width: cellWidth, height: cellHeight),
                isActive: isActive
            )
        }

        // Add instruction label
        // Keyboard shortcut hints
        let shortcuts = [
            "⌃⌥←/→ Switch",
            "⌃⌥1-9 Go to",
            "⌃⌥M Map",
            "⌃⌥N New",
            "⌃⌥R Rename"
        ]
        let hintText = shortcuts.joined(separator: "  |  ")
        let instructionLabel = NSTextField(labelWithString: hintText)
        instructionLabel.font = NSFont.systemFont(ofSize: 9)
        instructionLabel.textColor = NSColor.tertiaryLabelColor
        instructionLabel.alignment = .center
        instructionLabel.frame = NSRect(x: padding, y: 8, width: windowWidth - padding * 2, height: 24)
        instructionLabel.maximumNumberOfLines = 2
        content.addSubview(instructionLabel)

        minimap.orderFront(nil)
        self.minimapWindow = minimap
    }

    private func drawWorkspaceCell(
        in parent: NSView,
        workspace: WorkspaceState,
        index: Int,
        frame: NSRect,
        isActive: Bool
    ) {
        let cellView = NSView(frame: frame)
        cellView.wantsLayer = true
        cellView.layer?.cornerRadius = 6
        cellView.layer?.borderWidth = isActive ? 2 : 1
        cellView.layer?.borderColor = isActive
            ? NSColor.controlAccentColor.cgColor
            : NSColor.separatorColor.cgColor
        cellView.layer?.backgroundColor = isActive
            ? NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
            : NSColor.controlBackgroundColor.cgColor
        parent.addSubview(cellView)

        // Workspace number
        let numberLabel = NSTextField(labelWithString: "\(index + 1)")
        numberLabel.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        numberLabel.textColor = isActive ? NSColor.controlAccentColor : NSColor.secondaryLabelColor
        numberLabel.frame = NSRect(x: 8, y: frame.height - 28, width: 30, height: 24)
        cellView.addSubview(numberLabel)

        // Workspace name (label or default)
        let name = workspace.label ?? "Workspace \(index + 1)"
        let nameLabel = NSTextField(labelWithString: name)
        nameLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        nameLabel.textColor = NSColor.labelColor
        nameLabel.frame = NSRect(x: 8, y: frame.height - 44, width: frame.width - 16, height: 14)
        nameLabel.lineBreakMode = .byTruncatingTail
        cellView.addSubview(nameLabel)

        // Viewport indicator (simplified - just shows it's active or not)
        if isActive {
            let indicator = NSTextField(labelWithString: "●")
            indicator.font = NSFont.systemFont(ofSize: 10)
            indicator.textColor = NSColor.controlAccentColor
            indicator.frame = NSRect(x: frame.width - 20, y: frame.height - 20, width: 12, height: 12)
            cellView.addSubview(indicator)
        }
    }

    func hideMinimap() {
        minimapWindow?.close()
        minimapWindow = nil
    }

    // MARK: - Workspace Switcher Overlay

    func showWorkspaceSwitcher() {
        // Remove existing
        minimapWindow?.close()

        let topology = displayAdapter.currentTopology()
        guard let primaryDisplay = topology.displays.first else { return }
        let workspaces = worldState.allWorkspaces(for: primaryDisplay.displayID)
        guard !workspaces.isEmpty else { return }

        let activeID = worldState.activeWorkspace(for: primaryDisplay.displayID)

        // Calculate size
        let cols = min(workspaces.count, 5)
        let rows = (workspaces.count + cols - 1) / cols
        let cellWidth: CGFloat = 80
        let cellHeight: CGFloat = 60
        let padding: CGFloat = 8
        let headerHeight: CGFloat = 40

        let windowWidth = CGFloat(cols) * (cellWidth + padding) + padding * 2
        let windowHeight = CGFloat(rows) * (cellHeight + padding) + padding + headerHeight + 30

        let switcher = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless, .titled],
            backing: .buffered,
            defer: false
        )
        switcher.level = .floating
        switcher.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.98)
        switcher.isOpaque = false
        switcher.title = "Switch Workspace"
        switcher.titlebarAppearsTransparent = true

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - windowWidth / 2
            let y = screenFrame.midY - windowHeight / 2
            switcher.setFrameOrigin(NSPoint(x: x, y: y))
        }

        let content = NSView(frame: switcher.contentView!.bounds)
        content.wantsLayer = true
        content.layer?.cornerRadius = 12
        content.layer?.masksToBounds = true
        content.layer?.borderWidth = 1
        content.layer?.borderColor = NSColor.separatorColor.cgColor

        // Title
        let titleLabel = NSTextField(labelWithString: "Switch Workspace")
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.frame = NSRect(x: padding, y: windowHeight - 28, width: windowWidth - padding * 2, height: 20)
        content.addSubview(titleLabel)

        // Draw cells
        for (index, workspace) in workspaces.enumerated() {
            let col = index % cols
            let row = index / cols
            let cellX = padding + CGFloat(col) * (cellWidth + padding)
            let cellY = padding + CGFloat(rows - 1 - row) * (cellHeight + padding)

            let isActive = workspace.workspaceID == activeID?.workspaceID

            let cellView = NSView(frame: NSRect(x: cellX, y: cellY, width: cellWidth, height: cellHeight))
            cellView.wantsLayer = true
            cellView.layer?.cornerRadius = 6
            cellView.layer?.borderWidth = isActive ? 2 : 1
            cellView.layer?.borderColor = isActive ? NSColor.controlAccentColor.cgColor : NSColor.separatorColor.cgColor
            cellView.layer?.backgroundColor = isActive ? NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor : NSColor.controlBackgroundColor.cgColor
            content.addSubview(cellView)

            // Number
            let numLabel = NSTextField(labelWithString: "\(index + 1)")
            numLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
            numLabel.textColor = isActive ? NSColor.controlAccentColor : NSColor.secondaryLabelColor
            numLabel.alignment = .center
            numLabel.frame = NSRect(x: 0, y: cellHeight - 25, width: cellWidth, height: 22)
            cellView.addSubview(numLabel)

            // Name
            let name = workspace.label ?? "Workspace \(index + 1)"
            let nameLabel = NSTextField(labelWithString: name)
            nameLabel.font = NSFont.systemFont(ofSize: 10)
            nameLabel.textColor = NSColor.labelColor
            nameLabel.alignment = .center
            nameLabel.frame = NSRect(x: 4, y: 8, width: cellWidth - 8, height: 14)
            nameLabel.lineBreakMode = .byTruncatingTail
            cellView.addSubview(nameLabel)
        }

        // Hints
        let hintText = "⌃⌥1-9 or Click to switch  |  Esc to close"
        let hintLabel = NSTextField(labelWithString: hintText)
        hintLabel.font = NSFont.systemFont(ofSize: 9)
        hintLabel.textColor = NSColor.tertiaryLabelColor
        hintLabel.alignment = .center
        hintLabel.frame = NSRect(x: padding, y: 8, width: windowWidth - padding * 2, height: 12)
        content.addSubview(hintLabel)

        switcher.contentView = content
        switcher.orderFront(nil)
        self.minimapWindow = switcher
    }
}