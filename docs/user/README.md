# PaperWM User Guide

PaperWM is a macOS window manager that provides a paper-space tiling experience. Windows are arranged in a continuous horizontal or vertical canvas, allowing you to scroll through workspaces infinitely.

## Quick Start

### Installation

1. Clone the repository
2. Build the app: `swift build`
3. Run the app bundle from `.build/debug/PaperWM.app`
4. Grant Accessibility permissions when prompted (System Settings → Privacy & Security → Accessibility)

### First-Time Setup

On first launch, PaperWM will:
- Request Accessibility permissions (required for window management)
- Create a default configuration at `~/.config/paperframe/config.json`
- Display a brief onboarding HUD

## Configuration

Configuration is stored at `~/.config/paperframe/config.json`.

### Config File Structure

```json
{
  "$schema": "./schema.json",
  "version": "1.0.0",
  "shortcuts": { ... },
  "behavior": { ... },
  "gestures": { ... },
  "workspaces": { ... }
}
```

### Default Configuration

The default config file is at `config/default.json` in the repository. Copy it to `~/.config/paperframe/config.json` to customize.

### Configuration Options

#### Shortcuts

| Setting | Default | Description |
|---------|---------|-------------|
| `modifier` | `ctrlOption` | Modifier key mode: `ctrlOption`, `option`, or `meh` |
| `switchWorkspaceLeft` | `ctrlOption + leftArrow` | Navigate to workspace on the left |
| `switchWorkspaceRight` | `ctrlOption + rightArrow` | Navigate to workspace on the right |
| `switchWorkspaceUp` | `ctrlOption + upArrow` | Navigate to workspace above |
| `switchWorkspaceDown` | `ctrlOption + downArrow` | Navigate to workspace below |
| `goToWorkspace1-9` | `ctrlOption + 1-9` | Jump directly to workspace 1-9 |
| `newWorkspace` | `ctrlOption + n` | Create new workspace |
| `renameWorkspace` | `ctrlOption + r` | Rename current workspace |
| `removeWorkspace` | `ctrlOption + delete` | Remove current workspace |
| `showMinimap` | `ctrlOption + m` | Toggle mini-map view |
| `showSwitcher` | `ctrlOption + /` | Show workspace switcher overlay |
| `hideWindow` | `ctrlOption + h` | Hide current window |
| `toggleFullscreen` | `ctrlOption + f` | Toggle fullscreen |
| `toggleFloat` | `ctrlOption + t` | Toggle floating |

#### Behavior

| Setting | Default | Description |
|---------|---------|-------------|
| `autoCreateWorkspace` | `false` | Auto-create workspace when window moved to non-existent |
| `animateTransitions` | `true` | Animate workspace transitions |
| `showHUD` | `true` | Show HUD notifications for actions |
| `hudDuration` | `1.5` | HUD display duration (seconds) |
| `persistWorkspaceState` | `true` | Save/restore workspace state across launches |
| `defaultLayout` | `horizontal` | Default tiling: `horizontal`, `vertical`, `grid`, `full` |

#### Gestures

| Setting | Default | Description |
|---------|---------|-------------|
| `enabled` | `true` | Enable trackpad gestures |
| `threeFingerSwipeLeft` | `switchLeft` | Three-finger swipe left action |
| `threeFingerSwipeRight` | `switchRight` | Three-finger swipe right action |
| `threeFingerSwipeUp` | `showSwitcher` | Three-finger swipe up action |
| `threeFingerSwipeDown` | `minimap` | Three-finger swipe down action |

Gesture actions: `switchLeft`, `switchRight`, `showSwitcher`, `minimap`, `none`

#### Workspaces

| Setting | Default | Description |
|---------|---------|-------------|
| `maxWorkspaces` | `10` | Maximum workspaces per display (1-20) |
| `defaultLabels` | `["Main", "Work", "Chat", "Code", "Mail"]` | Default workspace names |

## Keyboard Shortcuts

PaperWM uses `Ctrl + Option` (⌃⌥) as the default modifier to avoid conflicts with native macOS shortcuts.

### Navigation

| Action | Shortcut |
|--------|----------|
| Switch left | `⌃⌥ + ←` |
| Switch right | `⌃⌥ + →` |
| Switch up | `⌃⌥ + ↑` |
| Switch down | `⌃⌥ + ↓` |
| Go to workspace 1-9 | `⌃⌥ + 1-9` |

### Workspace Management

| Action | Shortcut |
|--------|----------|
| New workspace | `⌃⌥ + n` |
| Rename workspace | `⌃⌥ + r` |
| Remove workspace | `⌃⌥ + ⌫` |

### Visual Features

| Action | Shortcut |
|--------|----------|
| Show mini-map | `⌃⌥ + m` |
| Show switcher | `⌃⌥ + /` |

### Window Operations

| Action | Shortcut |
|--------|----------|
| Hide window | `⌃⌥ + h` |
| Toggle fullscreen | `⌃⌥ + f` |
| Toggle float | `⌃⌥ + t` |

## Features

### Visual Indicators

- **HUD**: Brief overlay showing current action (workspace switch, rename, etc.)
- **Mini-map**: Overview of all windows across workspaces
- **Workspace Switcher**: Visual overlay for workspace navigation

### Gestures

Three-finger swipe gestures can be configured to:
- Switch workspaces left/right
- Show the workspace switcher
- Show the mini-map

### Persistence

Workspace state (window positions, active workspace) is automatically saved and restored on app launch.

## Troubleshooting

### Accessibility Permissions Not Granted

If windows aren't being managed:
1. Open System Settings → Privacy & Security → Accessibility
2. Enable PaperWM in the list
3. Restart PaperWM

### Config Not Loading

Check that your config file is valid JSON. You can validate it against the schema:

```bash
# Validate config syntax
cat ~/.config/paperframe/config.json | python3 -m json.tool > /dev/null && echo "Valid JSON"
```

## Removing PaperWM

1. Quit the app
2. Remove `~/.config/paperframe/` directory (optional, removes custom config)
3. Remove from Login Items (optional)