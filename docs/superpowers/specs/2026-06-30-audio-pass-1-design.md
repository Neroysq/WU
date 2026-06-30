# Audio Pass 1 — Design

**Date:** 2026-06-30
**Status:** draft (pre-plan) — for user review
**Origin:** the funness pivot (`2026-06-30-funness-direction.md`) — the core duel is flat; audio is the highest-ROI fix. **Highest-priority work in the project.**

**Goal:** give the duel its first sound — ~10 serviceable SFX wired to events that already fire, with the **deflect clang** and **posture-break thud** crafted as hero sounds and hitstop tuned to them — so the core loop can be re-judged.

**Bar (from the grill):** serviceable, hero-sounds-first. Not shipping-grade sound design — enough that the deflect *cracks* and the break *thuds*, to de-flatten the duel and re-judge its depth.

---

## 1. Current state
**Zero audio** in the project — no `AudioStream`, no `assets/audio/`, no audio bus. Combat already emits visual-feel signals (`hitstop`, `camera_shake`, `slow_motion`, `damage_dealt`, `spawn_particles`, `show_feedback`) that `combat_scene` connects (`:1232`). Audio plugs into the same event points.

## 2. Architecture (keep combat headless-pure)
- **`AudioManager`** (autoload singleton, like `DataManager`): loads a manifest, plays SFX via a **pool of `AudioStreamPlayer`s** (so overlapping sounds don't cut each other), with optional per-play **pitch variation** (±a few %, so repeated hits don't sound robotic). API: `play(id: String, pitch_var: float = 0.0) -> void`. Graceful no-op if a stream is missing or running headless (so `--test`/`--playtest` never break).
- **`data/Audio/Sfx.json`** (data-driven, repo convention): `{ "parry": "res://assets/audio/parry.ogg", ... }` — id → file. AudioManager loads it at boot.
- **`assets/audio/*.ogg`** — the sound files (sourced; see §5).
- **`combat_system.gd` stays RefCounted/headless** — it does NOT touch audio nodes. Add **`signal sfx(id: String)`** and emit it at the resolution events; `combat_scene` connects `sfx → AudioManager.play` (alongside its existing signal hookups at `:1232`). This preserves headless-testability (combat sim emits an id; tests assert the id; no audio node needed).
- **Player-movement + UI sounds** that originate outside combat resolution (dash/jump/land triggered by input in `combat_scene`; menu move/confirm in the scene controllers) call `AudioManager.play(...)` directly at those existing input/animation points.
- **Bus:** route SFX to a `SFX` audio bus (default layout + one SFX bus) for a future volume control; v1 just plays. (Audio volume in Settings is a later add — out of scope here, but the bus makes it trivial.)

## 3. SFX set (~11 ids) + emit points
**Hero (craft these; tune hitstop to them):**
- `parry` — the **deflect clang**. Emit `sfx("parry")` at the successful-parry branch (`combat_system.gd:335`, `consume_parry_if_active()` success). THE sound of the game.
- `posture_break` — the **break thud/crack**. Emit at the break path (`combat_system.gd:276-279`, the `破` block).

**Supporting:**
- `hit_light` / `hit_heavy` — attack connects (at the `damage_dealt` emit; pick by `attack_def.is_heavy`).
- `block` — blocked hit, dull thunk (the `is_blocking` "BLOCKED" branch, ~`:386`).
- `swing` — attack whoosh, on attack start (light `:60` / heavy `:66`).
- `dash` — dash whoosh (`combat_scene` on dash start).
- `jump` / `land` (`combat_scene` on jump/land animation states `12_jump`/`14_land` are the capture states; the live triggers are `start_jump()` / land detection).
- `hurt` — fighter takes damage / HIT_REACTION.
- `ui_move` / `ui_confirm` — menu navigation + select (scene controllers / `menu_input` consumers). One shared pair across all menus.

(Footsteps deferred — keep the set tight for the re-judge.)

## 4. Hitstop/feel coupling
The hero moment is the channels firing **together**: on a parry, `sfx("parry")` + the existing hitstop + a brief flash land on the same frame. Tune the existing `hitstop`/`slow_motion` durations *to* the clang and thud so they feel like one impact, not three separate effects. (Numbers tuned by ear in-engine.)

## 5. Sourcing the sounds (implementer task)
No audio pipeline exists. For serviceable v1: pull **CC0 / royalty-free** SFX (e.g. a CC0 library or the Sonniss GDC bundle) into `assets/audio/` as small `.ogg`, OR AI-generate. Spend the care on the **two hero sounds** — audition a few `parry` clang and `posture_break` candidates and pick by feel in-engine; the supporting 9 just need to be clean and non-annoying. Keep files small/looping-free. Record the source/license of each file.

## 6. Testing / validation
- **Unit (headless):** `combat_system` emits `sfx("parry")` on a successful parry, `sfx("posture_break")` on a break, `hit_light`/`hit_heavy` on hits, `block` on a blocked hit (assert the emitted id per event). `AudioManager.load` parses the manifest; `play` no-ops safely on a missing id / headless.
- **No regression:** `./run.sh --test` green; `--playtest`/`--shot-combat` unaffected (AudioManager no-ops headless).
- **Manual (the real gate — feel can't be unit-tested):** play a fight, hear the clang on deflect and the thud on break; **re-judge the duel** (flat → fine → thrilling). This is the human-in-the-loop verdict the whole pivot hinges on.

## 7. Out of scope
- Volume settings UI (the SFX bus makes it a later trivial add).
- Music / ambient (this pass is combat SFX only).
- Footsteps, crafted/layered sound design, positional/stereo panning.
- Any gameplay change.

## 8. Sequencing
1. `AudioManager` autoload + `Sfx.json` manifest + pooled players + headless no-op; load at boot.
2. `combat_system` `signal sfx(id)` + emits at parry/break/hit/block/swing (+ unit tests on the ids).
3. `combat_scene` connects `sfx → AudioManager.play`; plays dash/jump/land/hurt directly.
4. UI move/confirm in the menu controllers.
5. Source the files (hero sounds with care) → `assets/audio/`; fill `Sfx.json`.
6. Tune hitstop/slow-mo to the hero sounds by ear. ✋ Manual re-judge of the duel.
