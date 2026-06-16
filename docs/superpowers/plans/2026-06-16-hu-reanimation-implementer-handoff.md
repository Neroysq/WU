# Hu Re-Animation — Implementer Handoff

**Date:** 2026-06-16
**Purpose:** Everything a new implementer needs to continue the Hu video-first re-animation. Read this first, then the three canonical docs it points to. Assumes you know Godot/GDScript but nothing about this project's pipeline or conventions.

---

## 0. How we work (read this — it governs everything)

- **Two roles.** A **reviewer** (Claude Code, working with the user) drafts/fixes docs, runs review pages, and relays the user's verdicts. **You (the implementer)** do all generation, installation, code edits, tests, and commits. The reviewer does *not* implement.
- **Two gates per action, the USER is the authority on both:**
  - **✋ Gate 1 — keyframe approval.** You generate candidate keyframe *stills*; the user picks/approves per slot before anything is installed. Genuinely-new poses only (see §6).
  - **✋ Gate 2 — in-engine feel.** You install + wire + capture an in-engine clip; the user judges the motion before you commit.
- **✋ STOP points** — any change to attack **reach / balance data** (`Attacks.json` `range_units`, enemy bands) must be presented to the user with a before/after table and approved *before commit*.
- **Never commit past a gate without the user's verdict.** Runtime work stays uncommitted until Gate 2 passes; keyframe approvals are committed as `art:` checkpoints as they pass Gate 1.
- **Commit message footer:** end commits with
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`

---

## 1. Project at a glance

- **Game:** WU (武) — Godot 4.6.2 wuxia 2D action roguelike. Project root: `/Users/animula/GitReps/WU`, Godot project in `WUGodot/`.
- **Goal of this effort:** re-animate all of Hu's visual states from **video-generated frames** (idle/walk/light/heavy = animated clips) and **exaggerated held poses** (hit/stunned/block/dash/jump = single stills carried by procedural motion — the "SF6 economy").
- **Three-truths architecture:** combat truth (deterministic gameplay) · animation truth (JSON timelines / manifest / graph) · presentation (`FighterPresenter` Node2D + shader). Keep them separate.

---

## 2. Canonical docs (source of truth — read in this order)

1. **Design spec (the *why* / architecture):** `docs/superpowers/specs/2026-06-12-hu-video-reanimation-design.md`
2. **Implementation plan (the *how*, task-by-task, Phases 0–6, runbook, gate + rollback protocol):** `docs/superpowers/plans/2026-06-12-hu-video-reanimation.md`
3. **Action design reference (the *what each action is and why*, per-action recipe + review decisions):** `docs/superpowers/specs/2026-06-16-hu-action-design-reference.md` — **keep this updated** as actions ship (status legend: ✅ shipped · ☑️ Gate 2 passed pending commit · 🔄 in progress · ⬜ queued).

This handoff is a snapshot/index; if it disagrees with the plan, the plan wins for *procedure* and the action-design-reference wins for *per-action intent*.

---

## 3. Current status (2026-06-16)

| Phase | What | Status |
|---|---|---|
| 0 | Foundations (presenter parity `useFighterOffset`, bounds provider, collision rule, temporal `--shot-action` harness, generalized installer, review page) | ✅ landed |
| 1 | Idle (guard-bracketed breathing loop, `vi_`) | ✅ landed |
| 2 | Walk (`vw_`, run3 take) | ✅ landed |
| 3 | Light attack (`vl_`, guard-start thrust; reach re-synced 342→362; BanditSwordsman re-tuned) | ✅ landed (`6638373`) |
| 4 | Heavy attack (`vh_`, overhead cleave; reach 340→258, close-range cleave, no lunge) | ✅ landed (`507300a`) |
| 5 | Held poses (hit/stunned/block/dash/jump, `vp_`) | ✅ landed (`12c27e2`) |
| **6** | **Entry draw (iaido flourish) + legacy `character_hu.json` retirement** | **⬜ NEXT — see §4** |

Phase 5 keyframes: `aa48b3d`, `90259a8`. Phase 5 runtime: `12c27e2` (held poses + stunned carrier retune + capture-prep `apply_stun` fix). Only Phase 6 remains.

---

## 4. ⏩ YOUR IMMEDIATE TASK — Phase 6 (the last phase)

Phases 0–5 are all landed (see §3). **Only Phase 6 remains: the entry draw + legacy retirement.** Full step-by-step is in the plan (`...2026-06-12-hu-video-reanimation.md`, "Phase 6") and summarized in §8 below. Shape:

1. **Keyframes (✋ Gate 1):** a sheathed-idle still + a mid-draw still.
2. **Video:** `animate-video --reference-seq sheathed mid-draw guard`, motion = *"stands relaxed with sword sheathed, then draws it in one fluid iaido motion into his ready guard stance."* Install as a new `entry_draw` clip.
3. **Wire as a scene-local combat-entry override** — NOT a `Fighter.AnimationState` (see §8 for the exact `COMBAT_ENTRY` routing contract: graph state with an arbitrary name, `_entry_timer` in `combat_scene`, input-suppressed-but-skippable).
4. **✋ Gate 2 → commit.**
5. **Retirement audit (only after every state above has passed Gate 2):** grep `character_hu.json`, switch Hu's visual profile off the legacy AnimationSet, delete the legacy set + orphaned frames (verify each with grep first), final full gates + `--shot-combat` across all 15 states. Commit `refactor(art): retire legacy Hu animation set`.

**Note this is the one phase that needs the sheathed scabbard** (with the sword *in* it) for the sheathed-idle keyframe — the rest of the canon is empty-scabbard (§7). The draw ends at the existing guard anchor.

### Reference: how Phase 5's stunned issue was resolved (now done, for context)
The stunned held pose first read as "breathing" for two compounding reasons, both fixed in `12c27e2`:
- **Carrier too timid:** the `AnimationState.STUNNED` offset in `fighter.gd` was a ±5px clean sinusoid (≈ idle). Retuned to a drunken stagger: `x = sin(t·6)·16 + sin(t·19)·4`, `y = cos(t·5)·6 + cos(t·23)·2`.
- **Capture-harness bug:** `--shot-action STUNNED` prep set `is_stunned` without `_stun_timer`, so the fighter reverted to IDLE on frame 1 and the GIF was 179 frames of idle. Fixed with `apply_stun(9999.0)`. **Lesson for any future held-state capture:** the prep must sustain the state's timer or the review rig silently shows the wrong state.

---

## 5. Commands & verification gates

All from repo root via `./run.sh`:

| Gate | Command | Pass condition |
|---|---|---|
| tests | `./run.sh --test 2>&1 \| tail -3` | `failed: 0` |
| import | `./run.sh --import 2>&1 \| grep -ciE "^ERROR\|SCRIPT ERROR"` | `0` |
| anchors | `./run.sh --anchor-sanity 2>&1 \| tail -1` | `ANCHOR SANITY: OK` |
| reach (attacks) | `./run.sh --probe-reach` | within balance band, or documented ✋ re-sync |
| temporal (feel) | `./run.sh --shot-action <STATE>` then `python3 tools/assemble_action_review.py <dir>` | GIF/strip show no foot-slide / flicker / loop seam; motion reads |

Other `run.sh` flags you'll use: `--install-video`, `--install-pixelized`, `--scale-masters`, `--measure-anchors`, `--stage-held-keyframes`, `--shot-combat`.

`--shot-action` states: `ATTACKING_LIGHT`, `ATTACKING_HEAVY`, `HIT_REACTION`, `STUNNED`, `BLOCKING`, `DASHING`, `JUMPING` (DASHING/JUMPING carry a `physics:true` flag so real velocity/gravity drives root motion). Capture is fixed-step at `DEV_CAPTURE_STEP = 1/60` — do **not** advance on wall-clock delta (it compresses the timeline).

---

## 6. File map (where things live)

- **Sprites:** `WUGodot/assets/sprites/characters/hu/<prefix>_NNN.png`. `.import` sidecars are **gitignored** — commit the PNGs only; run `--import` to regenerate sidecars locally.
  - Prefixes: `vi_` idle · `vw_` walk · `vl_` light · `vh_` heavy · `vp_` held poses (single stills, e.g. `vp_hit`, `vp_stun_a/b`, `vp_block`, `vp_dash`, `vp_rise`, `vp_peak`, `vp_fall`, `vp_land`). (Legacy `va_` iaido / `character_hu.json` set is being retired in Phase 6.)
- **Clip timelines:** `WUGodot/assets/animation_clips/*.timeline.json` (`idle`, `walk`, `hu_attack_light`, `hu_attack_heavy`, `held_*`). Held clips set `"useFighterOffset": true` to opt into the procedural offset.
- **Manifest (anchors/body rects):** `WUGodot/assets/animation_manifests/hu.manifest.json`
- **Animation graph (state → clip + enter mode/priority):** `WUGodot/assets/animation_graphs/humanoid.graph.json`
- **Attack data (timings, damage, `range_units`):** `WUGodot/data/Attacks/Attacks.json`
- **Procedural offset per state (`animation_offset`):** `WUGodot/scripts/fighter.gd` ~lines 243-277 (`match current_animation`). Each state writes a sin/cos offset; presenter adds it via `useFighterOffset`.
- **State resolution / presenter config:** `WUGodot/scripts/combat_scene.gd` (`_resolve_player_state_name()`, `configure(`), plus the `--shot-action` dev capture rig.
- **Presenter:** `WUGodot/scripts/visual/fighter_presenter.gd` (`useFighterOffset`, `get_body_rect()`); collision rule in `WUGodot/scripts/visual/presentation_collision.gd` (`STRIKE_POSE_BY_ID`, max-extension pose).
- **Keyframes (approved stills + provenance):** `art/keyframes/hu/<action>/<slot>.png` + `art/keyframes/keyframes.manifest.json` (record prompt/backend/seed/approved). Cost ledger: `art/keyframes/cost.md`.
- **Tooling:** `tools/install_video_frames.gd`, `tools/anchor_sanity.gd`, `tools/assemble_action_review.py`, `tools/build_keyframe_review.py`, `WUGodot/scripts/main.gd` (`--shot-action` harness).

---

## 7. Generation pipeline & conventions (the lessons that save reruns)

Generation uses **aiexp** (Seedance 2.0 for video, codex backend for ~$0 keyframe stills with image-to-image editing). Before the first generation step, capture `aiexp ... --help` and adapt flag spellings (the docs guarantee capability, not exact flag names).

- **Render:** foot-anchored, `renderScale` 2.0, `pixelize --fit-mode exact --palette vinik24` (24 colours). **Density match = identical `scale_applied`** across the family (exact mode), NOT identical pixel height.
- **Guard-start:** Hu's combat idle *is* the drawn-sword guard. Every action begins and ends at guard so combos chain. The one-time iaido draw is Phase 6 only.
- **Empty scabbard is canon:** the hip sheath has **no handle/pommel** (a handle reads as a duplicate sword). Every new keyframe must match the guard anchor's empty scabbard.
- **Genre-framed prompts:** describe motion in the game's terms ("2D fighting game", "Street Fighter neutral walk") + explicit negatives ("NO march", "NO deep lunges"), always "in place without translating" (the presenter handles travel).
- **Loops:** pin the same harvested pose at *both* ends (`--start-frame`/`--end-frame`) for closure-by-construction; if motion collapses, prompt for *more* steps rather than unpinning.
- **Grip/object consistency:** generate dependent poses (e.g. attack recover) via **image-to-image off a correct-grip adjacent frame**, not anatomical left/right wording.
- **Motion coherence:** adjacent attack anchors must form one natural swing (overhead→cleave OR coil→thrust — not overhead→horizontal).
- **Reach follows the visible blade:** each attack's `range_units` matches its max-extension pose tip; re-sync the enemy band (70–85% of Hu's light c2c 384) at a ✋ STOP with a table.
- **Judge colour on master PNGs / final vinik24 pixels**, never downscaled GIF previews (they fake green edge fringing).
- **Held poses (SF6 economy):** the still is static and maximally exaggerated; *all* motion comes from the procedural carrier in `fighter.gd` + juice (hitstop/shake/sparks). If a held state "looks like breathing," the carrier is undertuned (see §4) — not necessarily the art.
- **Deferred (accepted v1 artifact):** blade length varies slightly frame-to-frame on attacks (Seedance redraw). Gameplay-safe (hitbox uses one max-extension pose); polish later.

---

## 8. Phase 6 (next, after Phase 5 commits)

See plan §"Phase 6". Summary: sheathed-idle + mid-draw keyframes (Gate 1) → `animate-video --reference-seq sheathed mid-draw guard` → wire as a **scene-local `COMBAT_ENTRY` presenter override** (NOT a `Fighter.AnimationState`; graph state name is an arbitrary string; `combat_scene` holds an `_entry_timer`, suppresses input while >0, any input cancels) → Gate 2 → then the **retirement audit**: grep `character_hu.json`, switch Hu's visual profile off the legacy AnimationSet, delete `WUGodot/assets/animations/character_hu.json` + orphaned legacy frames (verify each with grep first), final full-gate + `--shot-combat` across all 15 states. Commit `refactor(art): retire legacy Hu animation set`.

---

## 9. Known test gap (FYI)

A past regression (non-boss enemy "won't die") slipped through because no test covered the victory path. If you touch `combat_scene.gd` end-of-combat logic, add coverage.
