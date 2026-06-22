# Venom Light Attack — Keyframe Brief (Task 8, Gate 1)

**Date:** 2026-06-22
**For:** move-skin slice — `venom_hu_attack_light` (replaces the placeholder copy)
**Gate:** this brief drives keyframe generation; the user approves the **poses/silhouette** (Gate 1) before any full generation, then scale-vs-idle review, then Gate 2 in-game. See [[review-keyframes-before-generating]], [[judge-art-size-overall-in-game]], [[art-direction-wild-comical]], [[character-art-placeholder]].

---

## Design intent

Hu's **base** light is a clean, linear **forward sword thrust** (long reach, range 362). The **Venom** light must read as a different *technique*, not a recolored thrust — because the fallback recolor proved color alone is invisible (thunder-on-blue vanished). The motif: **the serpent's fang** — Hu coils low like a snake, then lashes the blade forward in a venom-fang bite, flicking venom spray off the tip.

**Differentiators (so each school's light stays distinct):**
- **Base** = upright, straight horizontal thrust.
- **Venom** = **low coiled stance → rising serpentine lash**, off-hand held in a clawed "fang" guard, venom droplets spraying off the blade on contact. Lower center of gravity and a curved (S-shaped) body line are the silhouette tells; the green venom is secondary polish, not the read.

Wild-&-comical register: exaggerate the coil-and-snap (big wind-back, whip-fast lash, a theatrical venom spray fan) while keeping the pose legible at gameplay size.

---

## Hard constraints (must hold or it won't drop in)

- **Phase mapping** — keyposes anchor to the same timeline as the base (`duration: "fromAttackDef"`, hu_light: windup_end 0.18 / active_end 0.30 / total 0.50). Reuse the base's `t` anchors incl. the string anchors `"windup_end"` / `"active_end"` so the hit window lines up. Keep the `attack_active_start` / `attack_active_end` events at those anchors, and a `smear` track over the active lash (≈ t 0.36→0.66 of norm like the base).
- **Reach** — the **active frames must visibly extend the blade forward** to cover the long hit range (≈ the base's `strike_extended` extension). The coil is in windup; the reach is in active. Don't let the serpentine flourish shorten the visible strike vs the hitbox.
- **Facing** — authored facing **right** (engine mirrors by `facing`).
- **Size + grounding** — overall character size matches **idle** in-game (judge overall char vs idle, not head box); `footAnchor` grounded on the canvas for every pose; feet planted except the lunge push. One scale for the clip.
- **No new gameplay** — visual only; timing/damage stay hu_light (the venom_light boon already supplies the venom stacks via its effect).

---

## Key poses for Gate 1 (approve the pose language, ~5 poses)

Generation fills the in-betweens; these are the silhouette beats to approve first.

| # | Phase / t (norm) | Pose — silhouette | Venom read |
|---|---|---|---|
| **K1** | windup start (t≈0.00) | Drop into a **low coiled stance**, weight back, blade drawn back beside the rear hip, off-hand forward in a clawed "fang" guard. S-curved torso. | the snake coiling before a strike |
| **K2** | windup peak (t≈`windup_end`) | Maximum load — blade cocked low-and-back, shoulders wound, like a spring/coiled serpent at full tension. | venom gathering on the fang |
| **K3** | active strike (t≈0.40–0.46) | Explosive **rising serpentine lash** — blade thrusts forward and slightly upward (fang bite), body elongates from low to extended, **full reach**. Venom droplets fan off the tip. | the bite + venom spray |
| **K4** | active end (t≈`active_end`) | Full extension held a beat — arm/blade at max reach, a lingering venom mist trailing the arc. | venom hanging in the air |
| **K5** | recovery (t≈0.70–0.85) | Blade recoils in a **coiling figure** back toward the fang guard; a last venom drip slides off the point; settle toward neutral. | the serpent re-coiling |

(For reference, the base maps these beats to `vl_001` → `vl_051` windup, `vl_055`–`vl_081` active, `vl_082`–`vl_097` recovery; the Venom variant gets its own pose set authored into `assets/animation_manifests/skins/venom.manifest.json`, with `assets/animation_clips/skins/venom/venom_hu_attack_light.timeline.json` keyposes pointing at them.)

---

## Generation prompt seed (per keyframe)

> 2D side-view pixel-art wuxia swordsman facing right, **wuxia "venom sect" light sword strike** — [pose K# description]. Low serpentine stance, clawed off-hand fang-guard, subtle venom-green sheen on the blade with small dripping/spraying venom droplets. Exaggerated, lively, readable silhouette; consistent character height with the idle pose; full body in frame, feet on the ground line. Match existing Hu proportions and palette (blue-grey robe), transparent background.

Keep mouth closed/neutral (no shouting) consistent with [[breathing-calm-mouth-closed]] unless a strike grimace is explicitly wanted.

---

## Gate flow after approval

1. **Gate 1 (now):** user approves these poses / the venom-fang direction (or redirects).
2. Generate the keyframe images from the approved poses.
3. **Scale review:** verify overall size vs idle in-game (slider/ghost overlay), recompute `footAnchor` on any down-scale.
4. Generate the full frame set; author poses into `venom.manifest.json` + keyposes/events/smear into `venom_hu_attack_light.timeline.json` (keep `duration:"fromAttackDef"`).
5. **Gate 2:** in-game review; capture vs base light should now **differ** at the active frame too (the visual-diff gate from the plan).
6. Then repeat for heavy → dash.
