# Paperframe

A public-API macOS paper-style window manager built with Swift/AppKit and Accessibility APIs.

## Project goals

- Build a robust macOS window controller using public APIs only
- Use a paper-space model internally
- Treat live macOS window snapshots as runtime truth
- Project logical placements onto real displays
- Degrade gracefully when permissions or app-specific API limitations prevent full control

## Architectural stance

- Swift-native core
- AppKit-first
- Accessibility-driven window control
- Observer-driven synchronization with reconciliation
- Native macOS Spaces are observed, not managed
- No private APIs, scripting additions, or SIP-dependent behavior in v1

## Near-term milestones

1. Create package/module structure
2. Add core protocols and data types
3. Add compileable stubs
4. Add diagnostics shell
5. Implement PermissionsService
6. Implement DisplayTopology snapshotting
7. Implement WindowInventoryService

## Module layout

```
Sources/
├── PaperWMCore/            # Pure data types and service protocols — no macOS framework imports
│   ├── Identity.swift      # ManagedWindowID, DisplayID, WorkspaceID
│   ├── SnapshotTypes.swift # ManagedWindowSnapshot, AppDescriptor, WindowCapabilities, WindowEligibility
│   ├── PaperSpaceTypes.swift  # PaperRect, PaperPoint, PaperWindowState, ViewportState, WorkspaceState, WindowMode
│   ├── PlanningTypes.swift # DisplayTopology, PlacementPlan/Intent/Report, WMEvent, WMCommand, Direction
│   ├── DiagnosticsTypes.swift # DiagnosticsReport
│   └── Protocols.swift     # All service protocol definitions
│
├── PaperWMMacAdapters/     # macOS adapter stubs (Cocoa/AppKit) — implements Core protocols
│   ├── AXAdapterStub.swift         # AX window enumeration and attribute read/write stubs
│   └── DisplayAdapterStub.swift    # NSScreen topology + NSWorkspace app lifecycle stubs
│
├── PaperWMRuntime/         # Domain service stubs — implements Core protocols using adapters
│   ├── PermissionsServiceStub.swift
│   ├── WindowInventoryServiceStub.swift
│   ├── WorldStateStub.swift
│   ├── ProjectionPlannerStub.swift
│   ├── PlacementTransactionEngineStub.swift
│   ├── PersistenceStoreStub.swift
│   └── DiagnosticsServiceStub.swift
│
└── PaperWMApp/             # Menu-bar executable shell — wires runtime together
    ├── AppDelegate.swift   # NSApplicationDelegate, status bar item, diagnostics panel stub
    └── main.swift          # NSApplication entry point

Tests/
├── PaperWMCoreTests/
├── PaperWMMacAdaptersTests/
└── PaperWMRuntimeTests/
```

### Dependency graph

```
PaperWMApp → PaperWMRuntime → PaperWMCore
           → PaperWMMacAdapters → PaperWMCore
```

`PaperWMCore` has no dependencies outside of Foundation.

## Building

```bash
swift build
swift test
```

Requires macOS 13+ and Xcode / Swift 5.9+.

## Remaining work

The following subsystems are stubbed out with TODOs and tracked as future issues:

1. **PermissionsService** — real `AXIsProcessTrustedWithOptions` check and Input Monitoring probe
2. **AXAdapter** — window enumeration, attribute read/write, capability probing via Accessibility APIs
3. **DisplayAdapter** — `NSScreen`-backed topology snapshots and change notifications
4. **WindowInventoryService** — full AX enumeration pass, capability probing, eligibility filtering
5. **PlacementTransactionEngine** — read → delta → write → verify loop with retry-once policy
6. **ObserverAndReconcileHub** — AX notification observers, app-lifecycle hooks, Space/display reconciliation
7. **ProjectionPlanner** — paper-space → screen-coordinate projection
8. **RuleEngine** — per-app ignore/floating rules
9. **PersistenceStore** — UserDefaults / JSON-backed paper-state persistence
10. **UI** — onboarding, permissions flow, diagnostics inspector panel, settings window

## Repo conventions

- Small PRs
- One subsystem per issue
- Explicit module boundaries
- Prefer TODOs over speculative implementations
- Tests for completed behavior
