import Foundation
import PaperWMCore

/// Stub implementation of `PermissionsServiceProtocol`.
///
/// In a real implementation this wraps `AXIsProcessTrustedWithOptions` and
/// `IOHIDCheckAccess` / `CGRequestPostEventAccess`.
///
/// TODO (Phase 1): Implement real Accessibility trust check via AXIsProcessTrustedWithOptions.
/// TODO (Phase 1): Implement real Input Monitoring check.
public final class PermissionsServiceStub: PermissionsServiceProtocol {

    /// Hard-coded to false; real implementation reads from the system.
    public var accessibilityGranted: Bool { false }

    /// Hard-coded to false; real implementation reads from the system.
    public var inputMonitoringGranted: Bool { false }

    public init() {}

    /// TODO: Call AXIsProcessTrustedWithOptions(_:) with a prompt option to trigger the system dialog.
    public func requestAccessibilityPermission() {
        // TODO: AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true] as CFDictionary)
    }

    /// TODO: Trigger the Input Monitoring system prompt via the appropriate API.
    public func requestInputMonitoringPermission() {
        // TODO: CGRequestPostEventAccess() or IOHIDRequestAccess(kIOHIDRequestTypePostEvent)
    }
}
