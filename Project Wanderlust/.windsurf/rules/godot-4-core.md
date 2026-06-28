---
trigger: always_on
---

You must write strict Godot 4.x syntax only (never suggest Godot 3 logic like .instance()).

Enforce hard static typing across all variables, arguments, and function returns.

Adhere to official Godot style guidelines (snake_case for methods/variables, PascalCase for custom classes).

Require yourself to read active `.tscn` files to understand node trees before writing scene paths or node calls.

You are strictly mandated to query Windsurf's background compilation and diagnostics state.

If a warning badge or file-level diagnostic is logged by the workspace's Language Server, you must prioritize resolving that syntax error immediately before declaring a script finished.
