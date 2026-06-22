# WU — Boon Move-Skin System (Visual Variance) — Design

**Date:** 2026-06-22
**Status:** draft (pre-plan) — for user review (revised after reviewer findings)
**Sub-project:** #3 of the "complete fun run" effort (visual variance). Builds on the boon build system (#2) and the technique-effect engine; validated by the playtest harness (visual capture).

**Goal:** A boon infusing a move slot gives that move a **distinct, school-specific animation** — so committing to a 流 (school) visibly transforms how Hu fights, not just his numbers.

**Why:** Today the player renders through `FighterPresenter` with one fixed set of timeline clips, tinted only by run state. The boon system (#2) already changes mechanics per move slot through the technique engine, but the build is invisible — a Venom light attack and a Sword light attack look identical. #3 closes that gap on the visual side.

---

## 1. Decided (from brainstorming + review)

- **Scope = boons → per-move visuals only.** Relic/equipment → overall outlook/aura is a **separate, deferred spec ("spec B")** — no relic/equipment system exists yet (Rewards are flat stat boosts), so it has no driver.
- **Separate animations, not FX overlays.** Each (school, move) is a genuinely distinct timeline clip — not a recolor of the base move. (Recolor is only the *fallback* for not-yet-arted slots, and the v1 treatment for stance.)
- **System + one vertical slice.** Build the clip-routing/fallback engine now, and animate **Venom (毒)** as the proof on the slots it can actually reach: **light, heavy, dash**.
- **Per-clip timing allowed**, served by the existing seam — no new timing system (see §4).
- **Fallback = base clip + school recolor** for slots without a bespoke clip yet.
- **Stance = active-mode recolor in v1** (see §3). The ideal (replace Hu's idle stance per active school, with transitions into every move) is **deferred** — too much transition work for now.
- **Validated by the harness** visual capture (a Venom move reads different from base; non-blank; deterministic).

---

## 2. Scope & decomposition

| Subsystem | Driver | Status |
| --- | --- | --- |
| **A — Boon → per-move clip** (this spec) | `BoonLoadout.slots[slot]` → 流 (live, from #2) | **build now** |
| **B — Relic/equipment → outlook & aura** | needs an equipment/relic system | **deferred** (no driver exists) |

The six boon move slots (from #2): **light, heavy, dash, block, stance, jump**. The six schools (`data/Schools/Schools.json`, each with `themeColor` + `hanzi`): Venom 毒, Thunder 雷, Soft Palm 柔, Iron Body 鐵, Windstep 風, Sword 劍. The full target space is up to **6 schools × (skinnable slots)** clips, filled incrementally; this spec ships the system + the Venom slice.

---

## 3. Model — per-move skin resolution

The **player renders through `FighterPresenter`** (`combat_scene.gd:99` configures it; `:580` updates it; `:690` draws it). Enemies render through `FighterVisual` and are never skinned. The presenter resolves, each frame, a **clip** for the current animation state via the animation **graph** (`state → clip id`) and plays it from the **manifest** (`pose → texture/geometry`). #3 inserts a skin layer into that clip resolution, for the player only.

**State → slot map** (the slots that map to a real `Fighter.AnimationState` and are skinnable):

| Slot | Animation state(s) | Base clip(s) |
| --- | --- | --- |
| light | `ATTACKING_LIGHT` | `hu_attack_light` |
| heavy | `ATTACKING_HEAVY` | `hu_attack_heavy` |
| dash | `DASHING` | `held_dash` |
| block | `BLOCKING` | `held_block` |
| jump | `JUMPING`, `FALLING` | `held_jump`, `held_fall` |

- **Never skinned** (no slot, always base): `IDLE`, `WALKING`, `HIT_REACTION`, `STUNNED`, `LANDING`, `COMBAT_ENTRY`. **LANDING is a return-to-neutral recovery and stays base** (resolving the earlier contradiction — jump owns `JUMPING`+`FALLING` only).
- **Stance has no animation state.** It is an active technique mode (`technique_engine.activate_stance`, `:203`). v1 treatment: **active-mode recolor** — while a stance technique is active, tint the player render in the active stance's school `themeColor` until it deactivates. No new clip, state, or graph edit. (The ideal — swapping Hu's idle stance pose per school with transitions into each move — is deferred, §8.)

**Resolution per move state (player):** state → slot → infusing 流 (from loadout). If that 流 has a **variant clip** for the state → play the variant. Else play the base clip; if the slot is infused but unskinned, apply the **school recolor**. A slot with no boon → base, no recolor.

---

## 4. Architecture (data-driven, art-agnostic)

**Art is placeholder.** Current Hu/enemy art will be replaced (see [[character-art-placeholder]]), so routing is by data + state name with graceful fallback, so swapping the underlying art later needs no code change.

The presenter is built from three data kinds (`FighterPresenter.configure(manifest_path, graph_path, clip_paths, render_scale)`):

- **Manifest** (`assets/animation_manifests/hu.manifest.json`) — `pose id → texture + geometry (hurtbox, etc.)`.
- **Graph** (`assets/animation_graphs/humanoid.graph.json`) — `state → { clip, enter, priority, … }`; `clip_for(state)` yields the clip id.
- **Timeline clips** (`assets/animation_clips/*.timeline.json`) — each has an `id`, `keyposes`, `events`, and either `duration:"fromAttackDef"` (norm_t = `attack_state.elapsed / attack_def.duration`) or a `fixed_duration`/`loop` (`animation_clip_timeline.gd`).

**Skin layer (the #3 addition):**

- **Per-school overlay assets**, lazy-loaded only for equipped schools:
  - **Variant timeline clips** under `assets/animation_clips/skins/<school>/` — e.g. `venom_attack_light.timeline.json` — one per skinnable state the school overrides. Attack variants use `duration:"fromAttackDef"` (so they inherit the move's real timing); dash/block/jump variants use `fixed_duration`, mirroring their base clips.
  - **Variant manifest poses** under `assets/animation_manifests/skins/<school>.manifest.json` (the new Venom art's poses), merged over the base manifest at configure.
- **`FighterPresenter.set_move_skins(slot_school_map: Dictionary)`** (slot → school id), called at **combat setup** from the player's `BoonLoadout` (the loadout is fixed for the duration of a combat, so it is set once per fight). On set, the presenter lazy-loads the referenced schools' overlay clips + manifest poses and caches them, and records the slot→school map. **This static map only says which school *owns* each slot — it does not say whether a stance is currently active.**
- **Per-frame active-stance route (closes the stance-tint data path):** the stance tint must also know *when* a stance is active. The combat scene reads `TechniqueEngine.is_stance_active()` / `active_stance()` (`technique_engine.gd:226–232`) each frame and pushes the active stance's school (or none) into the presenter — e.g. `FighterPresenter.set_active_stance_school(school_or_empty)` — so activation/deactivation drives the tint on/off. (Wiring a one-shot combat-scene signal on activate/deactivate is an acceptable equivalent.)
- **Clip resolution becomes skin-aware:** where the presenter currently uses `clip_for(state)`, it first maps state→slot; if that slot is infused by school `S` and a variant clip is registered for `(S, state)`, it uses the variant clip id; otherwise the base clip id. `handles_state` needs no change — it keys off the base graph clip, which always exists, so skinnable states keep rendering through the presenter (a registered variant just supersedes the base inside resolution).
- **Recolor + stance tint require new shader uniforms.** The presenter shader (`scripts/visual/shaders/fighter_presenter.gdshader`) currently exposes only `flash`/`smear`/`smear_dir`/`dissolve` — there is no tint channel. The plan must add explicit `skin_tint` (vec4/color) + `skin_tint_weight` (float) uniforms and have the presenter set them via `_mat_current`. The tint must be applied **after / under** `flash`, so the teaching flash always wins (flash priority preserved); readability is never degraded. The same `skin_tint` channel serves both the un-arted-slot fallback and the active-stance recolor.

**Timing needs no new system.** Gameplay timing already flows through the **technique engine**: `start_light_attack()/start_heavy_attack()` consult `technique_engine.get_*_override()` (`fighter.gd:367–374`), and `technique_effect` has per-slot hooks (`attack_override`, `modify_block`, `on_dash_end/through`, `on_jump`, `on_stance_activate/deactivate`). Boons are technique effects, so a Venom boon can already return a custom attack definition. Because attack variant clips use `duration:"fromAttackDef"`, the clip renders against **whatever** timing the active def has. "Per-clip timing allowed" is therefore satisfied by the existing seam — this spec adds **no** gameplay-timing code; custom timings live in the boon effects (their existing rider domain) and are validated by the harness.

---

## 5. Vertical slice — Venom (毒): light, heavy, dash

Venom move boons today cover exactly **light (`venom_light`), heavy (`venom_heavy`), dash (`venom_dash`)** (`data/Boons/Boons.json`); the other Venom boons are passives/duo/mastery with no move slot. So the slice covers the three attainable slots, generated through the **animation gate** in order:

**light → heavy → dash**

(attacks first: most visible, and light/heavy already drive `fromAttackDef` timing). Each clip follows the standard gate: **Gate 1 keyframe pose review → scale-vs-idle review → generate → Gate 2 in-game** (see [[review-keyframes-before-generating]], [[judge-art-size-overall-in-game]]). Venom flavor reads as distinct silhouettes, not just green tint — e.g. a venomous palm strike (light), a spray/spit (heavy), a serpentine dash.

Each variant clip is authored under `assets/animation_clips/skins/venom/`, with its new poses in `assets/animation_manifests/skins/venom.manifest.json`. The remaining slots (block, stance, jump) and the other five schools ride the **recolor / active-stance-tint** fallback until their boons and clips exist on the incremental track.

---

## 6. Fallback & recolor

- **Un-arted infused move slot** (e.g. any non-Venom school's light/heavy/dash today, or a future Venom block once authored): play the **base clip tinted toward that school's `themeColor`** via the presenter material (`skin_tint`/`skin_tint_weight`, §4) — a subtle, readable tint under the telegraph/active-flash signals. Every school reads as *something* immediately; the bespoke variant clip silently supersedes the recolor when it lands.
- **Active stance:** while a stance technique from a stance-slot boon is active, tint the whole player render in that school's `themeColor` until deactivation (the v1 stance treatment).

---

## 7. Validation loop

- **Structure tests** (deterministic, scene-free where possible):
  - slot infused + variant clip registered → resolver returns the **variant** clip id;
  - slot infused + no variant clip → resolver returns the **base** clip id and flags **recolor** with the school color;
  - slot not infused → **base**, no recolor;
  - non-slot states (`IDLE`/`WALKING`/`HIT_REACTION`/`STUNNED`/`LANDING`/`COMBAT_ENTRY`) → never skinned, even with a full loadout;
  - enemy fighter → **never** skinned (renders via `FighterVisual`, has no loadout);
  - active stance → recolor flagged with the stance school's color; deactivation clears it.
- **Harness visual capture** (non-headless, real renderer through `main.gd`): capture a player **Venom light** attack and a **base light** attack; assert the Venom frame is **non-blank** and **differs** from base (the variant clip actually swapped), and that capture is **deterministic** across runs.
- **Readability check:** with a Venom loadout, the existing telegraph/active-flash colors still dominate during their windows (recolor/stance tint must not mask the teaching flash).

---

## 8. Out of scope / YAGNI

- The other five schools' bespoke clips, and Venom block/stance/jump (the incremental art track; the latter also needs the corresponding boons authored in #2's domain).
- **Ideal stance visuals:** replacing Hu's idle/neutral stance pose per active school, with transitions into every move. Deferred — large transition-authoring effort; v1 uses active-mode recolor.
- **Duo/Mastery blended visuals.** v1: a duo boon in a slot uses its **primary school's** variant clip (or that school's recolor); mastery uses its school's. A blended/unique look is a later enhancement.
- Idle/walk/persistent silhouette/aura changes — that's **spec B** (relic/equipment).
- Enemy move-skins.
- New gameplay-timing infrastructure (the technique engine already covers it).

---

## 9. Resolved decisions

1. **Scope:** boons → per-move clips only; relic/equipment aura deferred to spec B.
2. **Render target:** `FighterPresenter` (manifest + graph + timeline clips), player-only; enemies via `FighterVisual` untouched.
3. **System + Venom slice** = light, heavy, dash (the slots with existing Venom boons), order light→heavy→dash.
4. **Per-clip timing allowed**, served by the existing technique-engine override seam + `duration:"fromAttackDef"` — no new timing system.
5. **Fallback:** base clip + school recolor for un-arted slots (via presenter material, under telegraph/flash).
6. **Stance:** active-mode recolor in v1; ideal idle-stance replacement deferred.
7. **State mapping:** jump owns `JUMPING`+`FALLING`; `LANDING` and all non-move states stay base/never skinned.
8. **Storage:** per-school overlay variant clips (`assets/animation_clips/skins/<school>/`) + overlay manifest poses (`assets/animation_manifests/skins/<school>.manifest.json`), lazy-loaded for equipped schools.
9. **Art-agnostic** routing (current art is placeholder; see [[character-art-placeholder]]).

---

## 10. Sequencing (phases — full plan after approval)

1. **Skin schema + loader:** overlay variant-clip + overlay-manifest format under `assets/.../skins/`; lazy-load + cache + manifest merge in `FighterPresenter`; `set_move_skins(slot_school_map)`. Tests: load/merge/registration.
2. **Skin-aware clip resolution:** state→slot map; variant-vs-base resolution and `handles_state` update in the presenter; wire the player's `BoonLoadout` → `set_move_skins` at combat setup. Tests: §7 structure cases.
3. **Recolor + stance tint:** add `skin_tint`/`skin_tint_weight` uniforms to `scripts/visual/shaders/fighter_presenter.gdshader` (flash retains priority); presenter sets them via `_mat_current`. Route the per-frame active-stance school from `TechniqueEngine.is_stance_active()`/`active_stance()` into the presenter (`set_active_stance_school`). Apply `themeColor` tint for infused-but-unskinned slots and for active stance, under telegraph/flash. Tests: recolor flag + readability + stance activate/deactivate.
4. **Harness capture test:** Venom-light vs base-light capture assertion (non-blank, differs, deterministic).
5. **Venom slice content:** generate the 3 Venom variant clips (light→heavy→dash) through the gate, each into `skins/venom/` with poses in `skins/venom.manifest.json`; verify in-game (Gate 2) and via capture.
6. **Record** which slots/schools are filled and the roadmap for the rest.
