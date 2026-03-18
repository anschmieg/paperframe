# PaperWM Control Behavior Proposal

## Overview

This document proposes an intuitive control scheme for PaperWM that combines modifier-based keyboard shortcuts with mouse/touchpad gestures for window navigation and workspace management.

## Design Principles

1. **Zero conflicts** - Never override or conflict with native macOS shortcuts
2. **Visual feedback** - Always show what's happening (HUD, indicators)
3. **Discoverability** - Menu shows shortcuts; visual hints during gestures
4. **Non-intrusive** - Doesn't fight with app behavior

---

## Modifier Key Strategy

### Problem with Option

`Option + click/drag` has native macOS behavior (Option+drag = copy files). This conflicts.

### Solution: Use two-key modifier or function keys

**Option A: `Ctrl + Option` (recommended)**

- Not used by any native macOS app
- Can be bound to single key using Karabiner-Elements
- Safe namespace for all PaperWM shortcuts

**Option B: Function keys (F13-F19)**

- Unused on most Macs
- Require no modifier
- Easy to remember

**Option C: Meh (Ctrl+Option+Shift) + key**

- Even more unused than Ctrl+Option
- Good for Power users with Karabiner

**Option D: Menu bar prefix (hybrid)**

- Click and hold menu bar icon → Shows action HUD
- Press key while holding for action
- Most discoverable

For this proposal, we'll use **Ctrl+Option** as primary, with **Meh + key** as alternative.

---

## Visual Indicators

### 1. Workspace Indicator (Always Visible)

**Location:** Menu bar icon area

**Format:** `⬜ 1/3` or `⬜ Work:2`

- Current workspace index / total
- Custom name when set

### 2. Action HUD (Transient)

**Shows:** When action is triggered

```
┌─────────────────────────────────┐
│  ← Switched to Workspace 2     │
│  "Development"                  │
└─────────────────────────────────┘
```
- Appears for 1.5 seconds
- Bottom-center of screen
- Semi-transparent background

### 3. Workspace Switcher Overlay

**Trigger:** `Ctrl + Option + /` or 3-finger swipe up

**Shows:** Grid of all workspaces
```
┌─────────┬─────────┬─────────┐
│ WS 1    │ WS 2 ● │ WS 3   │
│ ─────── │ ───────│ ───────│
│ [win]   │ [win]  │        │
│ [win]   │        │        │
│ [win]   │        │        │
└─────────┴─────────┴─────────┘
     ↑ Current (highlighted)
```

### 4. Mini-Map (The Radar View)

**Trigger:** Hold `Ctrl + Option` (no other key)

**Shows:** Overview of all virtual paper space
```
┌──────────────────────────────────────────────────────────┐
│                    Paper Space (virtual)                  │
│                                                          │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                  │
│  │ WS 1    │  │ WS 2    │  │ WS 3    │                  │
│  │ ████    │  │ ██      │  │ ██      │                  │
│  │ ████    │  │ ██      │  │         │                  │
│  │ ─────── │  │ ─────── │  │ ─────── │                  │
│  │ viewport│→ │         │  │         │                  │
│  └─────────┘  └─────────┘  └─────────┘                  │
│                                                          │
│  ←────────────  Current View ───────────→               │
└──────────────────────────────────────────────────────────┘
```

**Features:**
- Shows ALL workspaces as a grid
- Current viewport highlighted with border
- Windows shown as rectangles
- Draggable viewport indicator

### 5. Placement Verification Toast

**Shows:** When window placement is resisted

```
┌─────────────────────────────────┐
│  ⚠ Window resisted: Terminal   │
│  Position changed externally   │
└─────────────────────────────────┘
```

---

## Keyboard Shortcuts

### Using Menu Bar Prefix (Recommended)

**Pattern:** Hold menu bar → press key → release

| Key | Action | Visual |
|-----|--------|--------|
| `←` | Switch left | HUD |
| `→` | Switch right | HUD |
| `↑` | Switch up | HUD |
| `↓` | Switch down | HUD |
| `1-9` | Switch to workspace N | HUD |
| `N` | New workspace | Dialog |
| `R` | Rename workspace | Dialog |
| `Delete` | Remove workspace | Confirm |
| `T` | Switcher overlay | Overlay |
| `M` | Mini-map (hold) | Radar |
| `Esc` | Cancel | - |

### Alternative: Direct Shortcuts (Ctrl + Option)

| Shortcut | Action |
|----------|--------|
| `Ctrl+Option+←` | Switch left |
| `Ctrl+Option+→` | Switch right |
| `Ctrl+Option+↑` | Switch up |
| `Ctrl+Option+↓` | Switch down |
| `Ctrl+Option+1-9` | Switch to workspace N |
| `Ctrl+Option+Shift+←` | Move window left |
| `Ctrl+Option+Shift+→` | Move window right |
| `Ctrl+Option+N` | New workspace |
| `Ctrl+Option+R` | Rename workspace |
| `Ctrl+Option+Delete` | Remove workspace |

---

## Mouse / Touchpad Gestures

### Trackpad Gestures

| Gesture | Action | Visual |
|---------|--------|--------|
| 3-finger swipe left/right | Switch workspace | HUD |
| 3-finger swipe up | Workspace switcher | Overlay |
| 3-finger swipe down | Mini-map | Radar |
| Option + 3-finger drag | Move window | Snap preview |

### Click Actions

| Click | Action | Visual |
|-------|--------|--------|
| Click menu bar | Show mini-map | Radar |
| Hold menu bar | Show action HUD | HUD |
| Double-click workspace in overlay | Switch to workspace | - |

---

## Mini-Map (Radar) Details

### Layout
```
┌─────────────────────────────────────────┐
│ ◉ Mini-Map                          ✕ │
├─────────────────────────────────────────┤
│                                         │
│   ┌──────┐   ┌──────┐   ┌──────┐       │
│   │  1 ● │   │  2   │   │  3   │       │
│   │ ████ │   │ ██   │   │      │       │
│   │ ████ │   │      │   │      │       │
│   └──────┘   └──────┘   └──────┘       │
│    ↑                                  │
│    viewport                           │
│                                         │
│ Current: Development (2/3)             │
│ ───────────────────────────────────── │
│ [← Prev]  [Switch]  [Next →]          │
└─────────────────────────────────────────┘
```

### Interactions
- **Click workspace**: Switch to it
- **Drag viewport**: Pan the view
- **Scroll wheel**: Zoom in/out
- **Arrow keys**: Navigate workspaces

---

## Behavior Details

### Workspace Switching

1. User triggers switch (key/gesture/menu)
2. HUD shows "Switching to..."
3. Windows animate to new positions
4. HUD confirms "Now on Workspace X"
5. Menu bar updates indicator

### Window Movement

1. User triggers move (Shift+direction or drag)
2. Target workspace highlighted
3. Window visually moves to target
4. Target workspace becomes active

### Tiling Behavior

- Windows tile horizontally by default
- Manual resize "snaps" to grid
- Visual guides show snap points

---

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| No workspace in direction | HUD: "No workspace in that direction" |
| Move to single workspace | Reject: "Cannot move, only one workspace" |
| Last workspace deletion | Reject: "Cannot delete last workspace" |
| Window resists placement | Toast: "Window placement resisted" |
| Fullscreen app | Skip in tiling, show icon in mini-map |

---

## Implementation Priority

### Phase 1: Visual Indicators
1. Workspace indicator in menu bar
2. Action HUD (simple text)
3. Connection to existing actions

### Phase 2: Mini-Map
1. Basic radar view
2. Workspace switching via click
3. Current viewport highlight

### Phase 3: Keyboard Shortcuts
1. Ctrl+Option+arrows
2. Menu bar prefix mode

### Phase 4: Gestures
1. Trackpad 3-finger swipe
2. Drag to move windows

---

## Component Architecture

```
┌──────────────────────────────────────────────┐
│                 AppDelegate                   │
├──────────────────────────────────────────────┤
│  VisualIndicatorController                   │
│  ├── WorkspaceIndicator (menu bar)          │
│  ├── ActionHUD (floating window)             │
│  ├── WorkspaceSwitcher (overlay)            │
│  └── MiniMapWindow (borderless panel)        │
├──────────────────────────────────────────────┤
│  InputHandler                                 │
│  ├── KeyboardShortcutHandler                │
│  ├── GestureRecognizer                       │
│  └── MenuBarPrefixHandler                    │
└──────────────────────────────────────────────┘
```

---

## Comparison to Other Window Managers

| Feature | Rectangle | Amethyst | yabai | PaperWM (proposed) |
|---------|-----------|----------|-------|---------------------|
| No conflicts | Good | Good | Good | Best (prefix) |
| Visual indicators | Some | None | None | Full HUD |
| Mini-map | No | No | No | Yes (radar) |
| Menu prefix | No | No | No | Yes |

PaperWM's advantage: visual-first design, mini-map, zero conflicts

---

## Open Questions

1. **Should mini-map show all displays or single?**
   - Proposal: Show virtual paper space across all displays

2. **How long should HUD persist?**
   - Proposal: 1.5 seconds, adjustable

3. **Should mini-map be toggle or hold?**
   - Proposal: Hold for radar, toggle for switcher

4. **Default modifier if not using prefix?**
   - Proposal: Ctrl+Option (document as requiring Karabiner for single-key)