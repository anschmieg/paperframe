# Paperframe

A public-API macOS paper-style window manager built with Swift/AppKit and Accessibility APIs.

## Project goals

- Build a robust macOS window controller using public APIs only
- Use a paper-space model internally
- Treat live macOS window snapshots as runtime truth
- Project logical placements onto real displays
- Degrade gracefully when permissions or app-specific API limitations prevent full control

## Architectural stance

- Swift-native core
- AppKit-first
- Accessibility-driven window control
- Observer-driven synchronization with reconciliation
- Native macOS Spaces are observed, not managed
- No private APIs, scripting additions, or SIP-dependent behavior in v1

## Near-term milestones

1. Create package/module structure
2. Add core protocols and data types
3. Add compileable stubs
4. Add diagnostics shell
5. Implement PermissionsService
6. Implement DisplayTopology snapshotting
7. Implement WindowInventoryService

## Repo conventions

- Small PRs
- One subsystem per issue
- Explicit module boundaries
- Prefer TODOs over speculative implementations
- Tests for completed behavior
