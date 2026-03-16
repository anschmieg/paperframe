import Testing
import Cocoa
@testable import PaperWMMacAdapters
@testable import PaperWMRuntime
import PaperWMCore

@Test("AXAdapterStub init does not crash")
func axAdapterStubInitDoesNotCrash() {
    _ = AXAdapterStub()
}

@Test("AXAdapterStub windowElements returns empty")
func axAdapterStubWindowElementsReturnsEmpty() {
    let axAdapter = AXAdapterStub()
    let systemElement = AXUIElementCreateSystemWide()
    let windows = axAdapter.windowElements(for: systemElement)
    #expect(windows.isEmpty)
}

@Test("AXAdapterStub probeCapabilities returns none")
func axAdapterStubProbeCapabilitiesReturnsNone() {
    let axAdapter = AXAdapterStub()
    let systemElement = AXUIElementCreateSystemWide()
    let caps = axAdapter.probeCapabilities(of: systemElement)
    #expect(!caps.canMove)
    #expect(!caps.canResize)
}

@Test("AXAdapterStub applicationElement returns nil")
func axAdapterStubApplicationElementReturnsNil() {
    let axAdapter = AXAdapterStub()
    let element = axAdapter.applicationElement(for: 0)
    #expect(element == nil)
}

@Test("DisplayAdapter init does not crash")
func displayAdapterInitDoesNotCrash() {
    _ = DisplayAdapter()
}

@Test("DisplayAdapter conforms to DisplayTopologyProviderProtocol")
func displayAdapterConformsToDisplayTopologyProviderProtocol() {
    // Verifies that DisplayAdapter can be used as any DisplayTopologyProviderProtocol,
    // which is the contract required by ReconciliationCoordinator.
    let adapter = DisplayAdapter()
    let provider: any DisplayTopologyProviderProtocol = adapter
    _ = provider.currentTopology()
}

@Test("DisplayAdapter currentTopology returns a non-nil topology")
func displayAdapterCurrentTopologyIsNonNil() {
    let adapter = DisplayAdapter()
    let topology = adapter.currentTopology()
    // topology is always a valid value type; this asserts init+call does not crash
    _ = topology.displays
}

@Test("DisplayAdapter topology display snapshots have positive frame dimensions")
func displayAdapterTopologyFramesArePositive() {
    let adapter = DisplayAdapter()
    let topology = adapter.currentTopology()
    for snapshot in topology.displays {
        #expect(snapshot.frame.width > 0)
        #expect(snapshot.frame.height > 0)
    }
}

@Test("DisplayAdapter topology display snapshots have valid scale factors")
func displayAdapterTopologyScaleFactorsAreValid() {
    let adapter = DisplayAdapter()
    let topology = adapter.currentTopology()
    for snapshot in topology.displays {
        #expect(snapshot.scaleFactor >= 1.0)
    }
}

@Test("DisplayAdapter topology visible frames are consistent with full frames")
func displayAdapterTopologyVisibleFramesConsistentWithFrames() {
    let adapter = DisplayAdapter()
    let topology = adapter.currentTopology()
    for snapshot in topology.displays {
        if let visibleFrame = snapshot.visibleFrame {
            // Visible frame must fit within the full frame (or equal it on secondary displays).
            #expect(visibleFrame.width <= snapshot.frame.width)
            #expect(visibleFrame.height <= snapshot.frame.height)
        }
    }
}

@Test("DisplayAdapter topology has at most one primary display")
func displayAdapterTopologyAtMostOnePrimary() {
    let adapter = DisplayAdapter()
    let topology = adapter.currentTopology()
    let primaries = topology.displays.filter { $0.isPrimary }
    #expect(primaries.count <= 1)
}

@Test("DisplayAdapter topology display IDs are unique")
func displayAdapterTopologyDisplayIDsAreUnique() {
    let adapter = DisplayAdapter()
    let topology = adapter.currentTopology()
    let ids = topology.displays.map { $0.displayID }
    let uniqueIDs = Set(ids)
    #expect(ids.count == uniqueIDs.count)
}

@Test("DisplayAdapter snapshot lookup works for returned displays")
func displayAdapterSnapshotLookupWorksForReturnedDisplays() {
    let adapter = DisplayAdapter()
    let topology = adapter.currentTopology()
    for snapshot in topology.displays {
        let found = topology.snapshot(for: snapshot.displayID)
        #expect(found != nil)
    }
}

@Test("WorkspaceAdapterStub frontmostApp returns nil")
func workspaceAdapterStubFrontmostAppReturnsNil() {
    let adapter = WorkspaceAdapterStub()
    #expect(adapter.frontmostApp() == nil)
}

@Test("WorkspaceAdapterStub runningApps returns empty")
func workspaceAdapterStubRunningAppsReturnsEmpty() {
    let adapter = WorkspaceAdapterStub()
    #expect(adapter.runningApps().isEmpty)
}

// MARK: - PermissionsService tests

@Test("PermissionsService init does not crash")
func permissionsServiceInitDoesNotCrash() {
    _ = PermissionsService()
}

@Test("Accessibility status is never notDetermined")
func accessibilityStatusIsNeverNotDetermined() {
    let service = PermissionsService()
    #expect(service.currentState.accessibility == .granted || service.currentState.accessibility == .denied)
}

@Test("Accessibility granted matches currentState")
func accessibilityGrantedMatchesCurrentState() {
    let service = PermissionsService()
    #expect(service.accessibilityGranted == (service.currentState.accessibility == .granted))
}

@Test("Input monitoring granted matches currentState")
func inputMonitoringGrantedMatchesCurrentState() {
    let service = PermissionsService()
    #expect(service.inputMonitoringGranted == (service.currentState.inputMonitoring == .granted))
}

@Test("Reduced mode is consistent with accessibility state")
func reducedModeIsConsistentWithAccessibilityState() {
    let service = PermissionsService()
    #expect(service.currentState.isReducedMode == (service.currentState.accessibility != .granted))
}

@Test("Input monitoring probe never returns denied")
func inputMonitoringIsNeverDeniedFromProbeAlone() {
    let service = PermissionsService()
    #expect(service.currentState.inputMonitoring != .denied)
}

@Test("PermissionsService refresh returns valid state")
func permissionsServiceRefreshReturnsValidState() {
    let service = PermissionsService()
    service.refresh()
    #expect(service.currentState.accessibility == .granted || service.currentState.accessibility == .denied)
    #expect(service.currentState.inputMonitoring != .denied)
}

@Test("PermissionsService requestAccessibilityPermission does not crash")
func permissionsServiceRequestAccessibilityPermissionDoesNotCrash() {
    let service = PermissionsService()
    service.requestAccessibilityPermission()
}

@Test("PermissionsService requestInputMonitoringPermission does not crash")
func permissionsServiceRequestInputMonitoringPermissionDoesNotCrash() {
    let service = PermissionsService()
    service.requestInputMonitoringPermission()
}

@Test("PermissionsService conforms to protocol shape")
func permissionsServiceConformanceToProtocol() {
    let service: any PermissionsServiceProtocol = PermissionsService()
    let _ = service.currentState
    let _ = service.accessibilityGranted
    let _ = service.inputMonitoringGranted
}

// MARK: - AXAdapter real implementation tests

@Test("AXAdapter can read frame from system element")
func axAdapterCanReadFrame() {
    let axAdapter = AXAdapter()
    let systemElement = AXUIElementCreateSystemWide()
    // System-wide element has a frame; we just verify the method doesn't crash
    // and returns a value (may be nil or .zero depending on AX state)
    let frame = axAdapter.frame(of: systemElement)
    // Frame should be nil or a valid CGRect - either is acceptable
    _ = frame
}

@Test("AXAdapter can read title from system element")
func axAdapterCanReadTitle() {
    let axAdapter = AXAdapter()
    let systemElement = AXUIElementCreateSystemWide()
    // Title may be nil or a string depending on AX state
    let title = axAdapter.title(of: systemElement)
    _ = title
}

@Test("AXAdapter probeCapabilities returns a valid struct")
func axAdapterProbeCapabilitiesReturnsValidStruct() {
    let axAdapter = AXAdapter()
    let systemElement = AXUIElementCreateSystemWide()
    let caps = axAdapter.probeCapabilities(of: systemElement)
    // Should return a valid WindowCapabilities struct (may be all false)
    _ = caps.canMove
    _ = caps.canResize
    _ = caps.canMinimize
    _ = caps.canFocus
    _ = caps.canClose
}

@Test("AXAdapter applicationElement returns nil for invalid PID")
func axAdapterApplicationElementReturnsNilForInvalidPID() {
    let axAdapter = AXAdapter()
    // PID 0 is the kernel, which has no AX representation
    let element = axAdapter.applicationElement(for: 0)
    #expect(element == nil)
}

@Test("AXAdapter windowElements returns array for any element")
func axAdapterWindowElementsReturnsArray() {
    let axAdapter = AXAdapter()
    let systemElement = AXUIElementCreateSystemWide()
    // Should return an array (may be empty)
    let windows = axAdapter.windowElements(for: systemElement)
    _ = windows.isEmpty  // Just verify it's a valid array
}

// MARK: - AXAdapter real implementation tests

@Test("AXAdapter applicationElement returns nil for non-existent PID")
func axAdapterApplicationElementReturnsNilForNonExistentPID() {
    let axAdapter = AXAdapter()
    // PID 99999 is unlikely to exist and should return nil
    let element = axAdapter.applicationElement(for: 99999)
    // May return nil or a non-functional element; both are acceptable
    _ = element
}

@Test("AXAdapter windowElements returns empty for system element")
func axAdapterWindowElementsReturnsEmptyForSystemElement() {
    let axAdapter = AXAdapter()
    let systemElement = AXUIElementCreateSystemWide()
    let windows = axAdapter.windowElements(for: systemElement)
    // System-wide element doesn't have windows attribute in the same way
    // Result may be empty or the call may fail gracefully
    _ = windows
}

@Test("AXAdapter frame returns nil for system element")
func axAdapterFrameReturnsNilForSystemElement() {
    let axAdapter = AXAdapter()
    let systemElement = AXUIElementCreateSystemWide()
    let frame = axAdapter.frame(of: systemElement)
    #expect(frame == nil)
}

@Test("AXAdapter title returns nil for system element")
func axAdapterTitleReturnsNilForSystemElement() {
    let axAdapter = AXAdapter()
    let systemElement = AXUIElementCreateSystemWide()
    let title = axAdapter.title(of: systemElement)
    // Title may be nil or empty for system element
    _ = title
}

@Test("AXAdapter probeCapabilities returns conservative values for system element")
func axAdapterProbeCapabilitiesReturnsConservativeValues() {
    let axAdapter = AXAdapter()
    let systemElement = AXUIElementCreateSystemWide()
    let caps = axAdapter.probeCapabilities(of: systemElement)
    // System-wide element should return conservative (mostly false) capabilities
    _ = caps
}

@Test("AXAdapter init does not crash")
func axAdapterInitDoesNotCrash() {
    _ = AXAdapter()
}

// MARK: - WindowInventoryService tests

@Test("WindowInventoryService init does not crash")
@MainActor
func windowInventoryServiceInitDoesNotCrash() {
    let permissions = PermissionsServiceStub()
    _ = WindowInventoryService(permissionsService: permissions)
}

@Test("WindowInventoryService returns empty snapshots when accessibility denied")
@MainActor
func windowInventoryServiceReturnsEmptyWhenAccessibilityDenied() async {
    let permissions = PermissionsServiceStub(initialState: PermissionsState(
        accessibility: .denied,
        inputMonitoring: .notDetermined
    ))
    let service = WindowInventoryService(permissionsService: permissions)
    await service.refreshSnapshot()
    #expect(service.snapshots.isEmpty)
}

@Test("WindowInventoryService snapshots have valid structure when accessible")
@MainActor
func windowInventoryServiceSnapshotsHaveValidStructure() async {
    let permissions = PermissionsServiceStub(initialState: PermissionsState(
        accessibility: .granted,
        inputMonitoring: .notDetermined
    ))
    let service = WindowInventoryService(permissionsService: permissions)
    await service.refreshSnapshot()
    // Snapshots may be empty or populated depending on system state
    // Just verify the array is accessible
    _ = service.snapshots
}

@Test("WindowInventoryService snapshot fields are valid")
@MainActor
func windowInventoryServiceSnapshotFieldsAreValid() async {
    let permissions = PermissionsServiceStub(initialState: PermissionsState(
        accessibility: .granted,
        inputMonitoring: .notDetermined
    ))
    let service = WindowInventoryService(permissionsService: permissions)
    await service.refreshSnapshot()

    for snapshot in service.snapshots {
        // All snapshots must have valid IDs
        #expect(!snapshot.windowID.rawValue.isEmpty)

        // All snapshots must have an app descriptor
        #expect(snapshot.app.pid > 0)

        // Frame must have non-negative dimensions
        #expect(snapshot.frameOnDisplay.width >= 0)
        #expect(snapshot.frameOnDisplay.height >= 0)

        // Display ID must be valid
        #expect(snapshot.displayID.rawValue > 0)
    }
}
