# Paperframe — Manual Validation Plan

Run this checklist on a real Mac before merging any PR that touches permissions, display topology, AX adapters, event taps, or observer/reconciliation logic.

---

## 1. Accessibility Permission Behavior

**What to verify:**
- [ ] App launches without crashing when Accessibility is not granted.
- [ ] `PermissionsService` returns `.notDetermined` or `.denied` (never `.granted`) when the app is not trusted in System Settings → Privacy & Security → Accessibility.
- [ ] Onboarding or diagnostics UI surfaces the missing-permission state clearly.
- [ ] After granting Accessibility, the permission state updates without requiring an app relaunch (or a relaunch prompt is shown if required).
- [ ] After revoking Accessibility, the app degrades gracefully (no crash, no stale assumptions).

**Blocks merge:**
- App crashes on launch without Accessibility.
- `PermissionsService` reports `.granted` when Accessibility is not trusted.
- No user-visible feedback when Accessibility is missing and an AX operation is attempted.

**Can be deferred:**
- Animated or polished onboarding UI.
- Automatic re-request flow after revocation.

---

## 2. Input Monitoring Behavior

**What to verify:**
- [ ] App launches without crashing when Input Monitoring is not granted.
- [ ] `PermissionsService` returns `.notDetermined` or `.denied` for Input Monitoring when not listed in System Settings → Privacy & Security → Input Monitoring.
- [ ] Global hotkeys are silently disabled (not crashed) when Input Monitoring is absent.
- [ ] Menu bar fallback commands still function without Input Monitoring.

**Blocks merge:**
- App crashes without Input Monitoring.
- Global hotkeys silently activate without the permission (security regression).
- Menu bar commands stop working when Input Monitoring is absent.

**Can be deferred:**
- Explicit per-hotkey degradation messaging in the UI.

---

## 3. Display Topology Behavior

**What to verify:**
- [ ] `DisplayAdapter` returns at least one `DisplaySnapshot` on a single-display Mac.
- [ ] Connecting or disconnecting an external display triggers an updated topology (check via diagnostics panel or log).
- [ ] Display geometry (frame, scale factor) is captured correctly for each connected screen.
- [ ] No crash or hang when display count changes at runtime.

**Blocks merge:**
- Crash or empty topology on a standard single-display Mac.
- Topology not updated after display connect/disconnect.

**Can be deferred:**
- Precise per-display scale-factor handling edge cases.
- Multi-display arrangement ordering.

---

## 4. AX Window Inventory (Placeholder)

> Validate after Phase 2 (Live Inventory) is implemented.

**What to verify (future):**
- [ ] `WindowInventoryService` enumerates windows for frontmost app.
- [ ] `WindowCapabilities` correctly reflects move/resize/minimize support per window.
- [ ] Ineligible windows (panels, sheets, HUDs) are filtered out.
- [ ] Window snapshot is refreshed after app focus change.

**Blocks merge (future):**
- Managed window list includes system panels or desktop elements.
- Capability probing crashes on windows with partial AX support.

---

## 5. Placement / Resize Behavior (Placeholder)

> Validate after Phase 3 (Transactional Control) is implemented.

**What to verify (future):**
- [ ] Move command updates window position via AX write.
- [ ] Resize command updates window size within display bounds.
- [ ] Verification step detects and reports drift.
- [ ] Resistant windows (e.g., apps that ignore AX size writes) enter a reduced mode rather than retrying indefinitely.
- [ ] Transaction result is visible in the diagnostics inspector.

**Blocks merge (future):**
- Infinite retry loop on a resistant window.
- No verification step after AX write.

---

## 6. Observers / Reconciliation (Placeholder)

> Validate after Phase 4 (Event-Driven Runtime) is implemented.

**What to verify (future):**
- [ ] AX observer fires on window move/resize/close.
- [ ] App launch/quit triggers inventory refresh.
- [ ] Space change triggers reconciliation pass.
- [ ] Display change triggers projection replan.
- [ ] No stale observers leak after an app quits.

**Blocks merge (future):**
- Observer registration crash on app launch.
- Inventory not updated after window close.
