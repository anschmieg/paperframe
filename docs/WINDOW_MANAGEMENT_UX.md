# Paperframe Window Management UX Concept

## Overview

Paperframe is a **paper-style window manager** where windows exist in a continuous scrollable canvas rather than discrete spaces. This document outlines the intended user experience and implementation plan.

## Core Metaphor: Infinite Paper Canvas

Imagine your displays as a viewport looking at an infinite canvas of windows. You can:
- **Scroll** through windows horizontally (primary) or vertically
- **Zoom** to see an overview (minimap)
- **Jump** to specific workspaces
- **Arrange** windows on the canvas

```
                    ┌─────────────────────────────┐
                    │      Display Viewport       │
                    │  ┌─────┐ ┌─────┐ ┌─────┐   │
                    │  │ W1  │ │ W2  │ │ W3  │   │  ← Visible windows
                    │  └─────┘ └─────┘ └─────┘   │
                    └─────────────────────────────┘

← ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ →
    W1      W2      W3      W4      W5      W6      (Infinite canvas)
```

## Window Management Operations

### Current State

| Category | Implemented | Planned |
|----------|-------------|---------|
| Workspace Navigation | ✅ Switch left/right/up/down | |
| Workspace Management | ✅ Create/Rename/Remove | |
| Visual Feedback | ✅ HUD/Minimap/Switcher | |
| **Window Movement** | ❌ Not implemented | Move window between workspaces |
| **Window Sizing** | ❌ Not implemented | Resize within tiling |
| **Window Focus** | ❌ Not implemented | Focus specific window |
| **Window Float** | ❌ Not implemented | Toggle floating |
| **Window Hide/Close** | ❌ Not implemented | Hide/Minimize |

### Proposed Window Shortcuts

**Window Movement** (move focused window to adjacent workspace):

| Shortcut | Action |
|----------|--------|
| `Ctrl+Opt+Shift+←` | Move window to workspace left |
| `Ctrl+Opt+Shift+→` | Move window to workspace right |
| `Ctrl+Opt+Shift+↑` | Move window to workspace up |
| `Ctrl+Opt+Shift+↓` | Move window to workspace down |

**Window Focus** (cycle through windows in current workspace):

| Shortcut | Action |
|----------|--------|
| `Ctrl+Opt+Tab` | Focus next window |
| `Ctrl+Opt+Shift+Tab` | Focus previous window |

**Window Sizing** (adjust focused window):

| Shortcut | Action |
|----------|--------|
| `Ctrl+Opt+Shift+H` | Shrink window horizontally |
| `Ctrl+Opt+Shift+L` | Expand window horizontally |
| `Ctrl+Opt+Shift+J` | Shrink window vertically |
| `Ctrl+Opt+Shift+K` | Expand window vertically |

**Window State**:

| Shortcut | Action |
|----------|--------|
| `Ctrl+Opt+F` | Toggle fullscreen (already defined) |
| `Ctrl+Opt+T` | Toggle floating (already defined) |
| `Ctrl+Opt+H` | Hide window (already defined) |
| `Ctrl+Opt+W` | Close window |

### Tiling Behavior

Paperframe uses **horizontal paper tiling** as the primary layout:

1. **Primary axis (horizontal)**: Windows tile left-to-right
2. **Secondary axis (vertical)**: Windows can stack in columns
3. **Focus-follows-mouse**: Optional, configurable

```
Workspace View:
┌────────┬────────┬────────┐
│   W1   │   W2   │   W3   │  ← Horizontal primary
│        │        │        │
│        ├────────┤        │
│        │   W4   │        │  ← W2 stacked with W4
└────────┴────────┴────────┘
```

### Floating Windows

Floating windows:
- Are not tiled
- Can be positioned freely
- Appear above tiled windows
- Can be toggled back to tiled

Use cases:
- Temporary dialogs
- Reference windows (calculator, notes)
- Picture-in-picture video

## Mouse Interaction

### Current (Not Implemented)

| Gesture | Action |
|---------|--------|
| `⌘ + Drag` | Move window (native macOS) |
| `⌘ + Scroll` | Scroll workspace |

### Proposed: Window Drag Between Workspaces

1. **Drag to edge**: Hold window at screen edge → workspace switches
2. **Drag to minimap**: Drag window onto minimap workspace → moves to that workspace
3. **Drag to switcher**: During workspace switcher, drop window on workspace → moves

## Implementation Plan

### Phase 1: Window Focus and Movement

**Goal**: Enable moving windows between workspaces

1. **Add `focusedWindowID` to WorldState**
   - Track which window has keyboard focus
   - Update on window focus events

2. **Implement `moveWindow` command**
   - `Command.moveWindow(windowID:to workspaceID)`
   - Remove from current workspace, add to target

3. **Add keyboard shortcuts**
   - `Ctrl+Opt+Shift+Arrow` for move-window-to-workspace
   - Wire through CommandRouter

4. **Update visual indicators**
   - Show source/destination in HUD
   - Animate window movement

### Phase 2: Window Sizing

**Goal**: Allow resizing windows within tiling

1. **Add `windowSize` to window state**
   - Relative size (ratio) or absolute (points)
   - Persist with workspace state

2. **Implement `resizeWindow` command**
   - `Command.resizeWindow(windowID:direction:delta)`
   - Update tiling layout

3. **Add keyboard shortcuts**
   - `Ctrl+Opt+Shift+H/J/K/L` for sizing

4. **Update tiling algorithm**
   - Recalculate layout on resize
   - Maintain proportions

### Phase 3: Floating Windows

**Goal**: Toggle windows between tiled and floating

1. **Add `windowMode` to window state**
   - `.tiled` (default)
   - `.floating`

2. **Implement `toggleFloat` command**
   - Remove from tiling → floating
   - Floating → tiling → add to layout

3. **Handle floating windows**
   - Track position/size separately
   - Render above tiled windows
   - Not affected by workspace scroll

4. **Update visual indicators**
   - Different border/style for floating

### Phase 4: Mouse Gestures

**Goal**: Drag windows between workspaces

1. **Track window drag events**
   - Detect ⌘+drag start
   - Track window position

2. **Edge detection**
   - When window at edge for N seconds
   - Trigger workspace switch

3. **Minimap drop target**
   - When minimap open during drag
   - Highlight drop zones

## Configuration

Add to `config.json`:

```json
{
  "shortcuts": {
    "moveWindowLeft": { "key": "leftArrow", "modifiers": ["ctrl", "option", "shift"] },
    "moveWindowRight": { "key": "rightArrow", "modifiers": ["ctrl", "option", "shift"] },
    "focusNextWindow": { "key": "tab", "modifiers": ["ctrl", "option"] },
    "focusPrevWindow": { "key": "tab", "modifiers": ["ctrl", "option", "shift"] },
    "shrinkWindowH": { "key": "h", "modifiers": ["ctrl", "option", "shift"] },
    "expandWindowH": { "key": "l", "modifiers": ["ctrl", "option", "shift"] },
    "shrinkWindowV": { "key": "j", "modifiers": ["ctrl", "option", "shift"] },
    "expandWindowV": { "key": "k", "modifiers": ["ctrl", "option", "shift"] },
    "closeWindow": { "key": "w", "modifiers": ["ctrl", "option"] }
  },
  "behavior": {
    "focusFollowsMouse": false,
    "dragEdgeDelay": 0.5
  }
}
```

## Success Criteria

1. **Discoverable**: Users can figure out window management from HUD hints
2. **Efficient**: Common operations take ≤2 keystrokes
3. **Predictable**: Windows go where expected
4. **Reversible**: All actions have an undo path
5. **Safe**: Cannot lose windows or crash the app

## Next Steps

1. Implement window focus tracking in WorldState
2. Add `moveWindow` command to CommandRouter
3. Wire up `Ctrl+Opt+Shift+Arrow` shortcuts
4. Update config schema and PaperframeConfig
5. Add HUD feedback for window movement