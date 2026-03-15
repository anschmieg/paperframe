import Testing
import Cocoa
@testable import PaperWMMacAdapters
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

@Test("DisplayAdapterStub currentTopology returns empty")
func displayAdapterStubCurrentTopologyReturnsEmpty() {
    let adapter = DisplayAdapterStub()
    let topology = adapter.currentTopology()
    #expect(topology.displays.isEmpty)
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
