# WU (武)

WU is a 2D wuxia-themed action roguelike focused on deliberate 1v1 combat.

## Engine

- Godot Engine 4.x

## Current Prototype

The repository now contains a single playable implementation in Godot:

- Run flow: `Map -> Combat -> Reward -> Game Over`
- Core combat: attack, block/parry, dash, jump, posture/rage/health
- Enemy AI with telegraphed attacks
- JSON-driven gameplay tuning with live reload (`F5`)

## Run

1. Install Godot 4.x.
2. Open `WUGodot/project.godot`.
3. Press Play.

## Controls

- `A / D`: move (map navigation and combat)
- `W`: jump
- `J`: attack / confirm
- `K`: block / parry
- `Space`: dash
- `1 / 2`: choose reward
- `P`: pause (combat)
- `` ` ``: debug overlay toggle (combat)
- `F5`: reload JSON data
- `R`: restart run
- `Esc`: quit

## Repo Layout

- `WUGodot/`: Godot project
- `docs/GAMEPLAY_DESIGN_DOC.md`: gameplay vision and systems
- `docs/ART_DESIGN_DOC.md`: visual direction and art pipeline
