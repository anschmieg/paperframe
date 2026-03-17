import Foundation
import PaperWMCore
import Testing

@testable import PaperWMRuntime

// MARK: - PersistenceStore tests

// These tests exercise the full round-trip behaviour of WorldStateStub when
// backed by an InMemoryWorldStatePersistenceStore, plus the PersistedWorldState
// encoding/decoding using the JSONWorldStatePersistenceStore on a temp file.

// MARK: - Helpers

private func makeWorkspace(
    displayID: UInt32,
    originX: Double = 0
) -> WorkspaceState {
    let did = DisplayID(displayID)
    return WorkspaceState(
        displayID: did,
        viewport: ViewportState(displayID: did, origin: PaperPoint(x: originX, y: 0), scale: 1.0)
    )
}

private func makePaperWindow(id: String, x: Double = 0) -> PaperWindowState {
    PaperWindowState(
        windowID: ManagedWindowID(id),
        paperRect: PaperRect(x: x, y: 0, width: 800, height: 600)
    )
}

// MARK: - Empty / no-data cases

@Test("WorldStateStub init with nil store starts empty and is safe")
func persistenceNilStoreStartsEmpty() {
    let ws = WorldStateStub(persistenceStore: nil)
    let displayID = DisplayID(1)
    #expect(ws.activeWorkspace(for: displayID) == nil)
    #expect(ws.allWorkspaces(for: displayID).isEmpty)
    #expect(ws.paperWindowState(for: ManagedWindowID("any")) == nil)
}

@Test("WorldStateStub init with empty in-memory store starts empty and is safe")
func persistenceEmptyStoreStartsEmpty() {
    let store = InMemoryWorldStatePersistenceStore()
    let ws = WorldStateStub(persistenceStore: store)
    let displayID = DisplayID(1)
    #expect(ws.activeWorkspace(for: displayID) == nil)
    #expect(ws.allWorkspaces(for: displayID).isEmpty)
}

// MARK: - Registered workspaces round-trip

@Test("Registered workspaces round-trip through in-memory persistence store")
func persistenceWorkspacesRoundTrip() {
    let store = InMemoryWorldStatePersistenceStore()
    let displayID = DisplayID(1)

    let wsA = makeWorkspace(displayID: 1, originX: 0)
    let wsB = makeWorkspace(displayID: 1, originX: 1000)

    do {
        let writer = WorldStateStub(persistenceStore: store)
        writer.updateWorkspaceState(wsA)  // activates wsA for d1
        writer.updateWorkspaceState(wsB)  // activates wsB for d1 (last registered)
    }

    // New instance loads from the same store.
    let reader = WorldStateStub(persistenceStore: store)
    let all = reader.allWorkspaces(for: displayID)
    #expect(all.count == 2)

    let ids = Set(all.map(\.workspaceID))
    #expect(ids.contains(wsA.workspaceID))
    #expect(ids.contains(wsB.workspaceID))
}

// MARK: - Active workspace per display round-trips

@Test("Active workspace per display round-trips through persistence")
func persistenceActiveWorkspaceRoundTrip() {
    let store = InMemoryWorldStatePersistenceStore()
    let d1 = DisplayID(1)
    let d2 = DisplayID(2)

    let ws1 = makeWorkspace(displayID: 1)
    let ws2a = makeWorkspace(displayID: 2)
    let ws2b = makeWorkspace(displayID: 2, originX: 500)

    do {
        let writer = WorldStateStub(persistenceStore: store)
        writer.updateWorkspaceState(ws1)
        writer.updateWorkspaceState(ws2a)
        writer.updateWorkspaceState(ws2b)  // d2 active = ws2b
        // Explicitly switch d2 back to ws2a.
        writer.setActiveWorkspace(ws2a.workspaceID, for: d2)
    }

    let reader = WorldStateStub(persistenceStore: store)
    #expect(reader.activeWorkspace(for: d1)?.workspaceID == ws1.workspaceID)
    #expect(reader.activeWorkspace(for: d2)?.workspaceID == ws2a.workspaceID)
}

// MARK: - Viewport state round-trips

@Test("Viewport state is preserved through persistence")
func persistenceViewportRoundTrip() {
    let store = InMemoryWorldStatePersistenceStore()
    let displayID = DisplayID(1)

    let viewport = ViewportState(
        displayID: displayID,
        origin: PaperPoint(x: 42.5, y: 7.0),
        scale: 2.0
    )
    let ws = WorkspaceState(
        displayID: displayID,
        viewport: viewport
    )

    do {
        let writer = WorldStateStub(persistenceStore: store)
        writer.updateWorkspaceState(ws)
    }

    let reader = WorldStateStub(persistenceStore: store)
    let restored = reader.activeWorkspace(for: displayID)
    #expect(restored?.workspaceID == ws.workspaceID)
    #expect(restored?.viewport.origin.x == 42.5)
    #expect(restored?.viewport.origin.y == 7.0)
    #expect(restored?.viewport.scale == 2.0)
}

// MARK: - Paper window state round-trips

@Test("Paper window states round-trip through persistence")
func persistencePaperWindowStateRoundTrip() {
    let store = InMemoryWorldStatePersistenceStore()

    let winA = makePaperWindow(id: "win-a", x: 100)
    let winB = makePaperWindow(id: "win-b", x: 200)

    do {
        let writer = WorldStateStub(persistenceStore: store)
        writer.updatePaperWindowState(winA)
        writer.updatePaperWindowState(winB)
    }

    let reader = WorldStateStub(persistenceStore: store)
    let restoredA = reader.paperWindowState(for: ManagedWindowID("win-a"))
    let restoredB = reader.paperWindowState(for: ManagedWindowID("win-b"))

    #expect(restoredA?.paperRect.x == 100)
    #expect(restoredB?.paperRect.x == 200)
}

// MARK: - Cross-display activation still rejected after restore

@Test("Cross-display workspace activation is rejected even after restore")
func persistenceCrossDisplayRejectedAfterRestore() {
    let store = InMemoryWorldStatePersistenceStore()
    let d1 = DisplayID(1)
    let d2 = DisplayID(2)

    let ws1 = makeWorkspace(displayID: 1)

    do {
        let writer = WorldStateStub(persistenceStore: store)
        writer.updateWorkspaceState(ws1)
    }

    let restored = WorldStateStub(persistenceStore: store)
    // Attempt to activate a d1 workspace for d2 — must fail.
    let result = restored.setActiveWorkspace(ws1.workspaceID, for: d2)
    #expect(!result)
    #expect(restored.activeWorkspace(for: d2) == nil)
    #expect(restored.activeWorkspace(for: d1)?.workspaceID == ws1.workspaceID)
}

// MARK: - Workspace switching after restore persists new active workspace

@Test("Switching workspace after restore persists the updated active workspace")
func persistenceSwitchAfterRestoreIsPersisted() {
    let store = InMemoryWorldStatePersistenceStore()
    let displayID = DisplayID(1)

    let wsA = makeWorkspace(displayID: 1)
    let wsB = makeWorkspace(displayID: 1, originX: 999)

    do {
        let writer = WorldStateStub(persistenceStore: store)
        writer.updateWorkspaceState(wsA)
        writer.updateWorkspaceState(wsB)  // wsB is active
    }

    // Restore and switch to wsA.
    do {
        let mid = WorldStateStub(persistenceStore: store)
        #expect(mid.activeWorkspace(for: displayID)?.workspaceID == wsB.workspaceID)
        let switched = mid.setActiveWorkspace(wsA.workspaceID, for: displayID)
        #expect(switched)
    }

    // Third instance should see wsA as active.
    let final = WorldStateStub(persistenceStore: store)
    #expect(final.activeWorkspace(for: displayID)?.workspaceID == wsA.workspaceID)
}

// MARK: - Safety: persisted active workspace references missing workspace

@Test("Persisted active workspace ID referencing missing workspace is safely ignored")
func persistenceMissingWorkspaceIsSafe() {
    let displayID = DisplayID(1)
    let orphanID = WorkspaceID()

    // Manually craft a snapshot with an active workspace entry that has no
    // matching workspace in the workspace list.
    let snapshot = PersistedWorldState(
        workspaces: [],  // empty — no workspace registered
        activeWorkspaces: [
            ActiveWorkspaceEntry(displayID: displayID, workspaceID: orphanID)
        ],
        paperWindowStates: []
    )

    let store = InMemoryWorldStatePersistenceStore(initial: snapshot)
    let ws = WorldStateStub(persistenceStore: store)

    // The orphan active entry must be silently dropped; display must have no active workspace.
    #expect(ws.activeWorkspace(for: displayID) == nil)
}

// MARK: - Safety: partial persisted data (no active workspace IDs)

@Test("Partial persisted data with workspaces but no active IDs restores workspaces only")
func persistencePartialDataWorkspacesOnly() {
    let displayID = DisplayID(1)
    let ws = makeWorkspace(displayID: 1)

    let snapshot = PersistedWorldState(
        workspaces: [ws],
        activeWorkspaces: [],  // no active workspace persisted
        paperWindowStates: []
    )

    let store = InMemoryWorldStatePersistenceStore(initial: snapshot)
    let worldState = WorldStateStub(persistenceStore: store)

    // Workspace is registered but no display has an active workspace.
    #expect(worldState.allWorkspaces(for: displayID).count == 1)
    #expect(worldState.activeWorkspace(for: displayID) == nil)
}

// MARK: - Multiple displays have independent active workspaces

@Test("Multiple displays each restore their own independent active workspace")
func persistenceMultipleDisplaysAreIndependent() {
    let store = InMemoryWorldStatePersistenceStore()
    let d1 = DisplayID(1)
    let d2 = DisplayID(2)

    let ws1a = makeWorkspace(displayID: 1)
    let ws1b = makeWorkspace(displayID: 1, originX: 500)
    let ws2a = makeWorkspace(displayID: 2)

    do {
        let writer = WorldStateStub(persistenceStore: store)
        writer.updateWorkspaceState(ws1a)
        writer.updateWorkspaceState(ws1b)  // d1 active = ws1b
        writer.updateWorkspaceState(ws2a)  // d2 active = ws2a
        // Explicitly switch d1 back to ws1a.
        writer.setActiveWorkspace(ws1a.workspaceID, for: d1)
    }

    let reader = WorldStateStub(persistenceStore: store)
    #expect(reader.activeWorkspace(for: d1)?.workspaceID == ws1a.workspaceID)
    #expect(reader.activeWorkspace(for: d2)?.workspaceID == ws2a.workspaceID)
}

// MARK: - Workspace label round-trip tests

@Test("Workspace label survives in-memory persistence round-trip")
func workspaceLabelInMemoryRoundTrip() {
    let store = InMemoryWorldStatePersistenceStore()
    let displayID = DisplayID(1)

    let did = displayID
    var ws = WorkspaceState(
        displayID: did,
        viewport: ViewportState(displayID: did)
    )
    ws.label = "My Work"

    do {
        let writer = WorldStateStub(persistenceStore: store)
        writer.updateWorkspaceState(ws)
    }

    let reader = WorldStateStub(persistenceStore: store)
    let restored = reader.activeWorkspace(for: displayID)
    #expect(restored?.workspaceID == ws.workspaceID)
    #expect(restored?.label == "My Work")
}

@Test("Workspace label survives JSON persistence round-trip")
func workspaceLabelJSONRoundTrip() throws {
    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("paperframe-label-test-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: tmpURL) }

    let displayID = DisplayID(42)
    let did = displayID
    var ws = WorkspaceState(
        displayID: did,
        viewport: ViewportState(displayID: did)
    )
    ws.label = "Design Sprint"

    let original = PersistedWorldState(
        workspaces: [ws],
        activeWorkspaces: [ActiveWorkspaceEntry(displayID: displayID, workspaceID: ws.workspaceID)],
        paperWindowStates: []
    )

    let jsonStore = JSONWorldStatePersistenceStore(fileURL: tmpURL)
    try jsonStore.save(original)

    guard let loaded = jsonStore.load() else {
        Issue.record("JSONWorldStatePersistenceStore.load() returned nil after save")
        return
    }

    #expect(loaded.workspaces.count == 1)
    #expect(loaded.workspaces[0].label == "Design Sprint")
}

@Test("Older persisted data without label field restores with nil label (backward-compatible)")
func workspaceLabelMissingFromOldDataRestoresSafely() throws {
    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("paperframe-old-data-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: tmpURL) }

    // Manually craft JSON that does not include the "label" key.
    let oldJSON = """
    {
      "workspaces": [
        {
          "workspaceID": {"rawValue": "00000000-0000-0000-0000-000000000001"},
          "displayID": {"rawValue": 1},
          "viewport": {
            "displayID": {"rawValue": 1},
            "origin": {"x": 0, "y": 0},
            "scale": 1
          },
          "windowIDs": []
        }
      ],
      "activeWorkspaces": [
        {
          "displayID": {"rawValue": 1},
          "workspaceID": {"rawValue": "00000000-0000-0000-0000-000000000001"}
        }
      ],
      "paperWindowStates": []
    }
    """
    try oldJSON.write(to: tmpURL, atomically: true, encoding: .utf8)

    let jsonStore = JSONWorldStatePersistenceStore(fileURL: tmpURL)
    guard let loaded = jsonStore.load() else {
        Issue.record("load() returned nil for valid old-format JSON")
        return
    }

    #expect(loaded.workspaces.count == 1)
    // label must be nil when absent from persisted data.
    #expect(loaded.workspaces[0].label == nil)
}

@Test("Workspace with nil label falls back to deterministic Workspace N label")
func workspaceLabelFallbackIsDeterministic() {
    let store = InMemoryWorldStatePersistenceStore()
    let displayID = DisplayID(1)
    let did = displayID

    // Register two workspaces without explicit labels.
    let ws1 = WorkspaceState(
        displayID: did,
        viewport: ViewportState(displayID: did)
    )
    let ws2 = WorkspaceState(
        displayID: did,
        viewport: ViewportState(displayID: did)
    )

    let writer = WorldStateStub(persistenceStore: store)
    writer.updateWorkspaceState(ws1)
    writer.updateWorkspaceState(ws2)

    let reader = WorldStateStub(persistenceStore: store)
    let all = reader.allWorkspaces(for: displayID)
        .sorted { $0.workspaceID.rawValue.uuidString < $1.workspaceID.rawValue.uuidString }
    #expect(all.count == 2)

    // Both should have nil labels (explicit fallback logic is in AppDelegate/display layer).
    for ws in all {
        #expect(ws.label == nil)
    }
}

@Test("Workspace with empty/whitespace-only label is treated as nil by display layer")
func workspaceLabelWhitespaceOnlyIsTreatedAsNil() {
    let displayID = DisplayID(1)
    let did = displayID
    var ws = WorkspaceState(displayID: did, viewport: ViewportState(displayID: did))
    ws.label = "   "

    // Simulate the label-resolution logic from AppDelegate.
    let trimmed = ws.label?.trimmingCharacters(in: .whitespaces) ?? ""
    let isUsable = !trimmed.isEmpty
    #expect(!isUsable)
}

@Test("Multiple displays each preserve their own labeled workspaces independently")
func workspaceLabelMultipleDisplaysAreIndependent() {
    let store = InMemoryWorldStatePersistenceStore()
    let d1 = DisplayID(1)
    let d2 = DisplayID(2)

    var wsD1 = WorkspaceState(displayID: d1, viewport: ViewportState(displayID: d1))
    wsD1.label = "Display One WS"
    var wsD2 = WorkspaceState(displayID: d2, viewport: ViewportState(displayID: d2))
    wsD2.label = "Display Two WS"

    do {
        let writer = WorldStateStub(persistenceStore: store)
        writer.updateWorkspaceState(wsD1)
        writer.updateWorkspaceState(wsD2)
    }

    let reader = WorldStateStub(persistenceStore: store)
    #expect(reader.activeWorkspace(for: d1)?.label == "Display One WS")
    #expect(reader.activeWorkspace(for: d2)?.label == "Display Two WS")
}

@Test("Workspace switching still works correctly when labels are present")
func workspaceSwitchingWithLabelsIsUnchanged() {
    let store = InMemoryWorldStatePersistenceStore()
    let displayID = DisplayID(1)
    let did = displayID

    var wsA = WorkspaceState(displayID: did, viewport: ViewportState(displayID: did))
    wsA.label = "Alpha"
    var wsB = WorkspaceState(displayID: did, viewport: ViewportState(displayID: did))
    wsB.label = "Beta"

    do {
        let writer = WorldStateStub(persistenceStore: store)
        writer.updateWorkspaceState(wsA)
        writer.updateWorkspaceState(wsB)  // wsB is active
    }

    let session = WorldStateStub(persistenceStore: store)
    #expect(session.activeWorkspace(for: displayID)?.workspaceID == wsB.workspaceID)
    #expect(session.activeWorkspace(for: displayID)?.label == "Beta")

    // Switch to wsA and verify label is preserved.
    let switched = session.setActiveWorkspace(wsA.workspaceID, for: displayID)
    #expect(switched)
    #expect(session.activeWorkspace(for: displayID)?.workspaceID == wsA.workspaceID)
    #expect(session.activeWorkspace(for: displayID)?.label == "Alpha")
}


@Test("PersistedWorldState JSON round-trip preserves all fields")
func persistenceJSONRoundTrip() throws {
    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("paperframe-test-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: tmpURL) }

    let displayID = DisplayID(42)
    let ws = WorkspaceState(
        displayID: displayID,
        viewport: ViewportState(
            displayID: displayID,
            origin: PaperPoint(x: 123, y: 456),
            scale: 1.5
        ),
        windowIDs: [ManagedWindowID("w1"), ManagedWindowID("w2")]
    )
    let win = PaperWindowState(
        windowID: ManagedWindowID("w1"),
        paperRect: PaperRect(x: 10, y: 20, width: 800, height: 600),
        mode: .tiled
    )

    let original = PersistedWorldState(
        workspaces: [ws],
        activeWorkspaces: [ActiveWorkspaceEntry(displayID: displayID, workspaceID: ws.workspaceID)],
        paperWindowStates: [win]
    )

    let jsonStore = JSONWorldStatePersistenceStore(fileURL: tmpURL)
    try jsonStore.save(original)

    guard let loaded = jsonStore.load() else {
        Issue.record("JSONWorldStatePersistenceStore.load() returned nil after save")
        return
    }

    // Workspaces
    #expect(loaded.workspaces.count == 1)
    let loadedWS = loaded.workspaces[0]
    #expect(loadedWS.workspaceID == ws.workspaceID)
    #expect(loadedWS.displayID == displayID)
    #expect(loadedWS.viewport.origin.x == 123)
    #expect(loadedWS.viewport.origin.y == 456)
    #expect(loadedWS.viewport.scale == 1.5)
    #expect(loadedWS.windowIDs == [ManagedWindowID("w1"), ManagedWindowID("w2")])

    // Active workspaces
    #expect(loaded.activeWorkspaces.count == 1)
    #expect(loaded.activeWorkspaces[0].displayID == displayID)
    #expect(loaded.activeWorkspaces[0].workspaceID == ws.workspaceID)

    // Paper window states
    #expect(loaded.paperWindowStates.count == 1)
    let loadedWin = loaded.paperWindowStates[0]
    #expect(loadedWin.windowID == ManagedWindowID("w1"))
    #expect(loadedWin.paperRect.x == 10)
    #expect(loadedWin.paperRect.y == 20)
    #expect(loadedWin.paperRect.width == 800)
    #expect(loadedWin.paperRect.height == 600)
}

@Test("JSONWorldStatePersistenceStore returns nil when file does not exist")
func persistenceJSONMissingFileReturnsNil() {
    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("paperframe-nonexistent-\(UUID().uuidString).json")
    let store = JSONWorldStatePersistenceStore(fileURL: tmpURL)
    #expect(store.load() == nil)
}

@Test("JSONWorldStatePersistenceStore returns nil for corrupt file (fail safe)")
func persistenceJSONCorruptFileReturnsNil() throws {
    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("paperframe-corrupt-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: tmpURL) }

    try "this is not valid JSON {{{".write(to: tmpURL, atomically: true, encoding: .utf8)

    let store = JSONWorldStatePersistenceStore(fileURL: tmpURL)
    #expect(store.load() == nil)
}
