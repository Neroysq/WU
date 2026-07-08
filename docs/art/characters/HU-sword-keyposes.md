# Hu — Sword Key Poses (chapter-1 weapon: 贗劍)

**Date:** 2026-07-08 · **Status:** K1 APPROVED (`art/canon/hu/k1.png`, anime cel take 2 — face trade-off accepted); K2–K7 generating. **Generator policy: pixelforge×codex (GPT-Image-2) for character keyframes**; every output gets `flatten_quantize.py --denoise-only`; style spine = crisp anime cel, flat fills, 布鞋 cloth shoes, needle-long jian.
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
| K5 | 遊龍 dash — FANTASTIC | 輕功 | **no ref — deliberately cinematic** | dash |
| K6 | 登雲 jump — FANTASTIC | 輕功 | **no ref — deliberately cinematic** | jump apex |
| K7 | 點腕 wrist-point | 點 | #029 left — tip dropping onto the wrist line | light-attack recovery accent |

*(Plate↔figure numbering: front matter occupies images 001–011, so 圖N ≈ image #(N+11) — confirmed by 圖26 金雞獨立 = #037.)*

**Grounding rule (user decision, 2026-07-08):** grounded combat verbs (K1–K4, K7) take manual refs — they are the "real kung fu" register. **Dash and jump are NOT realistic combat moves; they go fantastic** (輕功 register, art law #2: bursts go cartoon) — no photographic ref, exaggeration in the prompt itself. K7 is experimental (unclear read) — one trial round.

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

## K5 — 遊龍 dash (FANTASTIC — 輕功 register)

From Li Jinglin's own words: 身如遊龍 — the body like a swimming dragon. The dash is that line made literal: body stretched almost horizontal, impossibly low and long, slipping through the air like a dragon through water; sword swept back along the body; 戟指 cutting the way forward; everything streaming. Exaggeration budget: 2–3× stretch, smear-friendly (§3c). **Flaw:** eyes squeezed shut — he still flinches when he commits.
`dash-youlong:1:false:fantastical martial arts dash - body stretched almost horizontal flying low above the ground lunging right like a dragon slipping through water - sword swept back along the body blade trailing - left hand sword-fingers cutting forward leading the motion - sash and hair whipping straight back clothes rippling with speed - side view facing right - eyes squeezed shut thrilled grin`

## K6 — 登雲 jump apex (FANTASTIC — 輕功 register)

Cloud-stepping: rising as if pulled skyward by a thread — body drawn long and weightless, legs gathered beneath, sword swept up in one vertical line above the head, robe and sash billowing DOWN while he goes up. The mountain's clouds are the destination; the pose should look like he belongs to them for half a second. **Flaw:** the gathered foot flexed, not pointed — no one taught him the finish.
`jump-dengyun:1:false:fantastical weightless leap apex - rising straight up as if pulled skyward by a thread - body drawn long and light - both legs gathered slightly beneath - sword swept up above the head in one vertical line - robe and sash billowing downward - left hand sword-fingers pointing to the sky - side view facing right - wide-eyed exhilarated laugh`

## K7 — 點 wrist-point (light recovery accent)

Body and arm still — ONLY the wrist snaps the tip down (the manual is explicit: 身臂皆不動). Front foot 虛, rear 實; a small, precise, almost polite motion — the comic beat after a landed light. **Flaw:** none; this one he does perfectly by accident, which is the joke. *(Experimental — unclear read at game size; one trial round, cut if it doesn't land.)*
`recover-point:1:false:standing nearly still after a strike - sword arm extended level while only the wrist snaps the blade tip downward in a small precise point - front foot light rear foot full - left hand sword-fingers in a calm half circle - side view facing right - pleasantly surprised face`

## Pipeline notes

- Generate K1 first (it replaces the earlier f1 gate); on approval, K2–K7 generate with K1's approved frame attached as the character reference, then clips pin K1 at start/end per the user directive (mid keys assist where Seedance/animate drifts).
- Grip-dial words (中陰/太陰 → "thumb-up grip"/"palm-down grip") stay in English in hints — the generator doesn't read the dial.
- Judged per ART_DESIGN_DOC: §3c timing budgets, §5b clean zones (weapon hand/blade unobscured), silhouette-vs-schools check at Task-9 time.
