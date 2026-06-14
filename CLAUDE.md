# CLAUDE.md

## Godot engine

The Godot editor/runtime (v4.6.3-stable) lives one level up from this project.
Paths below are relative to the project root; use the binary matching the
machine's architecture (the other set won't be present):

- x86-64: `../Godot_v4.6.3-stable_win64.exe` (editor/GUI), `../Godot_v4.6.3-stable_win64_console.exe` (console)
- arm64: `../Godot_v4.6.3-stable_windows_arm64.exe` (editor/GUI), `../Godot_v4.6.3-stable_windows_arm64_console.exe` (console)

Use the console binary for headless `--headless` parse checks and CLI output. It
is not on `PATH`, so invoke it by relative path.

## Documentation

The official Godot documentation is available locally in `docs/godot` (a git submodule of [godot-docs](https://github.com/godotengine/godot-docs), `stable` branch). Consult it for engine API, node, and feature reference instead of relying on memory or the web.
