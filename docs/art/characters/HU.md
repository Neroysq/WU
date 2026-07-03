# Hu (胡) — Character Bible

**Date:** 2026-07-03 · **Status:** full design draft — for user review (supersedes the concept-round-1 sheet)
**Sources:** identity spec (`2026-07-03-creative-identity-revamp-design.md` §3), ART_DESIGN_DOC v2.1 (§2, §4, §5b), concept round 1 (user lean: B's energy, not unique enough — uniqueness must come from story).

---

## 1. Backstory — the kid from the First Step

Hu grew up at **the First Step (第一步)** — the last inn village before 九仙山's pilgrim road — raised by an innkeeper aunt after the road took his parents' trade and, eventually, his parents. The village lives off pilgrims: sells them straw sandals on the way up, and buys back their gear cheap when they come down broken. **Hu grew up on what climbers left behind** — cracked scabbards, lucky charms, and above all *stories*, told at the inn's long table by men and women who had seen the Nine's disciples fight and lost to them.

He was never taught. Schools want lineage or tuition; a no-name inn boy gets neither. So he learned the only way left: **watching through fences** — outer-gate drills glimpsed over walls, drunk pilgrims re-enacting bouts at the inn, one masked traveler who did something impossible in the courtyard once and left before dawn. He practiced alone at night, copying what he half-saw and misremembered. His kung fu is a **patchwork of imitations, learned wrong, in the honest way** — which is exactly why it belongs to no lineage. *(Diegetic reading of the base kit: light/heavy/dash/jump/block/parry are Hu's fence-watched forms — the only kung fu on the mountain that doesn't descend from the door.)*

Twice he saved coin for a school's gate fee. Twice he was laughed off before reaching the inner door. The ledger of those refusals lives in his **stamp book** (§3). At sixteen-and-change he did the thing every First Step kid jokes about and no one does: he packed his aunt's worst blanket, bought the cheapest sword on the souvenir row, and **started climbing — to ask the Nine themselves.**

## 2. Motivation & arc

- **Surface want:** a master. Any of the Nine. He's not proud — he'd take the Ninth's junior disciple's errand-boy job. He wants to *belong to the thing he loves*.
- **Under it:** proof that a nobody from the buy-back village can matter without a name.
- **The curdle:** the thing he loves is a feeding system. Every autograph he dreamed of is a bite mark. The arc of the game is his want inverting: from *"teach me"* to *"let go of everything they taught me"* — the buildless true fight is the thesis of his whole life: the only clean kung fu is the kind nobody would teach him.
- **The 胡/虎 pun stays unresolved:** disciples mishear his name ("Tiger?! WHICH master—"), he corrects them, embarrassed. Whether the vacancy in the Nine sounds like his name by accident is never answered in chapter 1.

## 3. Personality & voice (the comic register's engine)

- **Relentlessly enthusiastic.** Meets an elite disciple mid-ambush: *"Wait — Crane school?? What's HE like??"* Names enemy techniques out loud, slightly wrong, with delight.
- **Fan etiquette.** Apologizes after winning. Asks for autographs at terrible moments. Rates the mountain's shrines like an enthusiast reviewer.
- **Self-taught tells.** Counts stances under his breath; resets his feet when nervous (he learned forms as *pictures*, not corrections — no master ever fixed him).
- **Not naive about people, only about kung fu.** Inn kids read drunks and liars fine; it's the *legend* he can't see straight. When the truth lands, it lands on someone whose only inheritance was those stories.

## 4. Concept design (from the story — the uniqueness levers)

**Base:** concept B's energy (grin, light frame, forward eagerness), **black hair** in a short messy tail (continuity with the current sprite's darkness; B's red reads off-model), plain **pilgrim blues** (淵/湖/靄) + 雪 under-layer, self-mended — visible mending stitches on sleeve/knee read "poor and cared-for," and keep the §5b ink zones (collar, hands, forearms) quiet.

**Signature prop 1 — the replica sword (贗劍).** A cheap souvenir-row "Genuine Ninth Immortal Replica": proportions slightly off, vendor's red tassel-tag still on the hilt (he can't bring himself to cut it). **Thematic load:** every *authentic* blade on the mountain descends from the door's lineage — **the fake is the only clean sword on 九仙山.** As Hu's corruption stages advance, *he* stains — **the replica never does.** (Late-game visual: an ink-veined hand on an untouched hilt.) Carried at the hip; humble scabbard.

**Signature prop 2 — the stamp book (集印簿).** A pilgrim's shrine-stamp book, repurposed: pages of shrine stamps, ticket stubs, two school refusal slips he keeps out of spite, and nine empty slots he ruled himself — one per immortal, for the autographs he's climbing for. Worn at the belt, wrapped in oilcloth. **Corruption interplay:** its pages darken with the climb; what fills the nine slots is never what he hoped. *(Diegetic hook, later slices: the book is a natural home for run records / boss marks / mirror moments.)*

**Explicitly NOT:** school colors or emblems (he's nobody's disciple — fan-merch charms from round-1 B are dropped as clutter; the two props carry the fandom better), tiger motifs (the pun stays verbal), extra gear (bedroll/gourd/satchel cut — silhouette stays light and quick).

**Silhouette:** light frame, short messy tail, sword low at left hip, book bump at right belt — an asymmetric, boyish, unaffiliated shape that collides with none of the six school stances (test vs `art/canon/schools/stances.png` when it lands).

**Expression sheet needs (the face is the register):** starstruck sparkle · eager grin (B's) · counting-under-breath focus · post-parry astonishment at his own success · the arc's later faces: doubt, the mirror look, the letting-go calm.

## 5. Hard tokens (unchanged, from ART_DESIGN_DOC v2.1)

| token | value |
|---|---|
| Proportion | ~6 heads, light frame |
| Canvas / scale | 256×256, bbox ≈205px; judged at `player_humanoid` scale from `DefaultProfiles.json` |
| Palette | VINIK24 source-exclusive; blues 淵 #20394f / 湖 #255674 / 靄 #577399 + 雪 #faf6f6 |
| Corruption zones (§5b) | collar, sword hand/wrist, forearms, eyes stay visually quiet at stage 清; caps 10/25/45% [PROV]; **replica sword and stamp book are defined stain-exempt objects** (the fake stays clean; the book darkens on its own schedule) |
| Weapon | the replica straight sword, hip-carried, red vendor tassel-tag |
| Silhouette | non-school, asymmetric (sword left hip / book right belt), light |

## 6. Concept round 2 (after this doc is approved)

Generate 2–3 candidates of **this** Hu — B-energy, black hair short tail, mended blues, replica sword with tassel-tag at hip, stamp book at belt, eager grin — full body + proofs; user picks; winner fills §7 and becomes the Task-5 turnaround brief.

## 7. Approved concept

*(filled after the round-2 pick — file, provenance, axis decisions; the turnaround must match it.)*
