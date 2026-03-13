# AGENTS.md

## Project context

This repository is building a public-API macOS paper-style window manager.

The implementation must follow `docs/IMPLEMENTATION_PLAN.md`.

The architecture is intentionally Swift-native and AppKit-first.

## Core architectural rules

- Treat live macOS window snapshots as runtime truth.
- Treat paper-space as intent and organization, not as a literal OS-level desktop.
- Use public APIs only for v1.
- Native macOS Spaces are observed, not managed.
- All window mutations must be transactional: read, compute delta, write, verify.
- Capability probing is required before assuming a window supports any operation.
- Diagnostics are a first-class feature.

## Scope rules

- Do not broaden issue scope.
- Do not implement unrelated features.
- Prefer compileable stubs and TODOs over broad speculative code.
- Keep module boundaries clean.
- Keep PRs small and reviewable.

## Stack rules

- Language: Swift
- UI shell: AppKit first, SwiftUI only when clearly justified
- Package management: Swift Package Manager
- Testing: XCTest
- Avoid introducing Rust, Bevy, Electron, Tauri, or private macOS APIs

## Output rules for coding tasks

When implementing a task:
- complete only the requested subsystem
- add tests for implemented behavior where practical
- document remaining work explicitly
- avoid unrelated refactors
- leave the repository in a good continuation state

## If blocked

If a dependency on unavailable macOS runtime behavior or unsupported APIs is discovered:
- do not fake a complete implementation
- leave a stub with a clear explanation
- add a concise TODO or follow-up note
- preserve the architecture
