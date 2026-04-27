# WU Combat Feel — Phased Animation, Visible Hitboxes, Extended Strikes

**Date:** 2026-04-27
**Source:** Playtest feedback after pass-3 polish: attack animations don't extend the body far enough, the active hitbox window is invisible, and pre/post telegraph timing isn't readable. Combat is mechanically Sekiro-paced (proper windup/active/recovery split per attack) but the visuals don't honour the timing.
**Revision:** 2 — rev 1 had three high-severity errors (stale claim about telegraph never being drawn, references to non-existent `events_emitted_this_frame`/`phase_changed` APIs, and a 4-frame assumption that doesn't match the live JSONs). Rev 2 corrects all three plus three smaller issues; see Revision notes at bottom.

This plan delivers the missing combat-feel layer in three coordinated passes.

---

## Findings summary

| # | Priority | Issue |
|---|---|---|
| 1 | P0 | Attack frames play at fixed FPS, ignoring the windup/active/recovery split — fast attacks blur into a single motion, telegraphed attacks still look fast |
| 2 | P0 | The active-window weapon line at `combat_scene.gd:364-368` reads as a thin gameplay overlay, not as a strike. Needs body flash + arc trail to land. |
| 3 | P0 | The telegraph outline at `combat_scene.gd:332-345` is already wired but reads as a multi-line border only — easy to miss against the dark arena. Needs body-tint pulse to be unmistakeable. |
| 4 | P0 | Attack frames don't extend the silhouette — character barely lunges; weapon never reaches past the canvas edge |

---

## Why this is a P0 set

The mechanical timing is already correct (`scripts/attack_catalog.gd`):

| attack | windup | active | recovery |
|---|---:|---:|---:|
| `hu_light` | 0.18 s | 0.12 s | 0.20 s |
| `hu_heavy` | 0.40 | 0.15 | 0.30 |
| `bandit_slash` | 0.45 | 0.15 | 0.20 |
| `bandit_thrust_perilous` | 0.55 | 0.13 | 0.22 |

The fight system reads these and `Fighter._attack_state.phase()` (in `fighter.gd:299`) returns the correct phase enum every frame. **The visuals throw all of this away**: `FighterVisual` plays the `ATTACKING_LIGHT` clip at a fixed 12 fps × 4 frames = 0.33 s and never tints the body or draws an arc. The mechanical windup might be 0.40 s but the player only sees 0.33 s of generic swing.

That decoupling is the root cause of "I can't read attacks."

---

## Order of operations

Layer 3 first (cheapest, unblocks the "is this readable?" question), then Layer 1 (proper timing), then Layer 2 (regenerated frames + push).

---

## Layer 3 — Visible hitboxes and telegraphs (~1 hr)

The cheapest layer. Adds body-tint pulse + active-window flash + a proper weapon arc, **on top of** the existing telegraph outline and weapon line that already live in `combat_scene.gd`.

### 3a. Body-tint pulse during windup (additive to existing telegraph outline)

The existing telegraph at `combat_scene.gd:332-345` draws *outline rectangles* around the fighter when `current_telegraph_color()` is non-transparent. It works but reads quietly against the dark arena. Add a body-tint pulse so the fighter sprite itself colours during windup.

**Where to wire it.** `FighterVisual.draw` at `fighter_visual.gd:78-83`. Before `canvas.draw_texture_rect(texture, rect, false, tint)`:

```gdscript
var tele: Color = fighter.current_telegraph_color()
var draw_tint: Color = tint
if tele.a > 0.001:
    var pulse: float = 0.5 + 0.5 * sin(_telegraph_pulse_t * 8.0)
    draw_tint = tint.lerp(tele, 0.35 + 0.25 * pulse)
canvas.draw_texture_rect(texture, rect, false, draw_tint)
```

Add `var _telegraph_pulse_t: float = 0.0` to `FighterVisual` and tick it in `update(dt)` (`fighter_visual.gd:31` onward, the existing function): `_telegraph_pulse_t += dt`. Pulse rate ≈ 8 rad/s gives ~1.3 Hz; a 0.45 s windup shows ~0.6 pulses — bump to 12 rad/s if more pulses are wanted.

**Coexistence with the outline.** Keep the outline at `combat_scene.gd:332-345` — it complements the body tint. Both fade together because both read from `current_telegraph_color()`.

### 3b. Active-window body flash

At the start of the active window, snap the sprite to full-white for one frame, then fade back to normal over ~0.08 s.

**Trigger contract — what actually exists.** `attack_state.gd:advance(dt)` at `:41` returns a Dictionary with three flags: `hit_started`, `hit_ended`, `finished`. `fighter.gd:212` currently consumes only `finished` (in the recovery branch around `:213`). The `hit_started` flag is set the same tick `is_hit_active()` flips true — exactly the trigger we need.

**Fix.** Two pieces:

1. In `Fighter._update_attack` (around `fighter.gd:212-213` where `advance(dt)` is called and only `finished` is read), additionally:
    ```gdscript
    if events.get("hit_started", false):
        emit_signal("attack_active_started")
    ```
    Add `signal attack_active_started` to `Fighter` near the other signals at the top of the file.

2. In `combat_scene.setup_combat` (where the visual is bound to the fighter), connect: `fighter.attack_active_started.connect(visual._on_attack_active_started)`.

3. In `FighterVisual`, add `var _active_flash_t: float = 0.0`; the handler sets it to `0.08`. `update(dt)` decrements it. `draw` blends the existing `draw_tint` toward `Color.WHITE` by `clamp(_active_flash_t / 0.08, 0.0, 1.0)`.

This avoids polling phase transitions in `draw`/`update` and uses the engine event that already exists. No `events_emitted_this_frame()` invention needed.

### 3c. Weapon-arc slash trail during the active window

The existing weapon-active line at `combat_scene.gd:364-368` is a single straight segment from chest to attack-range. It reads as a gameplay overlay, not a strike. Replace it with a fading polyline trail of the last N tip positions so the player sees motion.

**Sample tip positions in `update(dt)`, not `draw`.** Draw calls happen every render frame (which can run at variable cadence and after camera shake mutates `camera_offset`); the simulation tick is `update(dt)`. Sampling in `draw` would jitter and double-emit on slow frames. So:

```gdscript
# in FighterVisual: top-level state
var _tip_history: Array[Vector2] = []  # world-space positions, oldest first
const TIP_HISTORY_MAX: int = 6
const TIP_HISTORY_LIFETIME: float = 0.10  # seconds; entries older than this drop
var _tip_history_ts: Array[float] = []

# in update(fighter, dt):
if fighter.is_hit_active():
    var tip: Vector2 = fighter.position + Vector2(float(fighter.facing) * 60.0, -20.0)
    _tip_history.append(tip)
    _tip_history_ts.append(0.0)
    if _tip_history.size() > TIP_HISTORY_MAX:
        _tip_history.pop_front()
        _tip_history_ts.pop_front()
# always age the buffer
for i in range(_tip_history_ts.size() - 1, -1, -1):
    _tip_history_ts[i] += dt
    if _tip_history_ts[i] > TIP_HISTORY_LIFETIME:
        _tip_history.remove_at(i)
        _tip_history_ts.remove_at(i)
```

**Render in `draw`** by iterating the buffer and translating each sample by `camera_offset`. Alpha = `1.0 - (age / TIP_HISTORY_LIFETIME)`. Stroke width tapers from 4 px (newest) to 1 px (oldest). This survives camera shake and slow-frame stalls.

**Replace, don't add to, the existing line.** Delete the `draw_line(weapon_start, weapon_end, slash_color, 3.0)` at `combat_scene.gd:368` so the new arc is the only active-window cue (plus 3b's body flash). Otherwise we'll have a straight line *and* a trail, which is noisy.

**Per-archetype tip offset.** The hardcoded `(60.0, -20.0)` is a starting point. Add an optional `weapon_tip_offset: Vector2` field to `VisualProfiles/DefaultProfiles.json`; default to that constant; iron_bear (staff) and bandit_spear (long spear) need larger offsets.

### 3d. Hit spark on connect (optional, defer if Layer 3 a/b/c is enough)

When `combat_system.gd` confirms a damage application (around `combat_system.gd:296-422` where damage is dealt), emit a one-shot signal with the contact position. `FighterVisual` (or a new `HitFx` overlay) draws a 4-frame radial burst over 0.12 s. ~30 min if needed; defer to a follow-up if the arc + flash already feels readable.

### 3e. Verify

After 3a-c land, run any combat node and observe:

- Enemy whites/reddens visibly during their windup.
- Player's own sprite snaps white at the moment they swing.
- A short white streak follows the weapon arc during the active window.

If still not readable, add 3d.

**Effort.** 1 hr including telegraph tuning.

---

## Layer 1 — Phase-driven animation playback (~2 hr)

Replace fixed-FPS playback for combat actions with phase-driven playback that pulls duration from the live `AttackDefinition`.

### Data shape change

Animation JSON for combat clips gains an optional `phases` block:

```json
"ATTACKING_LIGHT": {
  "fps": 12.0,
  "loop": false,
  "phases": [
    {"frames": [0, 1], "phase": "windup"},
    {"frames": [2],     "phase": "active"},
    {"frames": [3],     "phase": "recovery"}
  ],
  "frames": [
    {"path": "res://assets/sprites/characters/hu/attack_0.png", "offset": [0, 0]},
    {"path": "res://assets/sprites/characters/hu/attack_1.png", "offset": [0, 0]},
    {"path": "res://assets/sprites/characters/hu/attack_2.png", "offset": [0, 0]},
    {"path": "res://assets/sprites/characters/hu/attack_3.png", "offset": [0, 0]}
  ]
}
```

Clips without a `phases` block keep the current fixed-FPS behaviour, so non-combat clips (idle, walk, jump) are unaffected.

### `progress_in_phase()` — exact formula and boundary contract

`attack_state.gd` currently exposes `progress()` (whole-attack 0..1 at `:31`). Add `progress_in_phase()` with these exact rules:

```gdscript
func progress_in_phase() -> float:
    if def == null or def.duration <= 0.0:
        return 0.0
    var p: int = phase()
    match p:
        AttackDefinitionScript.Phase.WINDUP:
            # 0.0 at elapsed=0, 1.0 at elapsed=windup_end
            if def.windup_end <= 0.0:
                return 1.0
            return clampf(elapsed / def.windup_end, 0.0, 1.0)
        AttackDefinitionScript.Phase.ACTIVE:
            # 0.0 at elapsed=windup_end, 1.0 at elapsed=active_end
            var active_span: float = maxf(def.active_end - def.windup_end, 0.0001)
            return clampf((elapsed - def.windup_end) / active_span, 0.0, 1.0)
        AttackDefinitionScript.Phase.RECOVERY:
            # 0.0 at elapsed=active_end, 1.0 at elapsed=duration
            var recovery_span: float = maxf(def.duration - def.active_end, 0.0001)
            return clampf((elapsed - def.active_end) / recovery_span, 0.0, 1.0)
        _:
            return 1.0  # FINISHED
```

**Boundary behaviour.** At `elapsed == windup_end`, `phase()` already transitions to ACTIVE (per `def.phase_at`). `progress_in_phase` therefore returns 0.0 at the boundary, not 1.0 of the previous phase — no double-render. At `elapsed == active_end`, same handover into RECOVERY. Tests must assert each boundary explicitly (windup_end, active_end, duration) returns the expected (phase, progress) pair.

### Playback logic in `FighterVisual.update`

When the current state is ATTACKING_LIGHT / ATTACKING_HEAVY and the clip has a `phases` block:

1. Read `fighter._attack_state.phase()`.
2. Read `fighter._attack_state.progress_in_phase()`.
3. Pick the phase block matching the enum; map `progress_in_phase` to a frame index: `idx = clamp(int(p * frames.size()), 0, frames.size() - 1)`.
4. Render that frame.

If `_attack_state` is FINISHED but the clip is still nominally selected (one render frame of dangling state), fall back to the last frame in the phases block.

### Why this beats the existing `fps`

The whole attack now stretches to its mechanical duration: a 0.40 s windup actually shows two frames over 0.40 s (200 ms each — slow enough to read), not 167 ms total. A 0.12 s active flash genuinely reads as a single fast strike. Recovery frames hold long enough to convey "off-balance".

### Backwards compatibility

Animation set loader reads `phases` as optional. If absent, runtime continues using `fps` per clip (existing behaviour). Test suite must confirm both paths.

### Effort

- `animation_set.gd` schema parse: ~30 min.
- `FighterVisual.update` phase branch: ~45 min.
- Add `progress_in_phase` to `attack_state.gd` if missing: ~15 min.
- JSON edits for all 7 characters' ATTACKING_LIGHT/HEAVY clips: ~15 min.
- Tests for both phased and fixed paths: ~15 min.

**Total ~2 hr.**

---

## Layer 2 — Regenerate attack frames with phase-specific prompts (~1 hr)

Current attack frames are 4 generic "swing" poses; none clearly say "wind up", "fully extended", or "recovery". With Layer 1 stretching them to the right durations, the wrong-shaped poses will now be even more visible.

### aiexp custom-action approach

aiexp now supports custom actions via `name:frames:loop[:hint]`. We split the single `attack` action into three runs per character:

```bash
AIEXP=/Users/animula/GitReps/AIexp/.venv/bin/aiexp
DEST=/Users/animula/GitReps/WU/WUGodot/assets/sprites/characters

for char in hu bandit_sword bandit_spear ronin disciple assassin iron_bear; do
  "$AIEXP" sprite-extractor animate \
    --character "$DEST/$char/static.png" \
    --describe "<existing per-character description>" \
    --actions "attack-windup:2:false:weapon raised high, body coiled, weight on back foot,attack-strike:1:false:full lunge forward, weapon fully extended past frame, body stretched out,attack-recovery:1:false:weapon trailing back, off-balance, returning to neutral" \
    --palette vinik24 --size 64
done
```

Output:
- `attack-windup/frames/frame_001.png` and `frame_002.png` → install as `attack_0.png` and `attack_1.png`.
- `attack-strike/frames/frame_001.png` → install as `attack_2.png`.
- `attack-recovery/frames/frame_001.png` → install as `attack_3.png`.

### Install script tweak

Update `/tmp/install_sprites_v2.py` (or its successor) to map the three custom action dirs onto `attack_0.png` ... `attack_3.png`.

**Important — the JSON `frames` arrays must also be updated.** Live `character_hu.json:62` lists only `attack_0..attack_2` for `ATTACKING_LIGHT` (3 frames, not 4). After Layer 2 generates `attack_0..attack_3`, the install step must rewrite each character's animation JSON so:

- `ATTACKING_LIGHT.frames` references all four PNGs (`attack_0..attack_3`).
- `ATTACKING_LIGHT.phases` is added per Layer 1's schema, mapping `[0, 1] → windup`, `[2] → active`, `[3] → recovery`.
- `ATTACKING_HEAVY` likewise; can share frames with light or have its own (currently it does in `character_hu.json:89`).

If the JSONs aren't updated, the new `attack_3.png` recovery sprite is generated but never rendered — the runtime keeps playing the old 3-frame loop.

Audit all 7 character JSONs: list their current `ATTACKING_LIGHT/HEAVY.frames` arrays, identify which are missing `attack_3`, and amend in the same change as the install. A single Python pass over the JSONs is fine; just script it alongside the sprite install.

### Verification

After install and re-import, look at `assassin/attack_2.png` (the strike frame): silhouette must extend visibly past the canvas edge in the facing direction. If not, regenerate that single character with a stronger hint (`weapon tip beyond frame edge, full body lunging`). Iterate per-character; some archetypes (boss, spearman) need more explicit "long weapon" hints.

### Optional programmatic forward-push (skipped per the brainstorm — covered later if Layer 1+2 isn't enough)

The user picked Option A only. If after Layer 1 + the new frames the strike still feels undersold, the cheap follow-up is a per-active-frame `+30 px` forward push in `FighterVisual.draw`. Not implementing in this plan; flag here so it isn't lost.

**Effort.** 30 min batch + 15 min install-script tweak + 15 min visual-verify each character ≈ **1 hr**.

---

## Order of operations

1. **Layer 3 (a, b, c)** — telegraph hookup, active flash, weapon arc. ~1 hr. Independent of the other layers; ships value immediately.
2. **Layer 1** — phased animation playback. ~2 hr. Requires `attack_state.progress_in_phase()`; otherwise self-contained.
3. **Layer 2** — frame regeneration with phase-specific prompts. ~1 hr aiexp + install + verify.

After all three, do a single re-shoot focused on combat states (`10`, `12`, `13`) plus one capture of an active strike mid-frame and one of an enemy windup. Add to the playtest sweep coverage list.

Total estimated effort: **~4 hr** end-to-end.

---

## Preconditions

- Commit `830dc54` landed; pass-3 polish either landed or queued (this plan is independent of pass-3 polish work).
- aiexp at `/Users/animula/GitReps/AIexp/.venv/bin/aiexp` available for Layer 2.
- Godot 4.6.2+ via `./run.sh`. Use `./run.sh --reimport` after Layer 2 lands new sprites.
- Existing tests at `tests/run_tests.gd` should continue to pass; Layer 1 expects new tests for both phased and fixed playback paths.

---

## Verification checklist after implementation

### Layer 3

- [ ] During an enemy normal-attack windup, the enemy sprite tints white-ish and pulses ~2× before the strike.
- [ ] During an enemy perilous-attack windup, the tint is red instead of white. Visibly different.
- [ ] At the moment of `is_hit_active()` becoming true, the attacker's sprite snaps white for one frame then fades back over ~80 ms.
- [ ] A thin white arc trails the weapon during the active window and decays as the active phase ends.
- [ ] Telegraph drops out the instant the active phase ends (recovery shows neutral colour).

### Layer 1

- [ ] An `hu_heavy` swing visibly takes ~0.85 s end-to-end with the player able to count "wind, strike, recover". Compare to `hu_light` at ~0.50 s — the difference must be perceptible without a stopwatch.
- [ ] Animation JSONs without a `phases` block (idle, walk, jump, hit-react, stunned, block, dash) still play at the legacy fixed-FPS rate. No regressions.
- [ ] `attack_state.progress_in_phase()` returns 0.0 at the start of each phase and 1.0 at the boundary into the next phase. Boundary tests at `elapsed = windup_end` and `elapsed = active_end` assert the new phase + 0.0, not the old phase + 1.0.
- [ ] Each character's `ATTACKING_LIGHT.frames` array now references `attack_0..attack_3` (was `attack_0..attack_2` for at least Hu). `phases` block present on every combat clip.
- [ ] Tests cover both phased and fixed playback paths plus the three phase-boundary cases. Test count grows by ≥ 6.

### Layer 2

- [ ] Strike frames (`attack_2.png`) for all 7 characters show the silhouette extending past the canvas edge in the facing direction.
- [ ] Windup frames (`attack_0.png` / `attack_1.png`) show clear "weapon raised, body coiled" pose distinct from idle.
- [ ] Recovery frame (`attack_3.png`) shows trailing weapon / off-balance pose distinct from idle.
- [ ] No regression of static / idle / walk / block / hit / stunned (those frames untouched).

### End-to-end

- [ ] `./run.sh --test` passes.
- [ ] A combat re-shoot of `10_combat_duel.png` mid-strike shows: weapon arc visible, attacker body white-flashed, defender sprite registering hit reaction. None of these were visible in the 2026-04-27 baseline.
- [ ] A combat re-shoot of `13_combat_boss.png` during boss windup shows the boss tinted red and pulsing. Compare to baseline where the boss was indistinguishable colour-wise from neutral.

---

## Out of scope for this plan

- Programmatic forward-push during the active window (deferred follow-up if Layer 1 + 2 isn't enough).
- Hand-redrawn frames in a pixel-art editor (high effort, defer to dedicated art polish).
- Hit-spark radial burst (3d above; defer if 3a-c suffice).
- Camera shake / time slowdown on parries and boss perilous attacks (separate combat-game-feel pass).
- Sound design (this plan is visual-only).
- Posture-bar visual feedback during stagger (related, but a separate UI pass).

---

## What "done" looks like

A player watching a 30-second clip of a duel can:

1. Predict a parryable strike about to land — they see the windup tint and have the full mechanical windup duration to react.
2. Distinguish parryable from perilous — colour cue, no UI text needed.
3. See exactly when the hitbox is "live" — body flash + weapon arc.
4. Feel the difference between a light attack and a heavy attack viscerally — the heavy now visibly takes longer through every phase, with a longer wind-up pose held.

If those four read clean from a silent screen capture, the combat-feel pass is done.

---

## Revision notes (rev 2, 2026-04-27)

Six review corrections after a code-grounded second pass:

1. **Layer 3 was based on stale code.** Rev 1 claimed `Fighter.current_telegraph_color()` was never read. In fact `combat_scene.gd:332-345` already draws a multi-line outline using it, and `combat_scene.gd:364-368` already draws a straight active-window weapon line. Rev 2 reframes Layer 3 as **additive** (body-tint pulse + flash + arc trail on top of the outline) and explicitly **replaces** the straight weapon line with the new fading polyline trail to avoid double-rendering.
2. **Active-window flash referenced non-existent APIs.** Rev 1 invoked `events_emitted_this_frame()` and a `phase_changed` event. Neither exists. `attack_state.gd:advance(dt)` returns `{hit_started, hit_ended, finished}` (lines 41-onward); `fighter.gd:212` consumes only `finished`. Rev 2 specifies the real contract: emit a new `attack_active_started` signal from `Fighter._update_attack` when `events.hit_started` is true, connect it from `combat_scene.setup_combat` to the visual, and the visual sets a fade timer in the handler.
3. **Layer 2 four-frame assumption was wrong.** Rev 1 assumed `ATTACKING_LIGHT` already had four frames. Live `character_hu.json:62-87` lists only `attack_0..attack_2` (3 frames). Rev 2 makes Layer 2's install step responsible for **rewriting each character's animation JSON** — extending the `frames` array to 4 entries and adding the `phases` block — so newly generated recovery art is actually rendered.
4. **`progress_in_phase()` had no contract.** Rev 1 said "add this method"; rev 2 specifies the exact formula per phase, the boundary handover (at `windup_end` it's already ACTIVE phase with progress 0.0, not WINDUP phase with progress 1.0), and the FINISHED return path. Tests must cover the three boundary points.
5. **Weapon arc mutated state in `draw`.** Rev 1 stored `_last_tip_pos` inside the draw call. `draw` runs at render cadence; sampling there would jitter on slow frames and mis-align under camera shake (which mutates `camera_offset`). Rev 2 moves tip sampling to `update(dt)`, stores a buffer with timestamps, ages it, and renders the buffer translated by `camera_offset` in `draw`.
6. **Stale checklist item.** Rev 1's Layer 1 verification mentioned `_compute_event_panel_layout` (carried over from the panel-polish plan). Removed; replaced with phase-boundary assertions and the JSON `frames`-array audit.
