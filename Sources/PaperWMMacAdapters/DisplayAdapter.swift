import AppKit
import PaperWMCore

/// Maps live `NSScreen` data into `DisplayTopology` snapshots.
///
/// Uses only public AppKit APIs to enumerate connected displays and extract
/// their geometry. Screen device-description parsing is conservative: screens
/// whose `CGDirectDisplayID` cannot be resolved are silently skipped and do
/// not appear in the returned topology.
///
/// `NSScreen` APIs must be called on the main thread. Callers are responsible
/// for dispatch to the main thread when invoking `currentTopology()` from a
/// background context.
///
/// TODO (Phase 3): Register for `NSApplication.didChangeScreenParametersNotification`
///   and drive a topology-refresh event into the reconcile hub when displays change.
public final class DisplayAdapter: DisplayTopologyProviderProtocol {

    public init() {}

    // MARK: - Topology snapshot

    /// Returns a `DisplayTopology` built from the currently connected screens.
    ///
    /// Reads `NSScreen.screens` synchronously on the calling thread, which must
    /// be the main thread per AppKit's threading contract.
    ///
    /// Each screen is mapped to a `DisplaySnapshot` using its `CGDirectDisplayID`
    /// from `NSDeviceDescriptionKey("NSScreenNumber")`. Screens that do not expose
    /// this key (unexpected in practice) are skipped conservatively.
    ///
    /// - Returns: A `DisplayTopology` containing one snapshot per mappable screen.
    ///   Returns `.empty` only if no screens could be mapped (e.g. in a headless CI
    ///   environment where `NSScreen.screens` is empty).
    public func currentTopology() -> DisplayTopology {
        let screens = NSScreen.screens
        let mainScreen = NSScreen.main
        let snapshots = screens.compactMap { screen -> DisplaySnapshot? in
            snapshot(from: screen, isPrimary: screen == mainScreen)
        }
        return DisplayTopology(displays: snapshots)
    }

    // MARK: - Private helpers

    /// Converts a single `NSScreen` into a `DisplaySnapshot`.
    ///
    /// Returns `nil` if the screen's device description does not contain a
    /// `CGDirectDisplayID` under `NSDeviceDescriptionKey("NSScreenNumber")`.
    /// This guard is defensive; all attached physical screens are expected to
    /// expose this key in practice.
    private func snapshot(from screen: NSScreen, isPrimary: Bool) -> DisplaySnapshot? {
        guard
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else {
            // Conservative: skip screens whose CGDirectDisplayID cannot be read.
            return nil
        }
        let id = DisplayID(number.uint32Value)
        return DisplaySnapshot(
            displayID: id,
            frame: screen.frame,
            visibleFrame: screen.visibleFrame,
            scaleFactor: screen.backingScaleFactor,
            isPrimary: isPrimary
        )
    }
}
