# CONTEXT.md — Project Wanderlust

_A living document. Update whenever major architecture, aesthetic, or workflow changes occur._

---

## Stack

| Layer | Technology |
|-------|------------|
| Engine | Godot 4.6 (Forward Plus) |
| Language | GDScript (strict typing) |
| Terrain | Terrain3D v1.0.2 (C++ GDExtension) |
| AI Bridge | Agent Tools MCP addon (TCP 127.0.0.1:9920 / 9090) |
| Save Format | JSON (`user://savegame.json`) |
| Audio Bus | Master, SFX, Music, Ambience (low-pass dynamic filter) |
| Viewport | 640×480 stretched → 1920×1080 window |

---

## Aesthetic Direction

**PS1-style low-poly 3D** with a **cozy horror / liminal** mood.

### Setting
- **Location**: Golden, Colorado (rocky mountain town)
- **Era**: 1994–1997
- **Season**: Winter / snowy
- **Vibe**: *Langoliers*-style emptiness — perfectly normal world, perfectly abandoned. Not monsters, just surreal isolation. "One second behind the present."

### Visual Pillars
- **Low-poly geometry**: Embrace simple meshes, limited draw distance
- **Heavy fog**: Used as both atmosphere and performance optimization
- **Affine texture filtering**: PS1-style texture warping is intentional
- **Sharp light falloff**: Darkness presses in; practical sources only
- **Warm / cool contrast**: Orange-yellow interiors vs cold blue-green fog and overcast sky
- **Retro 1980s–90s Americana**: Station wagons, CRT static, brick ranch houses, water towers, wood-paneled interiors
- **Snowy winter**: Persistent light snowfall, muted overcast lighting

### Mood & Motifs
- **"Cozy Dread"**: Safe domestic spaces that feel slightly wrong
- **Isolation**: Empty roads, abandoned structures, vast snowy woods
- **Threshold spaces**: Open doors looking into darkness, windows as warm light sources
- **Companion object**: The station wagon recurs as an anchor/objective
- **Retro tech**: TVs with static, radios, record players, neon signs
- **Isolation**: Empty roads, abandoned structures, vast woods
- **Threshold spaces**: Open doors looking into darkness, windows as light sources
- **Companion object**: The station wagon recurs as an anchor/objective
- **Retro tech**: TVs with static, radios, record players, neon signs

### Technical Rendering Notes
- Use **fog liberally** — match fog color to sky
- Keep draw distances short; fog hides the cutoff
- Emphasize **baked lighting** or very limited dynamic lights with heavy attenuation
- Consider a custom shader for subtle PS1 vertex snap / affine distortion if not already present
- Heavy use of emission/glow for practical lights rather than bright omnis

---

## Architecture

### Directory Layout
```
Project Wanderlust/
├── core/
│   ├── autoload/          # 13 global singletons
│   ├── components/        # Reusable scene behaviors
│   ├── debug/
│   ├── player.gd          # First-person controller
│   └── terrain/           # Terrain3D baking scripts
├── scenes/
│   ├── basement.tscn      # Starting level (indoor)
│   ├── main_floor.tscn    # House main floor (indoor)
│   ├── town.tscn          # Small town area (outdoor, currently unused)
│   ├── player.tscn        # Player prefab (1.5x scale)
│   ├── ui/                # Title screen, pause menu
│   ├── collectibles/      # Key, note pickups
│   ├── props/             # Interactive objects
│   ├── structures/        # Architectural pieces
│   ├── terrain/           # Baked terrain meshes
│   └── templates/         # Level template
├── demo/
│   ├── Demo.tscn          # **Overworld** — big open world (Golden, CO)
│   ├── components/        # Environment, Tunnel, etc.
│   ├── src/               # DemoScene.gd, etc.
│   ├── assets/            # Rocks, crystals, models
│   └── data/              # Terrain3D data files
├── resources/
│   ├── levels/            # LevelConfig .tres files
│   └── terrain/           # Terrain3D asset libraries
├── assets/
│   ├── audio/             # Bus layout, sound files
│   ├── materials/         # Basement, snow, etc.
│   └── terrain/           # Baked mesh + collision
├── ui/                    # Inventory, dev console, overlay, editor panel
├── addons/
│   ├── agent_tools/       # MCP bridge for AI coding
│   └── terrain_3d/        # Terrain3D plugin + demo scenes
└── docs/                  # Terrain3D quickstart
```

### Autoload Singletons
| Name | File | Responsibility |
|------|------|----------------|
| GameState | `core/autoload/game_state.gd` | Story/world flags, pending spawn ID |
| SpawnManager | `core/autoload/spawn_manager.gd` | Player placement across scenes; JSON overrides supported |
| SceneTransition | `core/autoload/scene_transition.tscn` | Full-screen fade; prevents overlapping transitions |
| AudioManager | `core/autoload/audio_manager.gd` | Ambient loops; indoor/outdoor low-pass filter mix |
| InventoryManager | `core/autoload/inventory_manager.gd` | Items, notes, keys; fast lookup dict |
| SaveManager | `core/autoload/save_manager.gd` | JSON save/load (scene, spawn, flags, items, audio) |
| DevMode | `core/autoload/dev_mode.gd` | Noclip, freecam, teleport |
| LevelEditor | `core/autoload/level_editor.gd` | In-game editor (F8): place, terrain, spawn, select |
| McpInteractionServer | `core/autoload/mcp_interaction_server.gd` | TCP server for external AI agent control |
| InventoryPanel | `ui/inventory_panel.tscn` | Inventory UI overlay |
| PauseMenu | `scenes/ui/pause_menu.tscn` | Pause UI |
| DevConsole | `ui/dev_console.tscn` | Debug command console |
| DevOverlay | `ui/dev_overlay.tscn` | Performance / debug readout |
| SpawnManager | `core/autoload/spawn_manager.gd` | Global spawn placement; JSON overrides for any scene |

---

## Design Patterns

### 1. Component / Template Method
`Interactable` is the base class for everything the player can interact with.
```gdscript
class_name Interactable
extends Node3D
signal interacted(player: Node3D)
@export var prompt_text: String = "Interact"
func interact(player: Node3D) -> void:
    if can_interact(): _on_interact(player)
func _on_interact(_player: Node3D) -> void:
    pass  # Override in subclasses
```
**Subclasses**: `Collectible`, `KeyItem`, `KeyLockedDoor`

### 2. Data-Driven Levels
Every level uses a `LevelRoot` node with an attached `LevelConfig` resource:
```gdscript
class_name LevelConfig
extends Resource
@export var level_id: String
@export var display_name: String
@export var ambient_loop: AudioStream
@export var music_loop: AudioStream
@export var use_outdoor_mix: bool
```

### 3. Flag-Driven Reactivity
`GameState` stores boolean flags. `WorldStateTrigger` listens and shows/hides nodes declaratively:
```gdscript
@export var required_flag: String
@export var target_nodes: Array[NodePath]
```

### 4. Signal-Driven Data Flow
```
Player Input → Interactable.interact() → Collectible._on_interact()
  → InventoryManager.collect() → GameState.set_flag()
  → WorldStateTrigger reacts → AudioZone updates filter
```

---

## Conventions

### GDScript Style
- **Types everywhere**: explicit on vars, params, and return values
- **Naming**: `snake_case` functions/variables, `PascalCase` classes, `_private` prefix
- **Node refs**: `@onready var camera: Camera3D = $Camera3D`
- **Inspector values**: `@export` for designer-editable fields
- **Signals**: declared at top, emitted with `.emit()`
- **Async**: `await SceneTransition.change_scene(...)`, `await get_tree().process_frame`

### Error Handling
- `push_warning()` for non-critical issues
- `push_error()` for critical failures
- Null guard before access: `if node == null: return`
- Fallback values in `.get()` calls

### Scene Organization
All levels follow this hierarchy under `LevelRoot`:
```
LevelRoot (LevelConfig assigned)
├── Terrain
├── Structures
├── Props
├── Vehicles
├── Lighting
├── AudioZones
├── SpawnPoints
└── Triggers
```

---

## Key Systems

### Player Controller (`core/player.gd`)
- **Movement**: WASD + mouse look, sprint (Shift toggle), auto-run (RMB)
- **Interaction**: RayCast3D from camera, 2.5m range, dynamic prompt
- **Flashlight**: SpotLight3D toggle (F)
- **Footsteps**: Adaptive timing by speed; surface detection via collision groups (`surface_wood`, `surface_snow`, etc.)
- **Input arbitration**: Respects DevConsole, LevelEditor, and InventoryManager open states

### Scene Transition Flow
```
SceneExit (Area3D, body_entered)
  → SceneTransition.change_scene(target_scene, spawn_id)
    → Fade to black (0.6s default)
    → Load new scene
    → SpawnManager._place_player()
      → JSON override? → Named SpawnPoint? → "default" fallback
    → LevelRoot applies LevelConfig (audio, fog, etc.)
    → Fade from black
```

### Audio Zones
- `AudioZone` (Area3D) toggles low-pass filter on the **Ambience** bus
- Indoor: 20500 Hz (clear) | Outdoor: 800 Hz (muffled)
- Optional ambient loop override per zone

### Save/Load
Save file (`user://savegame.json`) stores:
```json
{
  "version": 1,
  "current_scene": "res://scenes/basement.tscn",
  "spawn_id": "default",
  "flags": { "found_basement_key": true },
  "items": [{ "id", "title", "text", "icon" }],
  "audio": { "master", "sfx", "music", "ambience" }
}
```

---

## Input Map
| Action | Key | Context |
|--------|-----|---------|
| move_forward / back / left / right | W S A D | Always |
| interact | E | Gameplay |
| toggle_flashlight | F | Gameplay |
| toggle_inventory | Tab | Gameplay |
| sprint | Shift | Gameplay |
| toggle_console | ` | Debug |
| toggle_debug_overlay | F10 | Debug |
| toggle_freecam | G | Debug |
| toggle_editor | F8 | Debug |
| editor_cycle_tool | Tab | Editor |
| editor_delete | Delete | Editor |
| teleport_player_here | + (numpad) | Debug |

---

## Addons

### Terrain3D v1.0.2
- Up to 32 textures, 10 LOD levels
- Sculpting, painting, foliage instancing
- Used in `town.tscn` (baked to static mesh at runtime for performance; hidden Terrain3D node can be re-enabled for editing)
- Baking script: `core/terrain/generate_town_ground_mesh.gd`

### Agent Tools (MCP Bridge)
- TCP servers on `127.0.0.1:9920` and `9090`
- 43 JSON-RPC tools for scene editing, signal inspection, resource management, animation, headless testing
- Enables external AI agents (Claude, Cursor, Windsurf) to query and manipulate the running game

---

## Build / Run

No custom build step required (GDScript + Godot Editor). To run:
1. Open `project.godot` in Godot 4.6
2. Play main scene (`scenes/ui/title_screen.tscn`)

For distribution, use Godot's built-in export templates.

---

## Testing

- **No automated test framework** currently in use.
- Manual testing checklist:
  - [ ] New game → basement spawn
  - [ ] Pick up key → inventory shows item
  - [ ] Unlock door → scene transition to town
  - [ ] Save, quit, continue → restore position and inventory
  - [ ] Audio zone crossing → low-pass filter shifts
  - [ ] Freecam + teleport → player moves correctly
  - [ ] Level editor → place prefab, save layout, reload

---

## Known Gaps / TODO

- Music loop system exists in `LevelConfig` but is not yet wired up
- Settings menu is a placeholder
- No automated tests
- No custom shaders in main project (only Terrain3D addon shaders)
- Terrain sculpting integration in `LevelEditor` is simplified

---

## Session Learnings (Critical)

### DO NOT SECOND-GUESS THE DESIGN
- The Obsidian vault at `C:\Users\sikke\Obsidian\Vaults\Projects\Project-Wanderlust` is the source of truth
- **Setting**: Golden, Colorado, 1994-1997, WINTER/SNOWY — NOT autumn
- **Mood**: Langoliers-style emptiness, surreal isolation, NO monsters
- Screenshots show the **mood/vibe**, not necessarily the exact season
- Always read the vault before making aesthetic changes

### Scene Flow (Confirmed)
```
Title Screen → basement.tscn → main_floor.tscn → demo/Demo.tscn (Overworld)
```
- `Demo.tscn` is the BIG open world (Terrain3D)
- `town.tscn` is a smaller area (currently unused)
- Exits: main_floor front/back doors → Demo.tscn
- Demo has SpawnPoints for default, from_basement, from_front_door, from_back_door

### Systems Built This Session
- **Sprint**: Shift toggle (NOT hold), 3.5x multiplier
- **Auto-run**: Hold LMB = forward, RMB toggle locks it
- **Freecam**: G to toggle, scroll wheel adjusts speed, + to teleport player
- **Level Editor**: F8 toggle, Tab cycles tools, placement/terrain/select/delete
- **SpawnManager**: JSON overrides in `user://spawn_overrides.json`
- **DevConsole**: pos, setspawn, goto, teleport, editor, save_layout, load_layout

### Bugs Fixed
- `current_scene_changed` is NOT a real signal — use polling in `_process()`
- `Vector3` requires 3 args; `PlaneMesh.size` takes `Vector2`
- `global_scale` is read-only in Godot 4 — use `scale` or `set("scale", val)`
- Player's `_mouse_captured` var gets stale — check `Input.mouse_mode` directly
- Mouse capture after tab-out: use `await get_tree().process_frame` before capturing

### Input Map
| Action | Key |
|--------|-----|
| move | WASD |
| sprint | Shift (toggle) |
| auto_run_forward | LMB (hold) |
| auto_run_lock | RMB (toggle) |
| interact | E |
| flashlight | F |
| inventory | Tab |
| pause | Escape |
| dev_console | ~ (backtick) |
| dev_freecam | G |
| teleport_player_here | + / numpad + |
| editor_toggle | F8 |
| editor_cycle_tool | Tab |
| editor_delete | Delete |

## Devin Mind Commands

Use these in any session for context and learning:
- `/reflect` — review recent work and extract reusable skills
- `/learn` — deep pattern extraction from session history
- `/search-memory <query>` — search all past sessions
- `/soul` — view or edit user model

---

_Generated by Devin on 2026-06-21. Updated after codebase exploration + aesthetic reference analysis._
