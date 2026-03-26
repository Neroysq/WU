# WU Godot

This is the only active game implementation in the repository.

## Scope

Current playable prototype includes:
- `Map -> Combat -> Reward -> Game Over`
- Procedural run map generation with varied middle tiers
- 1v1 combat with health/posture/rage
- Block/parry, dash, jump, and combo chaining
- Enemy AI with telegraphed attacks
- JSON-configured character/enemy/reward/settings data with hot reload (`F5`)

## Run

1. Install Godot 4.x.
2. Open `project.godot` in this folder.
3. Press Play.

## Project Layout

- `scenes/Main.tscn` - entry scene
- `scripts/main.gd` - run state machine and non-combat UI
- `scripts/combat_scene.gd` - combat update loop and rendering
- `scripts/combat_system.gd` - combat logic, AI, hit resolution
- `scripts/fighter.gd` - fighter state model and timing
- `scripts/data_manager.gd` - JSON loading and defaults
- `scripts/input_tracker.gd` - shared pressed-key / mouse-edge tracking
- `scripts/visual/` - modular sprite/animation runtime
- `data/` - gameplay configuration
- `assets/animations/` - animation-set JSON definitions
- `assets/sprites/` - sprite frame assets (placeholder art included)

## Animation Modding

Animation rendering is data-driven:
- Add/replace sprite frames under `assets/sprites/`
- Define clip timing and frame sequences in `assets/animations/*.json`
- Point characters/enemies to a visual profile via `data/VisualProfiles/*.json`
- Assign `visualProfile` ids in `data/Characters/*.json` and `data/Enemies/*.json`
