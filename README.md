# Empire Seed — Phase 1 (Core Builder)

Offline pixel civilization builder. Godot 4.7 / GDScript. See `PIXEL_CIV_SPEC.md` for the full design.

## Run it
1. Open **Godot 4.7**.
2. *Import* this folder (the one containing `project.godot`).
3. Press **F5** (Play).

Or from a terminal:
```
"C:\Users\marka\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe" --path "<this folder>"
```

## How to play
- **Pan:** click-drag (or drag on touch). **Zoom:** mouse wheel.
- **Build:** tap an empty grid tile → pick a building (cost shown) → it enters the build queue with a timer.
- **Upgrade:** tap an existing building → Upgrade button.
- A **Town Hall** is pre-placed at the center.
- Resources accrue in real time up to their **storage caps**. Build **Warehouses** to raise caps.
- Progress **auto-saves** every 15s and on quit, to `user://empire_seed_save.json`.
- Close and reopen later — **offline production** is granted on return (capped at 8h).

## What's implemented (Phase 1 from the spec)
- 16x16 grid, pannable/zoomable camera, tap-to-place.
- Tier-1 resources (Wood, Stone, Food, Water) with upgradable storage caps.
- 5 building types (Town Hall, Lumber Camp, Quarry, Farm, Water Pump) + Warehouse, all upgradable.
- Single-lane build queue with per-level build times.
- Local JSON save/load + offline accrual. Base64 export/import helpers in `SaveManager`.

## Project layout
```
project.godot          # engine config, autoloads, pixel-perfect rendering
scenes/Main.tscn       # root: Node2D + Camera2D + HUD (CanvasLayer)
scripts/GameState.gd   # autoload: resources, buildings, queue, production, offline accrual
scripts/SaveManager.gd # autoload: save/load + offline + export/import
scripts/Main.gd        # grid draw, camera, tap-to-place
scripts/HUD.gd         # resource bar, build menu, upgrade panel, toasts
```

## Art
- Sprites: **Liberated Pixel Cup (LPC)** farm assets (fruit trees, crops, farm
  buildings, terrain), in `assets/lpc_*`. Licensed CC-BY-SA / CC-BY / GPL — **credit
  required**. See `ATTRIBUTION.md` and the bundled `CREDITS-*.txt` files.
- Source rects are mapped in `scripts/Main.gd` (`BLD`, `APPLE`, `PEAR`, `CROP_*`,
  `GRASS`, `DIRT`). Buildings map to LPC structures: town hall = thatched cabin,
  lumber camp = slate cabin, warehouse/quarry = silos, water pump = water tank,
  farm = tilled plot with crops.
- Run with `-- shot` to have the game save a screenshot to `assets/shot.png` (dev aid).

## Notes / next (Phase 2)
- Next per spec: Tier 2–4 resources + processing buildings, era progression, research.
