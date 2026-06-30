# Mulen Nano macOS

This repository contains a native macOS SwiftUI application. Treat it as macOS software, not as an iOS port or a web dashboard embedded in a window.

## Skill Routing

- For SwiftUI implementation, state, concurrency, performance, accessibility, and API correctness, use `$swiftui-expert-skill` first.
- Before changing macOS interaction patterns, windows, inspectors, menus, file pickers, drag and drop, clipboard, or AppKit integration, use `$macos-patterns`.
- For visual and interaction design work, use `$macos-design` as the primary design skill and preserve the app's established compact visual language.
- For broader architecture, packaging, performance, or release work, use `$fireworks-macapp-creator` when relevant.
- Use `$macos-settings-ui` specifically for Settings screens.
- Use `$swiftui-glass-ui-designer` only when the task explicitly asks for glass or Liquid Glass treatment. Do not apply glass globally by default.
- Use `$macos-app-design` as a secondary native-macOS guardrail when a custom control or layout departs from standard Mac behavior.
- Do not invoke every design skill for one task. Choose the smallest relevant set and resolve conflicts in favor of the user's explicit reference and the existing app design.

## Working Rules

- Critically evaluate proposals instead of automatically agreeing with them.
- Preserve business logic and unrelated screens during visual changes.
- Prefer compact native macOS proportions and system behavior unless an explicit reference requires a custom implementation.
- Use only Codex's integrated browser for browser-based work. Do not open Chrome or another external browser without permission.
