# Paperframe Developer Guide

## Overview

Paperframe is a macOS window manager built with Swift/AppKit using public Accessibility APIs. It implements a paper-space model where windows exist in a continuous logical space, projected onto real displays.

## Architecture

### Module Structure

```
Sources/
├── PaperframeCore/            # Pure data types and service protocols — no macOS framework imports
├── PaperframeMacAdapters/     # macOS adapter stubs (Cocoa/AppKit) — implements Core protocols
├── PaperframeRuntime/         # Domain service implementations using adapters
└── PaperframeApp/             # Menu-bar executable — wires runtime together
```

### Dependency Graph

```
PaperframeApp → PaperframeRuntime → PaperframeCore
           → PaperframeMacAdapters → PaperframeCore
```

**PaperframeCore** has no dependencies outside Foundation.

### Key Components

#### PaperframeCore (Core Types)

- `Identity.swift` - ManagedWindowID, DisplayID, WorkspaceID
- `SnapshotTypes.swift` - ManagedWindowSnapshot, AppDescriptor, WindowCapabilities
- `PaperSpaceTypes.swift` - PaperRect, PaperPoint, PaperWindowState, ViewportState
- `PlanningTypes.swift` - DisplayTopology, PlacementPlan, WMEvent, WMCommand, Direction
- `Protocols.swift` - All service protocol definitions

#### PaperframeMacAdapters (macOS Integration)

- `AXAdapter.swift` - Accessibility API window enumeration and control
- `DisplayAdapter.swift` - NSScreen topology and display management
- `WindowInventoryService.swift` - Window enumeration and capability probing

#### PaperframeRuntime (Domain Logic)

- `CommandRouter.swift` - Routes commands to appropriate handlers
- `WorkspaceSwitchCoordinator.swift` - Workspace switching orchestration
- `ObserverAndReconcileHub.swift` - Event observation and reconciliation
- `PlacementTransactionEngine.swift` - Window positioning and verification

#### PaperframeApp (Application)

- `AppDelegate.swift` - Menu bar app, status item, initialization
- `PaperframeConfig.swift` - Configuration loading and management
- `KeyboardShortcutHandler.swift` - Global keyboard event handling
- `VisualIndicatorController.swift` - HUD, minimap, workspace switcher

## Building

### Prerequisites

- macOS 13.0+
- Xcode 15+ or Swift 5.9+

### Build Commands

```bash
# Build
swift build

# Run tests
swift test

# Build release
swift build -c release
```

### Running

```bash
# Run the app
swift run PaperframeApp
```

## Configuration System

### JSON Schema

The config file is validated against `config/schema.json`. This provides:

- IDE auto-completion
- JSON validation
- Documentation of available options

### Config Models

Swift models are in `Sources/PaperframeApp/PaperframeConfig.swift`:

- `Config` - Root configuration
- `ShortcutsConfig` - Keyboard shortcut bindings
- `BehaviorConfig` - Runtime behavior settings
- `GesturesConfig` - Trackpad gesture mappings
- `WorkspacesConfig` - Workspace limits and defaults
- `KeyBinding` - Individual key binding
- Enums: `Key`, `KeyModifier`, `ModifierMode`, `LayoutMode`, `GestureAction`

### Loading Priority

1. `~/.config/paperframe/config.json` (user config)
2. Built-in defaults (hardcoded in Swift)

## Development Workflow

### Adding a New Feature

1. Define protocols in PaperframeCore if new service required
2. Implement in appropriate adapter/runtime module
3. Wire up in PaperframeApp
4. Add tests
5. Add config options if user-configurable

### Code Style

- Small PRs focused on one subsystem
- Explicit module boundaries
- Prefer protocols over concrete implementations
- Document public APIs

### Testing

See `docs/TEST_STRATEGY.md` for testing approaches.

## Existing Documentation

- `REPO_BOOTSTRAP.md` - Initial project setup
- `IMPLEMENTATION_PLAN.md` - Feature implementation tracking
- `MANUAL_VALIDATION_PLAN.md` - User validation checklist
- `TEST_STRATEGY.md` - Testing approach
- `REVIEW_CHECKLIST.md` - Code review criteria
- `CONTROL_BEHAVIOR_PROPOSAL.md` - Control scheme design

## Troubleshooting Development

### Build Errors

```bash
# Clean and rebuild
swift package clean
swift build
```

### Running Tests

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter PaperframeRuntimeTests
```

### Debug Logging

Add debug output by importing PaperframeCore and using `print()` statements. The app runs in the menu bar so check Console.app for output.

## Permissions

The app requires Accessibility permissions. During development, you may need to:

1. System Settings → Privacy & Security → Accessibility
2. Add your development build or disable/enable to refresh

## Related

- [User Guide](../user/README.md)
- [JSON Schema](../../config/schema.json)
- [Default Config](../../config/default.json)