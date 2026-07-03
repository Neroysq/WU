# WU (武) — Art Design Document
*Version 2.1 — 九仙山 · 「山高墨濁」 ("the mountain is high, the ink is turbid")*

> v2 consolidates the approved creative identity (`docs/superpowers/specs/2026-07-03-creative-identity-revamp-design.md`), the art style bible (`.../2026-07-03-art-style-bible-design.md`), and the locked technical decisions (256px: `.../2026-04-29-wu-256px-resolution-spec.md`). It supersedes v1.0 everywhere they disagree. **v2.1 adds the executable token layer** (design review, 2026-07-03): tokens marked **[PROV]** are provisional — the canon reconciles them (canon over prose still holds; canon status is marked per reference since production is in flight).

**Consumer index** — *character artist/brief:* §2, §4, §5, craft constants (§3b), timing (§3c) · *icon brief:* §7 + palette table (§3a) · *scene brief:* §6 + §3a · *implementer:* §3, §7 tokens, §8 · *reviewer:* §9 gates.

---

## 1. What the art must say

WU is a **bright, wild, comic kung-fu pilgrimage that curdles into cosmic horror as you climb**. Every visual choice serves that one arc:

- The **foothills** must look like the poster of the rumor — warm, generous, a mountain worth worshipping.
- The **summit** must look like the truth — near-black, wrong, a door pretending to be a peak.
- Between them, the change must be **gradual enough to feel like weather and unmistakable in hindsight**.

Two first-signals, explicitly (they don't compete): **altitude is the first *world* signal** (band palettes shift before anything else changes), and **Hu is the first *personal* signal** (corruption shows on his body before any UI — diegetic 濁, no meter).

## 2. The three laws (from the style bible)

1. **Lean wuxia heroic.** Mostly-real ~6-head proportions, elegant blade silhouettes, stances that visibly echo each school's real root art (洪拳 rooting, 詠春 centerline, 八卦 circling, 八極 charge, 蛇形 coil, 鷹爪 seize) — never named in-game.
2. **Bursts go cartoon.** Exaggeration is an **event, not a state**: smears, 2–3× anticipation squash, comic face swaps, white impact frames — on action beats only. Idle/walk/neutral stay grounded.
3. **Ink invades.** Corruption is literal black ink: it stains, bleeds, pools, and at the extreme forms *wrong shapes*. The flesh stays cartoon-clean; **the ink lies** — and it **never costs combat information** (§5b).

## 3. Presentation & technical constants (locked)

- **Diorama stage:** combat on platform stages with painted backgrounds; theatrical framing per arena context. Platform materials: worn stone / wood / bamboo; cracked earth reserved for touched arenas (folded from v1 — v1 is fully superseded).
- **Character canvas:** **256×256 native**; character bbox ≈205px tall (80%). **Runtime scales are per-profile values whose normative source is `WUGodot/data/VisualProfiles/DefaultProfiles.json`** — cite the file, never bake numbers into docs (they drift: the 256px spec's migration table said player 1.625; live data today says 2.0). Proof tooling reads the file. Sampling: **nearest-neighbor**, no AA at source or scale time.
- **Pipeline:** generation (aiexp / GPT-Image-2; **pixelforge** — lives in `AIexp/tools/pixelforge-*` — under trial) → pixelize/normalize → canonical slots with measured anchors + manifests; foot-anchored rendering; capsule collision matched to visible art. Judgments **in-game at runtime scale**, never zoomed stills.
- **Animation:** presenter graph/timeline JSON; attack/move motion via Seedance video → frame harvest; GPT-Image-2 keyframes for Gate-1 approval and pins.

### 3a. Palette law + tables

**Scope of "VINIK24 exclusively": SOURCE ASSETS** (sprites, backgrounds, icons — what `tools/art/palette_audit.py` audits *(planned — canon plan Task 2)*). **Runtime compositing is exempt** — band washes, ink-overlay alpha, hit flashes, school tints — but must **start from palette colors**. Enumerated computed exemptions: `COLOR_GOLD_DARK` (#6a4a1a, derived midpoint, `game_constants.gd:44`); add future exemptions HERE, not in code comments.

**VINIK24 (extracted from pipeline palette data — the single source):**
`#0f0f1b 墨 ink-black · #565a75 石 slate · #c6b7be 紙 paper-grey · #faf6f6 雪 snow-white · #f49e4c 橙 warm-orange · #ab5236 土 clay · #bf2652 緋 crimson · #74233c 瘀 bruise · #3b1725 夜 dark-wine · #73172d 血 dried-blood · #b4202a 朱 vivid-red · #df7126 焰 flame-orange · #ee9c24 金 imperial-gold · #f8c83c 亮金 bright-gold · #4e8339 竹 bamboo-green · #2c4a2e 松 pine · #20394f 淵 deep-blue · #255674 湖 lake · #577399 靄 haze-blue · #96b2c5 霧 mist-blue · #a1d2e0 天 sky · #6b3e75 紫暗 dark-purple · #905ea9 紫 purple · #a884f3 亮紫 light-purple`

**Band registers [PROV]** (bands may overlap; environment keys on altitude/node tier):
| band | member colors | note |
|---|---|---|
| foothill | 橙 焰 金 亮金 竹 松 紙 雪 | warm, generous |
| mid | 紙 霧 石 靄 淵 土 | neutral, thinning |
| high | 淵 湖 靄 霧 紫暗 紫 亮紫 石 | cold; ink pooling |
| gate | 墨 夜 瘀 血 石 淵 + **accent 緋 (door-crimson)** | near-black + one hot accent |

**School colors [PROV — data migration task]:** current `Schools.json` themeColors are all off-palette; pin VINIK24-nearest and migrate the data: Snake 蛇 → 竹 #4e8339 · Ox 牛 → 天 #a1d2e0 · Crane 鶴 → 亮金 #f8c83c · Bear 熊 → 霧 #96b2c5 · Swallow 燕 → 湖 #255674 · Eagle 鷹 → 金 #ee9c24. Immortal ink tint = school color blended toward 墨 (runtime, exempt class).

### 3b. Craft constants [PROV]

Outline: **dark outline 墨** with selective selout (lit edges may use the adjacent darker ramp color); **key light top-left**, consistent across characters and scenes; **dither:** painted far layers only — never characters, icons, or UI; **AA: none** at source; **shadows:** soft dark ellipse under every grounded character (jump readability), consistent opacity.

### 3c. Animation timing [PROV — reconciled in the animation pass]

Engine 60Hz. Sprite animation targets **12–15 effective fps**. Clip budgets (source frames): idle 4–6 · walk 6–8 · attack anticipation 2–3, **active 1–2**, recovery 2–3 (matches the pipeline's action set) · hit-react 2–3. **Smears: 1–2 frames, active beats only. White impact frame: ≤2 engine frames**, always paired with hitstop (0.18s on break; tuned to the audio hero sounds). Burst frames freeze during hitstop (one impact, not three effects).

## 4. Character language

### Hu — the starstruck pilgrim
Young, light-framed, expressive earnest face; plain pilgrim blues, no school markings — nobody's disciple. Personality lives in **reaction frames**; tragedy in the **four corruption stages** — same base sprite, escalating ink overlay, all readable at gameplay size, all within the §5b limits:
1. **清 Clean** — baseline.
2. **Touched** — stain at collar + sword hand, knuckles darkening. Coverage ≤ **10% [PROV]**.
3. **Marked** — ink veins up forearms/neck, **eyes darkened (the sanctioned flesh exception — eyes are where kung fu enters)**; stain desyncs from motion by **1–2px, 2-frame lag [PROV]**. Coverage ≤ **25% [PROV]**.
4. **Claimed** — half-swallowed; stain edges form wrong shapes. Coverage ≤ **45% [PROV]**.

### The Nine (immortals)
**Power = permission to distort — within hitbox trust.** Torso mass, robes, ink aura, and anticipation poses may break scale/anatomy; the **active limb, weapon path, hurtbox center, and feet stay readable at all times**. Immortal ink is fully **integrated** — calm, total, dignified — and integration *suppresses* wrong-shapes (the finished don't leak; leaking is for the in-between). Fight styles echo their root arts so the player's boons visually rhyme with the boss who taught them.

| immortal | school (root) | animal | stance silhouette | color (VINIK) |
|---|---|---|---|---|
| 熊鐵 Xiong Tie | iron (洪拳) | 熊 Bear | low-rooted wide | 霧 #96b2c5, iron-dark ink |
| 牛雷 Niu Lei | thunder (八極) | 牛 Ox | charging mass | 天 #a1d2e0 |
| 鶴柔 He Rou | soft (詠春) | 鶴 Crane | one vertical line | 亮金 #f8c83c |
| 燕影 Yan Ying | wind (八卦) | 燕 Swallow | mid-circle step | 湖 #255674 |
| 蛇噬 She Shi | venom (蛇形) | 蛇 Snake | coiled low | 竹 #4e8339 |
| 鷹目 Ying Mu | sword (鷹爪) | 鷹 Eagle | reaching seize | 金 #ee9c24 |
| — unseen | (龍 the First Master's root) | 龍 Dragon | *not this chapter* | — |
| — unseen | (虎 the vacancy) | 虎 Tiger | *not this chapter* | — |
| — unseen | (猴拳) | 猴 Monkey | *not this chapter* | — |

### Schools & the silhouette law
Identifiable in **pure black silhouette by stance alone** (table above). Test asset: `art/canon/schools/stances.png` *(this slice — canon plan Task 9)*. Tested at gameplay size, 2× UI size, and thumbnail; on stance poses now, extended to windup/active/recovery when the animation pass lands. Failing the silhouette test fails review.

### Enemies (the mountain's population)
Mooks comic and readable (Dropout Blade: hand-me-downs, cocky grin, recognizably *bad* form). **Touched-ness = runtime ink overlay keyed to encounter pool_class** (weak none → strong trace drips (2–3 drip marks [PROV]) → elite inky aura (≤0.15 char-height halo [PROV])); never baked per archetype. Uniques may bake. **Mook death convention: burst into ink** (blot-burst + dissipate — the mountain reclaims its lessons) **[PROV]**.

## 5. Corruption grammar (濁)

- Stains **grow from where kung fu enters**: hands, forearms, eyes.
- Wrongness is **always one layer removed** — drawn *in* the ink, never as body horror on the flesh (eyes darkening is the single sanctioned exception).
- Escalation across a run: environment palettes are the first *world* signal; Hu's stages the first *personal* signal; enemies (by pool), the boss (integrated), the door complete the ladder.

### 5b. Readability limits (law — the ink never costs combat information)

- **Reserved clean zones at combat scale:** weapon hand, blade edge, face direction, feet, and the active attacking limb stay ink-free (stains route around them; the "sword-hand stain" of stage 2 sits at wrist/knuckles, never obscuring grip or blade line).
- **Coverage caps per stage:** 10 / 25 / 45% **[PROV]** (§4).
- **Wrong-shape minimum size: ≥8 source px** for micro motifs, larger for face/hand motifs; wrong-shapes appear on **idle / result / mirror closeups** — in-combat only if proven readable in combat captures.
- **Immortal distortion limits:** §4 (active limb / weapon path / feet always readable).
- **Ink is never threat information** (§8a): ink trails on touched enemies are cosmetic; players must never learn a false language.

## 6. Scene grammar (hybrid: painted far, procedural near)

- **Painted far layers:** four skies of the same mountain, one per band — foothill warm dawn · mid paler, peak slightly *too tall* · high cold, ink pooling in valleys, ridgelines disagreeing · gate near-black, summit fills the frame, wrong.
- **Procedural mid/near** restyled to tokens; **ink-wash clouds** thicken with altitude (later atmosphere slice).
- **Band palettes: §3a tables.** Environment wrongness keys on **altitude**; enemy wrongness on **pool_class**.
- **Arc coverage matrix (honesty about what carries the arc today):** sky ✓ per band (canon slice) · band washes ✓ shipped · clouds — deferred · enemy ink — corruption slice · Hu stages — corruption slice · UI wrongness — corruption slice. **Mid-band's carrier until clouds land: the palette register + the too-tall peak [PROV: revisit if mid reads flat].**

## 7. Icons, UI & typography

- **School marks: animal pictogram icons** — silhouette-first, 2–3 VINIK24 tones, legible at 24px, one family (1–2px stroke, 2px safe padding **[PROV]**); hanzi text fallback.
- **UI tokens (from `game_constants.gd`, normative):** panel bg 墨-family dark @ ~0.88 α · border 石 · accent 金 #ee9c24 · heading 雪 · body 紙 · hint 霧. **Rarity:** common 霧 #96b2c5 · rare 天 #a1d2e0 · epic 亮紫 #a884f3 · legendary 亮金 #f8c83c. **Interactive states:** normal / **selected** (accent border + cursor glyph + lift) / **locked** (dimmed + "Locked" chip — never strikethrough) / hover = selected-preview / pressed n/a (selection UI).
- **Typography:** **Noto Sans SC for both scripts** (current, normative), display + body roles via `fonts.gd`; size scale in use 13–24px; **CJK floor 12px**; damage numbers: bold, 金/朱 by type, rising+fading. *(Bitmap CJK face at small sizes: open question for the canon slice — Noto renders acceptably at ≥13px today.)*
- Band-tinted meta screens (runtime wash, exempt class). UI wrongness at high bands subtle; overt distortion belongs to the corruption slice.

## 8. VFX & feel

- Channels (hitstop, shake, slow-mo, particles, damage numbers) tuned **to the audio hero sounds** — one impact, not three effects.
- **Size tiers [PROV]:** S ≤0.15 char-height (drips, sparks) · M ≤0.4 (deflect spark, blot-burst) · L ≤1.0 (posture-break 破 burst, boss beats). **Shake tiers (existing, normative):** light hit 3–4.5 · stance 10 · grab 14 · break/boss 18–20.
- **Priority & suppression law: threat > contact-confirmation > state > decorative ink.** During an active enemy telegraph, decorative ink VFX are suppressed near the attacker; nothing may overdraw a telegraph or a deflect confirm.
- Ink VFX vocabulary: drips, blot-bursts on 破, stain-spread on corruption gain, ink-wash trails (cosmetic only) on touched enemies' attacks.

### 8a. Threat & feedback color law (reserved meanings — corruption may NEVER use these hues as VFX)

| meaning | color | channel |
|---|---|---|
| perilous / unparryable telegraph | 朱 #b4202a | **full-sprite flash — this channel is EXCLUSIVELY perilous** |
| parryable cue (windup glint) | 亮金 #f8c83c | weapon glint |
| deflect success | 雪+亮金 white-gold | spark + flash (pairs with the clang) |
| posture damage | 金 #ee9c24 | bar + blot |
| HP damage | 朱 #b4202a | damage numbers only (number channel ≠ flash channel) |
| heal / cleanse | 竹 #4e8339 | numbers + glow |

### 8b. Contrast & accessibility floor

- **Character silhouettes sit ≥2 VINIK24 value steps from the band background at every altitude; the gate band achieves this with rim light (霧/天), never brighter flesh.**
- School colors, rarity colors, and §8a threat colors get a **CVD-simulation check recorded at canon acceptance** (within 24 colors, epic-vs-legendary and red-green confusions are the known risks — glyphs/icons carry meaning alongside color everywhere it matters, per the map-legend precedent).
- White impact frames ≤2 engine frames (flash safety).

## 9. Production law

- **Canon over prose:** every asset run cites its canon sheet — `art/canon/` + `canon.manifest.json` *(this slice — canon plan Tasks 3–10; until sheets land, THIS doc's tokens are the working reference)*. Rejected candidates never enter canon.
- **Gates:** shotgun → derived proofs (silhouette @ gameplay size · 24px icon row · palette audit · runtime-scale render) → user picks; scale re-checked in-game before install.
- **Generator policy:** aiexp incumbent; **pixelforge** (in `AIexp/tools/pixelforge-*`) on trial via the icon bake-off. Briefs are generator-agnostic (canon reference image + tokens + fragment). Negative-prompt fragments: no anti-alias blur, no off-palette colors, no painterly gradients, no unreadable micro-detail, no flesh mutation (wrongness lives in ink).
- **Sequencing reality:** identity pass SHIPPED · canon production current · real animation waits for canon · corruption mechanics their own slice.

## 10. Asset-class coverage (absence is a decision, not a gap)

Characters/enemies/immortals ✓ (§4) · scenes ✓ (§6) · icons/UI ✓ (§7) · VFX ✓ (§8) · **shadows** ✓ (§3b ellipse) · **mook death** ✓ ink-burst (§4) · **projectiles: none in the game today** (spec when one exists) · **pickups/ground loot: none** (rewards are menu-level) · **portraits/dialogue art: none** (text beats only, by design) · map/node marks ✓ (hanzi glyphs, shipped) · boss intro ✓ (text beat, shipped) · clouds — designed, deferred · non-Euclidean scene wrongness — high-band scene assets, not yet produced · back-dash clip — animation pass · map climb inversion — with the implementer.

## Implementation Tasks
Synthesized from the 2026-07-03 design review. Checkbox as shipped.

- [ ] **T1 (P2, human: ~1h / CC: ~10min)** — data — Migrate `Schools.json` themeColors to the §3a VINIK24-nearest values
  - Surfaced by: palette law — all six current themeColors are off-palette
  - Files: `WUGodot/data/Schools/Schools.json`; re-run school-choice/boon captures
  - Verify: captures + future palette audit on UI accents
- [ ] **T2 (P2, human: ~half day / CC: ~30min)** — combat VFX — Wire the §8a threat-color law (perilous full-sprite flash 朱; parryable glint 亮金; reserve the flash channel)
  - Surfaced by: threat/telegraph language absent (both outside voices, P1)
  - Files: `combat_scene.gd`/presenter timeline data
  - Verify: matchup captures during enemy windup (perilous vs normal); no ink VFX in threat hues

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 1 (outside voice) | CLEAR | 7 P1 / 6 P2 / 3 P3 — all folded into v2.1 |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 0 | — | n/a for an art doc |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | CLEAR | score: 6.5/10 → 9/10, 4 decisions |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

- **CODEX:** parry-readability + corruption-vs-silhouette P1s adopted as §5b/§8a laws; palette/timing/craft tokens pinned [PROV].
- **CROSS-MODEL:** Codex and the independent subagent converged on all five P1 classes (threat language, ink readability, unpinned palette, palette-law scope, missing craft/timing tokens); both folded.
- **VERDICT:** DESIGN REVIEW CLEARED — v2.1 is the executable bible pending canon reconciliation (eng review not applicable to an art doc).

NO UNRESOLVED DECISIONS
