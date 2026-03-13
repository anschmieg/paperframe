import XCTest
import Cocoa
@testable import PaperWMMacAdapters
import PaperWMCore

/// Bootstrap tests for the Mac Adapters layer.
///
/// These tests confirm the stubs compile and return safe default values.
/// Real behavior tests will be added in later phases when adapters are implemented.
final class AXAdapterStubTests: XCTestCase {

    func testInitDoesNotCrash() {
        _ = AXAdapterStub()
    }

    func testWindowElementsReturnsEmpty() {
        // AXUIElementCreateSystemWide() gives a valid element to pass to the stub.
        let axAdapter = AXAdapterStub()
        let systemElement = AXUIElementCreateSystemWide()
        let windows = axAdapter.windowElements(for: systemElement)
        XCTAssertTrue(windows.isEmpty, "Stub should return empty array")
    }

    func testProbeCapabilitiesReturnsNone() {
        let axAdapter = AXAdapterStub()
        let systemElement = AXUIElementCreateSystemWide()
        let caps = axAdapter.probeCapabilities(of: systemElement)
        XCTAssertFalse(caps.canMove, "Stub should return all-false capabilities")
        XCTAssertFalse(caps.canResize, "Stub should return all-false capabilities")
    }

    func testApplicationElementReturnsNil() {
        let axAdapter = AXAdapterStub()
        // pid 0 is not a valid app pid; stub should return nil regardless.
        let element = axAdapter.applicationElement(for: 0)
        XCTAssertNil(element)
    }
}

final class DisplayAdapterStubTests: XCTestCase {

    func testCurrentTopologyReturnsEmpty() {
        let adapter = DisplayAdapterStub()
        let topology = adapter.currentTopology()
        // Stub always returns empty; real implementation will use NSScreen.
        XCTAssertTrue(topology.displays.isEmpty)
    }
}

final class WorkspaceAdapterStubTests: XCTestCase {

    func testFrontmostAppReturnsNil() {
        let adapter = WorkspaceAdapterStub()
        XCTAssertNil(adapter.frontmostApp())
    }

    func testRunningAppsReturnsEmpty() {
        let adapter = WorkspaceAdapterStub()
        XCTAssertTrue(adapter.runningApps().isEmpty)
    }
}

// MARK: - PermissionsService tests

/// Tests for the real `PermissionsService` backed by macOS public APIs.
///
/// NOTE: These tests run in a sandboxed XCTest process that has NOT been granted
/// Accessibility or Input Monitoring permission. The assertions reflect the
/// expected conservative "not trusted" defaults in that environment.
final class PermissionsServiceTests: XCTestCase {

    func testInitDoesNotCrash() {
        _ = PermissionsService()
    }

    /// In the test environment Accessibility is never pre-granted, so
    /// `accessibilityGranted` should be `false` and `isReducedMode` should be `true`.
    func testAccessibilityNotGrantedInTestEnvironment() {
        let svc = PermissionsService()
        // The test runner is not in the Accessibility list, so this must be false.
        XCTAssertFalse(svc.accessibilityGranted)
        XCTAssertTrue(svc.currentState.isReducedMode)
    }

    /// Accessibility status must be a definitive answer (granted or denied), not notDetermined.
    ///
    /// `AXIsProcessTrustedWithOptions` always returns a Boolean — there is no
    /// "not determined" state for Accessibility trust. The service maps `false` to `.denied`.
    func testAccessibilityStatusIsNeverNotDetermined() {
        let svc = PermissionsService()
        XCTAssertNotEqual(svc.currentState.accessibility, .notDetermined,
            "Accessibility status should be .granted or .denied, never .notDetermined")
    }

    /// Input Monitoring uses a conservative mapping: non-granted → `.notDetermined`.
    func testInputMonitoringIsConservativelyNotDetermined() {
        let svc = PermissionsService()
        // In the test environment IM is not granted; service maps this conservatively.
        let im = svc.currentState.inputMonitoring
        XCTAssertTrue(im == .notDetermined || im == .granted,
            "Input Monitoring should be .notDetermined (conservative) or .granted, never .denied from probe alone")
    }

    func testRefreshDoesNotCrash() {
        let svc = PermissionsService()
        svc.refresh()
        // State is still valid after a second probe.
        let _ = svc.currentState
    }

    func testRequestAccessibilityPermissionDoesNotCrash() {
        let svc = PermissionsService()
        // In a test environment this should not show a dialog, but must not crash.
        svc.requestAccessibilityPermission()
    }

    func testRequestInputMonitoringPermissionDoesNotCrash() {
        let svc = PermissionsService()
        svc.requestInputMonitoringPermission()
    }

    func testConformanceToProtocol() {
        let svc: any PermissionsServiceProtocol = PermissionsService()
        // Protocol accessors must be available.
        let _ = svc.currentState
        let _ = svc.accessibilityGranted
        let _ = svc.inputMonitoringGranted
    }
}
