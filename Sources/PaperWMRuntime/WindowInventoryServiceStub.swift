import Foundation
import PaperWMCore

/// Stub implementation of `WindowInventoryServiceProtocol`.
///
/// In a real implementation this uses `AXAdapterStub` (and eventually a real
/// AX adapter) to enumerate all running apps and their windows, probe capabilities,
/// apply eligibility rules, and populate `snapshots`.
///
/// TODO (Phase 2): Inject `AXAdapterStub` (or a real AX adapter) and enumerate windows.
/// TODO (Phase 2): Apply `RuleEngineProtocol` to filter ineligible windows.
/// TODO (Phase 2): Build stable `ManagedWindowID` values from AX identity attributes.
public final class WindowInventoryServiceStub: WindowInventoryServiceProtocol {

    /// The most recent window snapshots. Empty until a real AX adapter is wired in.
    public private(set) var snapshots: [ManagedWindowSnapshot] = []

    public init() {}

    /// Performs a full inventory refresh.
    ///
    /// TODO: Enumerate NSWorkspace.shared.runningApplications, create AX elements,
    ///       read window attributes, probe capabilities, and build snapshots.
    public func refreshSnapshot() async {
        // TODO: Real implementation uses AXAdapterStub / real adapter.
        // snapshots = await buildSnapshots()
    }
}
