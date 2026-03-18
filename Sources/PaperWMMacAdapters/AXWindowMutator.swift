import Cocoa
import PaperWMCore

/// Production implementation of `WindowMutatorProtocol`.
///
/// Resolves the live AX window element for a snapshot and applies the
/// placement intent using `AXUIElementSetAttributeValue`.
///
/// Resolution strategy: match the AX window element whose current frame
/// equals `snapshot.frameOnDisplay`. This is the most reliable per-window
/// discriminator available without a persistent AX window token.
///
/// TODO: Consider title-based fallback when two windows of the same app share
///       an identical frame (rare, but theoretically possible).
public final class AXWindowMutator: WindowMutatorProtocol {

    private let axAdapter: AXAdapter

    public init(axAdapter: AXAdapter = AXAdapter()) {
        self.axAdapter = axAdapter
    }

    // MARK: - WindowMutatorProtocol

    public func applyPlacement(
        intent: PlacementIntent,
        snapshot: ManagedWindowSnapshot
    ) -> PlacementResult {
        let windowID = intent.windowID

        // Reject ineligible windows before touching any AX state.
        switch snapshot.eligibility {
        case .eligible:
            break
        case .ineligible(let reason):
            return .capabilityMissing(windowID: windowID, capability: reason)
        case .unknown:
            return .failed(windowID: windowID, reason: "Window eligibility unknown")
        }

        // Require at least one mutatable capability.
        let caps = snapshot.capabilities
        guard caps.canMove || caps.canResize else {
            return .capabilityMissing(windowID: windowID, capability: "canMove or canResize")
        }

        // Resolve the live AX element using the snapshot's application PID.
        guard let element = resolveAXElement(for: snapshot) else {
            return .failed(windowID: windowID, reason: "AX element could not be resolved")
        }

        let target = intent.targetFrame

        // Write position before size (macOS AX convention: position first).
        var positionVerified = true
        if caps.canMove {
            guard axAdapter.setPosition(target.origin, of: element) else {
                return .resistedByApp(windowID: windowID)
            }
            // Verify the position was actually applied.
            positionVerified = axAdapter.verifyPosition(target.origin, of: element)
        }

        // Write size.
        var sizeVerified = true
        if caps.canResize {
            guard axAdapter.setSize(target.size, of: element) else {
                return .resistedByApp(windowID: windowID)
            }
            // Verify the size was actually applied.
            sizeVerified = axAdapter.verifySize(target.size, of: element)
        }

        // Check if both position and size were verified successfully.
        // Only require verification for the capabilities we attempted to change.
        let positionRequired = caps.canMove
        let sizeRequired = caps.canResize

        if (positionRequired && !positionVerified) || (sizeRequired && !sizeVerified) {
            return .resistedByApp(windowID: windowID)
        }

        return .success
    }

    // MARK: - Private

    /// Finds the AX window element whose current on-screen frame equals `snapshot.frameOnDisplay`.
    ///
    /// Returns `nil` when no element matches or when more than one element matches
    /// the same frame (ambiguous match). Ambiguous matches are treated as failures
    /// to avoid mutating the wrong window.
    private func resolveAXElement(for snapshot: ManagedWindowSnapshot) -> AXUIElement? {
        guard let appElement = axAdapter.applicationElement(for: snapshot.app.pid) else {
            return nil
        }
        let windows = axAdapter.windowElements(for: appElement)
        let matching = windows.filter { element in
            guard let frame = axAdapter.frame(of: element) else { return false }
            return frame == snapshot.frameOnDisplay
        }
        // Require exactly one match to avoid silently targeting the wrong window.
        guard matching.count == 1 else {
            return nil
        }
        return matching.first
    }
}
