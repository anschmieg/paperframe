# Paperframe — PR Review Checklist

Use this checklist when reviewing agent-generated or contributor PRs.

---

## Scope Discipline

- [ ] The PR addresses only the stated issue; no unrelated refactors or features.
- [ ] No changes to `docs/IMPLEMENTATION_PLAN.md` or `AGENTS.md` unless explicitly requested.
- [ ] New modules or types match the package layout in the implementation plan (`PaperWMCore`, `PaperWMMacAdapters`, `PaperWMRuntime`, `PaperWMApp`).
- [ ] No private macOS APIs introduced.

## Architecture / Module Boundaries

- [ ] Pure logic lives in `PaperWMCore`; macOS-specific code lives in `PaperWMMacAdapters`.
- [ ] Adapters are behind protocols so `PaperWMCore` and `PaperWMRuntime` do not import AppKit or AX directly.
- [ ] Permission checks go through `PermissionsService` only; no ad-hoc `AXIsProcessTrustedWithOptions` calls outside that service.
- [ ] Any new AX operation is guarded by a capability check.
- [ ] Placement writes follow the transactional pattern: read → compute delta → write → verify.

## Test Quality

- [ ] Pure logic changes have unit tests in `PaperWMCore`.
- [ ] New adapter code has contract tests that pass in CI (no real permission required).
- [ ] No test asserts a specific permission state (`.granted` / `.denied`).
- [ ] No test asserts specific display geometry or window coordinates from the real system.
- [ ] Tests use protocol stubs, not real macOS adapters, wherever the system boundary would be crossed.
- [ ] No existing tests are removed or weakened.

## Environment-Dependent Test Pitfalls

- [ ] No test calls `AXIsProcessTrustedWithOptions`, `CGPreflightListenEventAccess`, or similar trust APIs directly.
- [ ] No test spins up a real event tap or AX observer.
- [ ] No test relies on a specific number of connected displays.
- [ ] Tests that require a real Mac are documented as manual validation only (see `docs/MANUAL_VALIDATION_PLAN.md`).

## Manual Validation

- [ ] The PR description states which manual validation sections from `docs/MANUAL_VALIDATION_PLAN.md` apply.
- [ ] If the PR touches Accessibility, Input Monitoring, display topology, AX inventory, placement, or observers: all relevant checklist items are confirmed (or explicitly deferred with justification).
- [ ] No macOS-adapter change is merged with "not tested on device" and no deferral note.

## Merge Readiness

- [ ] CI passes (build + unit/contract/smoke tests).
- [ ] No compile warnings introduced in changed files.
- [ ] Remaining work is documented (stub comment, TODO, or follow-up issue).
- [ ] PR is small enough to review in a single sitting; if not, request a split.
