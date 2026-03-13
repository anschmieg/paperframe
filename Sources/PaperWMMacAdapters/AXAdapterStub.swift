import Cocoa
import PaperWMCore

/// Stub for AX-backed window enumeration and attribute access.
///
/// In a real implementation this wraps `AXUIElementCreateApplication`,
/// `AXUIElementCopyAttributeValue`, `AXUIElementSetAttributeValue`,
/// and related Accessibility API calls.
///
/// TODO (Phase 2): Implement real window enumeration via AX.
/// TODO (Phase 3): Implement AX attribute writes with verification.
public final class AXAdapterStub {

    public init() {}

    // MARK: - Application elements

    /// Returns an AX application element for the given process, or nil if the
    /// app is not accessible or AX permission is not granted.
    ///
    /// TODO: Implement using `AXUIElementCreateApplication(pid)`.
    public func applicationElement(for pid: pid_t) -> AXUIElement? {
        // TODO: Real implementation:
        //   let element = AXUIElementCreateApplication(pid)
        //   // probe kAXWindowsAttribute to verify reachability
        //   return element
        return nil
    }

    // MARK: - Window enumeration

    /// Returns the AX window elements for a given application element.
    ///
    /// TODO: Implement using `AXUIElementCopyAttributeValue` with `kAXWindowsAttribute`.
    public func windowElements(for appElement: AXUIElement) -> [AXUIElement] {
        // TODO: Real implementation:
        //   var value: CFTypeRef?
        //   let err = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
        //   guard err == .success, let windows = value as? [AXUIElement] else { return [] }
        //   return windows
        return []
    }

    // MARK: - Attribute reads

    /// Reads the current frame of a window in screen coordinates.
    ///
    /// TODO: Implement reading kAXPositionAttribute and kAXSizeAttribute.
    public func frame(of windowElement: AXUIElement) -> CGRect? {
        // TODO: Read position via AXValueGetValue and size via AXValueGetValue
        return nil
    }

    /// Reads the window title.
    ///
    /// TODO: Implement reading kAXTitleAttribute.
    public func title(of windowElement: AXUIElement) -> String? {
        // TODO: AXUIElementCopyAttributeValue with kAXTitleAttribute
        return nil
    }

    // MARK: - Attribute writes

    /// Sets the position of a window.
    ///
    /// TODO: Implement using `AXUIElementSetAttributeValue` with `kAXPositionAttribute`.
    @discardableResult
    public func setPosition(_ position: CGPoint, of windowElement: AXUIElement) -> Bool {
        // TODO: AXUIElementSetAttributeValue with AXValue wrapping position
        return false
    }

    /// Sets the size of a window.
    ///
    /// TODO: Implement using `AXUIElementSetAttributeValue` with `kAXSizeAttribute`.
    @discardableResult
    public func setSize(_ size: CGSize, of windowElement: AXUIElement) -> Bool {
        // TODO: AXUIElementSetAttributeValue with AXValue wrapping size
        return false
    }

    // MARK: - Capability probing

    /// Probes a window element for the capabilities the window manager can use.
    ///
    /// TODO: Implement by reading kAXSubroleAttribute, kAXRoleAttribute,
    ///       and checking settable attributes via AXUIElementIsAttributeSettable.
    public func probeCapabilities(of windowElement: AXUIElement) -> WindowCapabilities {
        // TODO: Real implementation checks each relevant AX attribute for settability.
        return .none
    }

    // MARK: - Focus

    /// Raises and focuses a window.
    ///
    /// TODO: Implement using kAXRaiseAction and kAXFocusedAttribute.
    @discardableResult
    public func focus(windowElement: AXUIElement) -> Bool {
        // TODO: AXUIElementSetAttributeValue(element, kAXFocusedAttribute, kCFBooleanTrue)
        return false
    }
}
