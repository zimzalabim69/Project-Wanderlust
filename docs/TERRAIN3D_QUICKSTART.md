# Town terrain (already baked)

The playable town snow is **already built** — you do not need to sculpt anything to test the game.

- **Visible ground:** `scenes/terrain/town_snow_ground.tscn` (200×200 m rolling snow + collision)
- **Mesh data:** `assets/terrain/town/town_ground_mesh.tres`
- **Press F5** from `town.tscn` or run from basement → exit to town

## Optional: Terrain3D sculpting (advanced)

`Terrain → Terrain3D` is **hidden** in the scene so it does not fight the baked mesh. To sculpt with Terrain3D:

1. Use **Godot 4.4–4.6** (Terrain3D **v1.0.2** is installed).
2. In `town.tscn`, set **Terrain3D → Visible** = on (temporarily hide **TownSnowGround**).
3. Select **Terrain3D** → left toolbar in the 3D view → **+ Add Region** → left-click ground.
4. Sculpt with **Raise** / **Paint Base Texture**.
5. Data saves to `assets/terrain/town/data/`.

Re-bake the simple mesh anytime:

```
godot --path . --display-driver headless --script res://core/terrain/generate_town_ground_mesh.gd
```

## Plugin troubleshooting

| Issue | Fix |
|-------|-----|
| No left toolbar | Godot **4.6** + Terrain3D **1.0.2** enabled in Plugins |
| Extension errors | Reload project; confirm `addons/terrain_3d/bin/*.dll` exists |
| Used Godot 4.3 only | Install [Terrain3D 1.0.0 godot4.3 build](https://github.com/TokisanGames/Terrain3D/releases/tag/v1.0.0-stable) instead |
