# Paperframe Manual Test Guide

This guide covers all manual tests to validate Paperframe functionality.

## Prerequisites

- macOS 13.0+
- Xcode 15+ or Swift 5.9+
- Accessibility permissions (will be requested on launch)

---

## 1. Build and Launch

### 1.1 Build the App

```bash
cd /path/to/paperframe
swift build
```

**Expected:** Build completes without errors.

**If fails:** Check Swift version (`swift --version` should show 5.9+)

### 1.2 Launch the App

```bash
swift run PaperframeApp
```

**Expected:**
- App launches
- Menu bar icon appears (Paperframe status item)
- No crash or immediate exit

**If fails:** Check Console.app for error logs

---

## 2. Permissions

### 2.1 Accessibility Permission Request

**Steps:**
1. Launch Paperframe for the first time
2. Observe permission request dialog

**Expected:**
- macOS prompts for Accessibility permission
- App displays guidance if permission denied

### 2.2 Grant Accessibility

**Steps:**
1. Open System Settings → Privacy & Security → Accessibility
2. Enable Paperframe if not already enabled

**Expected:**
- Paperframe appears in the list
- Toggle shows enabled state
- App functions correctly after enabling

### 2.3 Test Without Permission

**Steps:**
1. Disable Paperframe in Accessibility settings
2. Try keyboard shortcuts

**Expected:**
- Shortcuts do not trigger window management
- App remains running (no crash)
- HUD may show "Permission required" or similar

---

## 3. Configuration

### 3.1 Config File Creation

**Steps:**
1. Launch Paperframe (fresh install)
2. Check `~/.config/paperframe/`

**Expected:**
- Directory `~/.config/paperframe/` exists
- If config didn't exist, defaults are used

### 3.2 Config File Loading

**Steps:**
1. Create/edit `~/.config/paperframe/config.json`
2. Change a shortcut (e.g., `showMinimap` to use different key)
3. Restart app

**Expected:**
- App loads custom config
- New shortcut works, old one doesn't

### 3.3 Invalid Config

**Steps:**
1. Create invalid JSON in config file
2. Launch app

**Expected:**
- App doesn't crash
- Falls back to built-in defaults
- Console shows warning about config load failure

---

## 4. Keyboard Shortcuts

### 4.1 Workspace Navigation

| Shortcut | Action | Test |
|----------|--------|------|
| `Ctrl+Opt+←` | Switch left | Press, verify workspace changes left |
| `Ctrl+Opt+→` | Switch right | Press, verify workspace changes right |
| `Ctrl+Opt+↑` | Switch up | Press, verify workspace changes up |
| `Ctrl+Opt+↓` | Switch down | Press, verify workspace changes down |

**Expected:**
- Each shortcut triggers workspace switch
- HUD shows current workspace name
- Transition is smooth (if animations enabled)

### 4.2 Direct Workspace Access

| Shortcut | Action | Test |
|----------|--------|------|
| `Ctrl+Opt+1` | Go to workspace 1 | Press, verify jump to workspace 1 |
| `Ctrl+Opt+2` | Go to workspace 2 | Press, verify jump to workspace 2 |
| `Ctrl+Opt+3-9` | Go to workspace 3-9 | Press each, verify jumps |

**Expected:**
- Direct navigation to numbered workspace
- HUD shows workspace name briefly

### 4.3 Workspace Management

| Shortcut | Action | Test |
|----------|--------|------|
| `Ctrl+Opt+n` | New workspace | Press, verify new workspace created |
| `Ctrl+Opt+r` | Rename workspace | Press, verify rename prompt/behavior |
| `Ctrl+Opt+Delete` | Remove workspace | Press, verify workspace removed |

**Expected:**
- New workspace appears with default name or sequential number
- Rename allows changing workspace name
- Remove deletes current workspace (windows move to adjacent)

### 4.4 Visual Features

| Shortcut | Action | Test |
|----------|--------|------|
| `Ctrl+Opt+m` | Show minimap | Press, verify minimap appears/disappears |
| `Ctrl+Opt+/` | Show switcher | Press, verify workspace switcher overlay |

**Expected:**
- Minimap shows overview of all windows
- Switcher shows workspace list with previews
- Press again or Escape to dismiss

### 4.5 Window Operations

| Shortcut | Action | Test |
|----------|--------|------|
| `Ctrl+Opt+h` | Hide window | Press with focused window, verify it hides |
| `Ctrl+Opt+f` | Toggle fullscreen | Press, verify window enters/exits fullscreen |
| `Ctrl+Opt+t` | Toggle float | Press, verify window enters/exits floating mode |

**Expected:**
- Hide: Window disappears from tiling
- Fullscreen: Window fills screen, other windows hidden
- Float: Window becomes floating (not tiled)

---

## 5. Visual Indicators

### 5.1 HUD (Heads-Up Display)

**Steps:**
1. Trigger any workspace switch (`Ctrl+Opt+→`)

**Expected:**
- HUD appears briefly (default 1.5s)
- Shows workspace name or action performed
- Fades out automatically
- Does not block interaction with windows

### 5.2 Mini-Map

**Steps:**
1. Press `Ctrl+Opt+m` to show minimap
2. Observe content
3. Press `Ctrl+Opt+m` or `Escape` to dismiss

**Expected:**
- Minimap shows all workspaces
- Shows window thumbnails or representations
- Keyboard shortcut hints visible
- Dismisses cleanly

### 5.3 Workspace Switcher

**Steps:**
1. Press `Ctrl+Opt+/` to show switcher
2. Use arrow keys or numbers to navigate
3. Press Enter to select
4. Press Escape to cancel

**Expected:**
- Switcher shows all workspace names
- Can navigate between workspaces
- Enter selects and switches
- Escape dismisses without switching

---

## 6. Window Management

### 6.1 Window Detection

**Steps:**
1. Open several apps (Safari, Terminal, Finder)
2. Observe windows in minimap

**Expected:**
- All visible windows appear
- Windows are associated with correct workspace
- New windows appear automatically

### 6.2 Window Movement

**Steps:**
1. Open two windows in same workspace
2. Use shortcuts to navigate

**Expected:**
- Windows remain in correct positions
- Focus follows active window

### 6.3 Application Exclusions

**Note:** This feature may not be implemented yet.

**Steps:**
1. Configure exclusions (if available)
2. Open excluded app
3. Verify it's not managed

---

## 7. Gestures

### 7.1 Three-Finger Swipe

**Prerequisite:** Trackpad required, gestures enabled in config

| Gesture | Default Action | Test |
|---------|----------------|------|
| Swipe left | Switch left | Swipe left, verify workspace changes |
| Swipe right | Switch right | Swipe right, verify workspace changes |
| Swipe up | Show switcher | Swipe up, verify switcher appears |
| Swipe down | Show minimap | Swipe down, verify minimap appears |

**Expected:**
- Gestures trigger configured actions
- Response is immediate
- No accidental triggers from normal scrolling

### 7.2 Disable Gestures

**Steps:**
1. Set `gestures.enabled: false` in config
2. Restart app
3. Try gestures

**Expected:**
- Gestures do not trigger
- Keyboard shortcuts still work

---

## 8. Persistence

### 8.1 Workspace State Persistence

**Steps:**
1. Create multiple workspaces
2. Rename some workspaces
3. Move windows between workspaces
4. Quit Paperframe (`Cmd+Q` from menu bar icon)
5. Relaunch Paperframe

**Expected:**
- Workspaces restored with same names
- Windows in same positions
- Active workspace remembered

### 8.2 Config Persistence

**Steps:**
1. Edit `~/.config/paperframe/config.json`
2. Change `hudDuration` to `3.0`
3. Restart app
4. Trigger HUD

**Expected:**
- HUD displays for 3 seconds (new duration)
- Config changes persist across restarts

---

## 9. Edge Cases

### 9.1 No Windows

**Steps:**
1. Close all managed windows
2. Navigate between workspaces

**Expected:**
- App doesn't crash
- Empty workspaces handled gracefully
- Can still create new workspaces

### 9.2 Single Workspace

**Steps:**
1. Ensure only one workspace exists
2. Try to remove it

**Expected:**
- Either blocked with message, or
- Handled gracefully (no crash)

### 9.3 Max Workspaces

**Steps:**
1. Create workspaces up to `maxWorkspaces` limit (default 10)
2. Try to create one more

**Expected:**
- Creation blocked with appropriate message
- No crash

### 9.4 Multi-Monitor (if supported)

**Steps:**
1. Connect external display
2. Open windows on both displays
3. Navigate workspaces

**Expected:**
- Workspaces per display or unified (depends on implementation)
- No crash
- Windows stay on correct display

### 9.5 App Relaunch

**Steps:**
1. Launch Paperframe
2. Force quit via Activity Monitor
3. Relaunch immediately

**Expected:**
- App handles gracefully
- State recovered or reset cleanly
- No duplicate processes

---

## 10. Performance

### 10.1 Many Windows

**Steps:**
1. Open 20+ windows across multiple apps
2. Navigate between workspaces
3. Show minimap

**Expected:**
- No noticeable lag
- Smooth transitions
- Minimap renders quickly

### 10.2 Rapid Navigation

**Steps:**
1. Hold `Ctrl+Opt+→` for rapid workspace switching

**Expected:**
- Each switch processes correctly
- No dropped inputs
- No memory leak (monitor in Activity Monitor)

---

## 11. Error Handling

### 11.1 Accessibility Revoked

**Steps:**
1. Disable Paperframe in Accessibility settings while running
2. Try window management shortcuts

**Expected:**
- App continues running
- Shortcuts fail gracefully
- Possible notification about permission loss

### 11.2 Corrupted Config

**Steps:**
1. Write invalid JSON to config file
2. Launch app

**Expected:**
- App starts with defaults
- Error logged
- No crash

---

## Test Results Template

```
## Test Run: [Date]

### Passed
- [ ] Build and launch
- [ ] Permissions
- [ ] Configuration
- [ ] Keyboard shortcuts
- [ ] Visual indicators
- [ ] Window management
- [ ] Gestures
- [ ] Persistence
- [ ] Edge cases
- [ ] Performance
- [ ] Error handling

### Issues Found
1. [Description]
2. [Description]

### Notes
[Any additional observations]
```