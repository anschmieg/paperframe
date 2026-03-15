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
