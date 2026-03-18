import AppKit
import Carbon.HIToolbox
import PaperWMCore
import PaperWMRuntime
import PaperWMCore
import PaperWMRuntime

/// Handles global keyboard shortcuts for PaperWM
/// Uses Ctrl+Option as the modifier to avoid conflicts with native macOS
@MainActor
final class KeyboardShortcutHandler {

    // MARK: - Properties

    private var globalMonitor: Any?
    private var localMonitor: Any?

    private let worldState: WorldStateProtocol
    private let displayAdapter: any DisplayTopologyProviderProtocol
    private let commandRouter: CommandRouter
    private let visualController: VisualIndicatorController

    // Modifier flags
    private let requiredModifiers: NSEvent.ModifierFlags = [.control, .option]

    // MARK: - Init

    init(
        worldState: WorldStateProtocol,
        displayAdapter: any DisplayTopologyProviderProtocol,
        commandRouter: CommandRouter,
        visualController: VisualIndicatorController
    ) {
        self.worldState = worldState
        self.displayAdapter = displayAdapter
        self.commandRouter = commandRouter
        self.visualController = visualController
    }

    // MARK: - Start/Stop

    func start() {
        // Monitor global key events (when app is not focused)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleKeyEvent(event)
            }
        }

        // Monitor local key events (when app is focused)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let handled = self?.handleKeyEvent(event) ?? false
            return handled ? nil : event
        }
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    // MARK: - Event Handling

    /// Returns true if the event was handled
    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Check for Ctrl+Option modifier
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.contains(.control) && modifiers.contains(.option) else {
            return false
        }

        // Check for no other modifiers (except shift for some combos)
        let extraModifiers = modifiers.subtracting(requiredModifiers).subtracting(.shift)
        guard extraModifiers.isEmpty else { return false }

        let keyCode = event.keyCode
        let hasShift = modifiers.contains(.shift)

        // Handle the key
        switch keyCode {
        case 123: // Left arrow
            if hasShift {
                moveWindowToWorkspace(direction: .left)
            } else {
                switchWorkspace(direction: .left)
            }
            return true

        case 124: // Right arrow
            if hasShift {
                moveWindowToWorkspace(direction: .right)
            } else {
                switchWorkspace(direction: .right)
            }
            return true

        case 125: // Down arrow
            if hasShift {
                moveWindowToWorkspace(direction: .down)
            } else {
                switchWorkspace(direction: .down)
            }
            return true

        case 126: // Up arrow
            if hasShift {
                moveWindowToWorkspace(direction: .up)
            } else {
                switchWorkspace(direction: .up)
            }
            return true

        case 18: // 1
            if hasShift { return false }
            switchToWorkspace(index: 0)
            return true

        case 19: // 2
            if hasShift { return false }
            switchToWorkspace(index: 1)
            return true

        case 20: // 3
            if hasShift { return false }
            switchToWorkspace(index: 2)
            return true

        case 21: // 4
            if hasShift { return false }
            switchToWorkspace(index: 3)
            return true

        case 23: // 5
            if hasShift { return false }
            switchToWorkspace(index: 4)
            return true

        case 22: // 6
            if hasShift { return false }
            switchToWorkspace(index: 5)
            return true

        case 26: // 7
            if hasShift { return false }
            switchToWorkspace(index: 6)
            return true

        case 28: // 8
            if hasShift { return false }
            switchToWorkspace(index: 7)
            return true

        case 25: // 9
            if hasShift { return false }
            switchToWorkspace(index: 8)
            return true

        case 29: // 0
            if hasShift { return false }
            switchToWorkspace(index: 9)
            return true

        case 46: // M
            if hasShift { return false }
            visualController.showMinimap()
            return true

        case 44: // /
            if hasShift { return false }
            visualController.showWorkspaceSwitcher()
            return true

        case 53: // Escape
            if hasShift { return false }
            visualController.hideMinimap()
            return true

        default:
            return false
        }
    }

    // MARK: - Actions

    private func switchWorkspace(direction: Direction) {
        let topology = displayAdapter.currentTopology()
        guard let display = topology.displays.first else { return }

        let workspaces = worldState.allWorkspaces(for: display.displayID)
        guard let current = worldState.activeWorkspace(for: display.displayID) else { return }

        let currentIndex = workspaces.firstIndex { $0.workspaceID == current.workspaceID } ?? 0
        let targetIndex: Int

        switch direction {
        case .left:
            targetIndex = currentIndex - 1
        case .right:
            targetIndex = currentIndex + 1
        case .up:
            // For single display, up/down wraps or does nothing
            // For multi-display, up would go to display above
            return
        case .down:
            return
        }

        guard targetIndex >= 0 && targetIndex < workspaces.count else { return }

        let target = workspaces[targetIndex]
        commandRouter.route(command: .switchWorkspace(displayID: display.displayID, to: target.workspaceID))
        visualController.updateMenuBarIndicator()
        let label = target.label ?? "Workspace \(targetIndex + 1)"
        visualController.showHUD(message: "Switched to \(label)")
    }

    private func switchToWorkspace(index: Int) {
        let topology = displayAdapter.currentTopology()
        guard let display = topology.displays.first else { return }

        let workspaces = worldState.allWorkspaces(for: display.displayID)
        guard index < workspaces.count else { return }

        let target = workspaces[index]
        commandRouter.route(command: .switchWorkspace(displayID: display.displayID, to: target.workspaceID))
        visualController.updateMenuBarIndicator()
        let label = target.label ?? "Workspace \(index + 1)"
        visualController.showHUD(message: "Switched to \(label)")
    }

    private func moveWindowToWorkspace(direction: Direction) {
        // Get the focused window
        guard let focusedWindowID = worldState.focusedWindowID else {
            visualController.showHUD(message: "No window selected", detail: "Click a window first")
            return
        }

        // Map local Direction to PaperWMCore.Direction
        let coreDirection: PaperWMCore.Direction
        switch direction {
        case .left: coreDirection = .left
        case .right: coreDirection = .right
        case .up: coreDirection = .up
        case .down: coreDirection = .down
        }

        // Route the move window command
        commandRouter.route(command: .moveWindow(focusedWindowID, direction: coreDirection))

        // Show feedback
        visualController.showHUD(message: "Window moved", detail: directionText(for: direction))
    }

    private func directionText(for direction: Direction) -> String {
        switch direction {
        case .left: return "to previous workspace"
        case .right: return "to next workspace"
        case .up: return "to workspace above"
        case .down: return "to workspace below"
        }
    }

    // MARK: - Types

    enum Direction {
        case left, right, up, down
    }
}