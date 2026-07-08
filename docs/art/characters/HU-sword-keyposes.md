# Hu — Sword Key Poses (chapter-1 weapon: 贗劍)

**Date:** 2026-07-08 · **Status:** proposed — awaiting user review
**Sources:** 武當劍法大要 1931 plates (`art/reference/wudang-sword/`), HU.md §9 approved look, user directive (f1 anchors; walk/attack/jump/dash/block pin to f1 at both ends).

**Shared prompt spine (prepended to every action hint):** the §9 look is carried by the approved master (`hu-extract/extract/character.png`) via `sprite-extractor animate --character`; hints below are the per-action custom hints (comma-free, `name:frames:loop:hint` format).

**The wrongness dial:** keyframes generate the CLEAN Wudang shape; Hu's self-taught read comes from the eager face + one deliberate flaw per pose (noted per pose). Masters on the mountain later reuse these same shapes done perfectly — the contrast is the storytelling.

**Reference crops are SINGLE-FIGURE** (user note: paired plates are ambiguous generator input) — `art/reference/wudang-sword/crops/K*_plateNNN[LR].jpg`, cropped to the practitioner demonstrating the target shape:

| # | pose | 字 | ref crop (single figure) | game verb |
|---|------|----|--------------------------|-----------|
| K1 | 起手式 combat idle **f1** | 中陰 ready | #048 right — wide stable ready, 戟指 arced high | idle anchor |
| K2 | 平刺 flat thrust | 刺 | #040 left — tall clean full-extension line | light attack (active) |
| K3 | 劈山 overhead chop | 劈 | #030 right — overhead drop | heavy attack (active) |
| K4 | 上格 rising deflect | 格 | #048 left — blade up across the body | block / parry pose |
| K5 | 抽腕 dash draw-cut | 抽 | #013 left — deep committed lunge, rear arm arced | dash (attack blend) |
| K6 | 提膝 lifted-knee aerial | 提 | #037 right — 金雞獨立 one-leg thrust (圖26) | jump apex |
| K7 | 點腕 wrist-point | 點 | #029 left — tip dropping onto the wrist line | light-attack recovery accent |

*(Plate↔figure numbering: front matter occupies images 001–011, so 圖N ≈ image #(N+11) — confirmed by 圖26 金雞獨立 = #037.)*

## K1 — f1 起手式 (supersedes the three earlier f1 candidates; refines 乙)

Sword low-forward at thigh height in **中陰** grip (thumb-up), tip angled at the enemy's wrist line; left hand in **戟指 sword-fingers** arced before the chest; feet staggered, rear foot 實 full / front foot 虛 light; torso easy, chin up, eager alert face. **Flaw:** the 戟指 arc slightly too wide — a copied gesture, held too proudly.
`combat-f1:1:false:ready stance with straight sword DRAWN held low-forward at thigh height in thumb-up grip - tip aimed at opponent wrist line - left hand raised in arced sword-fingers pointing gesture before the chest - feet staggered with rear foot planted full and front foot light - side view facing right - eager alert expression - empty scabbard at left hip`

## K2 — 刺 flat thrust (light active)

Full extension: sword arm straight, blade FLAT (平刺), body leaning through the line, rear leg driving, front foot 實; 戟指 snaps back past the ear for counterbalance. **Flaw:** overextended half a hand — too eager.
`attack-thrust:1:false:full extension flat thrust - sword arm perfectly straight driving the blade tip forward at chest height - body leaning through the thrust line - front foot planted rear leg extended - left hand sword-fingers flung back past the ear - side view facing right - fierce eager face`

## K3 — 劈 overhead chop (heavy active)

Blade at the top of the drop, both hands committed, body tall then folding; front foot stomping 實. Windup key = blade behind the back shoulder (2–3 anticipation frames per §3c budgets). **Flaw:** heels a touch too square.
`attack-chop:1:false:overhead chop at the moment of impact - sword swung from high above the head down to waist height in front - both hands on the hilt - body folding forward with the strike - front foot stomped flat - side view facing right - shouting open-mouth effort face`

## K4 — 格 rising deflect (block & parry)

Blade angled up-forward across the body (下格 line), edge catching an imaginary wrist from below; hilt low, tip high; weight dropped, both knees soft, rear 實; 戟指 tucked at the sternum. This single pose serves block-hold AND the parry flash (deflect spark overlays it). **Flaw:** grip white-knuckled — he braces harder than a master needs to.
`guard-deflect:1:false:defensive deflect stance - sword held angled upward across the body with hilt low near the hip and tip high at head height - edge facing forward-up - knees bent weight dropped low - left hand sword-fingers tucked at the sternum - side view facing right - focused clenched expression`

## K5 — 抽 dash draw-cut (dash)

Mid-slip past the enemy: body low and long in the direction of travel, sword trailing in 太陰 (palm-down) grip slicing horizontally as he passes; 戟指 leading the motion. Reads as the dash streak's source pose. **Flaw:** eyes closed — he still flinches when he commits.
`dash-drawcut:1:false:low lunging slip to the right with body stretched long and low - sword trailing behind in palm-down grip slicing a flat horizontal line at waist height - left hand sword-fingers stabbing forward leading the motion - hair and sash streaming - side view facing right - eyes squeezed shut grin`

## K6 — 提 lifted-knee aerial (jump apex)

One knee lifted high (金雞獨立-class), hilt raised to shoulder, tip hanging down-forward (提 line), body drawn tall at the apex. **Flaw:** the lifted foot flexed, not pointed — no one taught him the finish.
`jump-lift:1:false:airborne apex pose - one knee lifted high to the chest - sword hilt raised at shoulder height with the blade tip hanging down-forward - body drawn tall and light - left hand sword-fingers extended level for balance - side view facing right - wide-eyed exhilarated face`

## K7 — 點 wrist-point (light recovery accent)

Body and arm still — ONLY the wrist snaps the tip down (the manual is explicit: 身臂皆不動). Front foot 虛, rear 實; a small, precise, almost polite motion — the comic beat after a landed light. **Flaw:** none; this one he does perfectly by accident, which is the joke.
`recover-point:1:false:standing nearly still after a strike - sword arm extended level while only the wrist snaps the blade tip downward in a small precise point - front foot light rear foot full - left hand sword-fingers in a calm half circle - side view facing right - pleasantly surprised face`

## Pipeline notes

- Generate K1 first (it replaces the earlier f1 gate); on approval, K2–K7 generate with K1's approved frame attached as the character reference, then clips pin K1 at start/end per the user directive (mid keys assist where Seedance/animate drifts).
- Grip-dial words (中陰/太陰 → "thumb-up grip"/"palm-down grip") stay in English in hints — the generator doesn't read the dial.
- Judged per ART_DESIGN_DOC: §3c timing budgets, §5b clean zones (weapon hand/blade unobscured), silhouette-vs-schools check at Task-9 time.
