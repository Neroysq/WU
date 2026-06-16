# Hu Frame Normalization Pass — Design

**Date:** 2026-06-17
**Status:** design (pre-plan)
**Purpose:** Polish Hu's 237 video-derived poses so they are dimensionally and spatially consistent: **uniform head size**, **no unwanted drift**, and **feet planted on a ground line** (except airborne/dash) — with intended travel (e.g. the light-attack lunge) moved out of the baked pixels and into the presenter. Follows the completed video re-animation (`2026-06-12-hu-video-reanimation-design.md`, `…-reanimation.md`) and the per-action reference (`2026-06-16-hu-action-design-reference.md`). This is the polish pass those docs deferred (blade-length variance is *not* in scope; see §11).

---

## 1. Goal & scope

Three user-stated polish goals, reframed as **one normalization pass with two axes**:

1. **Size (item 1)** — every pose's drawn character is the same size, judged by **head height** (head is the most pose-invariant feature; full-body height changes with every crouch/lunge).
2. **Drift (item 2)** — no unwanted horizontal/vertical shift across a clip's frames; intended movement (light attack) is allowed but comes from the engine, not the art.
3. **Feet (item 3)** — feet planted on a consistent ground line, except when airborne or dashing.

Scope: all 237 Hu poses (`vi_/vw_/vl_/vh_/vp_/vd_` + named poses) and the attack clips' travel wiring. **Not** in scope: enemy archetypes, attack timings/damage, blade-length frame variance.

---

## 2. Background — why the variance exists (from pipeline review)

- **Size is never measured.** `install_video_frames.gd` applies one uniform `scale_applied` per frame from the master sidecar; `scale_masters.gd` normalizes masters by the *idle body height*, not head size. The manifest stores `footAnchor`, `chestAnchor`, `weaponTip`, `hurtbox` per pose — **no head data**. So per-frame drawn size genuinely varies, uncorrected.
- **Foot Y is not normalized and a single anchor isn't a ground line.** The installer pins `footAnchor.x` per batch (`FOOT_X_GROUP_SPREAD_CEILING = 2.0`) and the presenter places that anchor at `fighter.position`, but `foot.y` is installed as-measured and the anchor can land on different feet across frames — so one-foot-lifted poses float and the "planted" point wanders.
- **The light-attack lunge is baked into the pixels.** Its timeline deliberately dropped the offset track ("frames carry the lunge travel in-frame"). That is the *same mechanism* as unwanted drift — one wanted, one not. The presenter's per-state lunge offset (`fighter.gd` `animation_offset`, e.g. light `sin(progress·π)·15·facing`) already exists but is applied only when a clip sets `use_fighter_offset` (currently only `held_jump`).

---

## 3. Locked decisions

| # | Decision | Choice |
|---|---|---|
| 1 | Measurement method | **Automated detection + outlier-review page** (manual nudge only where detection is shaky) |
| 2 | Intended travel | **Presenter-driven** — plant every frame; re-enable the existing `fighter.gd` offset on the attack clips |
| 3 | Size pass quality | **Lossless re-derive** — normalize at the master/keyframe (source) stage and re-pixelize; never rescale finished pixel-art for size |
| 4 | Grounding split | **Grounded** (contact/lowest foot on the line): idle, guard, block, stunned, hit, light, heavy, entry, land, **walk** (always ≥1 foot down). **Exempt** (no grounding): jump rise/peak/fall (airborne) + **dash** |
| 5 | Idle reference | **Measure first, decide** — idle is the size reference; use its mean head as the global target; leave idle as-is if its internal wobble is within tolerance; regenerate idle only if visibly bad |

---

## 4. Architecture — two normalizations, two mechanisms

**Size (lossless, source-stage).** Measure each pose's head; compute a per-pose scale so its rendered head height equals one global target; apply at the master/keyframe stage and **re-pixelize** through the existing pipeline. This requires the smooth source (masters or keyframes), so §6 salvages them.

**Spatial (lossless, translation).** Measure a consistent ground-contact foot per pose; translate each frame so (a) for grounded states the contact foot's y sits on a fixed ground line, and (b) the contact foot's x is pinned to a constant — removing baked horizontal drift and vertical float. Pure pixel move + canvas pad, folded into the re-pixelize/install blit. For exempt states (§3.4), skip the y-grounding (keep source vertical; the hop/arc comes from the presenter/physics) but still pin x and size-normalize.

Both flow through the **existing** pipeline unchanged in shape:
`scale_masters → pixelize → install_video_frames → measure_anchors → anchor_sanity → probe_reach`.

---

## 5. Components (each a focused, independently-testable unit)

1. **Head/foot detector** (`tools/`, new) — per source frame: a **head bbox** (top-of-silhouette region down to the neck inflection) and **foot ground points** (lowest opaque pixel per leg, plus which foot is the consistent contact reference). Emits `measurements.json`. The exact detection heuristic is a plan-level detail; the *contract* is: one head-height metric + one contact-foot point per pose, with the review page (component 3) as the authoritative correctness backstop.
2. **Normalization solver** (`tools/`, new) — from measurements: `scale = target_head / measured_head` per pose, and the grounding/centering offset per pose (respecting the §3.4 grounded/exempt split). Emits `transforms.json` keyed by pose.
3. **Outlier-review page** (HTML, our usual self-contained `open` channel) — overlays each pose's detected head bbox + ground line + contact-foot marker; flags poses whose head/foot deviates beyond tolerance for a manual nudge. Manual marks override detection and re-run the solver.
4. **Re-derive runner** — feeds `transforms.json` into `scale_masters` (size, via its existing per-master `SCALE_NORM` hook) and the install blit (grounding translation), re-pixelizes, re-installs, and re-runs `measure_anchors`.
5. **Presenter travel** — set `use_fighter_offset` on the attack clips (`hu_attack_light`, `hu_attack_heavy` as appropriate) so the existing `fighter.gd` lunge drives motion now that the frames are planted; re-verify reach.

---

## 6. Master salvage (Step 0 — urgent)

Masters are **not** committed; they live in ephemeral `/tmp/wu-reanim` run-dirs. Current inventory:

| Action | Source available | Re-derive path |
|---|---|---|
| entry | `entry-pix` (50 master+pixel+sidecar) | salvage → re-derive |
| heavy | `heavy-pix` (31) | salvage → re-derive |
| light | `light-pix` (31) | salvage → re-derive |
| walk | `walk-run` (97 masters, no pixels) | salvage masters → re-pixelize chosen frames |
| held (`vp_`) | committed `art/keyframes/hu/` stills | re-derive from keyframes |
| idle | **gone** | reference only (no rescale); regen only if Decision 5 triggers |

**Step 0 of the plan must salvage the surviving `/tmp` masters into the repo as durable assets** before `/tmp` is cleared, so this normalization (and any future one) is lossless and repeatable. Choose a committed location (e.g. `art/masters/hu/<action>/`).

---

## 7. State handling (the three axes per state)

- **Size — all states:** every pose's rendered head height = the idle-derived target (±~1px). Idle is the reference (Decision 5).
- **Drift — all states:** the consistent contact foot's x is pinned to a constant; baked horizontal drift removed. Body lean within a pose is preserved (it's part of the pose); only whole-character translation across frames is removed. Attack "steps" become presenter travel.
- **Feet (grounding) — per Decision 4:**
  - **Grounded** (contact/lowest foot on the ground line): idle, guard, block, stunned, hit, light, heavy, entry, land, walk.
  - **Exempt** (no y-grounding): jump rise/peak/fall, dash. Still size-normalized and x-pinned; vertical position from presenter/physics.

---

## 8. Data flow

```
salvage masters (Step 0)
   ↓
detector → measurements.json
   ↓
solver → transforms.json
   ↓
outlier-review page  ←→  manual nudges (override, re-solve)
   ↓
re-derive runner: scale_masters (size) + install blit (grounding) → pixelize → install
   ↓
measure_anchors → anchor_sanity → probe_reach
   ↓
presenter travel re-enable (attack clips)
   ↓
Gate 2 per clip + head-aligned montage page
```

---

## 9. Verification & gates

- `./run.sh --anchor-sanity` → `ANCHOR SANITY: OK` (foot-x spread, tip ceiling, anchor tolerance).
- `./run.sh --probe-reach` → within the balance band. **Rescaling changes anchors → `weaponTip`/`hurtbox`/reach shift.** `measure_anchors` re-derives them; if reach moves out of band, **✋ STOP** and present a before/after table for re-sync (same protocol as the attack phases).
- `./run.sh --test` → `failed: 0`; `./run.sh --import` → clean.
- **Per-clip Gate 2:** `--shot-action` / `--shot-combat` strips — confirm uniform head size, no drift, contact foot on the line, attacks still lunge (via presenter), airborne/dash arcs intact.
- **New head-aligned montage page:** all poses overlaid/aligned on the head so size uniformity is eyeballable at once. This is the headline acceptance artifact for item 1.

---

## 10. Risks & mitigations

| Risk | Mitigation |
|---|---|
| `/tmp` masters cleared before salvage | Salvage is Step 0, done immediately |
| Head detection unreliable (arm/blade occlusion) | Outlier-review page; manual marks are authoritative |
| Rescale shifts reach/hurtbox out of band | `measure_anchors` + `probe_reach`; ✋ STOP re-sync if needed |
| idle's own wobble (masters gone) | Decision 5: measure → leave if in tolerance, else regen idle |
| Re-pixelize must preserve density | Reuse exact `pixelize --fit-mode exact --palette vinik24`; `scale_applied` uniformity gate already enforced by installer |
| Presenter lunge double-counts with any residual baked motion | Frames are planted first; verify reach + visual at Gate 2 |

---

## 11. Out of scope / YAGNI

- Blade-length frame-to-frame variance (separate deferred item).
- Enemy archetypes (keep their own sets).
- Attack timings, damage, `Attacks.json` balance (only touched if reach must re-sync at a ✋ STOP).
- No new animation content (this normalizes existing poses; idle regen only if Decision 5 triggers).

---

## 12. Sequencing

1. **Step 0 — salvage** surviving `/tmp` masters into the repo.
2. **Pilot** on idle + guard + light: build detector + review page, validate the re-derive loop end-to-end (size + grounding + presenter travel), Gate 2.
3. **Roll out** to all remaining actions, respecting the §3.4 grounded/exempt split.
4. **Final** `--shot-combat` montage across all 15 states + head-aligned montage; full gates; commit.
