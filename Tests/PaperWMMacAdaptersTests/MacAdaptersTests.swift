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

/// Tests for the real `PermissionsService` backed by macOS public APIs.
///
/// These tests validate the structural contract of `PermissionsService` without
/// assuming any specific machine permission state. They assert that:
/// - the service returns valid `PermissionStatus` values
/// - the mapping rules (`AXIsProcessTrustedWithOptions` → non-.notDetermined, etc.) hold
/// - convenience accessors are consistent with `currentState`
/// - refresh and request methods do not crash
final class PermissionsServiceTests: XCTestCase {

    func testInitDoesNotCrash() {
        _ = PermissionsService()
    }

    /// Accessibility status must always be `.granted` or `.denied` — never `.notDetermined`.
    ///
    /// `AXIsProcessTrustedWithOptions` always returns a Boolean, so the service always
    /// resolves to one of the two definitive states.
    func testAccessibilityStatusIsNeverNotDetermined() {
        let svc = PermissionsService()
        XCTAssertNotEqual(svc.currentState.accessibility, .notDetermined,
            "Accessibility status should be .granted or .denied, never .notDetermined")
    }

    /// The `accessibilityGranted` convenience accessor must be consistent with `currentState`.
    func testAccessibilityGrantedMatchesCurrentState() {
        let svc = PermissionsService()
        XCTAssertEqual(svc.accessibilityGranted, svc.currentState.accessibility == .granted)
    }

    /// `isReducedMode` must be the inverse of Accessibility being granted.
    func testReducedModeIsConsistentWithAccessibilityState() {
        let svc = PermissionsService()
        XCTAssertEqual(svc.currentState.isReducedMode, !svc.accessibilityGranted)
    }

    /// Input Monitoring probe uses a conservative mapping: the probe result is
    /// never mapped to `.denied` — only `.granted` or `.notDetermined`.
    func testInputMonitoringIsNeverDeniedFromProbeAlone() {
        let svc = PermissionsService()
        let im = svc.currentState.inputMonitoring
        XCTAssertNotEqual(im, .denied,
            "Input Monitoring should be .granted or .notDetermined (conservative); .denied is never returned by the probe alone")
    }

    /// The `inputMonitoringGranted` convenience accessor must be consistent with `currentState`.
    func testInputMonitoringGrantedMatchesCurrentState() {
        let svc = PermissionsService()
        XCTAssertEqual(svc.inputMonitoringGranted, svc.currentState.inputMonitoring == .granted)
    }

    func testRefreshReturnsValidState() {
        let svc = PermissionsService()
        svc.refresh()
        // After a refresh the structural contract still holds.
        XCTAssertNotEqual(svc.currentState.accessibility, .notDetermined)
        XCTAssertNotEqual(svc.currentState.inputMonitoring, .denied)
    }

    func testRequestAccessibilityPermissionDoesNotCrash() {
        let svc = PermissionsService()
        // Must not crash; dialog behaviour is system-controlled.
        svc.requestAccessibilityPermission()
    }

    func testRequestInputMonitoringPermissionDoesNotCrash() {
        let svc = PermissionsService()
        svc.requestInputMonitoringPermission()
    }

    func testConformanceToProtocol() {
        let svc: any PermissionsServiceProtocol = PermissionsService()
        // All protocol accessors must be reachable.
        let _ = svc.currentState
        let _ = svc.accessibilityGranted
        let _ = svc.inputMonitoringGranted
    }
}
