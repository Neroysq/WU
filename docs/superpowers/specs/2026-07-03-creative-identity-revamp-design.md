# WU Creative-Identity Revamp — 九仙山 — Design

**Date:** 2026-07-03
**Status:** draft (pre-plan) — for user review
**Origin:** the funness pivot (`2026-06-30-funness-direction.md`): the core duel is flat and the current identity is placeholder. This revamp creates the identity the real animation pass will serve. **Scope (decided):** full creative identity + the corruption/cleanse/true-boss layer **designed on paper**; gameplay implementation is a separate later slice. The combat system itself does not change.

---

## 1. Tonal north star

**Wuxia + Cthulhu, corruption-arc blend.** A bright, wild, comic kung-fu pilgrimage that curdles, node by node, into cosmic horror. The foothills are Kung Fu Hustle; the summit is the door. The saved art direction — *wild, exaggerated, comical, unreal but clear* — is the **baseline register**, and the eldritch invades *through* it: the tone shift with altitude is itself the horror.

**Logline:** *All martial arts under heaven come from the Nine Immortals of Mount Jiuxian — and every one of them is a lie with something behind it.*

## 2. The world & the truth

- **九仙山 (Mount Jiuxian).** The jianghu's proverb: **天下武功出九仙** — all kung fu under heaven comes from the Nine Immortals. Every practitioner alive is, at some remove, their student. Pilgrims climb; the famous descend the mountain only in stories.
- **The truth:** all arts descend from **one founder — the First Master (祖師)** — who touched something beyond and became a **door (門)**. The proverb's hidden inversion: **九仙武功出一門** — the Nine's arts come from one *lineage*… and 門 also means *door*. Every kata descended from his forms is unknowingly a **summoning gesture**. **The more you master any kung fu, the more corrupted you become** — mastery is the ritual, performed. The Nine aren't teachers; they are the most-fed.
- **The Unknown Existences:** plural, unnamed, never shown whole — they whisper through the door. Each of the Nine hosts one. The mountain's martial world is their cultivation farm.

## 3. The cast

### Hu — the starstruck pilgrim
A young nobody who climbed 九仙山 to *learn*: a kung-fu fanboy raised on tales of the Nine, hungry for a master and an autograph. He has no lineage, no style, no teacher — and is therefore the only untainted blade in the jianghu, the one person who *can* break the cycle. His eager boon-grabbing is fandom made mechanical; the truth is a personal betrayal; cleansing means giving up the dream.
**The name pun (kept unresolved):** Hu (胡) is a homophone of **虎 Tiger** — one of the famous styles with no living master. Disciples mishear it constantly (*"Tiger?! Which master taught you?!"*) — comedy up front, quiet foreshadowing underneath. Whether Hu "is" the Tiger vacancy or the joke stays a joke is deliberately never answered in chapter 1.

### The famous Nine (Hades-2 pantheon model)
The rumor names the famous nine; there are more sources than the rumor knows. **Display identity = the animal, never the old school names; each style silently echoes one real art (never named in-game).** Six are on stage today (mapped 1:1 onto the existing school kits — mechanics unchanged):

| Kit (unchanged mechanics) | School (display) | Real root (never named) | Immortal |
|---|---|---|---|
| guard / posture / armor | **熊 Bear** | 洪拳 — iron body, rooted stances | **熊鐵 Xiong Tie** (chapter-1 final boss, the gatekeeper immortal) |
| burst / jolt / discharge | **牛 Ox** | 八極 — explosive short-range slam, trembling shock power | 牛雷 Niu Lei |
| parry / redirect / riposte | **鶴 Crane** | 詠春 — centerline interception, chain counters (crane-origin legend) | 鶴柔 He Rou |
| momentum / dash / aerial | **燕 Swallow** | 八卦 — circle-walking evasion + 輕功 | 燕影 Yan Ying |
| poison / DoT | **蛇 Snake** | 蛇形拳 | 蛇噬 She Shi |
| marks / precision / crit | **鷹 Eagle** | 鷹爪功 — seizing, precision | 鷹目 Ying Mu |

Naming pattern: animal + attribute (like 熊鐵). Each immortal is a **distinct corrupted personality with a voice** (pre/post-fight dialogue). Internal data ids (`iron`, `thunder`, …) may remain; every display surface changes.

- **The unseen famous three (lore only, future chapters):** **龍 Dragon** — the rumored greatest style no living person has seen, *because it is the First Master's own root art*, the form all others descend from; **虎 Tiger** — the vacancy that sounds like "Hu"; **猴 Monkey** (猴拳) — a future school kit.
- **The outsiders** (Hermes/Chaos analogs, future content): sources *not of the mountain*. First in line: **熊貓 the Drunken Panda** (醉拳) — the game already owns `stance_drunken` and the Drunken Master event; an outsider who tumbles, drinks, and is suspiciously *un*-corrupted. Outsiders are the natural home of cleanse-givers and strange bargains.
- **The true boss:** the First Master — or the thing wearing him — behind the door at the summit, fighting with the Dragon root-form.

## 4. The run as story

The map **is** the mountain climb; the corruption arc maps onto the existing node structure:

| Depth band | Existing pool | Tone | Wrongness |
|---|---|---|---|
| Foothills | weak | bright, comic — cocky bandits, readable duels | none (a grin held slightly too long) |
| Mid-slopes | strong | still funny, but *off* | scenery subtly wrong; disciples' forms too synchronized |
| High paths | elite | the mask slips | openly touched enemies (the promised Demon-Spirit class = the door's leakage) |
| The gate | boss | dread | 熊鐵 Xiong Tie, first of the Nine |
| The door | true boss | the truth | opens only for the clean (§5) |

The difficulty curve and the horror curve are the same curve — deaths already back-load to elite/boss.

## 5. 内功 / 外功 — corruption on paper (清/濁)

**The frame (classic wuxia, mechanically literal):**
- **外功 (external arts) = the build.** School boons, techniques, masteries — everything taken from the Nine. Corrupted by nature; the power you climb with.
- **内功 (internal foundation) = the corruption axis.** Hu's inner purity, 清 (clear) ↔ 濁 (turbid). Corrupted gains taint it; cleanses purify it.

**Sources of 濁:** taking school boons; tier upgrades; **masteries above all** — the currently-dead mastery system becomes the ritual's completion (a mastery is where the summoning gesture perfects). Exact numbers are the later gameplay slice's job; the paper design fixes the *ordering*: mastery ≫ tier ≫ boon.

**Cleanses disguised as loss** (the anti-greed twist): events that *take* from you actually clear you — the beggar who steals your purse; the shrine that demands fasting (max-HP cost); **the existing forget-technique mechanic** (losing kung fu is literally purification — already in the game, now meaningful); giving a boon away. Never labeled as cleanses up front; discovered through play.

**Reading it (diegetic + waypoint mirrors — no meter):**
- **Hu's own sprite changes with 濁** — the stored "gains change appearance" feature becomes THE narrative device (corruption stages are the character-art centerpiece).
- Scene/UI wrongness cues scale with his state.
- **Mirrors at waypoints** (rest shrines / a mirror event) show plainly where he stands.
- **The summit door reads him before the final fight** — the true-boss chance is never a hidden roll.

**The two endings (user-defined):**
1. **走火入魔 (dark ending):** defeat Xiong Tie with 内功 not pure enough → the corruption in Hu's own foundation erupts — he dies *right after the false victory*, destroyed by the power he climbed with. Lore stitch: **this is where immortals come from** — the Nine were once pilgrims who won the summit impure.
2. **The true fight (clean ending path):** 内功 pure enough → **Hu gives up ALL 外功** — every boon, technique, mastery, the entire build — and steps through the door to face the First Master with bare fundamentals and pure 内功. **The true final fight is buildless**: the ultimate statement of the theme (all kung fu belongs to the door; to fight it you must hold none of it) and of the game's fun model — the heart of WU is the bare duel, and the true ending is pure duel skill. (Base kit — light/heavy/dash/jump/block/parry — is proven viable bare by the combat harness.)

Chapter-1 scope note: the door may only *crack open* (tease) until the true fight is built; the judgment + 走火入魔 ending are chapter-1-complete.

## 6. Art direction

- **Wild, exaggerated, comical — invaded.** Exaggerated physiques, comic timing, big silhouettes as the baseline; the eldritch creeps in through them (too-wide grins, too-many joints at high altitude, background "window paintings" going subtly non-Euclidean at elite depth).
- **VINIK24 palette drifts cold/dark with altitude** — foothill warmth → summit wrong-dark. The palette bands align with the depth bands in §4.
- **School identity = animal icons.** Each school/immortal gets an animal pictogram as its primary mark (UI chips, boon cards, map, school choice). Icons — not hanzi — because two-character animals (熊貓) break the single-char pattern and 熊/熊貓 must read apart at a glance. Text names still appear alongside.
- **Hu's corruption stages** (clean → touched → marked → claimed, working tiers) are the flagship character-art deliverable; they must read at gameplay size.
- This identity is what the **real animation pass** (post-revamp, per the pivot) animates: immortal fight styles echoing their real root arts, Hu's starstruck expressions, corruption-stage idle/breath variants.

## 7. Delivery & content inventory

**Method: environmental + voiced bosses.** No cutscenes, no hub, no run-memory system.
- Scene wrongness ramps (§4) carry the arc wordlessly.
- **Boon/technique flavor text** whispers the truth (early text reads as proud lineage lore; deeper text lets the wrongness through).
- **The ~6 events rewritten as story beats**, including the disguised cleanses (Roadside Villager, Shrine Offering, Drunken Master → the Panda tease, etc.).
- **Each on-stage immortal gets pre/post-fight dialogue** — six corrupted personalities with voices (chapter 1: Xiong Tie's is the flagship; others land as their fights enter).
- **Surfaces to rewrite:** title screen (new saying + premise line), school display names/blurbs → animals, boon names/flavor for school fit (Sparrow Wing / Crane Step re-homed to their right schools), enemy flavor (disciples of which style), event texts, boss intro/outro, ending texts (走火入魔 / the door).

## 8. Out of scope & follow-ups

**Out of scope for this spec's implementation:** corruption/cleanse/door mechanics (designed above, built as their own slice); the three unseen immortals and outsider kits (lore hooks only); new school kits; any combat-system change; the true-boss fight itself (tease acceptable).
**Follow-up slices this unblocks, in order:** (1) content/identity pass (renames, flavor, events, dialogue, icons, palette bands — no new systems); (2) the corruption/cleanse/door gameplay slice; (3) the real animation pass on the new identity; (4) outsiders + unseen immortals as content grows.

---

## Decision log (from the brainstorm)
wuxia+Cthulhu (user) · corruption-arc blend (a) · premise 九仙山/mastery=corruption/cleanse-as-loss/false→true boss (user's own) · scope = identity + paper mechanics (a) · schools: Hades-2 model, animals only, rooted in 八極/八卦/詠春/洪拳/蛇形/鷹爪 (user-refined) · the Unknown = First Master's door (a) · Hu = starstruck pilgrim (a) · corruption UX = diegetic + mirrors (a) · delivery = environmental + voiced bosses (a) · 内功/外功 + 走火入魔 endings (user) · 熊貓 drunken outsider + animal icons (user).
