# WU (武) — Art Design Document
*Version 2.0 — 九仙山 · 「山高墨濁」 ("the mountain is high, the ink is turbid")*

> v2 consolidates the approved creative identity (`docs/superpowers/specs/2026-07-03-creative-identity-revamp-design.md`), the art style bible (`.../2026-07-03-art-style-bible-design.md`), and the locked technical decisions (256px: `.../2026-04-29-wu-256px-resolution-spec.md`). It supersedes v1.0 everywhere they disagree. The **approved reference canon** (`art/canon/`, in production) outranks this doc: tokens describe the canon, not aspirations.

---

## 1. What the art must say

WU is a **bright, wild, comic kung-fu pilgrimage that curdles into cosmic horror as you climb**. Every visual choice serves that one arc:

- The **foothills** must look like the poster of the rumor — warm, generous, a mountain worth worshipping.
- The **summit** must look like the truth — near-black, wrong, a door pretending to be a peak.
- Between them, the change must be **gradual enough to feel like weather and unmistakable in hindsight**.

The player character's own body is the second canvas: **corruption shows on Hu before anywhere else** (diegetic 濁 — there is no meter).

## 2. The three laws (from the style bible)

1. **Lean wuxia heroic.** Mostly-real ~6-head proportions, elegant blade silhouettes, stances that visibly echo each school's real root art (洪拳 rooting, 詠春 centerline, 八卦 circling, 八極 charge, 蛇形 coil, 鷹爪 seize) — never named in-game.
2. **Bursts go cartoon.** Exaggeration is an **event, not a state**: smears, 2–3× anticipation squash, comic face swaps, white impact frames — on action beats only (attack actives, posture breaks, deflects, boss beats). Idle/walk/neutral stay grounded so the world reads real between explosions.
3. **Ink invades.** Corruption is literal black ink: it stains, bleeds, pools, and at the extreme forms *wrong shapes*. The horror arrives through the medium itself. The flesh stays cartoon-clean; **the ink lies**.

## 3. Presentation & technical constants (locked)

- **Diorama stage:** combat on platform stages with painted backgrounds; theatrical framing per arena context. (v1's core concept, retained.)
- **Character canvas:** **256×256 native**, runtime scale ~1.7–1.9× — density matches the chosen reference look; on-screen size unchanged from the 64px era.
- **Palette: VINIK24 exclusively.** Machine-audited: canon assets must pass a zero-off-palette check (`tools/art/palette_audit.py`).
- **Pipeline:** generation (aiexp / GPT-Image-2; pixelforge under trial) → pixelize/normalize → canonical slots with **measured anchors** + manifests; foot-anchored rendering; capsule collision matched to visible art. Judgments are made **in-game at runtime scale**, never on zoomed stills.
- **Animation:** presenter graph/timeline JSON; attack/move motion via Seedance video → frame harvest (slow-mo full-clip prompting; idle-pinned ends for attacks); GPT-Image-2 keyframes serve Gate-1 pose approval and pins.

## 4. Character language

### Hu — the starstruck pilgrim
Young, light-framed, expressive earnest face; plain pilgrim blues, no school markings — nobody's disciple. His personality lives in **reaction frames** (the comic register) and his tragedy in the **four corruption stages** — same base sprite, escalating ink overlay, all readable at gameplay size:
1. **清 Clean** — baseline.
2. **Touched** — stain at collar + sword hand, knuckles darkening.
3. **Marked** — ink veins up forearms/neck, eyes darkened, the stain subtly out of sync with his motion.
4. **Claimed** — half-swallowed; the stain's edge forms faint wrong shapes (extra finger-silhouettes, a grin where no mouth is).

### The Nine (immortals)
**Power = permission to distort.** Immortals may break scale and anatomy (Xiong Tie's bulk fills the frame). Each immortal's ink is **tinted toward their school's themeColor** and fully integrated — calm, total, dignified: they are not monsters, they are *finished*. Fight styles must echo their root arts so the player's own boons visually rhyme with the boss who taught them.

### Schools & the silhouette law
Every school's practitioner must be identifiable in **pure black silhouette by stance alone**: Bear low-rooted wide · Ox charging mass · Crane one vertical line · Swallow mid-circle step · Snake coiled low · Eagle reaching seize. The stance canon sheet (`art/canon/schools/stances.png`) is the test asset; any character sheet failing the silhouette test fails review.

### Enemies (the mountain's population)
Mooks are **comic and readable** (Dropout Blade: ill-fitting hand-me-downs, cocky grin, recognizably *bad* form — failed students, not soldiers). **Touched-ness follows encounter pool_class as a runtime ink overlay** (weak none → strong trace drips → elite inky auras; selected at spawn like the other encounter modifiers — never baked per archetype, since archetypes appear in multiple pools). Uniques (immortals) may bake their ink.

## 5. Corruption grammar (濁)

- Stains **grow from where kung fu enters**: hands, forearms, eyes.
- Wrongness is **always one layer removed** — drawn *in* the ink (shapes inside stains, an eye in a sleeve-shadow), never as body horror on the flesh. This is how comedy and cosmic horror coexist.
- Escalation order across a run mirrors the climb: environment (band palettes) → enemies (overlays by pool) → the player (stages) → the boss (integrated) → the door.

## 6. Scene grammar (hybrid: painted far, procedural near)

- **Painted far layers:** four skies of the **same mountain**, one per depth band —
  **foothill** warm dawn, peak distant and lovely · **mid** paler, the peak slightly *too tall* · **high** cold thin light, ink pooling in valleys, ridgelines starting to disagree · **gate** near-black, the summit fills the frame, wrong.
- **Procedural mid/near** (bamboo, platforms) restyled to bible tokens; platform materials per v1 (stone/wood/bamboo; cracked earth reserved for touched arenas).
- **Ink-wash clouds:** procedural overlay thickening with altitude; at high/gate the clouds are the same 濁 language as the characters.
- **Band palette registers** (named VINIK24 subsets): foothill = warm golds/greens/earth · mid = neutrals · high = cold blues/purples · gate = ink extremes + one hot accent. Environment wrongness keys on **altitude (node tier)**; enemy wrongness keys on **pool_class** — the mountain is wrong because of where you are, the enemies because of what they are.

## 7. Icons & UI

- **School marks are animal pictogram icons** (not hanzi — two-character animals like 熊貓 broke the pattern): silhouette-first, 2–3 VINIK24 tones, **legible at 24px**, one visual family (stroke weight, framing, abstraction level) across schools and future outsiders. Hanzi text fallback when an icon is missing.
- HUD/UI stays ink-and-paper: dark panels, gold accent, bilingual labels (命 HP / 構 PST pattern), rarity chips (common/rare/epic/legendary colors), band-tinted backgrounds on meta screens.
- UI wrongness at high bands is permitted but subtle (the corruption slice owns overt UI distortion).

## 8. VFX & feel

- Existing channels (hitstop, shake, slow-mo, particles, damage numbers) tuned **to the audio hero sounds** (deflect clang, break thud) — one impact, not three effects.
- Burst-grammar visuals (smears, impact flashes) are timeline-JSON data on the presenter rig — cheap, art-agnostic where possible.
- Ink VFX vocabulary: drips, blot-bursts on posture break (破), stain-spread on corruption gain, ink-wash trails on touched enemies' attacks.

## 9. Production law

- **Canon over prose:** every asset run cites its canon sheet (`art/canon/`, manifest with `file/prompt/backend/generator/seed/approved/notes`). Rejected candidates never enter canon.
- **Gates:** shotgun candidates → derived proofs (silhouette @ gameplay size · 24px icon row · palette audit · runtime-scale render) → **user picks** (Gate-1 discipline; scale/size re-checked in-game before install, per project memory).
- **Generator policy:** aiexp pipeline is the incumbent; **pixelforge** is on trial via the icon bake-off — winner by user's eye becomes the small-asset default. All briefs are generator-agnostic (reference image + tokens + fragment).
- **Sequencing reality:** identity content pass SHIPPED (slice 1); canon production is the current slice; real animation waits for canon; corruption *mechanics* (stages actually appearing in play) are their own slice.

## 10. Known debts & deferred

- Enemy sprites are pre-canon placeholders until the canon-consuming production slices land (art is placeholder by declared intent).
- Back-dash reuses the forward-dash clip (queued for the animation pass).
- Map upside-down fix (climb reads bottom→top) — directive with the implementer.
- Cloud/mist overlay: designed here, implemented in a later atmosphere slice.
- Overt geometric wrongness (non-Euclidean window paintings) reserved for high-band scene assets, not yet produced.
