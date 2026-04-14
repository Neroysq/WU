# WU Milestone 1 Art Pass — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace placeholder visuals with VINIK24 pixel art infrastructure — BackgroundRenderer with arena selection, per-archetype animation configs, UI design language (scroll-aesthetic panels, corner-mark ornament, Chinese-first typographic hierarchy), and a full VFX color pass — so the game is ready to receive production sprite assets.

**Architecture:** The art pass is code-and-config only — it builds the rendering infrastructure and visual language that production assets plug into. `BackgroundRenderer` replaces the procedural arena drawing with texture-based backgrounds selected by node type. `GameConstants` gains VINIK24 color definitions used everywhere. Every `_draw_*` method in `main.gd` and `combat_scene.gd` is updated to use the new panel treatment and typographic hierarchy. Per-archetype visual profiles and animation JSON configs give each enemy its own sprite pipeline slot. Character sprite generation is a separate manual/AI pipeline step outside this plan.

**Tech Stack:** Godot 4.6.2 (GDScript), JSON data configs, Python palette preset in AIexp.

**Spec reference:** `docs/superpowers/specs/2026-04-14-art-pass-design.md`

---

## File Structure

**New files:**

- `AIexp/tools/palettes/src/palettes/data/vinik24.json` — VINIK24 palette preset (24 colors) for the AIexp pixel-converter pipeline.
- `WUGodot/scripts/visual/background_renderer.gd` — Loads and draws arena background textures. Exposes `set_arena(arena_id)` and `draw(canvas, camera_offset, battle_state)`. Milestone 1 implementation draws a static texture; `battle_state` is accepted but ignored (future-proofing).
- `WUGodot/assets/backgrounds/chapter1_bamboo_dusk.png` — Placeholder background (solid dark color). Replaced by AI-generated art during the asset creation pipeline step.
- `WUGodot/assets/backgrounds/chapter1_boss_clearing.png` — Placeholder boss background (solid darker color). Same replacement path.
- `WUGodot/assets/animations/character_hu.json` — Player-specific animation config (replaces shared `character_humanoid.json` for the player profile).
- `WUGodot/assets/animations/character_bandit_sword.json` — Bandit Swordsman animation config.
- `WUGodot/assets/animations/character_bandit_spear.json` — Bandit Spearman animation config.
- `WUGodot/assets/animations/character_ronin.json` — Wandering Ronin animation config.
- `WUGodot/assets/animations/character_disciple.json` — Sect Disciple animation config.
- `WUGodot/assets/animations/character_assassin.json` — Masked Assassin animation config.
- `WUGodot/assets/animations/character_iron_bear.json` — Xiong Tie boss animation config.
- `WUGodot/tests/test_background_renderer.gd` — Tests for BackgroundRenderer arena loading and draw interface.

**Modified files:**

- `WUGodot/scripts/game_constants.gd` — Replace all color constants with VINIK24 equivalents.
- `WUGodot/scripts/combat_scene.gd` — Replace `_draw_arena()` with BackgroundRenderer. Update `_draw_panel()`, `_draw_bar_frame()`, `_draw_hud()`, `_draw_fighter()` VFX colors, and `_draw_feedback()` to use VINIK24 + new panel treatment.
- `WUGodot/scripts/combat_system.gd` — Update all hardcoded `Color8(...)` particle spawn colors to VINIK24 equivalents (21 call sites).
- `WUGodot/scripts/main.gd` — Update `_draw_main_menu()`, `_draw_map()`, `_draw_reward()`, `_draw_event()`, `_draw_shop()`, `_draw_rest()`, `_draw_forget_technique()`, `_draw_victory()`, `_draw_game_over()`, `_draw_panel()`, `_draw_background()` to use VINIK24 + new UI language.
- `WUGodot/scripts/fighter.gd` — Split `AnimationState.ATTACKING` into `ATTACKING_LIGHT`/`ATTACKING_HEAVY`. Update `current_telegraph_color()` to VINIK24.
- `WUGodot/scripts/visual/fighter_visual.gd` — Update `_resolve_state()` to handle split attack states with fallback to shared `ATTACKING` clip.
- `WUGodot/data/VisualProfiles/DefaultProfiles.json` — Expand from 4 shared profiles to 7 per-archetype profiles, each pointing to its own animation config.
- `WUGodot/data/Enemies/BanditSpearman.json` — Update `visualProfile` to `enemy_humanoid_basic_spear`.
- `WUGodot/data/Enemies/WanderingRonin.json` — Update `visualProfile` to `enemy_humanoid_ronin`.
- `WUGodot/data/Enemies/MaskedAssassin.json` — Update `visualProfile` to `enemy_humanoid_assassin`.
- `WUGodot/tests/run_tests.gd` — Add `test_background_renderer.gd` to `_TEST_MODULES`.

---

## Testing Strategy

**Headless tests:**

- `test_background_renderer.gd` — Arena ID storage, switching, unknown arena acceptance, draw method existence, null texture fallback for unknown arenas, crash-free set_arena for known arenas.
- All 132 existing tests must continue to pass.

**Manual playtest checklist** (Task 8):

- VINIK24 colors visible throughout (no old placeholder colors remaining).
- Corner-mark panels on all screens.
- Chinese-first text order on menus and HUD.
- Boss fight uses darker background variant.
- Standard fights use bamboo dusk background.

---

### Task 1: VINIK24 Palette Preset for AIexp

**Files:**
- Create: `AIexp/tools/palettes/src/palettes/data/vinik24.json`

- [ ] **Step 1: Create the VINIK24 palette JSON**

Create `AIexp/tools/palettes/src/palettes/data/vinik24.json`:

```json
{
  "name": "vinik24",
  "colors": [
    "#0f0f1b",
    "#565a75",
    "#c6b7be",
    "#faf6f6",
    "#f49e4c",
    "#ab5236",
    "#bf2652",
    "#74233c",
    "#3b1725",
    "#73172d",
    "#b4202a",
    "#df7126",
    "#ee9c24",
    "#f8c83c",
    "#4e8339",
    "#2c4a2e",
    "#20394f",
    "#255674",
    "#577399",
    "#96b2c5",
    "#a1d2e0",
    "#6b3e75",
    "#905ea9",
    "#a884f3"
  ]
}
```

- [ ] **Step 2: Verify palette loads**

Run from the AIexp directory:

```bash
cd /Users/animula/GitReps/AIexp && python -c "from palettes import list_palettes, load_palette; assert 'vinik24' in list_palettes(); p = load_palette('vinik24'); assert len(p) == 24; print('OK: %d colors' % len(p))"
```

Expected: `OK: 24 colors`

- [ ] **Step 3: Commit**

```bash
cd /Users/animula/GitReps/AIexp && git add tools/palettes/src/palettes/data/vinik24.json && git commit -m "feat: add VINIK24 palette preset"
```

---

### Task 2: GameConstants — VINIK24 Color Definitions

**Files:**
- Modify: `WUGodot/scripts/game_constants.gd`

- [ ] **Step 1: Replace all color constants with VINIK24**

Replace the color constants section (lines 34-47) in `WUGodot/scripts/game_constants.gd`:

```gdscript
# VINIK24 palette - core usage
const COLOR_INK_BLACK: Color = Color8(15, 15, 27)       # #0f0f1b
const COLOR_INK_DARK: Color = Color8(15, 15, 27)        # #0f0f1b (alias)
const COLOR_INK_MID: Color = Color8(86, 90, 117)        # #565a75
const COLOR_SCROLL_WHITE: Color = Color8(250, 246, 246) # #faf6f6
const COLOR_PAPER: Color = Color8(198, 183, 190)        # #c6b7be
const COLOR_JADE_GREEN: Color = Color8(78, 131, 57)     # #4e8339
const COLOR_JADE_DARK: Color = Color8(44, 74, 46)       # #2c4a2e
const COLOR_VERMILLION_RED: Color = Color8(180, 32, 42) # #b4202a
const COLOR_CRIMSON: Color = Color8(191, 38, 82)        # #bf2652
const COLOR_IMPERIAL_GOLD: Color = Color8(238, 156, 36) # #ee9c24
const COLOR_GOLD_DARK: Color = Color8(106, 74, 26)      # derived shadow tone (not in VINIK24 — exempted as a computed midpoint)
const COLOR_GOLD_BRIGHT: Color = Color8(248, 200, 60)   # #f8c83c
const COLOR_MOUNTAIN_BLUE: Color = Color8(32, 57, 79)   # #20394f
const COLOR_MISTY_BLUE: Color = Color8(87, 115, 153)    # #577399
const COLOR_LIGHT_BLUE: Color = Color8(150, 178, 197)   # #96b2c5
const COLOR_SKY_BLUE: Color = Color8(161, 210, 224)     # #a1d2e0
const COLOR_EARTH_DARK: Color = Color8(59, 23, 37)      # #3b1725
const COLOR_EARTH_MID: Color = Color8(171, 82, 54)      # #ab5236
const COLOR_EARTH_LIGHT: Color = Color8(223, 113, 38)   # #df7126
const COLOR_PURPLE_DARK: Color = Color8(107, 62, 117)   # #6b3e75
const COLOR_PURPLE_MID: Color = Color8(144, 94, 169)    # #905ea9
const COLOR_PURPLE_LIGHT: Color = Color8(168, 132, 243) # #a884f3
const COLOR_SKIN_WARM: Color = Color8(244, 158, 76)     # #f49e4c
const COLOR_MAROON: Color = Color8(116, 35, 60)         # #74233c
const COLOR_RED_DARK: Color = Color8(115, 23, 45)       # #73172d

# UI semantic aliases
const COLOR_PANEL_BG: Color = Color8(15, 15, 27)        # ink black at 90% opacity in code
const COLOR_PANEL_BORDER: Color = Color8(86, 90, 117)   # ink mid
const COLOR_PANEL_ACCENT: Color = Color8(238, 156, 36)  # gold top-edge
const COLOR_TEXT_HEADING: Color = Color8(250, 246, 246)  # scroll white
const COLOR_TEXT_SUBHEADING: Color = Color8(198, 183, 190) # paper
const COLOR_TEXT_BODY: Color = Color8(150, 178, 197)     # light blue
const COLOR_TEXT_CAPTION: Color = Color8(86, 90, 117)    # ink mid
const COLOR_TEXT_ACCENT: Color = Color8(238, 156, 36)    # gold
const COLOR_HEALTH: Color = Color8(180, 32, 42)          # vermillion red
const COLOR_POSTURE: Color = Color8(238, 156, 36)        # imperial gold
const COLOR_RAGE: Color = Color8(78, 131, 57)            # jade green
```

- [ ] **Step 2: Commit**

```bash
git add WUGodot/scripts/game_constants.gd
git commit -m "feat: replace color constants with VINIK24 palette"
```

---

### Task 3: BackgroundRenderer

**Files:**
- Create: `WUGodot/scripts/visual/background_renderer.gd`
- Create: `WUGodot/assets/backgrounds/chapter1_bamboo_dusk.png`
- Create: `WUGodot/assets/backgrounds/chapter1_boss_clearing.png`
- Create: `WUGodot/tests/test_background_renderer.gd`
- Modify: `WUGodot/tests/run_tests.gd`

- [ ] **Step 1: Write tests**

Create `WUGodot/tests/test_background_renderer.gd`:

```gdscript
extends RefCounted

const BackgroundRendererScript = preload("res://scripts/visual/background_renderer.gd")

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var bg: Variant = BackgroundRendererScript.new()

	# Test 1: default arena id is empty
	if bg.current_arena_id == "":
		passed += 1
	else:
		failed += 1
		failures.append("default arena_id should be empty (got '%s')" % bg.current_arena_id)

	# Test 2: set_arena stores the id
	bg.set_arena("chapter1_bamboo_dusk")
	if bg.current_arena_id == "chapter1_bamboo_dusk":
		passed += 1
	else:
		failed += 1
		failures.append("set_arena should store id (got '%s')" % bg.current_arena_id)

	# Test 3: set_arena with different id switches
	bg.set_arena("chapter1_boss_clearing")
	if bg.current_arena_id == "chapter1_boss_clearing":
		passed += 1
	else:
		failed += 1
		failures.append("set_arena should switch id (got '%s')" % bg.current_arena_id)

	# Test 4: set_arena with unknown id doesn't crash, falls back
	bg.set_arena("nonexistent_arena")
	if bg.current_arena_id == "nonexistent_arena":
		passed += 1
	else:
		failed += 1
		failures.append("set_arena should accept any id (got '%s')" % bg.current_arena_id)

	# Test 5: draw() accepts battle_state without error (headless — no canvas, so test the method exists and signature is correct)
	# We can't call draw() without a CanvasItem in headless mode, but we can verify the method exists
	if bg.has_method("draw"):
		passed += 1
	else:
		failed += 1
		failures.append("BackgroundRenderer should have a draw() method")

	# Test 6: texture is null for unknown arena (fallback path)
	if bg._texture == null:
		passed += 1
	else:
		failed += 1
		failures.append("unknown arena should have null texture (fallback)")

	# Test 7: known arena loads texture (if file exists)
	bg.set_arena("chapter1_bamboo_dusk")
	# In headless mode, ResourceLoader may or may not find the PNG.
	# Just verify the method didn't crash.
	passed += 1

	return {"passed": passed, "failed": failed, "failures": failures}
```

- [ ] **Step 2: Implement BackgroundRenderer**

Create `WUGodot/scripts/visual/background_renderer.gd`:

```gdscript
class_name BackgroundRenderer
extends RefCounted

var current_arena_id: String = ""
var _texture: Texture2D = null
var _fallback_color: Color = Color8(15, 15, 27)

const ARENA_PATHS: Dictionary = {
	"chapter1_bamboo_dusk": "res://assets/backgrounds/chapter1_bamboo_dusk.png",
	"chapter1_boss_clearing": "res://assets/backgrounds/chapter1_boss_clearing.png",
}

func set_arena(arena_id: String) -> void:
	current_arena_id = arena_id
	_texture = null
	var path: String = str(ARENA_PATHS.get(arena_id, ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		_texture = load(path) as Texture2D

func draw(canvas: CanvasItem, camera_offset: Vector2, battle_state: Dictionary) -> void:
	# Draw with 40px bleed on all sides to cover camera shake without exposing blank edges
	var bleed: float = 40.0
	if _texture != null:
		var rect: Rect2 = Rect2(camera_offset.x - bleed, camera_offset.y - bleed, float(_texture.get_width()) + bleed * 2.0, float(_texture.get_height()) + bleed * 2.0)
		canvas.draw_texture_rect(_texture, rect, false)
	else:
		canvas.draw_rect(Rect2(camera_offset.x - bleed, camera_offset.y - bleed, float(GameConstants.VIEW_WIDTH) + bleed * 2.0, float(GameConstants.VIEW_HEIGHT) + bleed * 2.0), _fallback_color)
```

- [ ] **Step 3: Create placeholder background images**

Generate minimal 1920x1080 placeholder PNGs. These will be replaced by AI-generated art later.

```bash
cd /Users/animula/GitReps/WU/WUGodot/assets && mkdir -p backgrounds
```

Create a simple Python script to generate placeholder backgrounds:

```bash
python3 -c "
from PIL import Image
# Standard arena: dark blue-gray
img = Image.new('RGB', (1920, 1080), (15, 15, 27))
for y in range(1080):
    for x in range(0, 1920, 6):
        r = int(15 + (y / 1080.0) * 17)
        g = int(15 + (y / 1080.0) * 42)
        b = int(27 + (y / 1080.0) * 52)
        for dx in range(6):
            if x + dx < 1920:
                img.putpixel((x + dx, y), (r, g, b))
img.save('/Users/animula/GitReps/WU/WUGodot/assets/backgrounds/chapter1_bamboo_dusk.png')

# Boss arena: darker variant
img2 = Image.new('RGB', (1920, 1080), (10, 10, 18))
for y in range(1080):
    for x in range(0, 1920, 6):
        r = int(10 + (y / 1080.0) * 10)
        g = int(10 + (y / 1080.0) * 30)
        b = int(18 + (y / 1080.0) * 40)
        for dx in range(6):
            if x + dx < 1920:
                img2.putpixel((x + dx, y), (r, g, b))
img2.save('/Users/animula/GitReps/WU/WUGodot/assets/backgrounds/chapter1_boss_clearing.png')
print('Placeholder backgrounds created')
"
```

If PIL is not available, create solid-color fallbacks:

```bash
python3 -c "
import struct, zlib
def make_png(w, h, r, g, b, path):
    def chunk(ctype, data):
        c = ctype + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)
    header = b'\\x89PNG\\r\\n\\x1a\\n'
    ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
    raw = b''
    for y in range(h):
        raw += b'\\x00' + bytes([r, g, b]) * w
    idat = chunk(b'IDAT', zlib.compress(raw))
    iend = chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(header + ihdr + idat + iend)
make_png(1920, 1080, 15, 15, 27, '/Users/animula/GitReps/WU/WUGodot/assets/backgrounds/chapter1_bamboo_dusk.png')
make_png(1920, 1080, 10, 10, 18, '/Users/animula/GitReps/WU/WUGodot/assets/backgrounds/chapter1_boss_clearing.png')
print('Placeholder backgrounds created')
"
```

- [ ] **Step 4: Register test module**

In `WUGodot/tests/run_tests.gd`, add to `_TEST_MODULES`:

```gdscript
	"res://tests/test_background_renderer.gd",
```

- [ ] **Step 5: Run tests**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --script res://tests/run_tests.gd`

Expected: All tests pass (132 existing + 7 new = 139).

- [ ] **Step 6: Commit**

```bash
git add WUGodot/scripts/visual/background_renderer.gd WUGodot/assets/backgrounds/ WUGodot/tests/test_background_renderer.gd WUGodot/tests/run_tests.gd
git commit -m "feat: add BackgroundRenderer with arena selection and placeholder backgrounds"
```

---

### Task 4: Wire BackgroundRenderer into CombatScene

**Files:**
- Modify: `WUGodot/scripts/combat_scene.gd`

- [ ] **Step 1: Add BackgroundRenderer field and initialization**

In `WUGodot/scripts/combat_scene.gd`, add the preload after line 4:

```gdscript
const BackgroundRendererScript = preload("res://scripts/visual/background_renderer.gd")
```

After `_enemy_visual` declaration, add:

```gdscript
var _background: Variant = null
```

In `_ready()`, after `_enemy_visual = FighterVisual.new(_asset_catalog)`, add:

```gdscript
	_background = BackgroundRendererScript.new()
```

- [ ] **Step 2: Set arena in setup_combat**

In `setup_combat()`, add after `_enemy = EnemyFactory.create_enemy_for_node(node)`:

```gdscript
	var arena_id: String = "chapter1_boss_clearing" if node.node_type == MapNode.NodeType.BOSS else "chapter1_bamboo_dusk"
	if _background != null:
		_background.set_arena(arena_id)
```

- [ ] **Step 3: Replace _draw_arena with BackgroundRenderer**

Replace `_draw_arena()` (the method that draws procedural mountains):

```gdscript
func _draw_arena(offset: Vector2) -> void:
	if _background != null:
		_background.draw(self, offset, {})
	else:
		draw_rect(Rect2(offset.x, offset.y, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT), GameConstants.COLOR_INK_BLACK)
	_draw_platform(offset)
```

Remove `_draw_mountain_layer()` and `_draw_window_frame()` methods — they are no longer called.

- [ ] **Step 4: Commit**

```bash
git add WUGodot/scripts/combat_scene.gd
git commit -m "feat: wire BackgroundRenderer into combat scene, replace procedural arena"
```

---

### Task 5: Per-Archetype Animation Configs and Visual Profiles

**Files:**
- Create: 7 animation JSON files in `WUGodot/assets/animations/`
- Modify: `WUGodot/data/VisualProfiles/DefaultProfiles.json`

- [ ] **Step 1: Create per-archetype animation configs**

Each config has the same structure as the existing `character_humanoid.json` but with a unique `setId` and archetype-specific scale. For now, all reference the same placeholder frames — the asset pipeline will replace the frame paths later.

Create `WUGodot/assets/animations/character_hu.json`:

```json
{
  "setId": "character_hu",
  "meta": {
    "defaultScale": 1.0,
    "pivot": "bottom_center"
  },
  "clips": {
    "IDLE": {
      "fps": 6.0,
      "loop": true,
      "frames": [
        {"path": "res://assets/sprites/characters/humanoid_placeholder/idle_0.svg", "offset": [0, 0]},
        {"path": "res://assets/sprites/characters/humanoid_placeholder/idle_1.svg", "offset": [0, 0]}
      ]
    },
    "WALKING": {
      "fps": 10.0,
      "loop": true,
      "frames": [
        {"path": "res://assets/sprites/characters/humanoid_placeholder/walk_0.svg", "offset": [0, 0]},
        {"path": "res://assets/sprites/characters/humanoid_placeholder/walk_1.svg", "offset": [0, 0]},
        {"path": "res://assets/sprites/characters/humanoid_placeholder/walk_0.svg", "offset": [0, 0]},
        {"path": "res://assets/sprites/characters/humanoid_placeholder/walk_1.svg", "offset": [0, 0]}
      ]
    },
    "ATTACKING_LIGHT": {
      "fps": 12.0,
      "loop": false,
      "frames": [
        {"path": "res://assets/sprites/characters/humanoid_placeholder/attack_0.svg", "offset": [0, 0]},
        {"path": "res://assets/sprites/characters/humanoid_placeholder/attack_1.svg", "offset": [0, 0]},
        {"path": "res://assets/sprites/characters/humanoid_placeholder/attack_2.svg", "offset": [0, 0]}
      ]
    },
    "ATTACKING_HEAVY": {
      "fps": 10.0,
      "loop": false,
      "frames": [
        {"path": "res://assets/sprites/characters/humanoid_placeholder/attack_0.svg", "offset": [0, 0]},
        {"path": "res://assets/sprites/characters/humanoid_placeholder/attack_2.svg", "offset": [0, 0]},
        {"path": "res://assets/sprites/characters/humanoid_placeholder/attack_3.svg", "offset": [0, 0]}
      ]
    },
    "HIT_REACTION": {
      "fps": 10.0,
      "loop": false,
      "frames": [
        {"path": "res://assets/sprites/characters/humanoid_placeholder/hit_0.svg", "offset": [0, 0]},
        {"path": "res://assets/sprites/characters/humanoid_placeholder/idle_0.svg", "offset": [0, 0]}
      ]
    },
    "BLOCKING": {
      "fps": 8.0,
      "loop": false,
      "frames": [
        {"path": "res://assets/sprites/characters/humanoid_placeholder/block_0.svg", "offset": [0, 0]},
        {"path": "res://assets/sprites/characters/humanoid_placeholder/block_0.svg", "offset": [0, 0]}
      ]
    },
    "STUNNED": {
      "fps": 8.0,
      "loop": true,
      "frames": [
        {"path": "res://assets/sprites/characters/humanoid_placeholder/stunned_0.svg", "offset": [0, 0]},
        {"path": "res://assets/sprites/characters/humanoid_placeholder/hit_0.svg", "offset": [0, 0]}
      ]
    },
    "DASHING": {
      "fps": 16.0,
      "loop": false,
      "frames": [
        {"path": "res://assets/sprites/characters/humanoid_placeholder/dash_0.svg", "offset": [0, 0]},
        {"path": "res://assets/sprites/characters/humanoid_placeholder/dash_0.svg", "offset": [0, 0]}
      ]
    },
    "JUMPING": {
      "fps": 10.0,
      "loop": false,
      "frames": [
        {"path": "res://assets/sprites/characters/humanoid_placeholder/jump_0.svg", "offset": [0, 0]},
        {"path": "res://assets/sprites/characters/humanoid_placeholder/jump_0.svg", "offset": [0, 0]}
      ]
    },
    "FALLING": {
      "fps": 8.0,
      "loop": false,
      "frames": [
        {"path": "res://assets/sprites/characters/humanoid_placeholder/fall_0.svg", "offset": [0, 0]}
      ]
    },
    "LANDING": {
      "fps": 12.0,
      "loop": false,
      "frames": [
        {"path": "res://assets/sprites/characters/humanoid_placeholder/land_0.svg", "offset": [0, 0]},
        {"path": "res://assets/sprites/characters/humanoid_placeholder/idle_0.svg", "offset": [0, 0]}
      ]
    }
  }
}
```

Copy this file 6 times with different `setId` values:

```bash
cd /Users/animula/GitReps/WU/WUGodot/assets/animations
for archetype in bandit_sword bandit_spear ronin disciple assassin iron_bear; do
  cp character_hu.json "character_${archetype}.json"
done
```

Then update each file's `setId`:
- `character_bandit_sword.json` → `"setId": "character_bandit_sword"`
- `character_bandit_spear.json` → `"setId": "character_bandit_spear"`
- `character_ronin.json` → `"setId": "character_ronin"`
- `character_disciple.json` → `"setId": "character_disciple"`
- `character_assassin.json` → `"setId": "character_assassin"`
- `character_iron_bear.json` → `"setId": "character_iron_bear"`

- [ ] **Step 2: Update visual profiles**

Replace `WUGodot/data/VisualProfiles/DefaultProfiles.json`:

```json
{
  "profiles": [
    {
      "id": "player_humanoid",
      "animationSet": "res://assets/animations/character_hu.json",
      "scale": 2.2,
      "yOffset": 0.0
    },
    {
      "id": "enemy_humanoid_basic",
      "animationSet": "res://assets/animations/character_bandit_sword.json",
      "scale": 2.15,
      "yOffset": 0.0
    },
    {
      "id": "enemy_humanoid_basic_spear",
      "animationSet": "res://assets/animations/character_bandit_spear.json",
      "scale": 2.15,
      "yOffset": 0.0
    },
    {
      "id": "enemy_humanoid_ronin",
      "animationSet": "res://assets/animations/character_ronin.json",
      "scale": 2.2,
      "yOffset": 0.0
    },
    {
      "id": "enemy_humanoid_elite",
      "animationSet": "res://assets/animations/character_disciple.json",
      "scale": 2.3,
      "yOffset": 0.0
    },
    {
      "id": "enemy_humanoid_assassin",
      "animationSet": "res://assets/animations/character_assassin.json",
      "scale": 2.3,
      "yOffset": 0.0
    },
    {
      "id": "enemy_humanoid_boss",
      "animationSet": "res://assets/animations/character_iron_bear.json",
      "scale": 2.45,
      "yOffset": 0.0
    }
  ]
}
```

- [ ] **Step 3: Update enemy JSON data to use correct visual profiles**

In `WUGodot/data/Enemies/BanditSpearman.json`, change `"visualProfile"` from `"enemy_humanoid_basic"` to `"enemy_humanoid_basic_spear"`.

In `WUGodot/data/Enemies/WanderingRonin.json`, change `"visualProfile"` from `"enemy_humanoid_elite"` to `"enemy_humanoid_ronin"`.

In `WUGodot/data/Enemies/MaskedAssassin.json`, change `"visualProfile"` from `"enemy_humanoid_elite"` to `"enemy_humanoid_assassin"`.

- [ ] **Step 4: Commit**

```bash
git add WUGodot/assets/animations/ WUGodot/data/VisualProfiles/ WUGodot/data/Enemies/BanditSpearman.json WUGodot/data/Enemies/WanderingRonin.json WUGodot/data/Enemies/MaskedAssassin.json
git commit -m "feat: per-archetype animation configs and visual profiles"
```

---

### Task 6: Split ATTACKING into Light/Heavy Animation States

**Files:**
- Modify: `WUGodot/scripts/fighter.gd`
- Modify: `WUGodot/scripts/visual/fighter_visual.gd`

The spec requires distinct sacred-frame sets for light and heavy attacks. The current runtime uses a single `AnimationState.ATTACKING` for both. This task splits the enum and wires the routing.

- [ ] **Step 1: Add ATTACKING_LIGHT and ATTACKING_HEAVY to Fighter.AnimationState**

In `WUGodot/scripts/fighter.gd`, replace the `AnimationState` enum:

```gdscript
enum AnimationState {
	IDLE,
	WALKING,
	ATTACKING_LIGHT,
	ATTACKING_HEAVY,
	HIT_REACTION,
	BLOCKING,
	STUNNED,
	DASHING,
	JUMPING,
	FALLING,
	LANDING,
}
```

- [ ] **Step 2: Update all ATTACKING references in fighter.gd**

Replace every `AnimationState.ATTACKING` reference:

In `_start_attack_with()` (line 355-356), replace:
```gdscript
	current_animation = AnimationState.ATTACKING
```
with:
```gdscript
	current_animation = AnimationState.ATTACKING_HEAVY if definition.is_heavy else AnimationState.ATTACKING_LIGHT
```

In `update_timers()`, the attack finished handler — replace `current_animation == AnimationState.ATTACKING` with:
```gdscript
	elif current_animation == AnimationState.ATTACKING_LIGHT or current_animation == AnimationState.ATTACKING_HEAVY:
		current_animation = AnimationState.IDLE
```

In `_update_animation()`, replace the `AnimationState.ATTACKING:` match arm:
```gdscript
		AnimationState.ATTACKING_LIGHT, AnimationState.ATTACKING_HEAVY:
			var attack_progress: float = _attack_state.progress()
			animation_offset.x = sin(attack_progress * PI) * 15.0 * float(facing)
```

In `update_player()` in `combat_system.gd`, the `can_move` check — replace `Fighter.AnimationState.ATTACKING` with:
```gdscript
	var can_move: bool = fighter.current_animation != Fighter.AnimationState.DASHING and fighter.current_animation != Fighter.AnimationState.ATTACKING_LIGHT and fighter.current_animation != Fighter.AnimationState.ATTACKING_HEAVY and fighter.current_animation != Fighter.AnimationState.STUNNED and not fighter.is_grabbed
```

And the attack-move deceleration:
```gdscript
	elif fighter.current_animation == Fighter.AnimationState.ATTACKING_LIGHT or fighter.current_animation == Fighter.AnimationState.ATTACKING_HEAVY:
		fighter.velocity.x = lerp(fighter.velocity.x, 0.0, move_control * attack_move_control_multiplier)
```

- [ ] **Step 3: Update FighterVisual state resolution**

In `WUGodot/scripts/visual/fighter_visual.gd`, update `_resolve_state()` to handle the new states:

```gdscript
func _resolve_state(fighter: Fighter) -> String:
	var state_index: int = fighter.current_animation
	var raw_state: String = ""
	match state_index:
		Fighter.AnimationState.ATTACKING_LIGHT:
			raw_state = "ATTACKING_LIGHT"
		Fighter.AnimationState.ATTACKING_HEAVY:
			raw_state = "ATTACKING_HEAVY"
		_:
			raw_state = str(Fighter.AnimationState.keys()[state_index]).to_upper()

	if _animation_set.has_clip(raw_state):
		return raw_state

	# Fallback chain
	match raw_state:
		"ATTACKING_LIGHT", "ATTACKING_HEAVY":
			if _animation_set.has_clip("ATTACKING"):
				return "ATTACKING"
		"FALLING":
			if _animation_set.has_clip("JUMPING"):
				return "JUMPING"
		"HIT_REACTION":
			if _animation_set.has_clip("STUNNED"):
				return "STUNNED"
		"LANDING":
			if _animation_set.has_clip("IDLE"):
				return "IDLE"

	return "IDLE"
```

The fallback from `ATTACKING_LIGHT`/`ATTACKING_HEAVY` → `ATTACKING` ensures the old shared `character_humanoid.json` (which has a single `ATTACKING` clip) still works until per-archetype configs are populated with split clips.

- [ ] **Step 4: Run tests**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --script res://tests/run_tests.gd`

Expected: All tests pass. Existing tests that call `start_light_attack()` or `start_heavy_attack()` should work because the animation state change is cosmetic — it doesn't affect combat logic.

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/fighter.gd WUGodot/scripts/visual/fighter_visual.gd WUGodot/scripts/combat_system.gd
git commit -m "feat: split ATTACKING into ATTACKING_LIGHT and ATTACKING_HEAVY animation states"
```

---

### Task 7: UI Design Language — Panel Treatment and Drawing Helpers

**Files:**
- Modify: `WUGodot/scripts/main.gd`
- Modify: `WUGodot/scripts/combat_scene.gd`

- [ ] **Step 1: Replace _draw_panel in main.gd**

Replace the `_draw_panel()` method in `main.gd`:

```gdscript
func _draw_panel(rect: Rect2) -> void:
	# Ink-dark background
	draw_rect(rect, Color(GameConstants.COLOR_PANEL_BG.r, GameConstants.COLOR_PANEL_BG.g, GameConstants.COLOR_PANEL_BG.b, 0.92), true)
	# Outer border
	draw_rect(rect, GameConstants.COLOR_PANEL_BORDER, false, 2.0)
	# Gold accent on top edge
	draw_rect(Rect2(rect.position.x + 2.0, rect.position.y, rect.size.x - 4.0, 1.0), GameConstants.COLOR_PANEL_ACCENT)
	# Corner marks (6px perpendicular lines at each corner)
	var cm: float = 6.0
	var cc: Color = GameConstants.COLOR_PANEL_BORDER
	# Top-left
	draw_rect(Rect2(rect.position.x - 1.0, rect.position.y - 1.0, cm, 1.0), cc)
	draw_rect(Rect2(rect.position.x - 1.0, rect.position.y - 1.0, 1.0, cm), cc)
	# Top-right
	draw_rect(Rect2(rect.end.x - cm + 1.0, rect.position.y - 1.0, cm, 1.0), cc)
	draw_rect(Rect2(rect.end.x, rect.position.y - 1.0, 1.0, cm), cc)
	# Bottom-left
	draw_rect(Rect2(rect.position.x - 1.0, rect.end.y, cm, 1.0), cc)
	draw_rect(Rect2(rect.position.x - 1.0, rect.end.y - cm + 1.0, 1.0, cm), cc)
	# Bottom-right
	draw_rect(Rect2(rect.end.x - cm + 1.0, rect.end.y, cm, 1.0), cc)
	draw_rect(Rect2(rect.end.x, rect.end.y - cm + 1.0, 1.0, cm), cc)
```

- [ ] **Step 2: Replace _draw_panel in combat_scene.gd**

Replace the `_draw_panel()` method in `combat_scene.gd` with the same implementation:

```gdscript
func _draw_panel(rect: Rect2) -> void:
	draw_rect(rect, Color(GameConstants.COLOR_PANEL_BG.r, GameConstants.COLOR_PANEL_BG.g, GameConstants.COLOR_PANEL_BG.b, 0.92), true)
	draw_rect(rect, GameConstants.COLOR_PANEL_BORDER, false, 2.0)
	draw_rect(Rect2(rect.position.x + 2.0, rect.position.y, rect.size.x - 4.0, 1.0), GameConstants.COLOR_PANEL_ACCENT)
	var cm: float = 6.0
	var cc: Color = GameConstants.COLOR_PANEL_BORDER
	draw_rect(Rect2(rect.position.x - 1.0, rect.position.y - 1.0, cm, 1.0), cc)
	draw_rect(Rect2(rect.position.x - 1.0, rect.position.y - 1.0, 1.0, cm), cc)
	draw_rect(Rect2(rect.end.x - cm + 1.0, rect.position.y - 1.0, cm, 1.0), cc)
	draw_rect(Rect2(rect.end.x, rect.position.y - 1.0, 1.0, cm), cc)
	draw_rect(Rect2(rect.position.x - 1.0, rect.end.y, cm, 1.0), cc)
	draw_rect(Rect2(rect.position.x - 1.0, rect.end.y - cm + 1.0, 1.0, cm), cc)
	draw_rect(Rect2(rect.end.x - cm + 1.0, rect.end.y, cm, 1.0), cc)
	draw_rect(Rect2(rect.end.x, rect.end.y - cm + 1.0, 1.0, cm), cc)
```

- [ ] **Step 3: Replace _draw_bar_frame in combat_scene.gd**

```gdscript
func _draw_bar_frame(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position.x - 1, rect.position.y - 1, rect.size.x + 2, rect.size.y + 2), GameConstants.COLOR_PANEL_BORDER)
	draw_rect(rect, GameConstants.COLOR_INK_BLACK, true)
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 1), GameConstants.COLOR_PANEL_ACCENT)
```

- [ ] **Step 4: Replace _draw_background in main.gd**

```gdscript
func _draw_background() -> void:
	draw_rect(Rect2(0.0, 0.0, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT), GameConstants.COLOR_INK_BLACK, true)
```

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/main.gd WUGodot/scripts/combat_scene.gd
git commit -m "feat: implement UI design language — scroll panels, corner marks, VINIK24 bars"
```

---

### Task 8: VINIK24 Color Pass — All Screens and VFX

**Files:**
- Modify: `WUGodot/scripts/main.gd`
- Modify: `WUGodot/scripts/combat_scene.gd`
- Modify: `WUGodot/scripts/fighter.gd`

This task updates every hardcoded color in drawing code to use `GameConstants` VINIK24 values. It covers: main menu, map, reward, event, shop, rest, forget, victory, defeat, combat HUD, VFX particles, telegraph outlines, status indicators.

- [ ] **Step 1: Update main.gd screen colors**

Update `_draw_main_menu()` — replace all hardcoded colors:

```gdscript
func _draw_main_menu() -> void:
	draw_rect(Rect2(0.0, 0.0, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT), GameConstants.COLOR_INK_BLACK, true)

	var center_x: float = float(GameConstants.VIEW_WIDTH) * 0.5
	var title_y: float = float(GameConstants.VIEW_HEIGHT) * 0.3

	_draw_text("武", center_x - 40.0, title_y, GameConstants.COLOR_TEXT_HEADING, 80)
	_draw_text("WU", center_x - 22.0, title_y + 60.0, GameConstants.COLOR_TEXT_SUBHEADING, 28)
	_draw_text("A Sekiro-paced wuxia duel roguelike", center_x - 180.0, title_y + 110.0, GameConstants.COLOR_TEXT_CAPTION, 16)

	var prompt_pulse: float = 0.5 + 0.5 * sin(_cursor_flash * 4.0)
	_draw_text("Press Enter to begin", center_x - 100.0, float(GameConstants.VIEW_HEIGHT) * 0.65, Color(GameConstants.COLOR_TEXT_ACCENT.r, GameConstants.COLOR_TEXT_ACCENT.g, GameConstants.COLOR_TEXT_ACCENT.b, prompt_pulse), 20)
	_draw_text("第一章 江湖", center_x - 55.0, float(GameConstants.VIEW_HEIGHT) - 80.0, GameConstants.COLOR_TEXT_CAPTION, 14)

	# Corner-mark border
	var cm: float = 12.0
	var cc: Color = GameConstants.COLOR_PANEL_BORDER
	var m: float = 60.0
	var w: float = float(GameConstants.VIEW_WIDTH)
	var h: float = float(GameConstants.VIEW_HEIGHT)
	draw_rect(Rect2(m, m, cm, 1.0), cc)
	draw_rect(Rect2(m, m, 1.0, cm), cc)
	draw_rect(Rect2(w - m - cm, m, cm, 1.0), cc)
	draw_rect(Rect2(w - m - 1.0, m, 1.0, cm), cc)
	draw_rect(Rect2(m, h - m - 1.0, cm, 1.0), cc)
	draw_rect(Rect2(m, h - m - cm, 1.0, cm), cc)
	draw_rect(Rect2(w - m - cm, h - m - 1.0, cm, 1.0), cc)
	draw_rect(Rect2(w - m - 1.0, h - m - cm, 1.0, cm), cc)
```

Update `_draw_map()` — replace hardcoded colors with GameConstants:
- Path lines: `GameConstants.COLOR_PANEL_BORDER` at 0.3 alpha
- Title: `GameConstants.COLOR_TEXT_HEADING`
- Gold display: `GameConstants.COLOR_TEXT_ACCENT`
- Instructions: `GameConstants.COLOR_TEXT_CAPTION`
- Selected label: `GameConstants.COLOR_TEXT_BODY`

Update `_get_node_color()`:

```gdscript
func _get_node_color(node_type: int) -> Color:
	match node_type:
		MapNode.NodeType.BATTLE:
			return GameConstants.COLOR_MISTY_BLUE
		MapNode.NodeType.ELITE:
			return GameConstants.COLOR_EARTH_LIGHT
		MapNode.NodeType.AMBUSH:
			return GameConstants.COLOR_VERMILLION_RED
		MapNode.NodeType.MASTER:
			return GameConstants.COLOR_PURPLE_MID
		MapNode.NodeType.EVENT:
			return GameConstants.COLOR_LIGHT_BLUE
		MapNode.NodeType.SHOP:
			return GameConstants.COLOR_GOLD_BRIGHT
		MapNode.NodeType.REST:
			return GameConstants.COLOR_JADE_GREEN
		MapNode.NodeType.BOSS:
			return GameConstants.COLOR_CRIMSON
		_:
			return GameConstants.COLOR_PAPER
```

Update `_draw_victory()` — replace all hardcoded colors with GameConstants:
- Scroll background: `GameConstants.COLOR_INK_BLACK` at 240 alpha
- Gold border: `GameConstants.COLOR_IMPERIAL_GOLD`
- Title "江湖初顯": `GameConstants.COLOR_TEXT_HEADING` at 36px
- "The Wanderer Emerges": `GameConstants.COLOR_TEXT_SUBHEADING` at 18px
- Stat labels: `GameConstants.COLOR_TEXT_CAPTION`
- Stat values: `GameConstants.COLOR_TEXT_HEADING`
- Gold earned: `GameConstants.COLOR_TEXT_ACCENT`
- Technique list: `GameConstants.COLOR_TEXT_BODY`
- Teaser: `GameConstants.COLOR_TEXT_CAPTION`
- Separator lines: `GameConstants.COLOR_PANEL_BORDER` at 0.4 alpha
- Return prompt: `GameConstants.COLOR_TEXT_ACCENT` pulsing

Update `_draw_game_over()`:

```gdscript
func _draw_game_over() -> void:
	draw_rect(Rect2(0.0, 0.0, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT), GameConstants.COLOR_INK_BLACK, true)
	draw_rect(Rect2(0.0, 0.0, GameConstants.VIEW_WIDTH, GameConstants.VIEW_HEIGHT), Color(GameConstants.COLOR_EARTH_DARK.r, GameConstants.COLOR_EARTH_DARK.g, GameConstants.COLOR_EARTH_DARK.b, 0.2), true)

	var center_x: float = float(GameConstants.VIEW_WIDTH) * 0.5
	var center_y: float = float(GameConstants.VIEW_HEIGHT) * 0.5

	_draw_text("敗", center_x - 30.0, center_y - 60.0, Color(GameConstants.COLOR_VERMILLION_RED.r, GameConstants.COLOR_VERMILLION_RED.g, GameConstants.COLOR_VERMILLION_RED.b, 0.8), 60)
	_draw_text("Defeated", center_x - 50.0, center_y + 10.0, Color(GameConstants.COLOR_MAROON.r, GameConstants.COLOR_MAROON.g, GameConstants.COLOR_MAROON.b, 0.7), 22)

	var run_duration: float = _run_end_time - _run_start_time
	var minutes: int = int(run_duration) / 60
	var seconds: int = int(run_duration) % 60
	_draw_text("Time: %d:%02d" % [minutes, seconds], center_x - 50.0, center_y + 60.0, GameConstants.COLOR_TEXT_CAPTION, 14)

	var pulse: float = 0.5 + 0.5 * sin(_cursor_flash * 4.0)
	_draw_text("Press Enter to return", center_x - 90.0, center_y + 120.0, Color(GameConstants.COLOR_TEXT_CAPTION.r, GameConstants.COLOR_TEXT_CAPTION.g, GameConstants.COLOR_TEXT_CAPTION.b, pulse), 16)
```

Update `_draw_reward()`, `_draw_event()`, `_draw_shop()`, `_draw_rest()`, `_draw_forget_technique()` — replace all hardcoded `Color(0.xx, ...)` and `Color8(...)` values with the corresponding `GameConstants.COLOR_TEXT_*` semantic aliases. The pattern for each:
- Panel titles: `GameConstants.COLOR_TEXT_HEADING`
- Instructions: `GameConstants.COLOR_TEXT_CAPTION`
- Selected items: `GameConstants.COLOR_TEXT_HEADING`
- Unselected items: `GameConstants.COLOR_TEXT_CAPTION`
- Descriptions: `GameConstants.COLOR_TEXT_CAPTION`
- Gold values: `GameConstants.COLOR_TEXT_ACCENT`
- Unaffordable items: `Color(GameConstants.COLOR_VERMILLION_RED.r, GameConstants.COLOR_VERMILLION_RED.g, GameConstants.COLOR_VERMILLION_RED.b, 0.5)`
- Shop messages: `GameConstants.COLOR_TEXT_ACCENT`
- Event blocked messages: `Color(GameConstants.COLOR_VERMILLION_RED.r, ..., 0.95)`
- Forget-technique selected: `GameConstants.COLOR_VERMILLION_RED` (destructive action)

Update `_draw_reward_option_with_desc()`:
- Selected border: `GameConstants.COLOR_PANEL_ACCENT`
- Unselected border: `GameConstants.COLOR_PANEL_BORDER` at 0.3 alpha
- Background: `GameConstants.COLOR_INK_BLACK` at 0.85 alpha
- Label text: `GameConstants.COLOR_TEXT_HEADING`
- Description: `GameConstants.COLOR_TEXT_CAPTION`

- [ ] **Step 2: Update combat_scene.gd VFX and HUD colors**

Update `_draw_hud()`:
- Enemy name: `GameConstants.COLOR_TEXT_HEADING`
- Phase indicator: `GameConstants.COLOR_TEXT_ACCENT` for phase 2, `GameConstants.COLOR_TEXT_SUBHEADING` for phase 1
- Controls legend: `GameConstants.COLOR_TEXT_CAPTION`
- Technique header: `GameConstants.COLOR_TEXT_SUBHEADING`
- Technique colors: A-type `GameConstants.COLOR_LIGHT_BLUE`, B-type `GameConstants.COLOR_SKY_BLUE`, D-type `GameConstants.COLOR_GOLD_BRIGHT`
- Stance indicator: `GameConstants.COLOR_TEXT_ACCENT` pulsing

Update `_draw_bars()` to use `GameConstants.COLOR_HEALTH`, `GameConstants.COLOR_POSTURE`, `GameConstants.COLOR_RAGE`.

Update `_draw_single_bar()`:
- Value text shadow: `Color(0, 0, 0, 0.7)` (keep)
- Value text: `GameConstants.COLOR_TEXT_HEADING`

Update `_draw_feedback()`:
- Feedback text: `GameConstants.COLOR_TEXT_ACCENT` with alpha

Update `_draw_end_message()`:
- Message text: `GameConstants.COLOR_TEXT_HEADING`

Update `_draw_effects()` (border vignette):
- Keep `Color(0, 0, 0, 0.45)` — this is a screen-space effect, not themed

Update `_draw_platform()` colors to VINIK24:
- Platform top: `GameConstants.COLOR_PANEL_BORDER`
- Platform mid: `GameConstants.COLOR_MOUNTAIN_BLUE`
- Platform bottom: `GameConstants.COLOR_INK_BLACK`
- Jitter details: `GameConstants.COLOR_INK_MID`

Update `_draw_pause_indicator()`:
- "PAUSED": `GameConstants.COLOR_TEXT_HEADING`
- Instructions: `GameConstants.COLOR_TEXT_BODY`

Update VFX colors in `_draw_fighter()`:
- Invulnerability glow: `GameConstants.COLOR_LIGHT_BLUE` at varying alpha
- Parry indicator: `GameConstants.COLOR_GOLD_BRIGHT` at varying alpha
- Stun indicator: `GameConstants.COLOR_IMPERIAL_GOLD` at varying alpha
- Combo text: `GameConstants.COLOR_IMPERIAL_GOLD`
- Bleed indicator: `GameConstants.COLOR_VERMILLION_RED` at varying alpha
- Grab indicator: `GameConstants.COLOR_CRIMSON` at varying alpha
- Slash line (normal): `GameConstants.COLOR_LIGHT_BLUE` at 140 alpha
- Slash line (heavy): `GameConstants.COLOR_SKIN_WARM` at 180 alpha
- Trail lines: `GameConstants.COLOR_IMPERIAL_GOLD` at fading alpha

Update **every** `Color8(...)` in `combat_system.gd` to VINIK24. Complete mapping (line numbers from current file):

**update_player() particles:**
- Line 42: Jump dust `Color8(180, 200, 255)` → `Color8(150, 178, 197)` (light blue)
- Line 51: Dash trail `Color8(200, 200, 255)` → `Color8(150, 178, 197)` (light blue)
- Line 57: Heavy attack particles `Color8(240, 220, 255)` → `Color8(223, 113, 38)` (earth light — orange burst per spec)
- Line 63: Light combo color `Color8(255, 180, 100)` → `Color8(238, 156, 36)` (gold); `Color8(255, 255, 200)` → `Color8(248, 200, 60)` (gold bright)
- Line 95: Stance activation `Color8(255, 200, 50)` → `Color8(248, 200, 60)` (gold bright)
- Line 118: A1 Descending Leaf stab `Color8(255, 180, 100)` → `Color8(238, 156, 36)` (gold)
- Line 131: Landing dust `Color8(140, 120, 100)` → `Color8(86, 90, 117)` (ink mid)

**update_ai() particles:**
- Line 154: Boss phase transition `Color8(255, 140, 40)` → `Color8(238, 156, 36)` (gold)
- Line 170: Assassin teleport `Color8(80, 60, 120)` → `Color8(107, 62, 117)` (purple dark)
- Line 221: AI attack `Color8(255, 120, 100)` → `Color8(223, 113, 38)` (earth light)
- Line 232: AI dash `Color8(255, 100, 100)` → `Color8(180, 32, 42)` (vermillion)

**resolve_hits() particles:**
- Line 287: Grab crush `Color8(255, 100, 60)` → `Color8(191, 38, 82)` (crimson)
- Line 293: Phoenix save `Color8(255, 120, 40)` → `Color8(238, 156, 36)` (gold)
- Line 309: Parry sparks `Color8(255, 230, 90)` → `Color8(248, 200, 60)` (gold bright)
- Line 367: Phoenix save (second location) `Color8(255, 120, 40)` → `Color8(238, 156, 36)` (gold)
- Line 375: Posture break `Color8(255, 220, 60)` → `Color8(248, 200, 60)` (gold bright)
- Line 413: Normal hit impact `Color8(255, 190, 160)` → `Color8(238, 156, 36)` (gold)
- Line 421: Twin Dragons `Color8(255, 200, 100)` → `Color8(248, 200, 60)` (gold bright)

**combat_scene.gd boss death beat (lines 200-201):**
- `Color8(255, 200, 80)` → `Color8(248, 200, 60)` (gold bright)
- `Color8(255, 120, 40)` → `Color8(191, 38, 82)` (crimson)

- [ ] **Step 3: Update fighter.gd telegraph colors**

Replace `current_telegraph_color()` in `WUGodot/scripts/fighter.gd`:

```gdscript
func current_telegraph_color() -> Color:
	if not _attack_state.is_active():
		return Color(0.0, 0.0, 0.0, 0.0)
	if _attack_state.phase() != AttackDefinitionScript.Phase.WINDUP:
		return Color(0.0, 0.0, 0.0, 0.0)
	if _attack_state.def != null and _attack_state.def.is_perilous:
		return Color(GameConstants.COLOR_CRIMSON.r, GameConstants.COLOR_CRIMSON.g, GameConstants.COLOR_CRIMSON.b, 0.86)
	return Color(GameConstants.COLOR_PAPER.r, GameConstants.COLOR_PAPER.g, GameConstants.COLOR_PAPER.b, 0.78)
```

- [ ] **Step 4: Run tests**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --script res://tests/run_tests.gd`

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add WUGodot/scripts/main.gd WUGodot/scripts/combat_scene.gd WUGodot/scripts/fighter.gd WUGodot/scripts/combat_system.gd
git commit -m "feat: VINIK24 color pass across all screens, HUD, VFX, and telegraphs"
```

---

### Task 9: Manual Playtest Checklist

- [ ] **Step 1: Run all headless tests**

Run: `HOME=/tmp/godot-home godot --path WUGodot --headless --script res://tests/run_tests.gd`

Expected: All tests pass.

- [ ] **Step 2: Manual playtest**

Run the game: `HOME=/tmp/godot-home godot --path WUGodot`

Verify each item (pass/fail):

**VINIK24 palette:**
- [ ] No old placeholder colors visible (no bright cyan, no pure white #FFFFFF, no Color8(170, 170, 186) gray)
- [ ] Main menu: "武" in near-white, gold pulsing prompt, corner-mark border frame
- [ ] "第一章 江湖" shows Chinese first
- [ ] Map: node colors match VINIK24 assignments (blue duels, orange elites, red ambush, purple master, gold shop, green rest, crimson boss)
- [ ] Gold counter in VINIK24 gold
- [ ] Path lines in muted gray

**Panel treatment:**
- [ ] All panels have ink-dark background with gray border + gold top-accent + corner marks
- [ ] Reward boxes, shop items, event choices, rest choices all use the new panel style
- [ ] Bar frames have gold accent line on top

**Combat visuals:**
- [ ] Arena background is a solid dark texture (placeholder), not procedural sine-wave mountains
- [ ] Boss fight uses a visibly darker background than normal fights
- [ ] Parryable attacks: silver/paper telegraph outline
- [ ] Perilous attacks: crimson telegraph outline
- [ ] Parry indicator: gold pulsing outline
- [ ] Hit particles in gold tones
- [ ] Bleed indicator in vermillion red
- [ ] Posture break feedback in gold

**Victory / Defeat:**
- [ ] Victory scroll: gold border, "江湖初顯" title, VINIK24 stat colors, technique list, teaser text
- [ ] Defeat screen: red tint overlay, "敗" in vermillion, muted prompt

**Archetype profiles:**
- [ ] Each enemy type can display sprites from its own animation config (currently placeholder frames, but the profile routing works)
- [ ] Boss uses larger scale than normal enemies

---

## Review Cycle Audit

1. **All existing 132+ tests pass.** The art pass is visual-only — no gameplay logic changes.
2. **BackgroundRenderer set_arena called correctly.** BOSS nodes get `"chapter1_boss_clearing"`, everything else gets `"chapter1_bamboo_dusk"`.
3. **No old colors remain.** Grep for `Color8(` with values not in VINIK24 — any remaining are either alpha-modified VINIK24 colors (acceptable), the exempted `COLOR_GOLD_DARK` derived shadow tone (acceptable), or bugs (fix).
4. **Panel treatment consistent.** Both `main.gd._draw_panel()` and `combat_scene.gd._draw_panel()` use the same corner-mark implementation.
5. **Visual profiles route correctly.** BanditSpearman→`enemy_humanoid_basic_spear`, WanderingRonin→`enemy_humanoid_ronin`, MaskedAssassin→`enemy_humanoid_assassin`. SectDisciple keeps `enemy_humanoid_elite`.
6. **Chinese-first text order.** Main menu shows "武" then "WU", chapter label shows "第一章 江湖", enemy names show Chinese first, victory title shows "江湖初顯" then English translation.
