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
