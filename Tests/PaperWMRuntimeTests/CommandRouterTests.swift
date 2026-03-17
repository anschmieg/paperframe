import Foundation
import PaperWMCore
import Testing

@testable import PaperWMRuntime

// MARK: - Test doubles

/// Minimal ReconciliationTriggering spy for CommandRouter tests.
@MainActor
private final class CRReconciliationSpy: ReconciliationTriggering {
    private(set) var reasons: [ReconcileReason] = []

    @discardableResult
    func reconcile(reason: ReconcileReason) async -> ReconcileResult {
        reasons.append(reason)
        return ReconcileResult(
            reason: reason,
            snapshotCount: 0,
            planIntentCount: 0,
            executionReport: PlacementExecutionReport()
        )
    }
}

// MARK: - Helpers

/// Builds a WorkspaceState on the given display.
private func crWorkspace(displayID: UInt32 = 1) -> WorkspaceState {
    let did = DisplayID(displayID)
    return WorkspaceState(displayID: did, viewport: ViewportState(displayID: did))
}

/// Wires up a CommandRouter backed by a spy reconciliation coordinator.
@MainActor
private func makeRouter(
    worldState: WorldStateStub,
    spy: CRReconciliationSpy
) -> CommandRouter {
    let switcher = WorkspaceSwitchCoordinator(
        worldState: worldState, reconciliationCoordinator: spy)
    return CommandRouter(
        worldState: worldState,
        workspaceSwitchCoordinator: switcher,
        reconciliationCoordinator: spy)
}

// MARK: - Routing: switchWorkspace

@Test("CommandRouter.handle routes switchWorkspace to WorkspaceSwitchCoordinator")
@MainActor
func commandRouterRoutesSwitchWorkspace() async {
    let worldState = WorldStateStub()
    let displayID = DisplayID(1)
    let ws1 = crWorkspace()
    let ws2 = crWorkspace()
    worldState.updateWorkspaceState(ws1)
    worldState.updateWorkspaceState(ws2)  // ws2 is now active

    let spy = CRReconciliationSpy()
    let router = makeRouter(worldState: worldState, spy: spy)

    await router.handle(command: .switchWorkspace(displayID: displayID, to: ws1.workspaceID))

    // The active workspace must have switched to ws1.
    #expect(worldState.activeWorkspace(for: displayID)?.workspaceID == ws1.workspaceID)

    // The reconciliation reason must be a userCommand wrapping switchWorkspace.
    #expect(spy.reasons.count == 1)
    if let reason = spy.reasons.first {
        #expect(
            reason
                == .userCommand(.switchWorkspace(displayID: displayID, to: ws1.workspaceID)))
    }
}

@Test("CommandRouter.handle switchWorkspace to already-active workspace is no-op")
@MainActor
func commandRouterSwitchAlreadyActiveIsNoop() async {
    let worldState = WorldStateStub()
    let displayID = DisplayID(1)
    let ws = crWorkspace()
    worldState.updateWorkspaceState(ws)

    let spy = CRReconciliationSpy()
    let router = makeRouter(worldState: worldState, spy: spy)

    await router.handle(command: .switchWorkspace(displayID: displayID, to: ws.workspaceID))

    // Workspace is already active — no reconciliation should be triggered.
    #expect(spy.reasons.isEmpty)
    #expect(worldState.activeWorkspace(for: displayID)?.workspaceID == ws.workspaceID)
}

@Test("CommandRouter.handle switchWorkspace to unknown workspace is safe no-op")
@MainActor
func commandRouterSwitchUnknownWorkspaceIsNoop() async {
    let worldState = WorldStateStub()
    let displayID = DisplayID(1)
    let unknownID = WorkspaceID()

    let spy = CRReconciliationSpy()
    let router = makeRouter(worldState: worldState, spy: spy)

    await router.handle(command: .switchWorkspace(displayID: displayID, to: unknownID))

    #expect(spy.reasons.isEmpty)
    #expect(worldState.activeWorkspace(for: displayID) == nil)
}

@Test("CommandRouter.handle switchWorkspace cross-display is safe no-op")
@MainActor
func commandRouterSwitchCrossDisplayIsNoop() async {
    let worldState = WorldStateStub()
    let d1 = DisplayID(1)
    let d2 = DisplayID(2)
    let ws1 = crWorkspace(displayID: 1)
    worldState.updateWorkspaceState(ws1)

    let spy = CRReconciliationSpy()
    let router = makeRouter(worldState: worldState, spy: spy)

    // Attempt to activate ws1 (registered for d1) on d2 — must be rejected.
    await router.handle(command: .switchWorkspace(displayID: d2, to: ws1.workspaceID))

    #expect(spy.reasons.isEmpty)
    #expect(worldState.activeWorkspace(for: d2) == nil)
    #expect(worldState.activeWorkspace(for: d1)?.workspaceID == ws1.workspaceID)
}

// MARK: - Per-display independence

@Test("CommandRouter.handle per-display workspace switches are independent")
@MainActor
func commandRouterPerDisplaySwitchesAreIndependent() async {
    let worldState = WorldStateStub()
    let d1 = DisplayID(1)
    let d2 = DisplayID(2)

    let ws1a = crWorkspace(displayID: 1)
    let ws1b = crWorkspace(displayID: 1)
    let ws2a = crWorkspace(displayID: 2)

    worldState.updateWorkspaceState(ws1a)
    worldState.updateWorkspaceState(ws1b)  // d1 active = ws1b
    worldState.updateWorkspaceState(ws2a)  // d2 active = ws2a

    let spy = CRReconciliationSpy()
    let router = makeRouter(worldState: worldState, spy: spy)

    // Switch d1 to ws1a — d2 must remain unchanged.
    await router.handle(command: .switchWorkspace(displayID: d1, to: ws1a.workspaceID))

    #expect(worldState.activeWorkspace(for: d1)?.workspaceID == ws1a.workspaceID)
    #expect(worldState.activeWorkspace(for: d2)?.workspaceID == ws2a.workspaceID)
    #expect(spy.reasons.count == 1)
}

// MARK: - Routing: refreshInventory

@Test("CommandRouter.handle refreshInventory triggers manualRefresh reconciliation")
@MainActor
func commandRouterRoutesRefreshInventory() async {
    let worldState = WorldStateStub()
    let spy = CRReconciliationSpy()
    let router = makeRouter(worldState: worldState, spy: spy)

    await router.handle(command: .refreshInventory)

    #expect(spy.reasons.count == 1)
    #expect(spy.reasons.first == .manualRefresh)
}

// MARK: - Persisted / restored workspace state

@Test("CommandRouter.handle switches workspaces restored from persisted state")
@MainActor
func commandRouterSwitchesRestoredPersistedWorkspaces() async {
    let d1 = DisplayID(1)
    let ws1 = crWorkspace(displayID: 1)
    let ws2 = crWorkspace(displayID: 1)

    // Pre-seed a store with ws1 and ws2 — ws2 is the active workspace.
    let persistedState = PersistedWorldState(
        workspaces: [ws1, ws2],
        activeWorkspaces: [ActiveWorkspaceEntry(displayID: d1, workspaceID: ws2.workspaceID)],
        paperWindowStates: []
    )
    let store = InMemoryWorldStatePersistenceStore(initial: persistedState)
    let worldState = WorldStateStub(persistenceStore: store)

    // After restore, ws2 must be active.
    #expect(worldState.activeWorkspace(for: d1)?.workspaceID == ws2.workspaceID)

    let spy = CRReconciliationSpy()
    let router = makeRouter(worldState: worldState, spy: spy)

    // Switch to ws1 via the command router — must succeed on restored state.
    await router.handle(command: .switchWorkspace(displayID: d1, to: ws1.workspaceID))

    #expect(worldState.activeWorkspace(for: d1)?.workspaceID == ws1.workspaceID)
    #expect(spy.reasons.count == 1)
    if let reason = spy.reasons.first {
        #expect(reason == .userCommand(.switchWorkspace(displayID: d1, to: ws1.workspaceID)))
    }
}

@Test("CommandRouter.handle no workspaces registered is safe")
@MainActor
func commandRouterNoWorkspacesIsSafe() async {
    let worldState = WorldStateStub()
    let displayID = DisplayID(1)

    let spy = CRReconciliationSpy()
    let router = makeRouter(worldState: worldState, spy: spy)

    await router.handle(command: .switchWorkspace(displayID: displayID, to: WorkspaceID()))

    #expect(spy.reasons.isEmpty)
    #expect(worldState.activeWorkspace(for: displayID) == nil)
}

// MARK: - Routing: renameWorkspace

@Test("WMCommand.renameWorkspace equality matches same ID and label")
func wmCommandRenameWorkspaceEquality() {
    let id = WorkspaceID()
    let cmd1 = WMCommand.renameWorkspace(workspaceID: id, newLabel: "My WS")
    let cmd2 = WMCommand.renameWorkspace(workspaceID: id, newLabel: "My WS")
    let cmdDiffLabel = WMCommand.renameWorkspace(workspaceID: id, newLabel: "Other")
    let cmdDiffID = WMCommand.renameWorkspace(workspaceID: WorkspaceID(), newLabel: "My WS")
    let cmdNilLabel = WMCommand.renameWorkspace(workspaceID: id, newLabel: nil)

    #expect(cmd1 == cmd2)
    #expect(cmd1 != cmdDiffLabel)
    #expect(cmd1 != cmdDiffID)
    #expect(cmd1 != cmdNilLabel)
}

@Test("CommandRouter.handle renameWorkspace updates the workspace label")
@MainActor
func commandRouterRoutesRenameWorkspace() async {
    let worldState = WorldStateStub()
    let displayID = DisplayID(1)
    let ws = crWorkspace()
    worldState.updateWorkspaceState(ws)

    let spy = CRReconciliationSpy()
    let router = makeRouter(worldState: worldState, spy: spy)

    await router.handle(
        command: .renameWorkspace(workspaceID: ws.workspaceID, newLabel: "Focus Time"))

    #expect(worldState.activeWorkspace(for: displayID)?.label == "Focus Time")
    // Rename must not trigger reconciliation.
    #expect(spy.reasons.isEmpty)
}

@Test("CommandRouter.handle renameWorkspace unknown workspace is safe no-op")
@MainActor
func commandRouterRenameUnknownWorkspaceIsNoop() async {
    let worldState = WorldStateStub()
    let unknownID = WorkspaceID()

    let spy = CRReconciliationSpy()
    let router = makeRouter(worldState: worldState, spy: spy)

    // Must not crash, mutate anything, or trigger reconciliation.
    await router.handle(command: .renameWorkspace(workspaceID: unknownID, newLabel: "Ghost"))

    #expect(spy.reasons.isEmpty)
}

@Test("CommandRouter.handle renameWorkspace with whitespace-only label clears the label")
@MainActor
func commandRouterRenameWhitespaceOnlyClearsLabel() async {
    let worldState = WorldStateStub()
    let displayID = DisplayID(1)
    let did = displayID
    var ws = WorkspaceState(displayID: did, viewport: ViewportState(displayID: did))
    ws.label = "Old Name"
    worldState.updateWorkspaceState(ws)

    let spy = CRReconciliationSpy()
    let router = makeRouter(worldState: worldState, spy: spy)

    await router.handle(
        command: .renameWorkspace(workspaceID: ws.workspaceID, newLabel: "   "))

    #expect(worldState.activeWorkspace(for: displayID)?.label == nil)
}

@Test("CommandRouter.handle renameWorkspace with nil label clears the label")
@MainActor
func commandRouterRenameNilLabelClears() async {
    let worldState = WorldStateStub()
    let displayID = DisplayID(1)
    let did = displayID
    var ws = WorkspaceState(displayID: did, viewport: ViewportState(displayID: did))
    ws.label = "Old Name"
    worldState.updateWorkspaceState(ws)

    let spy = CRReconciliationSpy()
    let router = makeRouter(worldState: worldState, spy: spy)

    await router.handle(
        command: .renameWorkspace(workspaceID: ws.workspaceID, newLabel: nil))

    #expect(worldState.activeWorkspace(for: displayID)?.label == nil)
}

@Test("CommandRouter.handle renameWorkspace persists the new label across sessions")
@MainActor
func commandRouterRenameIsPersisted() async {
    let store = InMemoryWorldStatePersistenceStore()
    let displayID = DisplayID(1)
    let did = displayID
    let ws = WorkspaceState(displayID: did, viewport: ViewportState(displayID: did))

    let worldState = WorldStateStub(persistenceStore: store)
    worldState.updateWorkspaceState(ws)

    let spy = CRReconciliationSpy()
    let router = makeRouter(worldState: worldState, spy: spy)

    await router.handle(
        command: .renameWorkspace(workspaceID: ws.workspaceID, newLabel: "Persisted"))

    // Simulate restart: new WorldStateStub restores from same store.
    let restored = WorldStateStub(persistenceStore: store)
    #expect(restored.activeWorkspace(for: displayID)?.label == "Persisted")
}

@Test("CommandRouter.handle renameWorkspace preserves independence across displays")
@MainActor
func commandRouterRenameIsDisplayIndependent() async {
    let worldState = WorldStateStub()
    let d1 = DisplayID(1)
    let d2 = DisplayID(2)

    let ws1 = crWorkspace(displayID: 1)
    let ws2 = crWorkspace(displayID: 2)
    worldState.updateWorkspaceState(ws1)
    worldState.updateWorkspaceState(ws2)

    let spy = CRReconciliationSpy()
    let router = makeRouter(worldState: worldState, spy: spy)

    // Rename only the workspace on display 1.
    await router.handle(
        command: .renameWorkspace(workspaceID: ws1.workspaceID, newLabel: "Display One"))

    #expect(worldState.activeWorkspace(for: d1)?.label == "Display One")
    // Workspace on display 2 must be unaffected.
    #expect(worldState.activeWorkspace(for: d2)?.label == nil)
}

@Test("CommandRouter.handle renameWorkspace does not affect workspace identity or switching")
@MainActor
func commandRouterRenamePreservesIdentityAndSwitching() async {
    let worldState = WorldStateStub()
    let displayID = DisplayID(1)
    let ws1 = crWorkspace()
    let ws2 = crWorkspace()
    worldState.updateWorkspaceState(ws1)
    worldState.updateWorkspaceState(ws2)  // ws2 is active

    let spy = CRReconciliationSpy()
    let router = makeRouter(worldState: worldState, spy: spy)

    // Rename ws1 (currently inactive).
    await router.handle(
        command: .renameWorkspace(workspaceID: ws1.workspaceID, newLabel: "Renamed"))

    // Active workspace must still be ws2.
    #expect(worldState.activeWorkspace(for: displayID)?.workspaceID == ws2.workspaceID)
    // ws1 should be reachable and labelled.
    let all = worldState.allWorkspaces(for: displayID)
    let renamed = all.first { $0.workspaceID == ws1.workspaceID }
    #expect(renamed?.label == "Renamed")

    // Switching to ws1 after rename must still work.
    await router.handle(command: .switchWorkspace(displayID: displayID, to: ws1.workspaceID))
    #expect(worldState.activeWorkspace(for: displayID)?.workspaceID == ws1.workspaceID)
    #expect(worldState.activeWorkspace(for: displayID)?.label == "Renamed")
}
