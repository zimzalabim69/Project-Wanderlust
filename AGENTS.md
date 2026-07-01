# Project-Wanderlust — Project Reference

## Stack
- Godot 4.6 (Forward Plus renderer), GDScript (strict typing)
- Terrain3D v1.0.2 (C++ GDExtension) for terrain
- Agent Tools MCP addon (TCP 127.0.0.1:9920 / 9090) — AI/agent bridge
- Save format: JSON (`user://savegame.json`)
- Viewport: 640×480 stretched → 1920×1080 window

## Architecture
PS1-style low-poly 3D "cozy horror / liminal" game set in a snowy 1990s
Colorado mountain town (Golden). Main scene: `scenes/ui/title_screen.tscn`.

Key directories:
- `core/autoload/` — singleton autoloads (GameState, SpawnManager,
  SceneTransition, AudioManager, InventoryManager, SaveManager, DevMode,
  LevelEditor, McpInteractionServer). Registered in `project.godot [autoload]`.
- `scenes/` — game scenes: `main_floor.tscn`, `basement.tscn`, `town.tscn`,
  `player.tscn`, plus subfolders `collectibles/`, `props/`, `structures/`,
  `templates/`, `terrain/`, `tools/`, `ui/` (title_screen, pause_menu).
- `ui/` — reusable UI panels (inventory_panel, dev_console, dev_overlay,
  editor_panel, locked_door_message).
- `addons/` — `agent_tools` (MCP bridge + headless driver + tool modules) and
  `terrain_3d` (Terrain3D GDExtension, committed under `addons/terrain_3d/bin`).
- `assets/` — audio (bus layout: Master/SFX/Music/Ambience), models, textures.
- `resources/` — shared resource files.
- `demo/` — demo/prototype scenes.

`CONTEXT.md` is the living architecture/aesthetic document — read it first.

## Verification Commands
Open/run in the Godot 4.6 editor. No Makefile or CLI test suite is present.
The `agent_tools` addon exposes a `test_tools.gd` module and a headless driver
(`addons/agent_tools/headless/driver.gd`) for automated/agent-driven testing
over the MCP TCP bridge.

## Conventions
- GDScript with strict typing
- Autoload singletons for cross-scene state (see `project.godot [autoload]`)
- `.uid` files are Godot resource UID files (gitignored in principle but some
  are committed alongside addons)

## Design intent (read before adding any system)
- **Mood**: "Cozy dread" — passive atmosphere, NOT an active mechanic
- **Vibe**: Langoliers-style emptiness. Perfectly normal world, perfectly abandoned
- **No monsters. No enemies. No NPCs. No animals.** Just you, the snow, structures
- **No gameplay threat systems** — no dread meter, no tension ramp, no health
- The world feels wrong through *absence* and *atmosphere*, not through mechanics
- Source of truth: Obsidian vault at `/home/devbox/Documents/Obsidian-Vaults/Vaults/Projects/Project-Wanderlust/`
- Read `00 - Game Design/Game Design Overview.md` before any design decision

## Gotchas
- `.godot/`, `.import/`, `*.uid`, `*.import`, and `export_presets.cfg` are
  gitignored — expect a reimport step when cloning.
- `Terrain3D_v1.0.2.zip` and `_t3d_*` / `_bake_*` artifacts are build/cache
  leftovers (gitignored); the addon itself is committed under `addons/terrain_3d`.
- Input actions are defined in `project.godot [input]` (WASD move, F flashlight,
  E interact, Tab inventory, Shift sprint, ` toggle console, F3 debug overlay,
  G freecam, F4 editor, etc.).
- The `Project Wanderlust/` subdirectory (with space) is an Obsidian notes vault,
  not the Godot project root.
- `set_deferred("monitoring", false)` required in Area3D body_entered callbacks —
  direct assignment crashes in physics signals.
- Godot logs at `~/.local/share/godot/app_userdata/Project Wanderlust/logs/godot.log`
