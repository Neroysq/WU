# Venom Heavy Attack — Keyframe Brief (Task 8, Gate 1)

**Date:** 2026-06-23 · **For:** `venom_hu_attack_heavy` (move-skin slice, after light shipped).
**Gate:** GPT Image 2 keyframes → Gate-1 pose/style approval → Seedance (idle-pinned, slow-mo) → harvest/author → Gate-2. Same proven pipeline as the venom light. See [[move-anim-seedance-pipeline]], [[seedance-overlong-filler]], [[review-keyframes-before-generating]], [[judge-art-size-overall-in-game]], [[art-direction-wild-comical]].

## Design intent — "Venom Fang Cleave"

The venom **light** was a quick rising fang-thrust (fast, long reach). The **heavy** must read as its opposite: a **big, slow, committed venom blow** — Hu **charges the blade high overhead** (venom pooling and dripping heavily), then a **heavy downward/diagonal cleave** that **detonates venom on impact** (a fat green splatter/burst), then a weighty recovery. Heavy = commitment + a poison *detonation* (matches the boon: `venom_heavy` stacks 2 + `venom_heavy_detonate`).

**Differentiators (vs venom light):**
- **Light** = quick, forward, long-reach fang-thrust.
- **Heavy** = slow charged **overhead cleave**, **close** range (258), downward arc, **venom burst/splatter on impact** (a detonation, not a spray trail). Wider, heavier silhouette; clear big windup telegraph.

Wild-&-comical: exaggerate the overhead charge (blade wreathed in dripping venom) and the impact splatter, while staying readable.

## Hard constraints (must hold)

- **Idle-pinned both ends.** Seedance `--start-frame` and `--end-frame` = Hu idle `WUGodot/assets/sprites/characters/hu/vi_050.png`. The clip is `idle → charge → cleave → recover → idle`; the attack snaps in and idle isn't skinned, so it must start/end at the base idle pose (base heavy confirms: `vh_001`/`vh_097` are the idle guard). The charge/cleave are beats **within** the clip, not pins.
- **Phase mapping** onto `hu_heavy` (`duration:"fromAttackDef"`): windup 0→`windup_end` (0.40), active `windup_end`→`active_end` (0.40–0.55), recovery →1.0. Keep `attack_active_start`/`attack_active_end` events at the anchors and a `smear` track over the cleave. **Long windup (~47%)** = the heavy's big telegraph; make the raised-blade charge pose a clear tell.
- **Reach = close heavy** (~258). The cleave lands **close**, not at full arm extension — a heavy impact in front of Hu, not a long thrust. Don't over-extend the active frames past the hitbox.
- **Size vs idle**, feet planted (except the cleave step), `footAnchor` grounded, **facing right**, transparent bg, full body in frame, mouth closed.
- Visual only — timing/damage stay `hu_heavy`; venom stacks/detonate come from the boon effect.

## Key poses for Gate 1 (~5; generation/Seedance fills between)

| # | Phase / t (norm) | Pose — silhouette | Venom read |
|---|---|---|---|
| **K1** | windup start (t≈0.05) | from idle, both-hands/strong grip, begin raising the blade up-and-back, weight loading low | venom pooling on the blade |
| **K2** | windup peak (t≈`windup_end` 0.40) | blade **fully raised high overhead**, body wound/coiled to strike, **heavy venom dripping** off the edge — the big telegraph | charged poison, about to detonate |
| **K3** | active cleave (t≈0.45) | committed **downward/diagonal cleave**, blade slamming down **close**, **venom bursts/splatters** outward on impact | the detonation |
| **K4** | active end (t≈`active_end` 0.55) | follow-through — blade low/forward after the cleave, venom splatter hanging, weight forward | venom settling on the wound |
| **K5** | recovery (t≈0.72) | heavy recover — pulling the blade back up toward the idle guard, weighty settle | — |
| → | end (t=1.0) | **back to idle guard** (`vi_050`) | — |

## Generation prompt seed (GPT Image 2 keyframes, per pose)

> 2D side-view pixel-art wuxia swordsman facing right, **venom-sect HEAVY sword attack** — [pose K# description]. Big committed overhead cleave; thick venom-green pooling/dripping on the blade and a heavy venom splatter burst on impact. Heavier, wider silhouette than a light jab. Full body in frame, feet on the ground line, character height equal to Hu's idle; match Hu's exact pixel-art style, blue-grey robe, proportions, palette; transparent background; mouth closed.

## Seedance prompt (after Gate-1 pose approval)

> 2D wuxia fighting-game **venom-sect heavy sword attack in smooth SLOW MOTION**, one continuous strike across the entire clip. **Start and end in the neutral idle guard stance.** From idle: slowly raise the sword high overhead in a charged windup with venom pooling and dripping, then a heavy downward cleave that detonates a green venom splatter on impact (close range), then a weighty recovery **back to the same idle guard stance** — fully returned to idle by the final frame. Strike **in place without translating**; constant slow pace, the cleave landing around the **midpoint**. Keep Hu's exact pixel-art style/proportions/palette.

**Negatives:** ending in a different pose than the start, finishing early then holding, pausing mid-motion, a second swing/reset, high knees, drifting, floating, camera move, style drift, extra characters, mouth open, long thrust (this is a close cleave, not a reach).

## Gate flow
Gate 1 (approve these poses / the cleave direction) → generate GPT Image 2 keyframes → Seedance (idle-pinned slow-mo) → validate source (adjacent-diff: only a cleave/impact spike, no reset) → harvest/resample to 0.85s, normalize, author `skins/venom/venom_hu_attack_heavy.timeline.json` + manifest poses → Gate 2.
