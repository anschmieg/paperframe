# Paperframe — Updated Implementation Plan

## 1. Purpose

Build a public-API macOS window manager that uses a paper-space model internally while treating real macOS windows as the operational source of truth.

The system should:
- manage windows through public Accessibility APIs
- provide a logical paper or canvas abstraction for layout and navigation
- project paper-space placements onto real displays
- degrade gracefully when macOS APIs, app behavior, or permissions prevent perfect control

The design goal is robustness over purity. The product should behave like a dependable window controller, not a replacement compositor.

## 2. Product Principles

### 2.1 Core stance
- Paper space is a planning model, not a literal OS desktop.
- Real window snapshots are the runtime source of truth.
- All control is capability-driven.
- Native macOS Spaces are observed, not managed.
- Every write is transactional: read, compute delta, write, verify, degrade if necessary.

### 2.2 Non-goals for the public-API build
- replacing the system compositor/window server
- reliable direct control of native Mission Control Spaces
- guaranteed management of every app window type
- per-pixel desktop panning as if macOS had a giant hidden desktop surface
- dependency on private APIs, scripting additions, or SIP modifications

## 3. High-Level Architecture

- Permissions
  - Accessibility
  - Input Monitoring
- System Adapters
  - AX Adapter
  - Observer Adapter
  - Event Tap Adapter
  - Display Adapter
  - Workspace Adapter
- Domain Runtime
  - WindowInventoryService
  - WorldState
  - ProjectionPlanner
  - PlacementTransactionEngine
  - ObserverAndReconcileHub
  - CommandRouter
  - RuleEngine
  - PersistenceStore
- UI Layer
  - Menu Bar App
  - Settings
  - Inspector / Diagnostics
  - Onboarding / Permissions

## 4. Module Boundaries

### 4.1 PermissionsService
Centralize all permission and trust checks.

### 4.2 WindowInventoryService
Discover candidate windows, normalize them, probe capabilities, and maintain the latest observed snapshot.

### 4.3 WorldState
Store user intent and paper-space metadata.

### 4.4 ProjectionPlanner
Compute desired placement intents from live window snapshots plus paper-space state.

### 4.5 PlacementTransactionEngine
Apply placement intents to real windows using transactional AX writes.

### 4.6 ObserverAndReconcileHub
Listen for app/window/display/workspace changes and keep the runtime synchronized.

### 4.7 CommandRouter
Convert global inputs, UI actions, and internal commands into semantic commands.

### 4.8 RuleEngine
Apply app-specific and user-specific policy before planning and realization.

### 4.9 PersistenceStore
Persist user preferences and paper-state metadata.

### 4.10 DiagnosticsService
Provide visibility into runtime state and failures.

## 5. Core Data Types

### Identity
- ManagedWindowID
- DisplayID
- WorkspaceID

### Snapshot / capability / eligibility
- ManagedWindowSnapshot
- AppDescriptor
- WindowCapabilities
- WindowEligibility

### Paper-space
- PaperRect
- PaperWindowState
- ViewportState
- WorkspaceState
- WindowMode

### Planning / execution
- DisplayTopology
- DisplaySnapshot
- PlacementPlan
- PlacementIntent
- VisibilityPolicy
- PlacementExecutionReport
- PlacementResult
- WMEvent
- ReconcileReason
- WMCommand
- Direction

## 6. macOS API Mapping

### Accessibility / AX
Used for:
- trust checks
- window enumeration
- reading and writing window attributes
- raising and focusing windows
- observer registration
- AX messaging timeouts

### Quartz Event Services
Used for:
- global event taps
- keyboard-driven command capture

### AppKit / NSWorkspace / NSScreen
Used for:
- app lifecycle awareness
- frontmost app info
- Space change signals
- display geometry

### Core Graphics Window List
Used only as optional telemetry and diagnostics in v1.

## 7. Runtime Flow

### Startup
1. launch menu bar app
2. read persisted rules and world state
3. check permissions
4. start display/workspace observers
5. build initial inventory
6. start AX observers for known apps
7. compute initial placement plan
8. apply plan conservatively
9. expose diagnostics UI

### Steady-state event loop
1. event arrives
2. module emits WMEvent
3. event may trigger targeted inventory refresh
4. planner recomputes impacted placements
5. transaction engine applies minimal delta
6. verification result updates diagnostics and world metadata

## 8. Window Management Policies

### Eligibility Policy
A window is manageable only if it passes enough capability and role/subrole checks.

### Visibility Policy
Preferred default:
- project windows that intersect the active viewport
- leave off-viewport windows untouched unless user opts into minimize-on-exit behavior

### Focus Policy
Focus is determined from live system state, not inferred from paper coordinates.

### Native Spaces Policy
- native Spaces are observed only
- paper workspaces are app-defined abstractions
- no direct dependency on moving windows between native Spaces

## 9. Failure Modes and Contingencies

- Missing Accessibility permission
- Missing Input Monitoring permission
- Unsupported window attributes
- AX notification gaps or observer failure
- Transaction writes resist or drift
- Tabs / panels / sheets reported as windows
- Native Space changes break assumptions
- Display topology changes
- App hang or slow AX messaging
- Identity instability across relaunches

## 10. Robustness Rules

1. Read before write.
2. Write only deltas.
3. Verify once. Retry once. Stop.
4. Do not assume every AX window is manageable.
5. Do not make CGWindow correlation a hard dependency.
6. Do not encode native Spaces into the core model.
7. Prefer explicit reduced modes over silent failure.
8. Make diagnostics visible from the beginning.
9. Keep app-specific rule overrides first-class.
10. Treat user trust as more important than strict model purity.

## 11. Streamlined v1 Scope

### Included in v1
- menu bar app
- permission onboarding
- window inventory and capability probing
- one viewport per display
- paper coordinates per managed window
- move / resize / focus / minimize where supported
- global hotkeys when available
- menu bar fallback commands
- observer-driven sync with reconciliation
- per-app ignore/floating rules
- diagnostics inspector

### Deferred from v1
- deep native-Space semantics
- aggressive off-viewport hiding/parking
- complex animation system
- AX↔CG perfect correlation layer
- private-API or scripting-addition integration

## 12. Suggested File / Package Layout

Packages/
- PaperWMApp/
- PaperWMCore/
- PaperWMMacAdapters/
- PaperWMRuntime/

## 13. Implementation Sequence

### Phase 1 — Foundation
- menu bar app shell
- permission state model
- display topology snapshot
- diagnostics panel skeleton

### Phase 2 — Live Inventory
- enumerate apps and windows
- capability probing
- eligibility filtering
- stable snapshot model

### Phase 3 — Transactional Control
- move/resize/minimize/focus commands
- verification and retry policy
- timeout handling

### Phase 4 — Event-Driven Runtime
- AX observers
- app lifecycle hooks
- active Space and display change reconciliation

### Phase 5 — Paper Model
- persisted paper coordinates
- viewport model
- simple pan/focus commands
- follow-focus optional mode

### Phase 6 — Rules and UX Hardening
- per-app rules
- ignored window management
- reduced-mode UX
- inspector improvements

## 14. Reuse, Forking, and External Code Strategy

### Recommendation Summary
- build the core runtime in a Swift-native architecture
- use Paneru and orcv as reference implementations and UX/architecture studies
- fork only when research or prototyping requires invasive experimentation
- embed only narrowly scoped leaf dependencies that do not define the product architecture

### Decision Outcome
Proceed with:
- own core runtime
- Paneru as a research/benchmark reference
- orcv as a conceptual/UX reference
- no core submodule dependency on either project

## 15. Open Questions

- how aggressive should best-effort window identity matching be across relaunches?
- should off-viewport behavior default to leave-untouched or be workspace-specific?
- what tolerance should count as successful placement on different apps/displays?
- when should a repeatedly resistant app become auto-excluded or downgraded to focus-only?
- should paper workspaces be global or per-display by default?

## 16. Summary

The architecture should treat:
- live AX-backed snapshots as runtime truth
- paper-space as intent and organization
- placement as a verified transaction
- Spaces as observed external context
- API irregularities as normal conditions, not exceptions
