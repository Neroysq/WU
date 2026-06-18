# WU — Boon Build System (Wuxia Schools / 流) — Design

**Date:** 2026-06-18 (rev 3)
**Status:** draft (pre-plan) — for user review
**Sub-project:** #2 of the "complete fun run" effort (reward decisions & build depth). Sequenced before #1 (difficulty curve) and #3 (visual variance). Builds on the existing run loop (map nodes, combat, technique-effect engine).

**Goal:** Replace the shallow "pick 1 of 3 random techniques" reward with a **Hades-style boon system reskinned as wuxia schools (流/liú)** — meaningful, compounding, identity-defining build choices.

---

## 1. Vision

A run's power comes from **boons** granted by **schools (流)** — the wuxia analog of Hades' gods. Each boon **infuses one of Hu's base moves** with that school's signature effect. Builds deepen via **rarity upgrades that add new riders** (not just bigger numbers), **duos** (two-school synergy), **masteries** (one-school deep commit), and **passives**. The fun is discovering and committing to a build identity, then watching it compound.

Restructures **content & acquisition** only. The existing **technique-effect engine** (`technique_engine.gd`, `techniques/technique_registry.gd`, 30+ effect hooks) is the **substrate** — boons are effects; combat is not rewritten.

---

## 2. Decided (incl. reviewer calls + your rev-3 calls)

- Hades-style boons reskinned as wuxia schools, with duos, masteries, passives.
- **6 boon slots:** light, heavy, dash, block/parry, stance, jump.
- **6-school v1 roster** (§4): 毒 Venom · 雷 Thunderclap · 柔 Soft Palm · 铁 Iron Body · 风 Windstep · 剑 Sword Intent. **Crimson/血 fully out of v1** (returns later only as sacrifice/lifesteal/execute/low-HP — never a second DoT).
- **4 rarities:** Common · Rare · Epic · Legendary. **Each tier adds at least one mechanical rider; numbers are secondary tuning** (§5).
- **Boon kinds:** move-boon · passive · **duo** (two-school synergy) · **Mastery** (one-school deep commit). Duo and Mastery are *kinds*, not rarities. *(Mastery is named distinctly from the Legendary rarity to avoid collision.)*
- **Insight (顿悟)** = within-run upgrade currency.
- **Steering:** node-choice + favor for v1 (§6). Map-node school icons = **stretch / next pass**, not v1.
- **Content matrix (v1 min):** each school ships **≥3 move-boons (varied slots) + 2 passives + 1 duo** (2 duos only where pairings are obvious & cheap — the 4-tier rider ladder is the main content load).
- **Build-size target (v1):** ~**4 move-boons + 2 passives + 0–1 duo**, right-sized to today's ~5-reward run path.

Genuinely open: §11 (minor confirmations only).

---

## 3. Core model

- **Slot (6):** light, heavy, dash, block/parry, stance, jump. One move-boon per slot (a new boon for a filled slot *replaces* it, with confirm).
- **School (流):** lineage with a signature status/mechanic + boon pool.
- **Boon kinds:**
  - **Move-boon** — infuses a slot; has the 4-tier rarity ladder.
  - **Passive** — stacks, no slot; has the 4-tier ladder; offered less often.
  - **Duo** — requires a qualifying boon from **each of two specific schools**; single high-tier (no ladder).
  - **Mastery** — requires **N boons from one school**; the school's deep-commit payoff; single high-tier.
- **Rarity (move-boons & passives):** **Common · Rare · Epic · Legendary**, each tier adding a rider (§5). Duos/Masteries are single-tier.
- **Loadout:** `{slot → move-boon}` + passives + active duos/masteries → compiles to the engine's active-effect list each fight.

---

## 4. School roster (v1 — 6)

| School | Identity | Signature | Sample boons (slot → effect) |
|---|---|---|---|
| **毒 Venom Sect** | snowballing DoT | **Venom** stacks | light→apply venom · heavy→venom burst+spread · dash→venom cloud · passive→venom slows |
| **雷 Thunderclap** | burst & chain | **Jolt** (arcs to nearby) | light→jolt on hit · heavy→jolt nova · dash→discharge · passive→jolted take +dmg |
| **柔 Soft Palm** (Tai Chi) | counter/defense | **Deflect** → riposte | parry→perfect-parry riposte · light→redirect counter · stance→Drunken form · passive→reduce incoming dmg |
| **铁 Iron Body** | tanky bruiser | **Posture/Armor** | heavy→armored knockback · block→gain armor · stance→Tiger form · passive→+posture, heavy hits stagger |
| **风 Windstep** (qinggong) | mobility & flurries | **Momentum** | dash→extra dash + dash-strike · jump→aerial strike / landing burst / extra air-jump · light→flurry at high momentum · passive→+speed, −dash cd |
| **剑 Sword Intent** | precision, reach, crit | **Intent mark** | light→mark on hit · heavy→consume mark for crit burst · dash→dash-through sword-flash · passive→+reach & crit vs marked |

剑 Sword Intent is the **sword-first identity** for Hu. Existing **Drunken/Tiger** stances become stance-slot ultimates (Drunken→Soft, Tiger→Iron). The **bleed** effect infra is retained for reuse (e.g. Sword intent-mark detonation, or a future reworked Crimson).

**Duo examples:** Venom+Thunder = "Galvanic Venom" (jolt detonates venom) · Sword+Wind = "Thousand Cuts" (flurry hits apply marks) · Iron+Soft = "Immovable" (perfect parry grants armor) · Sword+Thunder = "Lightning Draw" (mark-consume jolts).
**Mastery examples:** Venom mastery = venom never expires + caps higher · Iron mastery = a flat damage-reduction floor · Sword mastery = marks build toward a guaranteed execute.

---

## 5. Boon mechanics — the rider ladder

**Rarity upgrades add new mechanical riders at Rare/Epic/Legendary; numbers are secondary tuning.** The plan must NOT implement Hades-style numeric-only scaling. Each move-boon/passive defines all four tiers; higher tiers are **cumulative** (Epic = Common base + Rare rider + Epic rider).

Example — *Venom Sect, light-attack boon*:
- **Common:** light hits apply 1 Venom stack.
- **Rare (+rider):** Venom now also **slows** the target.
- **Epic (+rider):** on a venomed enemy's death, the cloud **spreads** to nearby foes.
- **Legendary (+rider):** your next **heavy** detonates Venom applied by this boon. *(High-tier riders may create cross-slot interactions like this — intentional, but the boon factory/UI must make the source slot clear.)*

- **Upgrade — Insight (顿悟):** within-run resource (elite/boss drops, shop, events). Spend to raise one boon a tier (Common→Rare→…). This is the "build that scales" knob — and because each tier is a *rider*, scaling changes how the build *plays*, not just its numbers.
- **One boon per slot:** replacement shows old-vs-new confirm (the core tough choice).
- **Passives stack.** **Duos/Masteries** appear in offers only once prerequisites are met (a boon from each of two schools; or N boons from one school).
- Offered rarity is weighted, skewing higher with run depth.

---

## 6. Acquisition & node integration

- **Battle/Ambush → School Encounter:** on victory a school offers **1-of-3 boons**; which school is **steered** (below). Replaces the current technique reward screen.
- **Elite/Master/Event → player picks the school**, then 1-of-3 (higher tier / duo / mastery when eligible). Master = the current "free rare," upgraded.
- **Shop → buy** boons, **Insight**, rerolls (existing gold).
- **Rest → swap/remove** a boon or spend Insight to upgrade.
- **Event → "favor":** can bias the *next* combat encounter's school.

**Steering (v1):** player **chooses the school at Master/Elite/Event** + **favor** to bias the next battle reward; basic battle nodes stay random. Map-node school icons are a **stretch/next pass**, deliberately out of v1.

**Offer rules:** **prefer empty slots early** so a short run reliably builds a coherent kit before pushing replacements/upgrades.

---

## 7. Integration with existing systems

- **Engine reuse:** boons are effects in the existing registry. **New status effects to add:** Venom, Jolt, Deflect/riposte, Momentum, Intent-mark. (Posture/stat-delta/bleed already exist.)
- **Registry/data boundary (reviewer P1):** `TechniqueRegistry.create_effect(id)` currently only loads `DataManager.get_technique(id)`. The plan **must add `create_effect_from_data(effect_data, tier)` / a boon-instance factory** so tier riders, slot replacement, upgrades, and duo/mastery ids are *not* forced through fake technique ids. `BoonLoadout` builds tier-resolved boon instances → engine effects.
- **Jump-slot cost (reviewer P2):** lifecycle has dash/parry/block/hit/stance hooks but **no `on_jump`/`on_land`/aerial-hit hook** — must be added for jump boons. Hu **already has a baseline double-jump** (`fighter.gd` `has_double_jump`), so Windstep jump boons = **extra air-jump / aerial strike / landing burst / jump-force**, never "the double jump." Jump may ship a smaller v1 boon set.
- **Re-home the 20 techniques by BEHAVIOR/SLOT, not A/B/D letter (reviewer P2):** dash-stab, light-stagger, heavy-bleed, dash-window-damage, block-chip, twin-strike, stat-mods, stances → map each to a move-boon (by slot) or passive individually. Repurposed, not discarded.
- **Loadout layer:** new `BoonLoadout` replaces flat `run_techniques_acquired[]`; compiles into the engine per fight. `TechniqueEngine` stays the executor.
- **Data-driven:** new `data/Schools/Schools.json` + `data/Boons/Boons.json`, loaded by `DataManager`.

---

## 8. Data model (sketch)

```
Schools.json: [{ id, name, hanzi, signature, themeColor, blurb }]
Boons.json:   [{ id, school, kind: "move"|"passive"|"duo"|"mastery",
                 slot: "light|heavy|dash|block|stance|jump",        # move only
                 tiers: {                                           # move/passive only
                   common:    { effect:{type,params} },
                   rare:      { effect:{...}, riders:[ {type,params} ] },
                   epic:      { riders:[ ... ] },
                   legendary: { riders:[ ... ] } },                 # cumulative
                 effect: { type, params },                          # duo/mastery (single-tier)
                 requires: { schools:[...], counts:{...} } }]       # duo/mastery only
```

- Tiers are **cumulative**: the factory composes base + each lower tier's riders up to the current tier.
- **v1 content matrix:** 6 schools × (≥3 move-boons + 2 passives + 1 duo) ≈ **18 move-boons + 12 passives + ~6 duos**, plus ~6 masteries. Each move/passive authored across 4 tiers (riders) — the real content load. Offer rules (prefer-empty-slot) keep the pool feeling full in a short run.

Runtime: `BoonLoadout` on run state; compiles to engine effects each combat.

---

## 9. UI/UX (high level — detail at plan time)

- **Boon offer screen:** school banner + 1-of-3 cards (slot, **tier + rider preview**, "replaces: …"). Extends `reward_scene.gd`.
- **Loadout view:** 6 slots + passives + active duos/masteries, on map/pause. **Effect tooltips** (currently missing) folded in, showing the active tier's riders.
- Per-school theme color in UI now; **on-character visual variance is sub-project #3** — this spec only exposes the hook (loadout's active schools).

---

## 10. Out of scope / YAGNI

Difficulty curve (#1); on-character visual variance (#3, data hook only here); meta-progression; Crimson + alternate schools (寒/火/影/医/符) beyond v1; weapon swaps; ranged "cast" slot; map-node school icons (stretch).

---

## 11. Resolved decisions

1. The one-school kind is **Mastery** (`kind: "mastery"`).
2. **Duos and masteries are flat single-tier** in v1 — special eligibility payoffs, not an upgrade ladder. The 4-tier rider ladder on move/passive boons is the content multiplier.

---

## 12. Testing

Headless: `create_effect_from_data` tier resolution (cumulative riders); boon→effect compilation; slot replacement; duo/mastery eligibility gating; Insight tier-upgrade adds the right rider; loadout→engine activation; new status effects (venom/jolt/deflect/momentum/intent); new jump/land hooks; offer-rules prefer-empty-slot; re-home tests for converted techniques.

---

## 13. Sequencing (high level — full plan after spec approval)

1. **Boundary + model:** `create_effect_from_data`/boon factory (tier-aware), `BoonLoadout`, Schools/Boons JSON + DataManager loaders.
2. **New effects + hooks:** Venom, Jolt, Deflect, Momentum, Intent-mark; add `on_jump`/`on_land`/aerial-hit.
3. **Re-home** the 20 techniques into boons/passives by slot/behavior.
4. **Acquisition:** School Encounter offer screen + node integration + steering/favor + prefer-empty-slot.
5. **Tier ladder + Insight upgrade; duos + masteries.**
6. **Loadout UI + tooltips.**
7. **Content pass:** the 6 schools' v1 matrix (move-boons across 4 tiers, passives, duos, masteries).
