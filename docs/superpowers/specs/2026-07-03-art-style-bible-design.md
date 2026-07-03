# WU Art Style Bible — 「山高墨濁」 — Design

**Date:** 2026-07-03
**Status:** draft (pre-plan) — for user review
**Origin:** the 九仙山 identity revamp (`2026-07-03-creative-identity-revamp-design.md`) — user verdict on slice 1: a **consistent art style design must precede all asset production** (school-icon revamp, Hu + corruption stages, immortals, enemies, scenes, clouds). This bible is that design.

**Position:** sits on top of LOCKED technical decisions and does not reopen them — 256×256 native character canvas (~1.7–1.9× runtime scale, `2026-04-29-wu-256px-resolution-spec.md`), VINIK24 palette exclusively, diorama stage presentation, the aiexp/GPT-Image-2 → pixelize → canonical-slots pipeline with measured anchors.

---

## 1. The thesis — three laws

1. **Lean wuxia heroic.** Mostly-real proportions, elegant blade silhouettes, stances that visibly echo each school's real root art (洪拳 rooting, 詠春 centerline, 八卦 circling, 八極 charge, 蛇形 coil, 鷹爪 seize) — never naming them.
2. **Bursts go cartoon.** When kung fu *happens*, physics goes Kung Fu Hustle: smears, giant anticipation poses, comic reaction faces, oversized immortal physiques. **Exaggeration is an event, not a state** — idle/walk/neutral stay grounded so the world reads real between explosions.
3. **Ink invades.** Corruption (濁) is literal black ink: it stains, bleeds, pools, and at the extreme forms *wrong shapes*. The horror arrives through the medium itself — the brush that draws the world betraying it.

(Decision log: character anchor = lean-heroic + burst exaggeration (b); invaded language = ink-bleed stain (a); scenes = hybrid painted-far/procedural-near; deliverables = doc + user-approved reference canon; pixelforge = new primary generator to trial, bible written generator-agnostic.)

## 2. Character language

- **Proportions:** ~6-heads for humans; the current 256px Hu is the baseline density/build reference. Immortals may break scale and anatomy — **power = permission to distort** (Xiong Tie's bulk fills the frame; later immortals bend further).
- **Silhouette rule (hard):** every school's practitioner must be identifiable in **pure black silhouette by stance alone** — Bear low-rooted wide, Crane one vertical line, Ox charging mass, Swallow mid-circle step, Snake coiled low, Eagle reaching seize. Any generated character sheet that fails the silhouette test fails review.
- **Burst grammar:** exaggeration fires only on action beats — attack active frames, posture breaks, deflects, boss beats. Allowed distortions there: limb smears, 2–3× anticipation squash, comic face swaps (the starstruck register), impact frames with white flash. Neutral frames stay on-model.
- **Hu:** young, light-framed, expressive face — his personality lives in reactions. Costume: plain pilgrim blues (current base is directionally right), nothing school-marked — he is nobody's disciple.
- **Hu's four corruption stages** (the flagship set) — same base sprite, escalating **ink-stain overlay**, must read at gameplay size:
  1. **Clean (清)** — as-is.
  2. **Touched** — a stain at the collar and sword hand; knuckles darkening.
  3. **Marked** — ink veins up the forearms and neck; eyes darkened; the stain *moves* slightly out of sync with him.
  4. **Claimed** — half-swallowed: torso/arm largely ink, and the stain forms **faint wrong shapes** (extra finger-silhouettes, a suggestion of a grin where no mouth is). The body stays intact; **the ink lies**.

## 3. Ink-stain corruption grammar

- Stains **grow from where kung fu enters the body**: hands, forearms, eyes.
- **Enemy touched-ness follows pool_class** (enemy wrongness = what they are; environment wrongness = where you are, per the identity spec): weak = none; strong = trace drips; elite = inky auras, stains in the *clothes' shadows*; boss/immortal = fully integrated.
- **Each immortal's ink tints toward their school's themeColor** (Xiong Tie iron-dark; She Shi green-black; etc.) — corruption carries school identity.
- **Maximum corruption is drawn IN the ink, not the body:** wrong shapes inside stains — extra fingers, misplaced grins, an eye in a sleeve-shadow. Comic register survives because the flesh stays cartoon-clean; the wrongness is always one layer removed.

## 4. Scene grammar (hybrid: painted far, procedural near)

- **Painted far layers:** four skies/mountain-silhouettes of the **same mountain**, one per depth band — generated pixel art installed as parallax textures:
  - **foothill** — warm dawn, generous sky, the peak distant and lovely (the poster of the rumor);
  - **mid** — paler, higher, the peak closer and slightly *too* tall;
  - **high** — cold, thin light, **ink pooling in the valleys below**, geometry of ridges beginning to disagree;
  - **gate** — near-black, the summit filling the frame, wrong.
- **Procedural mid/near** (bamboo, platforms, existing `BackgroundRenderer` elements) restyled to bible tokens — silhouette shapes and band palettes, no new systems.
- **Cloud/mist overlay** (queued from the slice-1 verdict): procedural layer that **thickens with altitude**; at high/gate bands the clouds are **ink-wash** — the same 濁 language as the characters.
- **Palette discipline:** named VINIK24 registers per band — foothill = warm register (golds/greens/warm earth), mid = neutrals, high = cold register (blues/purples), gate = ink extremes (near-blacks + one hot accent). The slice-1 `BAND_TINTS` washes are superseded by real per-band palette assignments as scene assets land.

## 5. Icon & UI language

- **Pictograms: silhouette-first, 2–3 VINIK24 tones, must read at 24px.** One visual family — same stroke weight, same framing, same level of abstraction — across the six schools, future outsiders (熊貓), and any later marks.
- The icon row is the **pixelforge bake-off** (§6): first production test of the new generator against the incumbent pipeline.

## 6. Deliverables & process

**A. The bible doc** (`docs/art/STYLE_BIBLE.md` once canon exists): the rules above as tokens — proportion numbers, silhouette tests, burst-grammar allowlist, ink-stain stage definitions, per-band palette tables, icon rules — plus **prompt fragments** for each asset class. Written **generator-agnostic**: every generation request = reference image(s) from the canon + tokens + a fragment; works for pixelforge or aiexp/GPT-Image-2 → pixelize.

**B. The approved reference canon** (the real bible — images beat prose for generators): **six sheets**, each produced shotgun-style (N candidates → **user picks → winner becomes canon**, Gate-1 discipline; per project memory, keyframe/pose approval and scale checks precede any install):
1. **Hu turnaround** — idle/walk key poses (the density/build baseline made canonical).
2. **Hu corruption strip** — the 4 stages side by side, at gameplay size AND detail size.
3. **Xiong Tie** — the first immortal; sets the immortal register (scale-break permission, iron-dark ink).
4. **One weak-pool enemy** (Dropout Blade) — sets the mook register (readable, comic, un-touched).
5. **Scene strip** — the four band skies of the one mountain.
6. **Icon row** — six school pictograms; **run the same brief through pixelforge AND the aiexp pipeline; winner by user's eye** (the bake-off that decides the default generator for small assets).

Canon lives in-repo: `docs/art/canon/` (approved sheets + a one-line provenance note each). Every future asset plan MUST cite which canon sheet it matches.

**C. Acceptance:** the bible is DONE when all six sheets are user-approved and the doc's tokens match what was approved (tokens are *descriptions of the canon*, not aspirations).

## 7. Out of scope

- **Production beyond the six sheets** — icon install, Hu re-generation/animation, enemy/scene production, cloud implementation: each a later slice consuming the canon.
- **Animation** — the real animation pass follows the bible (its keyframes must match canon); burst-grammar timing details land there.
- **Corruption mechanics** (the 内功/外功 slice) and any gameplay.
- Reopening locked tech (256px, VINIK24, diorama, pipeline anchors).

## 8. Sequencing (phases — full plan after approval)

1. **Bible doc draft** — write the token doc from this spec (fast; it's §1–5 formalized).
2. **Canon production, cheapest-risk first:** icon row (the pixelforge bake-off — smallest assets, tests the new tool) → Hu turnaround → corruption strip → Xiong Tie → Dropout Blade → scene strip. Each sheet: shotgun N candidates → ✋ user picks → canon.
3. **Token reconciliation** — adjust doc tokens to match the approved canon exactly.
4. **Record** — canon index + provenance; hand off to the first production slice (icons install).
