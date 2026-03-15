import Cocoa
import PaperWMCore

/// Production implementation of `WindowInventoryServiceProtocol`.
///
/// Discovers candidate windows via Accessibility APIs, probes their capabilities,
/// and maintains a snapshot of the current window state.
///
/// This service gracefully degrades when Accessibility permission is not granted,
/// returning an empty snapshot array.
public final class WindowInventoryService: WindowInventoryServiceProtocol {

    /// The most recent window snapshots.
    public private(set) var snapshots: [ManagedWindowSnapshot] = []

    private let permissionsService: any PermissionsServiceProtocol
    private let axAdapter: AXAdapter
    private let displayAdapter: DisplayAdapter

    /// Creates a new inventory service.
    /// - Parameter permissionsService: The permissions service to check for Accessibility access.
    /// - Parameter axAdapter: The AX adapter for window enumeration (defaults to new instance).
    /// - Parameter displayAdapter: The display adapter for display topology (defaults to new instance).
    public init(
        permissionsService: any PermissionsServiceProtocol,
        axAdapter: AXAdapter = AXAdapter(),
        displayAdapter: DisplayAdapter = DisplayAdapter()
    ) {
        self.permissionsService = permissionsService
        self.axAdapter = axAdapter
        self.displayAdapter = displayAdapter
    }

    /// Performs a full refresh of the window inventory from the AX layer.
    ///
    /// If Accessibility permission is not granted, this method clears the snapshots
    /// and returns immediately.
    public func refreshSnapshot() async {
        // Check permissions first
        guard permissionsService.accessibilityGranted else {
            snapshots = []
            return
        }

        // Get current display topology for display ID mapping
        let topology = displayAdapter.currentTopology()

        // Enumerate all running applications
        let runningApps = NSWorkspace.shared.runningApplications

        var newSnapshots: [ManagedWindowSnapshot] = []

        for app in runningApps {
            // Skip apps that don't have a UI or are hidden/background
            guard app.activationPolicy == .regular else {
                continue
            }

            guard let appElement = axAdapter.applicationElement(for: app.processIdentifier) else {
                continue
            }

            let windowElements = axAdapter.windowElements(for: appElement)

            for windowElement in windowElements {
                guard let snapshot = buildSnapshot(
                    windowElement: windowElement,
                    app: app,
                    topology: topology
                ) else {
                    continue
                }

                newSnapshots.append(snapshot)
            }
        }

        snapshots = newSnapshots
    }

    // MARK: - Private helpers

    private func buildSnapshot(
        windowElement: AXUIElement,
        app: NSRunningApplication,
        topology: DisplayTopology
    ) -> ManagedWindowSnapshot? {
        // Get window attributes
        let frame = axAdapter.frame(of: windowElement) ?? .zero
        let title = axAdapter.title(of: windowElement) ?? ""
        let isMinimized = axAdapter.isMinimized(of: windowElement) ?? false
        let isFocused = axAdapter.isFocused(of: windowElement) ?? false
        let role = axAdapter.role(of: windowElement)
        let subrole = axAdapter.subrole(of: windowElement)

        // Determine eligibility based on role/subrole
        let eligibility = determineEligibility(role: role, subrole: subrole)

        // Skip ineligible windows
        guard case .eligible = eligibility else {
            return nil
        }

        // Probe capabilities
        let capabilities = axAdapter.probeCapabilities(of: windowElement)

        // Determine display ID based on window frame
        let displayID = determineDisplayID(for: frame, in: topology)

        // Build stable window ID
        // Format: "{bundleID}:{pid}:{windowIndex}" - this is stable within a session
        // but not across app restarts (which is acceptable for v1)
        let windowID = ManagedWindowID("\(app.bundleIdentifier ?? "unknown"):\(app.processIdentifier):\(title)")

        let appDescriptor = AppDescriptor(
            bundleID: app.bundleIdentifier ?? "",
            displayName: app.localizedName ?? "",
            pid: app.processIdentifier
        )

        return ManagedWindowSnapshot(
            windowID: windowID,
            app: appDescriptor,
            frameOnDisplay: frame,
            displayID: displayID,
            capabilities: capabilities,
            eligibility: eligibility,
            isMinimized: isMinimized,
            isFocused: isFocused
        )
    }

    private func determineEligibility(role: String?, subrole: String?) -> WindowEligibility {
        // Must have a standard window role
        guard role == kAXWindowRole else {
            return .ineligible(reason: "Non-window role: \(role ?? "nil")")
        }

        // Filter out non-standard window types
        if let subrole = subrole {
            switch subrole {
            case kAXStandardWindowSubrole:
                // Standard document/app window - eligible
                return .eligible
            case kAXDialogSubrole:
                // Dialogs and sheets - ineligible for management
                return .ineligible(reason: "Dialog/Sheet window")
            case kAXFloatingWindowSubrole:
                // Floating panels - ineligible
                return .ineligible(reason: "Floating window")
            case kAXSystemDialogSubrole, kAXSystemFloatingWindowSubrole:
                // System windows - ineligible
                return .ineligible(reason: "System window")
            default:
                // Unknown subrole - be conservative and allow it
                return .eligible
            }
        }

        // No subrole - allow it (may be a standard window)
        return .eligible
    }

    private func determineDisplayID(for frame: CGRect, in topology: DisplayTopology) -> DisplayID {
        // Find the display that contains the window's center point
        let center = CGPoint(x: frame.midX, y: frame.midY)

        for display in topology.displays {
            if display.frame.contains(center) {
                return display.displayID
            }
        }

        // Fallback to primary display if no match
        return topology.displays.first { $0.isPrimary }?.displayID
            ?? topology.displays.first?.displayID
            ?? DisplayID(0)
    }
}
