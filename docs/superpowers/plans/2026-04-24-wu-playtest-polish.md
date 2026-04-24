# WU Playtest Polish Plan

**Date:** 2026-04-24
**Source:** Playtest captures at `/tmp/wu-playtest-2026-04-24/` (16 states, from main menu through victory/defeat).
**Revision:** 3 — rev 2 added background/panel/map/game-over/boss-beat corrections; rev 3 fixes font wiring, pixel-scale factors, and a stale evidence bullet + Rect2 values. See `## Revision notes` at the bottom.

---

## Findings summary

| # | Priority | Issue |
|---|---|---|
| 1 | P0 | CJK characters render as tofu (▯) across the UI |
| 2 | P1 | Boss arena reads identical to duel arena — no visual escalation |
| 3 | P1 | Non-combat panels have weak readability and vast dead space |
| 4 | P2 | Main menu and map feel under-dressed |
| 5 | P2 | Reward / Victory screens feel sparse |
| 6 | P3 | Small housekeeping: game-over restart prompt, HUD crowding, debug hitbox, boss-beat FX scale |

---

## P0 — CJK font fallback (tofu everywhere)

**Evidence.** Tofu boxes appear *everywhere Chinese is expected*:

- `01_main_menu.png` — bottom tagline (`武者…`)
- `02_map.png` — "Path Select" header icon
- `03_reward_technique.png` — every technique name ornament (`(疤痕)`, `(麻雀)`, `(千里)`)
- `05_event_choice.png` / `06_event_result.png` — event title ornament
- `07_shop.png` — stance labels `(虎步)` inline with item names
- `10_combat_duel.png` through `14_combat_boss_death.png` — enemy name tag ornament and the technique list (`落葉`, `山鳴`, `醉拳`)
- `15_victory.png` — chapter heading ornament and technique glyphs

**Root cause.** `WUGodot/scripts/{main,combat_scene,combat_debug_overlay,damage_number_system}.gd` all call `ThemeDB.fallback_font`. No font resource is shipped in `assets/` (no `.ttf` / `.otf`). Godot's internal fallback on macOS does not cover Han glyphs, so every CJK codepoint renders as ▯. The art spec (section 3 of `docs/superpowers/specs/2026-04-14-art-pass-design.md`) mandates Chinese-first typography — nothing in the repo currently loads a CJK font.

**Fix.**

Important: the WU UI is **almost entirely custom-drawn via `draw_string()`** helpers that fetch `ThemeDB.fallback_font` directly and pass **explicit pixel sizes** as the final argument. See:
- `main.gd:857` (`_draw_text`)
- `combat_scene.gd:523` (its local `_draw_text`)
- `damage_number_system.gd:51`
- `combat_debug_overlay.gd:54`

A `project.godot` `gui/theme/custom_font` entry will **only affect Godot `Control` nodes**, of which this project has very few. It does **not** reach these custom helpers, and explicit pixel sizes in `draw_string` calls will continue to ignore any `default_font_size` the theme declares.

Steps, in order:

1. Add `WUGodot/assets/fonts/` with one open-licence CJK family:
   - Body: **Noto Sans SC** (OFL) or a pixel CJK face like **Zpix** for the pixel aesthetic.
   - Display / headings: **Noto Serif SC** cut at a larger size.
2. Create a simple `res://scripts/visual/fonts.gd` autoload that exposes `body()`, `display()`, etc. Each returns a preloaded `FontFile` resource.
3. **Migrate every custom helper** to use the autoload instead of `ThemeDB.fallback_font`:
   - `main.gd:857` / `combat_scene.gd:523` / `damage_number_system.gd:51` / `combat_debug_overlay.gd:54`.
4. For any future Control-based screen, also create `res://assets/fonts/theme.tres` and set `gui/theme/custom_font` in `project.godot` so `Control` nodes inherit the same family. (Not sufficient alone — see step 3.)
5. **Font-size changes are code edits.** The current `_draw_text(..., 14|16|17|20|24)` sizes are baked in at each call site. The readability pass (P1 panels) must edit those integer arguments — a theme `default_font_size` will not affect them.
6. Verify after headless reimport by screenshotting the menu + one combat scene; confirm no `▯` remains.

**Effort.** ~1.5h (was 1h). The helper migration across four files is small but easy to miss a call site; budget for a `grep` sweep of `draw_string` / `_draw_text` / `COLOR_TEXT_` to confirm coverage.

---

## P1 — Boss arena reads identical to duel arena

**Evidence.** `10_combat_duel.png` and `13_combat_boss.png` differ only in the HUD name tag and the enemy sprite. Both backdrops are gentle vertical gradients with a thin horizontal ground line. The Chapter 1 climax never feels like a distinct destination.

**Root cause.** The shipped backgrounds are placeholder gradients that were never replaced:

- `chapter1_bamboo_dusk.png` — maroon → navy gradient, no landscape content.
- `chapter1_boss_clearing.png` — near-black → navy gradient, no landscape content.

The spec (section 5 of `2026-04-14-art-pass-design.md`, lines 310–324) calls for bamboo silhouettes, mountains, rough stone ground, and an oppressive framing for the boss arena.

**Fix — two options, pick A now and B later.**

### Preconditions (read before running option A)

- `aiexp` is **not on PATH** in fresh shells. Use the absolute path `/Users/animula/GitReps/AIexp/.venv/bin/aiexp` or activate the venv first.
- `pixel-art run` writes to a timestamped run directory under `~/.aiexp/pixel-art/runs/<slug>/`, not to a named output path. There is no `--out` flag; copy the primary result into `WUGodot/assets/backgrounds/` after generation.
- The game viewport is **1920×1080** (`GameConstants.VIEW_WIDTH/HEIGHT`), and `scripts/visual/background_renderer.gd:20` draws textures at their **native pixel size** with no viewport scaling. If you generate at a low resolution (e.g. 320×180) the result will render as a small stamp in the corner. Either:
  - generate at a size that matches the viewport, **or**
  - add explicit scaling in `background_renderer.gd` (scale factor = `VIEW_WIDTH / texture.get_width()`) before adopting lower-resolution backdrops.
- `pixel-art run` uses `--size <int>` (single short-edge size) or `--sizes a,b,c` (list). It cannot be given a `WxH` string.
- **Pixel-scale must be integer** to preserve crisp pixel edges. 1920×1080 factors cleanly by:
  - 6× → **320×180** source (recommended; matches spec-referenced background resolution).
  - 8× → **240×135** source.
  - 12× → **160×90** source.
  - Any other size (e.g. 256) produces **non-integer scale factors** (1920/256 = 7.5×, 1080/256 ≈ 4.22×) and will render uneven pixel rows/columns, weakening the pixel-art look.
- `pixel-art run` only accepts a single short-edge size, so you will have to **generate square** at 180 (or 135, or 90), then **letterbox or crop** to the target 16:9 aspect before upscaling 6×/8×/12× with nearest-neighbour. Letterboxing preserves spec content; cropping costs vertical composition.

### A. Regenerate backgrounds (~60 min when preconditions are met)

```bash
AIEXP=/Users/animula/GitReps/AIexp/.venv/bin/aiexp
DEST=/Users/animula/GitReps/WU/WUGodot/assets/backgrounds

"$AIEXP" pixel-art run \
  --prompt-text "dark bamboo forest road, mountains in far background, muted dusk sky in deep maroon and dark blue tones, Chinese landscape silhouette composition, very dark, no bright warm colors" \
  --palettes vinik24 --size 180 --kind background

"$AIEXP" pixel-art run \
  --prompt-text "dark enclosed bamboo clearing at night, deep blue-black sky, rough stone ground, oppressive mood, torch embers at edges, no warm bright colors" \
  --palettes vinik24 --size 180 --kind background

# Install step (author as part of this task):
#   1. Locate each newest run dir under ~/.aiexp/pixel-art/runs/.
#   2. Pick the primary vinik24 PNG (180×180).
#   3. Crop or letterbox horizontally to 320×180 (16:9). Cropping risks losing
#      spec content; letterboxing preserves it but needs matching-ink-black
#      bars. Prefer crop for the duel backdrop, letterbox for the boss arena
#      if the composition is vertical.
#   4. Upscale 6× with nearest-neighbour -> 1920×1080 exactly.
#   5. Copy to $DEST as chapter1_bamboo_dusk.png / chapter1_boss_clearing.png.
```

Then run `./run.sh --reimport`. The boss arena will read as a distinct destination **only if** the upscaled PNGs cover the viewport with crisp pixels. Verify by re-shooting `10_combat_duel.png` and `13_combat_boss.png` and zooming in — diagonal lines should be stepped cleanly, not blurry or unevenly spaced.

**Alternative.** If you are willing to touch `background_renderer.gd`, have it scale the texture to viewport at draw time with `TEXTURE_FILTER_NEAREST` using the actual ratio (native → `VIEW_WIDTH`). Then a 180-tall source renders at exactly 6× and the install step loses the upscale pass.

### B. Layered parallax renderer (~1–2h, durable)

Extend `scripts/visual/background_renderer.gd` to composite three layers:

- `far/` — silhouette strip (bamboo / distant mountains), drawn at 60 % parallax.
- `ground/` — textured stone/path plane at 100 % parallax, aligned to `GameConstants.GROUND_Y`.
- `fx/` — optional effect layer (torch embers, drifting leaves), driven by `battle_state`.

Add boss-only effects: dimmer mid-band, soft radial vignette toward the boss, red torch flickers at edges. Survives future chapter additions and sets up the milestone-2 "dynamic background" goal.

**Recommendation.** Ship **A** immediately for the perceived-quality jump, then do **B** in a follow-up milestone.

---

## P1 — Non-combat panel readability

**Evidence.**

- `05_event_choice.png` / `06_event_result.png`: panel covers the whole screen but the text occupies only the top 15 %. The rest is empty.
- `07_shop.png`: item list is dense near the top, footer prompts at the very bottom; price/description cadence is visually flat.
- `08_rest.png`: a two-choice Rest screen — `Heal (40% max HP)` is muted to near-invisibility, `Remove a technique` is bright. The player cannot tell which is the default vs. disabled vs. highlighted.

(The game-over screen has a similar contrast complaint but it is a separate, smaller fix tracked under P3 — the prompt text already exists at `main.gd:818`.)

**Root causes.**

1. Panels expand to viewport instead of hugging content, so visual weight dilutes into voids.
2. Body color `#96b2c5` on `#0f0f1b` — ~4.5:1 contrast at a small pixel size — reads as secondary everywhere.
3. Unselected / unavailable / prose all use the same muted gray, so the player can't distinguish "unavailable" from "flavor prose" from "alternate choice".

**Fix — combined theme + per-screen re-layout.**

Caveat: there is no shared panel component. Every non-combat screen builds its panel with a hard-coded `Rect2` and fixed text Y positions inline in `WUGodot/scripts/main.gd` (e.g. `_update_shop` / `_update_rest` / `_update_forget_technique` / `_update_event` around `main.gd:666`–`733`, plus the victory scroll at `main.gd:736`–`776`). A shared theme change alone cannot fix the dead-space problem; each screen's `Rect2` and per-line Y offsets have to be edited.

Work splits into two passes:

**Centralised (theme-level):**
1. Body copy color raises to `#c6b7be` (already in VINIK24). Reserve `#96b2c5` for footnotes / hints only.
2. Distinct treatment for *unavailable*: half-alpha + strikethrough, or a `[locked]` chip. Do not just use "more gray" — this is what made `08_rest.png`'s valid option look disabled.
3. Bump base body size by +2 px via the theme; keep prompt line at current size.
4. `_draw_panel` already draws the corner-mark ornament (`main.gd:827`–`836`); keep it, but tune so ornaments are visible on the redimensioned panels.

**Per-screen (in `main.gd`):**
5. Shrink each panel's `Rect2` to hug its content. Current values (verified 2026-04-24):
   - Shop: `_draw_shop` at `main.gd:666` — `Rect2(160, 60, VIEW_WIDTH-320, VIEW_HEIGHT-120)` (nearly full-screen; item list is ~6 rows, so ~500 px tall would suffice).
   - Rest: `main.gd:696` — `Rect2(400, 260, VIEW_WIDTH-800, 300)`.
   - Forget Technique: `main.gd:714` — `Rect2(400, 160, VIEW_WIDTH-800, 500)`.
   - Event body: its panel `Rect2` is in the event draw branch near the shop/rest cluster; locate by searching for the event title draw call and resize similarly.
6. Re-centre each panel vertically after the resize; the current top-anchors assume tall panels.
7. Add a 10 % dark vignette over the surrounding screen by drawing a translucent overlay under `_draw_panel`.

**Effort.** 4–5h (was understated at 2–3h). The per-screen rect edits dominate; the theme pass is fast.

---

## P2 — Main menu and map under-dressed

**Evidence.**

- `01_main_menu.png`: 90 % of the screen is black. Logo is a small centred box; tagline is small muted gray; the `Press Enter to begin` prompt sits at ~65 % down.
- `02_map.png`: colored dots on black with thin gray edges. No road, no terrain, no sense of journey. The cursor is a tiny `>` arrow.

**Fix.**

Both menu and map render directly from `WUGodot/scripts/main.gd` (menu logic around `_update_main_menu`, map around `_update_map` at `main.gd:137`, with their respective draw branches in the scene-state draw block further down). There is **no `map_scene.gd`** in this repo; edits happen in `main.gd`.

- **Menu.** In `main.gd`'s menu-draw branch, scale the logo ~1.6×; add a slow horizontal-pan silhouette strip (bamboo) along the bottom third for motion. Move the `Press Enter` prompt down to ~90 % vertical.
- **Map.** In `main.gd`'s map-draw branch, redraw edges as brush-ink strokes (thicker segments + jitter); node dots get a soft glow in their type color; visited nodes dim to 50 %; the cursor becomes an animated ring. Add a watercolor wash behind the node field so it reads as terrain rather than a graph.

**Effort.** ~3h (was understated at 2h). The menu + map draw branches in `main.gd` are coupled with the shared scene-state render loop; touching either affects the other's timing. Budget extra for regression sweeps across other states.

---

## P2 — Reward / Victory screens sparse

**Evidence.**

- `03_reward_technique.png`: three cards floating mid-screen with ~60 % empty viewport above and below.
- `15_victory.png`: a small stats column occupies the top third of the panel; the flavor line "The road beyond the bamboo leads deeper into the jianghu…" is lonely at the bottom.

**Fix.**

- Rewards: add a titled header bar (`得技 · Technique Acquired`), and apply a card-lift animation on the selected option (y-offset + glow) so focus pops.
- Victory: set the chapter header in a display-serif cut of the CJK font; wrap the stats panel in the corner-mark ornament; give the flavor line its own serif treatment and enough breathing room.

**Effort.** ~1h once the font/theme work lands.

---

## P3 — Housekeeping

- `16_game_over.png`: a `Press Enter to return` prompt is **already** drawn at `main.gd:818`. The actual problem is **contrast / visibility**, not missing logic — the prompt draws at `COLOR_TEXT_CAPTION × 0.7` alpha and modulates with a slow pulse, so in the screenshot it was at the dim end of the pulse. Fix by: (a) raising the base alpha floor (e.g. 0.55 min, 1.0 peak instead of the current range), (b) using `COLOR_TEXT_ACCENT` (gold) for the restart prompt so it stands out against the maroon "Defeated" heading, and (c) moving it closer to centre (`center_y + 90` instead of `+120`) so it reads as the next action.
- Combat HUD (`10`–`14`): the technique list under the player HUD bleeds into the combat playfield. Drop it to the lower-left or collapse to icons during active combat; restore on pause.
- `11_combat_elite.png`: there is a visible thin gray rectangle around the Assassin. Confirm whether it is an intentional hostile highlight or a leftover debug hitbox; if debug, gate it behind a flag that's off in playtest builds.
- **Boss beat "破山!" moment** (`14_combat_boss_death.png`): the on-kill feedback is `_show_feedback("破山!", 1.2)` at `combat_scene.gd:205`, drawn through the generic feedback overlay at `combat_scene.gd:466` / `:560`. (The small `!` indicator visible in some shots is the assassin-teleport cue, not the boss beat.) To make the boss moment land, either: (a) add a boss-specific branch in `_show_feedback` that doubles the font size + adds a shake + flashes the boss HP bar, or (b) introduce a new overlay (`_show_boss_beat(label, duration)`) called from the boss-death path, leaving the shared feedback presentation unchanged for everything else. Option (b) is safer — the shared feedback is used by many callers.

---

## Suggested execution order (one focused day)

1. **CJK font + theme** (P0) — unblocks every downstream text fix because the Chinese becomes legible.
2. **Swap in real bamboo-dusk + boss-clearing backgrounds** (P1-A) — fastest perceived-quality jump.
3. **Panel-readability pass** (P1) — applies uniformly via the shared theme.
4. **Menu / map polish** (P2).
5. **Reward / Victory polish + P3 housekeeping** (P2 / P3).

---

## Out of scope for this plan

- Layered parallax renderer (P1-B). Ship A first, revisit B in a follow-up art milestone.
- New gameplay features, balance changes, or additional enemy archetypes.
- Localization beyond ensuring Chinese renders — copy edits stay deferred.

---

## Preconditions

- `aiexp` CLI available at `/Users/animula/GitReps/AIexp/.venv/bin/aiexp` (not on PATH in fresh shells — use absolute path or activate the venv). Required only for P1-A background regen.
- Godot 4.6.2+ available via `./run.sh` (auto-detected). Required for `--reimport` and test runs.
- Font files (`Noto Sans SC` + `Noto Serif SC`, or `Zpix` if going pixel) downloaded and added under `WUGodot/assets/fonts/` before starting P0.

## Verification checklist after implementation

- [ ] No ▯ boxes appear in any of the 16 playtest states.
- [ ] Duel arena and boss arena are visually distinguishable at a glance.
- [ ] All body copy clears 7:1 contrast at the rendered font size.
- [ ] Rest menu clearly distinguishes *active* / *alt* / *disabled* options.
- [ ] Game-over screen shows a restart prompt.
- [ ] `./run.sh --test` passes (139+ tests).
- [ ] Re-shoot the 16-state playtest and diff against `/tmp/wu-playtest-2026-04-24/`.

---

## Revision notes (rev 2, 2026-04-24)

Five items corrected after a code-grounded review of rev 1:

1. **P1 background regen.** Rev 1 specified `--size 320x180` with an `--out` flag; the command would have produced a 320×180 stamp in the corner because `background_renderer.gd:20` draws at native texture size, and `pixel-art run` has no `--out` flag. Rev 2 adds a Preconditions block, uses `--size <int>` + `--kind background`, and calls out the required post-resize to 1920×1080 or an explicit scale in the renderer.
2. **P1 panel readability.** Rev 1 claimed theme-only edits suffice. The panels are hard-coded `Rect2`s inline in `main.gd` (`_update_shop/_update_rest/_update_forget_technique/_update_event`, ~`main.gd:666`–`733`), so per-screen rect and Y-position edits are mandatory. Rev 2 splits the work into centralised (theme) and per-screen passes, and raises the effort estimate from 2–3h to 4–5h.
3. **P2 menu/map polish.** Rev 1 pointed at `map_scene.gd`, which does not exist. Menu and map rendering both live in `main.gd`. Rev 2 redirects to `main.gd` and raises effort to 3h.
4. **P3 game-over prompt.** Rev 1 said "add Press Enter to return to menu"; the string is already drawn at `main.gd:818`. The symptom in the screenshot is low contrast from `COLOR_TEXT_CAPTION × 0.7` alpha pulsed down. Rev 2 changes the task to raising the alpha floor, re-coloring to `COLOR_TEXT_ACCENT`, and tightening the vertical offset.
5. **P3 boss-beat indicator.** Rev 1 said "render the `！` at 2–3× scale"; the actual boss-death feedback is `_show_feedback("破山!", 1.2)` at `combat_scene.gd:205`, drawn through the shared feedback overlay at `combat_scene.gd:466`/`:560`. The `!` seen elsewhere is the assassin-teleport cue. Rev 2 proposes either a boss branch in `_show_feedback` or a dedicated `_show_boss_beat` overlay (recommended, to avoid changing shared presentation).

## Revision notes (rev 3, 2026-04-24)

Three more items corrected after a second round of review:

1. **P0 font wiring.** Rev 2 said to create `theme.tres` + `gui/theme/custom_font` and swap `ThemeDB.fallback_font` callers. That wording implied a theme-level font-size change would propagate. It will not: the custom `_draw_text` helpers at `main.gd:857` / `combat_scene.gd:523` / `damage_number_system.gd:51` / `combat_debug_overlay.gd:54` pass explicit pixel sizes to `draw_string`, which ignore any theme default. Rev 3 spells this out: the migration is a **code change in each helper**, and all font-size tweaks are code edits at each call site, not theme edits. Effort raised 1h → 1.5h.
2. **P1-A pixel scale.** Rev 2 specified `--size 256` with a post-resize to 1920×1080. 1920/256 and 1080/256 are both non-integer, which produces uneven pixel rows/columns in a nearest-neighbour upscale. Rev 3 switches to integer-factor pipelines (`--size 180` → 320×180 crop/letterbox → 6× upscale = 1920×1080), with 240×135 @8× and 160×90 @12× as alternatives. Rev 3 also documents an alternative: scale at draw time in `background_renderer.gd` with `TEXTURE_FILTER_NEAREST` so the source can stay native.
3. **P1 panel section stale pointers.** Rev 2 still listed "game-over screen floats with no restart prompt" in P1 evidence despite correctly framing it as a contrast fix in P3; the Shop `Rect2` was quoted as `Rect2(400, 160, VIEW_WIDTH-800, 500)` but the actual value at `main.gd:666` is `Rect2(160, 60, VIEW_WIDTH-320, VIEW_HEIGHT-120)`. Rev 3 removes the contradictory evidence bullet (pointing to P3 instead) and corrects all three panel `Rect2` values against current source.
