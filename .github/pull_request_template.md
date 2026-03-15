## Summary

<!-- One or two sentences: what does this PR do and why? -->

## Scope

<!-- Which subsystem(s) does this touch? Check all that apply. -->

- [ ] PaperWMCore (pure logic)
- [ ] PaperWMMacAdapters (AX, permissions, display, event tap)
- [ ] PaperWMRuntime (wiring, observers, command routing)
- [ ] PaperWMApp (menu bar, UI, onboarding)
- [ ] Docs only

## Tests Run

<!-- List the test targets you ran and their outcome. -->

- `swift test --filter <target>`: pass / fail / skipped
- Manual validation: see below

## Manual Validation

<!-- Required if this PR touches any macOS adapter, permission flow, display topology, AX interaction, or event tap. -->
<!-- Reference docs/MANUAL_VALIDATION_PLAN.md sections. -->

- [ ] Not required (pure logic / docs only)
- [ ] Accessibility permission behavior — verified / deferred: _reason_
- [ ] Input Monitoring behavior — verified / deferred: _reason_
- [ ] Display topology behavior — verified / deferred: _reason_
- [ ] AX window inventory — verified / deferred / not yet applicable
- [ ] Placement / resize — verified / deferred / not yet applicable
- [ ] Observers / reconciliation — verified / deferred / not yet applicable

## Risks / Caveats

<!-- Anything a reviewer should watch for: edge cases, known gaps, environment assumptions. -->

## Remaining Work

<!-- TODOs, stubs, or follow-up issues left intentionally. Link issues if they exist. -->
