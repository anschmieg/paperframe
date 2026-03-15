import Cocoa
import PaperWMCore

/// Production implementation of AX-backed window enumeration and attribute access.
///
/// Wraps `AXUIElementCreateApplication`, `AXUIElementCopyAttributeValue`,
/// `AXUIElementSetAttributeValue`, and related Accessibility API calls.
///
/// All methods gracefully degrade when Accessibility permission is not granted
/// or when AX operations fail.
public final class AXAdapter {

    public init() {}

    // MARK: - Application elements

    /// Returns an AX application element for the given process, or nil if the
    /// app is not accessible or AX permission is not granted.
    public func applicationElement(for pid: pid_t) -> AXUIElement? {
        let element = AXUIElementCreateApplication(pid)
        // Verify the element is reachable by attempting to read an attribute
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value)
        // If we can't read windows, the app may not be accessible
        // Still return the element - let callers decide what to do
        if err == .success || err == .attributeUnsupported {
            return element
        }
        return nil
    }

    // MARK: - Window enumeration

    /// Returns the AX window elements for a given application element.
    public func windowElements(for appElement: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
        guard err == .success, let windows = value as? [AXUIElement] else {
            return []
        }
        return windows
    }

    // MARK: - Attribute reads

    /// Reads the current frame of a window in screen coordinates.
    public func frame(of windowElement: AXUIElement) -> CGRect? {
        guard let position = position(of: windowElement),
              let size = size(of: windowElement) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    /// Reads the window title.
    public func title(of windowElement: AXUIElement) -> String? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &value)
        guard err == .success, let title = value as? String else {
            return nil
        }
        return title
    }

    /// Reads whether the window is minimized.
    public func isMinimized(of windowElement: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(windowElement, kAXMinimizedAttribute as CFString, &value)
        guard err == .success, let minimized = value as? Bool else {
            return nil
        }
        return minimized
    }

    /// Reads whether the window is focused.
    public func isFocused(of windowElement: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(windowElement, kAXFocusedAttribute as CFString, &value)
        guard err == .success, let focused = value as? Bool else {
            return nil
        }
        return focused
    }

    /// Reads the window's role (e.g., "AXWindow", "AXSheet", etc.)
    public func role(of windowElement: AXUIElement) -> String? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(windowElement, kAXRoleAttribute as CFString, &value)
        guard err == .success, let role = value as? String else {
            return nil
        }
        return role
    }

    /// Reads the window's subrole (e.g., "AXStandardWindow", "AXDialog", etc.)
    public func subrole(of windowElement: AXUIElement) -> String? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(windowElement, kAXSubroleAttribute as CFString, &value)
        guard err == .success, let subrole = value as? String else {
            return nil
        }
        return subrole
    }

    // MARK: - Attribute writes

    /// Sets the position of a window.
    @discardableResult
    public func setPosition(_ position: CGPoint, of windowElement: AXUIElement) -> Bool {
        var point = position
        guard let axValue = AXValueCreate(.cgPoint, &point) else {
            return false
        }
        let err = AXUIElementSetAttributeValue(windowElement, kAXPositionAttribute as CFString, axValue)
        return err == .success
    }

    /// Sets the size of a window.
    @discardableResult
    public func setSize(_ size: CGSize, of windowElement: AXUIElement) -> Bool {
        var size = size
        guard let axValue = AXValueCreate(.cgSize, &size) else {
            return false
        }
        let err = AXUIElementSetAttributeValue(windowElement, kAXSizeAttribute as CFString, axValue)
        return err == .success
    }

    // MARK: - Capability probing

    /// Probes a window element for the capabilities the window manager can use.
    public func probeCapabilities(of windowElement: AXUIElement) -> WindowCapabilities {
        var caps = WindowCapabilities()

        // Check if position is settable
        var settable: DarwinBoolean = false
        if AXUIElementIsAttributeSettable(windowElement, kAXPositionAttribute as CFString, &settable) == .success {
            caps.canMove = settable.boolValue
        }

        // Check if size is settable
        settable = false
        if AXUIElementIsAttributeSettable(windowElement, kAXSizeAttribute as CFString, &settable) == .success {
            caps.canResize = settable.boolValue
        }

        // Check if minimized is settable
        settable = false
        if AXUIElementIsAttributeSettable(windowElement, kAXMinimizedAttribute as CFString, &settable) == .success {
            caps.canMinimize = settable.boolValue
        }

        // Check if focused is settable (for focus capability)
        settable = false
        if AXUIElementIsAttributeSettable(windowElement, kAXFocusedAttribute as CFString, &settable) == .success {
            caps.canFocus = settable.boolValue
        }

        // For close, we check if the close action is available
        var actions: CFArray?
        if AXUIElementCopyActionNames(windowElement, &actions) == .success,
           let actionNames = actions as? [String] {
            caps.canClose = actionNames.contains(kAXPressAction as String)
        }

        return caps
    }

    // MARK: - Focus

    /// Raises and focuses a window.
    @discardableResult
    public func focus(windowElement: AXUIElement) -> Bool {
        // First try to raise the window
        let raiseErr = AXUIElementPerformAction(windowElement, kAXRaiseAction as CFString)
        if raiseErr != .success {
            return false
        }

        // Then set it as focused
        let focusErr = AXUIElementSetAttributeValue(
            windowElement,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        )
        return focusErr == .success
    }

    // MARK: - Private helpers

    private func position(of windowElement: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(windowElement, kAXPositionAttribute as CFString, &value)
        guard err == .success, let axValue = value else {
            return nil
        }
        var point = CGPoint.zero
        if AXValueGetValue(axValue as! AXValue, .cgPoint, &point) {
            return point
        }
        return nil
    }

    private func size(of windowElement: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(windowElement, kAXSizeAttribute as CFString, &value)
        guard err == .success, let axValue = value else {
            return nil
        }
        var size = CGSize.zero
        if AXValueGetValue(axValue as! AXValue, .cgSize, &size) {
            return size
        }
        return nil
    }
}
