# Hu — Action Design Reference (reviewed)

**Date:** 2026-06-16 (living document — update as actions complete)
**Purpose:** The approved per-action design for Hu's video-first re-animation: concept, pose anchors, generation recipe, and the review decisions behind each. Complements the implementation plan (`2026-06-12-hu-video-reanimation.md`, the *how*) and the design spec (`2026-06-12-hu-video-reanimation-design.md`, the *why/architecture*). This doc is the *what each action is and why*, captured from the Gate-1/Gate-2 review sessions.

Status legend: ✅ shipped (committed) · ☑️ Gate 2 passed, pending cleanup/commit · 🔄 in progress · ⬜ queued

---

## Character constants (apply to every action)

- **Art direction:** wild, exaggerated, comical — unreal but clear and fun — in *action* poses. *Resting* states (idle breath) read calm.
- **Hip scabbard:** Hu wears a green scabbard at the hip + a jade tassel on the drawn sword. The scabbard is **empty** (just a sheath — no handle/pommel sticking out). A handle on the sheath reads as a second sword ("duplicate sword" defect, see Light/Heavy notes). Empty-scabbard is canon since the guard keyframe; every new keyframe must match it.
- **Guard-start:** Hu's combat idle *is* the drawn-sword guard. Every action begins and ends at this guard so combos chain cleanly; no per-swing draw/re-sheath. The one-time iaido draw is a separate combat-entry flourish (Phase 6).
- **Render:** foot-anchored, `renderScale` 2.0, `pixelize --fit-mode exact --palette vinik24` (24 colours). Density match = **identical `scale_applied` across the family** (exact mode), NOT identical pixel height — the idle/reference silhouette is ≈177px content height, but action silhouettes may legitimately be shorter/taller by pose. What must match is scale/texel density, not height.
- **Guard anchor keyframe:** approved `cand_1` (upright, blade raised, drawn). Conditions all other keyframes — `art/keyframes/hu/guard/stance.png`.

---

## Idle ✅

- **Concept:** calm combat-guard breathing loop. Chest rises/falls, weight shifts subtly. **Mouth closed — no panting/mouth-opening** (reads as exertion otherwise).
- **Anchors:** guard as BOTH endpoints. **No breath keyframe** — the inhale amplitude is the video model's job, judged in motion at Gate 2, not authored as a still.
- **Recipe:** `animate-video` bracketed, `--start-frame guard --end-frame guard`, motion = "breathes calmly, chest rising and falling, weight shifting subtly, returns exactly to the starting pose." Loop closure exact by construction.
- **Result:** 16 `vi_` poses, 2.0s loop, no synthetic offset/scale/rotation tracks (drawn breathing replaces them).
- **Review note:** v1 approved with a flag that breathing must stay calm/mouth-closed on any future regen.

## Walk ✅

- **Concept:** careful in-stance combat advance — a 2D fighting-game *neutral walk*, not a casual or military march. Reads as a poised fighter stalking forward.
- **Anchors:** the same stride pose pinned at BOTH ends (harvested from a free-run master frame, `walk_anchor.png` = run2 frame_037) → begin≡end loop closure by construction.
- **Recipe:** `animate-video`, `--start-frame walk_anchor --end-frame walk_anchor`, motion = "2D fighting game neutral walk, low grounded combat stance, small measured forward steps, feet low to the ground, stalking like a Street Fighter character, NO high knees, NO deep lunges, steady body height, stepping in place without translating across the frame." Chosen take: **run3** (careful one-stride).
- **Result:** `vw_` poses, `rate: velocity`, 0.6s, no bob/lean tracks.
- **Review notes / lessons:** locomotion needs **no authored keyframes** — the prompt is decisive ("march" → stiff lunges; fighting-game framing → grounded steps). Free-end runs wander (no clean loop → trim a window); pinning the same pose both ends closes the loop but can suppress motion (fix: prompt "two full steps"). Legs are deliberately subtle → **foot-slide is the in-engine Gate-2 check** (tune `move_speed`/duration, never regenerate). Green "outlines" in GIF previews were a palette artifact, not spill — judge colour on PNGs/final pixels.

## Light attack ✅

> **Repo state:** Phase 3 landed: `vl_` poses installed, old `va_` rollback assets removed, timeline/collision/reach/enemy tune committed.

- **Concept:** quick guard-start thrust. Coil back → explosive horizontal thrust → recover to guard. Replaces the old `va_` iaido (which drew + re-sheathed every swing); the new one chains from combat stance for combos.
- **Anchors:** guard → **coil** (coil_fixed cand_1) → **thrust** (thrust_fixed cand_1) → guard. Both coil/thrust were re-edited to empty the hip scabbard (initial generations drew a handled sheath = duplicate-sword defect).
- **Recipe:** `--reference-seq guard coil thrust guard`.
- **Result:** ~30 `vl_` poses. Collision → max-extension active pose `vl_051`. **Reach re-synced 342→362** ("match the visible blade" — the new thrust extends further); BanditSwordsman re-tuned (all attacks to 250) to stay in the 70–85% band.
- **Known issue (deferred):** blade length varies slightly frame-to-frame (Seedance redraw). Gameplay-safe (hitbox uses one max-extension pose); visual-polish deferral, will recur in heavy.

## Heavy attack ✅

> **Repo state:** Phase 4 landed (commit `507300a`): `vh_` poses installed, timeline/collision/reach committed, tests 305/0.

- **Concept:** **Overhead Cleave** — big telegraphed overhead raise → downward diagonal cleave → low heavy settle. Deliberately distinct from light's horizontal thrust (a horizontal heavy strike reads as "just a slow light"). The vertical silhouette differentiates the two attacks at a glance.
- **Anchors:** guard → **windup** (cand_2, overhead raise) → **strike** (cand_4, diagonal cleave down) → **recover** (cand_2, regenerated via image-to-image *from strike cand_4* to inherit the grip) → guard.
- **Recipe:** `--reference-seq guard windup strike recover guard`.
- **Result:** 30 `vh_` poses, timeline rewritten to `vh_` with smear track only (legacy `offsetX`/`scaleX` windup transforms deleted = motion-study transform rollback). Collision → max-extension active pose `vh_064`. **Reach re-synced 340→258** (-82; c2c 362→280, heavy now 72.9% of light) — the cleave tip lands closer than light's thrust, so by the "match the visible blade" rule heavy is shorter. **No enemy retune** — the 70–85% band is keyed to hu_light's c2c (384), unaffected by heavy's shorter reach.
- **Design decision (✋ STOP, user-approved):** **accept short reach, no lunge** (`forward_lunge` stays 0). Heavy is a deliberate close-range committed cleave: slower (0.85s vs light 0.5s) *and* shorter, paid back by 2× damage (22 vs 12). It must be landed from inside light range — the higher risk is the cost of the higher payoff. Considered and rejected: a lunging cleave that adds `forward_lunge` to keep blade-true reach while closing distance.
- **Known issue (deferred):** blade length varies slightly frame-to-frame (Seedance redraw, recurs from light). Gameplay-safe (hitbox uses the single max-extension pose `vh_064`); visual-polish deferral.
- **Review rule (important, learned here):** windup and strike must form **one coherent swing**. Overhead windup → horizontal thrust is an unnatural path and produces a muddy video + grip mismatch in the recover (recover was generated for a different swing than the chosen strike). Pick a coherent pairing first (overhead→cleave OR coil→thrust), *then* generate recover from the final strike.

## Held poses ⬜ (Phase 5)

- **Concept (SF6 economy):** hit / stunned / block / dash / jump are *held poses*, not animated clips — their durations are gameplay-variable and interrupt-any-frame. Single maximally-exaggerated stills (huge recoil, spiral-eye dizzy) carried by existing procedural motion (shake/wobble/bob/arc) + juice (hitstop, shake, sparks). No video.
- **Gate:** stills via Gate 1; quality judged at Gate 2 with the procedural carriers live. Requires the §5a presenter parity (opt-in `animation_offset`) already built in Phase 0.

## Entry draw ⬜ (Phase 6)

- **Concept:** one-time combat-entry flourish — sheathed idle → iaido draw → guard. The draw we removed from per-swing attacks returns here as entry swagger. Scene-local `COMBAT_ENTRY` presenter override, skippable on input.

---

## Cross-cutting generation lessons (the recipe knowledge)

1. **Gate 1 = genuinely new poses only.** Micro-variants of an approved pose (breath-tier deltas) are carried by a begin=end video prompt, not authored — judged in motion at Gate 2.
2. **Genre-framed prompts.** Describe motion in the game's own terms ("2D fighting game", "Street Fighter") + explicit negatives ("NO march", "NO deep lunges"). Always "in place without translating" (presenter handles travel).
3. **Loops:** pin the same harvested pose at both ends for closure-by-construction; if motion collapses, prompt for *more* steps rather than unpinning.
4. **Object-state consistency:** blade drawn, scabbard empty, same grip across the whole set. The "duplicate sword" / morphing artifacts come from inconsistency.
5. **Grip consistency** comes from **image-to-image editing off a correct-grip frame**, not from anatomical left/right wording (which does nothing). Generate dependent poses (e.g. recover) *from* the approved adjacent pose.
6. **Motion coherence:** adjacent anchors must form one natural swing; mismatched anchors muddy the video and desync grips.
7. **Judge colour on master PNGs or final vinik24 pixels**, never downscaled low-colour GIF previews (they fake edge fringing from saturated elements).
8. **Reach follows the visible blade.** Each attack's `range_units` matches its max-extension pose tip; re-sync enemy band (70–85% of Hu) at a ✋ STOP with a before/after table.
9. **Blade-length frame-to-frame variance** is an accepted v1 artifact (gameplay-safe via single-pose hitbox); polish later via tighter selection or a normalization pass.
