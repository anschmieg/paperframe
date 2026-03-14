# Paperframe — Test Strategy

## Overview

Tests are split into four categories. Each has a clear home and clear limits.

---

## 1. Pure Unit Tests

**Location:** `PaperWMCore` test target

**What belongs here:**
- `PaperRect` arithmetic and edge cases
- `WorldState` transitions (add window, remove window, move in paper space)
- `ProjectionPlanner` output given synthetic `DisplayTopology` and `PaperWindowState`
- `RuleEngine` policy evaluation given mock inputs
- `PlacementPlan` diff / delta computation
- `WindowEligibility` and `WindowCapabilities` flag logic

**Rules:**
- No AppKit, no AX, no real displays, no real processes.
- All inputs constructed in the test; no shared mutable state.
- Must compile and pass on Linux or in any CI sandbox with no macOS entitlements.

---

## 2. Adapter Contract Tests

**Location:** `PaperWMMacAdapters` test target

**What belongs here:**
- `PermissionsService` returns a valid `PermissionState` (any value) without crashing.
- `DisplayAdapter` returns a non-empty `DisplayTopology` when at least one screen is available.
- `AXAdapter` can be instantiated and exposes its interface (connection optional).
- `EventTapAdapter` setup path compiles and guards against missing permission.

**What to assert:**
- Type contracts and non-crash guarantees only.
- Never assert specific permission states (`.granted` / `.denied`).
- Never assert specific display counts or geometry; assert only structural validity.

**What not to assert:**
- That AX trust is granted.
- That a specific screen geometry is present.
- That event taps activate successfully.

These tests must pass in a sandboxed CI environment with no accessibility entitlements.

---

## 3. Smoke Tests

**Location:** `PaperWMRuntime` test target or a dedicated `SmokeTests` target.

**What belongs here:**
- End-to-end construction of the runtime stack with stub adapters.
- Verify that `WindowInventoryService`, `ObserverAndReconcileHub`, and `CommandRouter` wire up without crashing.
- Verify that a synthetic `WMEvent` round-trips through the planner without panic.

**Rules:**
- Use protocol-typed stub adapters, not real macOS adapters.
- Assert no crash, not specific state.
- These tests confirm the seams between modules, not business logic.

---

## 4. Manual Validation

**Trigger:** Required before merging any PR that touches a macOS adapter, permission flow, display topology, AX interaction, or event tap.

See `docs/MANUAL_VALIDATION_PLAN.md` for the full checklist.

Manual validation is explicitly out of scope for CI. Do not add assertions that require a real Accessibility permission grant.

---

## Handling Permission-Sensitive Behavior

- Permission checks must be behind a protocol so tests can inject a stub.
- Real `AXIsProcessTrustedWithOptions` and `CGPreflightListenEventAccess` calls belong only in `PermissionsService` in `PaperWMMacAdapters`.
- Tests must never call those APIs directly.
- If a code path requires permission, guard it behind a capability check and test only the guard logic, not the real grant.

---

## Summary Table

| Category         | Package                | macOS runtime needed | CI safe |
|------------------|------------------------|----------------------|---------|
| Pure unit        | PaperWMCore            | No                   | Yes     |
| Contract         | PaperWMMacAdapters     | Partial (no trust)   | Yes     |
| Smoke            | PaperWMRuntime         | No (stubs)           | Yes     |
| Manual validation| —                      | Yes (real Mac)       | No      |
