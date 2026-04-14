# WU Milestone 1 — Art Pass Design Spec

*Design pass: 2026-04-14. Outcome of a brainstorm session refining the Milestone 1 art direction from the MVP spec's growth ladder.*

## Framing

This spec defines the visual target for Milestone 1 (Art Pass) — the first post-MVP milestone. The MVP ships with geometric SVG placeholders that have honest animation timing. Milestone 1 replaces those placeholders with production pixel art while preserving all gameplay code and timing.

This spec supersedes the visual target sections of `docs/ART_DESIGN_DOC.md` where they conflict. The ART_DESIGN_DOC remains the reference for the diorama presentation vision (parallax, window frame) which is deferred to a later milestone.

**Decisions locked during brainstorm:**

1. Character resolution: 64x64px sprite frames, characters 48-56px tall within the frame.
2. Body proportions: 5-6 head ratio (adult martial artist, not chibi).
3. Visual style: Detailed pixel art — readability-first. Silhouette clarity wins over costume detail. 6-8 colors per character, no fine texture or dithering.
4. Palette: VINIK24 (24 colors). Foreground/background value separation enforced (backgrounds 0-40% value, fighters 40-80%, highlights 80-100%).
5. Animation approach: Hybrid — sacred keyframes (pixel-crisp authored poses, 25-27 per archetype) + procedural interpolation (engine-driven position/scale, never modifies the sprite).
6. Arena backgrounds: 2 painted backdrops for Chapter 1 (standard bamboo dusk + boss clearing variant). Architecture supports future dynamic/battle-responsive backgrounds.
7. Text order: Chinese first, English as translation. "武" then "WU", "江湖初顯" then "The Wanderer Emerges".
8. Production pipeline: AIexp tools (image-gen → pixel-converter → sprite-sheet) with manual cleanup.

---

## Section 1 — Character Sprites

### Resolution and proportions

Sprite frames are 64x64 pixels. Characters stand 48-56px tall within the frame, leaving headroom for weapon reach, jump clearance, and topknots. The 5-6 head-to-body ratio reads as an adult fighter — serious martial artist proportions, not chibi.

Scale differentiation by role:
- **Player (Hu):** ~52px tall. Standard frame.
- **Easy enemies (Bandits):** ~50px tall. Slightly smaller, reads as lesser threat.
- **Medium enemies (Ronin):** ~52px tall. Player-height, mirror-match feel.
- **Hard enemies (Disciple, Assassin):** ~54px tall. Slightly imposing.
- **Boss (Xiong Tie):** ~60px tall, ~36px wide. Uses the full frame. Massive presence.

### Art style

Detailed pixel art in the VINIK24 palette (24 colors). **Readability-first rule: when costume detail competes with silhouette clarity at combat speed, silhouette wins.** Detail is applied to reinforce shape (sash emphasizes waist, robe edge emphasizes stance width) not to decorate.

Characters use 6-8 colors from the palette per archetype (not 12). Internal detail is limited to: one robe overlap line, one belt/sash band, one weapon shape. No fine texture within cloth or leather — material reads through value contrast (light cloth vs dark leather) not through dithering or internal pattern.

Dark outlines (`#0f0f1b` from VINIK24) on all characters for consistent readability against any background.

VINIK24 color assignments:
- **Skin:** `#c6b7be` (light), `#f49e4c` for warmer/tanned skin.
- **Cloth (player blue):** `#20394f` → `#255674` → `#577399` (3-step ramp, not 4).
- **Cloth (bandit earth):** `#3b1725` → `#ab5236` → `#df7126`.
- **Metal/weapon:** `#565a75` → `#c6b7be`.
- **Gold trim/accent:** `#ee9c24`.
- **Leather/boots:** `#73172d` → `#ab5236`.

### Archetype visual language

Each of the 7 character types has a distinct silhouette and color identity so the player can identify them instantly at combat speed.

| Character | Dominant Palette | Distinguishing Features | Silhouette Cue |
|-----------|-----------------|------------------------|----------------|
| **Hu (player)** | Blue ramp (`#20394f` → `#577399`) | Gold sash, topknot, sword at hip | Upright stance, robe flows right |
| **Bandit Swordsman** | Brown/earth (`#ab5236`, `#df7126`) | Red headband, rough tunic, bare arms | Hunched, wide sword grip |
| **Bandit Spearman** | Brown/tan (`#ab5236`, `#d9a066`) | Long spear extending past frame, conical hat | Tall vertical weapon line |
| **Wandering Ronin** | Muted blue-gray (`#565a75`, `#577399`) | Tattered robe, straw hat, two-handed grip | Wide hat silhouette, low guard |
| **Sect Disciple** | Orange/gold (`#df7126`, `#ee9c24`) | Clean ornate robes, bound hair, upright posture | Symmetrical, formal stance |
| **Masked Assassin** | Dark purple/black (`#0f0f1b`, `#6b3e75`) | Cloth mask covering lower face, short blade, crouched | Low crouch, compact shape |
| **Xiong Tie (boss)** | Red-brown (`#ab5236`, `#b4202a`) | Massive frame, bare chest under open robe, iron staff across shoulders, diagonal scar | Widest silhouette, staff horizontal |

### Animation keyframes

The hybrid animation system has two layers with distinct responsibilities:

**Sacred keyframes (authored, pixel-crisp):** These are the AI-generated, manually-cleaned sprite frames. Each must be a clear, held pose with correct proportions and clean silhouette. No motion blur, no smearing, no in-between ambiguity. Every sacred frame must pass the "screenshot test" — readable as a still image.

**Procedural interpolation (engine-driven, code):** The engine's existing `animation_offset` system adds fluid motion between sacred frames. This layer handles: position tweening (lerp between frame offsets), sine-wave breathing (idle bob), attack-progress lean (body shifts forward during commit), dash stretch (horizontal squash), landing squash (vertical compress). Procedural motion never modifies the sprite itself — it moves, scales, and rotates the frame.

**The boundary is strict:** authored frames own the silhouette; code owns the motion. If a frame looks wrong as a still, fix the frame. If the motion between frames feels stiff, tune the code interpolation.

| Clip | Sacred Frames | Poses (each pixel-crisp) | Procedural Layer | Loop |
|------|--------------|--------------------------|-----------------|------|
| IDLE | 2 | Standing neutral, breath offset | Sine-wave Y offset (±2px) | Yes |
| WALKING | 4 | Contact R, passing R, contact L, passing L | Y bob (±1px per step) | Yes |
| ATTACKING (light) | 3 | Wind-up raise, active slash extended, recovery return | X lean toward target during commit | No |
| ATTACKING (heavy) | 3 | Deep wind-up crouch, powerful strike, slow recovery | Slower X lean, longer hold on frame 2 | No |
| HIT_REACTION | 2 | Recoil backward, return to neutral | X shake (±4px, decaying) | No |
| BLOCKING | 2 | Guard raised, guard braced | Y bob (±1.5px, slow) | No |
| STUNNED | 2 | Stagger off-balance, slumped | X+Y oscillation (drunken sway) | Yes |
| DASHING | 2 | Launch lean, stop plant | X squash-stretch (wide during dash, snap on stop) | No |
| JUMPING | 2 | Crouch launch, airborne tuck | Y offset follows physics arc | No |
| FALLING | 1 | Falling pose | None (gravity handles Y) | No |
| LANDING | 2 | Impact crouch, stand recovery | Y squash on impact (±3px) | No |

**Totals:**
- 25-27 sacred keyframes per archetype
- 7 archetypes = ~175-189 keyframes total
- At 64x64 pixels, this is the primary art production cost

### Silhouette readability rule

Every enemy attack must have a unique silhouette during its wind-up phase (first 3-5 frames). The player identifies the incoming attack by the enemy's body shape during wind-up, not by color or particle effects. This is inherited from the MVP spec's readability discipline and constrains attack animation design:

- Horizontal slash: weapon arm extends wide.
- Overhead: weapon raised above head.
- Thrust: body leans forward, weapon pointed ahead.
- Sweep: low crouch, weapon horizontal.
- Grab: both arms open wide.
- Charge: low wide stance, shoulders forward.

---

## Section 2 — Arena Backgrounds

### Milestone 1 approach

Two painted backdrop images for Chapter 1: a standard arena and a boss arena variant.

**Standard arena: bamboo road at dusk.** Used for all Duel, Elite, Ambush, and Event-triggered combat nodes.

**Boss arena: Iron Bear's clearing.** A darker, more enclosed variant — the bamboo presses closer, the sky is deeper (`#20394f` dominant, less warm), ground is rougher stone. Visually signals "this is the destination." Used only for the Boss node.

The background is a wide image (1920x1080 or wider for minor camera parallax) rendered in VINIK24 tones.

**Foreground/background value separation rule:** The background must stay in the dark-to-mid value range so fighters (who use mid-to-light values) read clearly against it. Specifically:
- Background colors are restricted to value band 0-40% (VINIK24 darks: `#0f0f1b`, `#3b1725`, `#20394f`, `#2c4a2e`, `#565a75`).
- Fighter bodies use value band 40-80% (mid ramps: `#ab5236`, `#577399`, `#6b3e75`, etc.).
- Highlights and accents (skin, weapon gleam, gold trim) use value band 80-100% (`#c6b7be`, `#ee9c24`, `#faf6f6`).
- **No warm orange/earth above 40% value in the background.** The sky gradient uses the dark end of the warm ramp (`#3b1725` → `#74233c`) not the mid-bright oranges that fighters share.

The background depicts:
- Gradient sky in dark warm tones (`#3b1725` → `#74233c` → `#20394f` top-to-bottom).
- Far mountain silhouettes in dark blue-gray (`#0f0f1b`, `#20394f`).
- Mid-ground bamboo tree silhouettes in near-black (`#0f0f1b`).
- Ground platform in dark stone (`#565a75`, `#20394f`) with minimal earth-tone detail.

The background is loaded as a texture and drawn behind the fighters, replacing the current procedural sine-wave mountains in `combat_scene.gd`.

### Architecture for future dynamic backgrounds

The rendering architecture should separate the background into a swappable layer with a defined interface, so future milestones can replace the static image with:
- Multi-layer parallax (3-5 layers responding to camera position).
- Battle-responsive effects (sky darkens during boss phase 2, lightning on posture break, ink wash on parry).
- Per-chapter arena themes (bamboo road, temple courtyard, graveyard).

Implementation: the background is a `BackgroundRenderer` class with:
- `set_arena(arena_id: String)` — loads the appropriate background texture. Called by `CombatScene.setup_combat()` based on node type (`"chapter1_boss_clearing"` for BOSS nodes, `"chapter1_bamboo_dusk"` for all others).
- `draw(canvas, camera_offset, battle_state)` — renders the current background. Milestone 1's implementation ignores `battle_state` and draws the loaded static image. Future implementations read battle state to drive dynamic effects (sky tint, weather, lighting shifts).

---

## Section 3 — VFX Style

### Particle effects

Current particle system (100 particles, radial spawn, gravity, alpha fade) is preserved. Color palette shifts to VINIK24:

| Effect | Current Color | VINIK24 Color | Notes |
|--------|--------------|---------------|-------|
| Normal hit | `(255, 200, 80)` | `#f8c83c` / `#ee9c24` | Gold sparks |
| Heavy hit | `(255, 120, 40)` | `#df7126` / `#ab5236` | Orange burst |
| Parry | `(255, 230, 90)` | `#f8c83c` / `#faf6f6` | Bright gold/white ring |
| Posture break | `(255, 220, 60)` | `#ee9c24` / `#f8c83c` | Gold burst + kanji |
| Dash trail | `(200, 200, 255)` | `#96b2c5` / `#a1d2e0` | Cool blue wisps |
| Boss death | `(255, 200, 80)` | `#f8c83c` / `#bf2652` | Gold + vermillion burst |
| Bleed | `(180, 30, 30)` | `#b4202a` / `#74233c` | Dark red drip |
| Technique activation | `(255, 200, 50)` | `#ee9c24` / `#a884f3` | Gold + purple qi |

### Telegraph outlines

Existing outline system (pulsing colored border around fighter during wind-up) is preserved but colors shift:
- **Parryable attacks:** Silver-white outline → `#c6b7be` (VINIK24 light gray).
- **Perilous attacks:** Red outline → `#bf2652` (VINIK24 crimson).
- **Parry window active:** Yellow outline → `#f8c83c` (VINIK24 bright gold).

### Future VFX (not Milestone 1)

These are noted for future milestones, not implemented in Milestone 1:
- Ink-splash parry VFX (splatter pattern on successful parry).
- Kanji burst on posture break (破 character rendered as particle cluster).
- Qi aura on rage activation / stance swap.
- Ink wash screen transition (wipe between scenes).

---

## Section 4 — UI Design Language

Milestone 1 introduces a cohesive visual language for all non-combat screens and the combat HUD. This is not a color swap — it establishes the ornamental vocabulary, typographic hierarchy, and panel treatment that makes the game feel authored.

### Design principles

1. **Wuxia scroll aesthetic.** Panels are styled as weathered parchment with ink borders — not modern glass/shadow UI. Every panel is a "document" within the game world.
2. **Ink and gold hierarchy.** Ink-dark (`#0f0f1b`) backgrounds, parchment-warm (`#c6b7be`, `#faf6f6`) text, gold (`#ee9c24`) for interactive highlights and ornamental accents. Red (`#b4202a`) reserved for danger/damage.
3. **Chinese-first typographic order.** Chinese characters appear first, English translation second. Examples: "武" then "WU", "江湖初顯" then "The Wanderer Emerges", "匪劍" then "Bandit Swordsman". Chinese at larger display sizes for emotional weight, English translation at smaller sizes for comprehension. No pinyin — either Chinese characters or English translation.
4. **Sparse ornament, not decoration.** Corner marks (two short perpendicular lines at panel corners), single horizontal rule dividers, thin gold border lines. No filigree, no repeating patterns, no gradients.

### Panel treatment

All panels (HUD frames, menu panels, reward boxes, shop inventory, event text) share one visual language:
- Background: `#0f0f1b` at 90% opacity (ink wash over dark background).
- Border: 2px `#565a75` (gray) outer line.
- Accent: 1px `#ee9c24` (gold) inner line on top edge only (like a scroll's gilded binding).
- Corner marks: 6px perpendicular lines in `#565a75` at each corner (replaces the current full-border rectangle).
- Internal dividers: 1px `#565a75` horizontal rules between sections.

### Typographic hierarchy

| Level | Use | Color | Size |
|-------|-----|-------|------|
| Display | Kanji titles ("武", "破山", "敗") | `#faf6f6` | 48-80px |
| Heading | Screen titles, enemy names | `#faf6f6` | 20-24px |
| Subheading | Chinese subtitles, section labels | `#c6b7be` | 16-18px |
| Body | Descriptions, event text, stats | `#96b2c5` | 14-15px |
| Caption | Controls legend, prompts, flavor text | `#565a75` | 12-13px |
| Accent | Interactive highlights, gold values | `#ee9c24` | Same as context |

### HUD

Layout preserved. Visual treatment updated:
- Bar backgrounds: `#0f0f1b`.
- Bar frames: corner-mark style (not full rectangle), `#565a75` lines with `#ee9c24` gold accent on top edge.
- Health fill: `#b4202a`. Posture fill: `#ee9c24`. Rage fill: `#4e8339`.
- Numeric values: `#faf6f6` with 1px `#0f0f1b` shadow for readability over bars.
- Enemy name: Chinese name in `#faf6f6` at subheading size, romanized in `#c6b7be` at body size.
- Technique list: type-colored (A=`#96b2c5`, B=`#a1d2e0`, D=`#f8c83c`), Chinese name first.

### Map screen

- Background: `#0f0f1b` solid.
- Node circles: 12px radius, type-colored (Duel=`#577399`, Elite=`#df7126`, Ambush=`#b4202a`, Master=`#905ea9`, Event=`#96b2c5`, Shop=`#f8c83c`, Rest=`#4e8339`, Boss=`#bf2652`).
- Path lines: `#565a75` at 30% opacity.
- Selected node: `#ee9c24` ring + corner-mark cursor (replaces current arc + dot cursor).
- Title: "江湖" in display size, "Path Select" in heading size.
- Gold display: `#ee9c24`, right-aligned.

### Main menu

- Background: `#0f0f1b` solid with corner-mark border (replacing the current thin rectangle).
- Title: "武" in display kanji (`#faf6f6`, 80px), "W U" below in heading (`#c6b7be`).
- Subtitle: body text, `#565a75`.
- Start prompt: `#ee9c24` pulsing, body size.
- Chapter label: "第一章 江湖" in subheading, `#565a75`.

### Victory scroll

- Scroll panel: `#0f0f1b` background, `#ee9c24` gold border (3px), corner marks in `#565a75`.
- Title: "江湖初顯" in display kanji, "The Wanderer Emerges" in heading.
- Stats: label in caption color, value in heading color. Gold value in accent.
- Technique list: each technique in body text, Chinese name first.
- Teaser: caption color, italic-style (smaller, lighter).
- Return prompt: `#ee9c24` pulsing.

### Defeat screen

- Background: `#0f0f1b` with subtle red tint (`#3b1725` at 20% opacity overlay).
- "敗" in display kanji, `#b4202a`.
- "Defeated" in heading, `#74233c`.
- Run time: body text, `#565a75`.
- Return prompt: `#565a75` pulsing (muted, not gold — defeat is quiet).

### Shop / Event / Rest / Forget screens

All follow the panel treatment above. Specific additions:
- **Shop:** item prices in `#ee9c24`. Unaffordable items dim to `#565a75`. Selected item has gold accent left-border.
- **Event:** choice text in body size. Selected choice in `#faf6f6`, unselected in `#565a75`. Outcome text in `#ee9c24`.
- **Rest:** two choices styled as shop items (gold accent on selected).
- **Forget technique:** technique list with red accent (`#b4202a`) on selected item (destructive action color).

---

## Section 5 — Production Pipeline

### Asset generation workflow

The AIexp toolchain at `/Users/animula/GitReps/AIexp` provides the production pipeline:

**Step 1: Static character sprite**
- Tool: `pixel-art-from-image-gen` (experiment 1)
- Input: Per-archetype prompt describing costume, pose, proportions, mood
- Style preset: `sprite` (full-body character, strong silhouette)
- Output: 64x64 VINIK24-quantized character PNG

**Step 2: Animation sprite sheets**
- Tool: `sprite-animation` (experiment 2)
- Input: Static character PNG as reference + action prompt (e.g., "walk-cycle", "sword slash")
- Output: Horizontal sprite sheet → split into individual frame PNGs

**Step 3: Palette quantization and cleanup**
- Tool: `pixel-converter`
- Input: Raw frames from Step 2
- Palette: VINIK24 (needs to be added to AIexp's `/tools/palettes/` presets)
- Output: Palette-perfect 64x64 frame PNGs with no antialiasing bleed

**Step 4: Assembly and export**
- Tool: `sprite-sheet`
- Input: Cleaned frame PNGs
- Output: Individual frames saved to `WUGodot/assets/sprites/characters/{archetype}/`
- Preview: Animated GIF for visual verification

**Step 5: Manual cleanup**
- Review each frame for: broken silhouettes, palette drift, proportion inconsistency, weapon detachment
- Fix artifacts in any pixel editor (Aseprite, Piskel, or similar)
- This step is expected for every archetype — AI generation is a starting point, not a finished product

**Step 6: Integration**
- Update animation JSON config at `WUGodot/assets/animations/` with new frame paths and timing
- Update visual profiles at `WUGodot/data/VisualProfiles/` with per-archetype animation set references
- Test in-game at combat speed for readability

### Arena background generation

Two backgrounds are generated for Chapter 1:

**Standard arena (bamboo road at dusk):**

1. Generate via `pixel-art-from-image-gen` with style preset `background`
   - Prompt: "dark bamboo forest road, mountains in far background, muted dusk sky in deep maroon and dark blue tones, Chinese landscape silhouette composition, very dark color values, no bright warm colors"
2. Convert to VINIK24 via `pixel-converter` — verify all colors fall in the 0-40% value band (darks only: `#0f0f1b`, `#3b1725`, `#74233c`, `#20394f`, `#2c4a2e`, `#565a75`)
3. Manual cleanup — ensure ground platform area is clear for fighter placement, adjust horizon line to match `GameConstants.GROUND_Y`, remove any mid-bright warm tones that survived quantization
4. Export as `WUGodot/assets/backgrounds/chapter1_bamboo_dusk.png`

**Boss arena (Iron Bear's clearing):**

1. Generate with same tools
   - Prompt: "dark enclosed forest clearing at night, bamboo pressing close, deep blue-black sky, rough stone ground, oppressive mood, very dark, no warm bright colors"
2. Same VINIK24 conversion and value-band verification
3. Manual cleanup — darker overall than standard, sky dominated by `#20394f` not `#74233c`
4. Export as `WUGodot/assets/backgrounds/chapter1_boss_clearing.png`

### VINIK24 palette preset

Add VINIK24 to AIexp's palette system at `/Users/animula/GitReps/AIexp/tools/palettes/`:

```json
{
  "name": "vinik24",
  "colors": [
    "#0f0f1b", "#565a75", "#c6b7be", "#faf6f6",
    "#f49e4c", "#ab5236", "#bf2652", "#74233c",
    "#3b1725", "#73172d", "#b4202a", "#df7126",
    "#ee9c24", "#f8c83c", "#4e8339", "#2c4a2e",
    "#20394f", "#255674", "#577399", "#96b2c5",
    "#a1d2e0", "#6b3e75", "#905ea9", "#a884f3"
  ]
}
```

---

## Section 6 — Godot Integration

### File structure changes

**New asset directories:**
```
WUGodot/assets/sprites/characters/hu/            — Player keyframes
WUGodot/assets/sprites/characters/bandit_sword/   — Bandit Swordsman keyframes
WUGodot/assets/sprites/characters/bandit_spear/   — Bandit Spearman keyframes
WUGodot/assets/sprites/characters/ronin/          — Wandering Ronin keyframes
WUGodot/assets/sprites/characters/disciple/       — Sect Disciple keyframes
WUGodot/assets/sprites/characters/assassin/       — Masked Assassin keyframes
WUGodot/assets/sprites/characters/iron_bear/      — Xiong Tie keyframes
WUGodot/assets/backgrounds/                       — Arena backdrop PNGs
```

**Modified files:**
- `WUGodot/assets/animations/` — Per-archetype animation JSON configs replacing the single shared `character_humanoid.json`.
- `WUGodot/data/VisualProfiles/DefaultProfiles.json` — Each profile points to its archetype-specific animation set.
- `WUGodot/scripts/visual/fighter_visual.gd` — No structural changes; the data-driven system already supports per-profile animation sets. May need minor adjustments for 64px frame size (current placeholder is 72x96 SVG).
- `WUGodot/scripts/combat_scene.gd` — Replace procedural `_draw_arena()` with background texture rendering via a `BackgroundRenderer` class.
- `WUGodot/scripts/game_constants.gd` — Update color constants to VINIK24 values.
- `WUGodot/scripts/main.gd` — Update main menu, victory, defeat screen colors to VINIK24.
- `WUGodot/scripts/combat_scene.gd` — Update HUD colors, particle colors, telegraph colors to VINIK24.

### BackgroundRenderer interface

```gdscript
class_name BackgroundRenderer
extends RefCounted

func set_arena(arena_id: String) -> void
func draw(canvas: CanvasItem, camera_offset: Vector2, battle_state: Dictionary) -> void
```

`set_arena()` is called by `CombatScene.setup_combat()`:
- BOSS nodes → `set_arena("chapter1_boss_clearing")`
- All other combat nodes → `set_arena("chapter1_bamboo_dusk")`

The `battle_state` dictionary is empty in Milestone 1. Future milestones populate it with: `{phase: int, hp_percent: float, posture_broken: bool, last_parry_time: float}` etc.

### Preserving the placeholder pipeline

The old SVG placeholders and `humanoid_placeholder/` directory remain in the repo as a fallback. The animation system's existing fallback (magenta checkerboard for missing textures) ensures the game runs even if some archetype sprites aren't yet authored.

---

## Scope Boundary

### In scope for Milestone 1 (this spec)

1. 7 character archetypes fully sprited (player + 5 enemies + 1 boss) at 64x64 in VINIK24.
2. 11 animation clips per archetype (25-27 sacred keyframes each).
3. 2 arena backgrounds (standard bamboo dusk + boss clearing variant).
4. UI design language pass: panel treatment, typographic hierarchy, corner-mark ornament, Chinese-first text order across all screens (HUD, map, menus, shop, event, rest, victory, defeat).
5. VINIK24 color pass on all particle/VFX colors.
6. BackgroundRenderer abstraction for future dynamic backgrounds.
7. VINIK24 palette preset added to AIexp pipeline.

### Explicitly out of scope

- Parallax backgrounds (future milestone).
- Diorama window frame presentation (future milestone).
- Battle-responsive dynamic backgrounds (future milestone — architecture is laid, implementation waits).
- Ink-splash parry VFX, kanji particle burst, qi aura (future milestone).
- Technique icons (remain text-only in Milestone 1).
- SFX and music (separate milestone, no audio assets exist).
- Additional arena themes beyond Chapter 1 (Chapter 2/3 arenas come with those content milestones).

---

## Content Budget

| Asset Type | Count | Est. Production |
|-----------|-------|-----------------|
| Character archetypes (64x64, 11 clips each) | 7 | ~182 sacred keyframes |
| Arena backgrounds (1920x1080) | 2 | Standard + boss variant |
| Animation JSON configs | 7 | 7 config files |
| Visual profile updates | 7 | JSON edits |
| UI design language pass | 1 | Panel treatment + typographic hierarchy + ornament code |
| VFX color pass | 1 | Particle/telegraph color code edits |
| VINIK24 palette preset | 1 | 1 JSON file in AIexp |

Total production: ~182 sacred keyframes + 2 backgrounds + UI language implementation + config updates. The AI pipeline handles initial generation; manual cleanup is expected for every frame.
