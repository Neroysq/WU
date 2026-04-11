# WU (武) — MVP Design Spec

*Design pass: 2026-04-10. Outcome of a brainstorm session focused on refining the existing concept into a shippable MVP with a clear growth ladder.*

## Framing

This spec supersedes the parts of `docs/GAMEPLAY_DESIGN_DOC.md` that describe the core gameplay, run structure, and progression. The v1 gameplay doc is a vision document with many overlapping systems stacked together; this spec narrows the scope to what actually ships first and names the growth ladder for everything that waits.

This spec does not replace `docs/ART_DESIGN_DOC.md`. It cross-references art decisions but defers full art direction to that document, which will need its own refinement pass alongside Milestone 1 below.

**Three pillars (inherited and sharpened):**

- **Fun** — compounding sources of interest: build-crafting (run level), mechanical mastery (moment level), map decisions (node level).
- **Wuxia feel** — Sekiro-paced duels, named martial techniques, recognizable wuxia archetypes, ink and calligraphy visual motifs. The "movie sparring match" feeling.
- **Responsiveness** — honest attack phases, animation-driven hit windows, input buffering, unambiguous telegraphs. The player never feels the game ignored them or cheated them.

**Core design bet (narrower than the v1 doc):**
WU is a **Sekiro-paced wuxia duel roguelike** with **build-crafting as the heart** and **mechanical mastery as the spice**. Runs are procedural chapter maps in the Slay-the-Spire shape; build variety comes from mid-run technique acquisition; combat is slow, readable, and reaction-based.

**Decisions locked during this brainstorm (for traceability):**

1. Heart is build-crafting; spice is mechanical mastery. Not Sekiro-first, not Hades-first — a hybrid weighted toward Hades's build-variety engine.
2. Combat shape is mixed: 1v1 honor duels as the core, 1v2/1v3 ambushes as flavor for power-fantasy beats.
3. Build variety in MVP comes from a single axis: mid-run techniques (Hades boon model). Schools, weapons, and cultivation are later growth layers.
4. Technique types: A (passive augments) and B (conditional triggers) as the main pool, plus 2-3 rare D (stance swaps) as signature drops. No C (active abilities with cooldowns) in MVP. No E (pure stacking items) — that's what the current reward system already is and it does not produce meaningful variety.
5. Combat pace is Sekiro-slow. Actions must be readable and reactable. Animation quality (read: animation *timing* and *silhouette differentiation*) is load-bearing.
6. MVP art budget is placeholder silhouettes with honest timing. Full pixel art + VINIK24 palette is the first post-MVP milestone.
7. Run structure is Slay the Spire-shaped: 3 chapters, each a procedural map of nodes, mixing fights with events, rewards, shops, and rest.
8. MVP scope is **Chapter 1 only** ("Act 1 complete"). Chapters 2 and 3 are growth milestones. This mirrors how Slay the Spire itself was originally released — Act 1 as early access for over a year — because validating the core loop matters more than shipping the full content at once.

---

## Section A — Core Experience

### Elevator pitch

**WU** is a Sekiro-paced wuxia duel roguelike. Each run, you play a wandering martial artist navigating a procedural chapter map. You survive a mix of duels, ambushes, events, and encounters, acquiring techniques that transform your combat style, until you face a named master at the chapter's end. A run takes ~15-25 minutes. Death sends you back to the start.

### Nested loops

The game is built around three compounding loops at different time scales:

**Moment-to-moment (inside a fight, 2-4 minutes per duel)**
Read enemy telegraphs. Time your parries and dashes. Commit to attacks knowing you can't cancel. Exploit openings. Break posture. Execute. This is where mechanical skill lives. Every fight is a small puzzle with a solution shaped by both the enemy's patterns and your current build.

**Fight-to-fight (inside a run, ~15-25 minutes)**
Navigate the chapter map. Choose which path to take — more fights for more technique rewards, more events for more surprises, shops for more deterministic build-crafting. Each node modifies your technique loadout, your HP, your gold. This is where build-crafting lives. The map is the decision engine.

**Run-to-run (across sessions)**
Die, start over. Every run is different because the map is procedural, the technique pool rolls different rewards, and your route choices are different. Meta-progression is intentionally minimal in the MVP — the fun lives in the run itself, not in grind. Persistent unlocks are a growth layer.

### How the three pillars are served

| Pillar | How this design serves it |
| --- | --- |
| **Fun** | Three compounding sources of interest that don't run out: build-crafting at run level, mechanical mastery at moment level, map route choice at node level. Each dimension keeps surprising the player. |
| **Wuxia feel** | Named techniques drawn from the wuxia martial lexicon. Enemies as recognizable wuxia archetypes (bandit, sect disciple, masked elite, boss master). Sekiro-paced duels deliver the "movie sparring match" feeling. Chapter themes (Jianghu → Sect → Demon Gate) echo classic wuxia story arcs. Visual motifs are ink washes and seal/calligraphy-style marks in VFX and UI. |
| **Responsiveness** | Committed attacks with honest anticipation/commit/recovery phases. Hit windows driven by animation frame events (not parallel timers). Input buffering so late inputs are honored. Enemy telegraphs always visually distinguishable. Player never feels "that should have worked." |

### A typical ~18-minute session

```
00:00  Boot → main menu → start run. Chapter 1 map appears.
00:15  Node 1: Duel against bandit. Sekiro-paced fight, ~2 min. Reward: pick 1 of 3.
02:30  Node 2: Event — villager asks for help. Pay HP for gold, or walk on.
02:50  Node 3: Duel against wandering ronin. ~2.5 min. Reward.
05:35  Node 4: Rest — heal 30% HP or upgrade one technique.
05:50  Node 5: Master — pick 1 of 3 rare techniques.
06:15  Node 6: Ambush. 1v2 against bandits, ~3 min. Power-fantasy moment,
       your techniques shine. Reward.
09:30  Node 7: Shop. Spend gold on a technique or an HP potion.
10:00  Node 8: Chapter boss — Zhao Feng. ~4 min, 2-phase duel.
14:00  Victory → return to start screen. Try again for a different build path.
```

Smooth run ~14-15 minutes; tough run with longer fights and route diversions stretches to ~25 minutes. Target range: **15-25 minutes per run**. This is roughly Slay the Spire's Act 1 length, adjusted for real-time combat taking longer per fight than turn-based.

---

## Section B — Combat System

Combat is the load-bearing system of the entire game. Everything else (technique system, map, enemies, art) exists to amplify or modify combat. This section defines the base kit, pacing, feel, and the discipline required to hit "Sekiro-slow + readable + responsive."

### Base moveset (player)

| Action | Button | Total duration | Phase breakdown | Notes |
| --- | --- | --- | --- | --- |
| Move | A / D | — | — | Max speed ~320 units/s (slower than current 420 to fit Sekiro pace). Ground-move lerp 0.25, air-move lerp 0.12. |
| Jump | W | — | Instant, rises ~0.45s, falls ~0.35s | Single jump, no double jump, no air dash. Landing recovery 0.10s. |
| Light attack | J (tap) | 0.50s | Wind-up 0.18s → active 0.12s → recovery 0.20s | Can chain into 2nd/3rd hit via input buffer during recovery. Damage scales +15% per combo hit. |
| Heavy attack | J (hold ≥ 0.25s) | 0.85s | Wind-up 0.40s → active 0.15s → recovery 0.30s | Higher damage, higher posture break. Cannot be blocked — must be parried or dashed. Color-coded wind-up flash (silver/white). |
| Block | K (held) | — | — | Hold to reduce damage to 20% and convert 80% of damage to posture fill. Releases on key-up. |
| Parry | K (tap) | 0.15s window | — | Fires on K press. 0.15s window of "perfect deflect." Successful parry: attacker takes 55 posture damage, 0.6s stun, 0.3s slow-mo on player. |
| Dash | Space | 0.22s | Startup 0.04s → i-frames 0.14s → recovery 0.04s | Cooldown 0.80s. Directional: facing-based on ground, horizontal-biased in air. |

Rationale for tuning changes vs. current code:
- Current light attack is 0.35s — too short for Sekiro pace. Moved to 0.50s to give telegraph room.
- Dash gets a clearer three-phase shape (startup / i-frames / recovery) so it feels committed rather than twitchy. Current code has two overlapping invulnerability mechanisms that make the effective window hard to reason about; the new spec collapses them into one explicit phase table.
- Parry window moves from 0.12s to 0.15s — slightly more generous, to match "readable and reactable."
- Heavy attack is new; current code only has one attack. Heavy attack is load-bearing for build variety (many A/B techniques will modify or trigger on heavy attacks specifically).

### Resources

| Resource | What it is | How it moves | Purpose |
| --- | --- | --- | --- |
| **Health (HP)** | Your life | Reduced on unblocked hits. Blocked hits reduce HP by 20%. | Death at 0. Main losing condition. |
| **Posture** | Stamina-for-hit-trades | Fills from blocked hits, heavy attacks taken, parries against you, general pressure | When full → 0.8s stun → executable. Recovers at ~12/sec when not under pressure. |
| **Rage** (optional for MVP) | Meta-resource | Fills from landing hits and taking hits (~10 per hit landed, ~4 per hit taken) | Consumed by D-type stance-swap techniques. If no D techniques ship in MVP, remove rage entirely; re-add in growth phase. **Current recommendation: ship 1-2 D techniques in MVP and keep rage as their activation gate.** |

The `Rage` meter infrastructure already exists in `WUGodot/scripts/fighter.gd:75-86`. Keeping it preserves the current UI and save format; it just becomes a meaningful resource instead of a cosmetic bar.

### Readability discipline (how "responsiveness" is achieved)

This is the most important technical discipline in the spec. Five rules, non-negotiable:

1. **Hit windows are animation-frame-event driven, not parallel timers.** The animation system emits a signal on specific frames ("hit frame start" / "hit frame end"), and combat logic responds. If animation playback speed changes for any reason (hitstop, slow-mo, buff), hit timing changes with it. **No desync between what the player sees and what the game does.** This is a refactor from the current `combat_system.gd:274` approach where `_attack_timer` and animation run on parallel clocks.

2. **Every enemy attack has a unique silhouette wind-up.** Horizontal slash, overhead slam, thrust, sweep, grab — each has a visually distinct anticipation pose within the first 3-5 frames of wind-up. The player can tell from the silhouette alone which attack is coming. This constrains enemy design: no enemy ships with two attacks that look the same during wind-up.

3. **Input buffering.** Attack, dash, jump, and parry inputs are buffered for 0.15s (~9 frames at 60 fps). If you press attack during the last 9 frames of your current attack's recovery, it chains into the next attack on the earliest legal frame. Same for dash during landing recovery, parry during any late-state recovery, etc. The player never feels like a "late" input was eaten.

4. **Parry-able vs. unparryable attacks are color-coded on wind-up.** Standard attacks flash silver/white during their wind-up — these are parryable. "Perilous" attacks (thrusts, grabs, unblockable heavies) flash red during their wind-up — these *must* be dashed. This mirrors Sekiro's kanji warning system and is the most important readability cue in combat.

5. **Feedback discipline — every impact has all of:**
   - **Hitstop**: 0.05s on normal hits, 0.10s on heavy hits, 0.15s on parries, 0.18s on posture breaks. Applied to BOTH fighters.
   - **Camera shake**: scaled by impact type. Small hits 3-5 units; parry 12 units; posture break 18 units.
   - **Particle burst**: 8-24 particles depending on impact. Color-coded (white for normal, gold for parry, red for heavy, purple for special).
   - **Damage number**: pops up with damage value. Critical/combo hits are larger and differently-colored.
   - **SFX**: an impact sound layered with a whoosh + an impact thud. Parry has a distinctive metallic ring. Posture break has a drumbeat-like thunk.
   - **Parry slow-mo**: 0.5x global time for 0.3s on successful parry. Only on *player* parry — enemy parries do not slow-mo (that's asymmetric on purpose, keeps the player-perspective hype).
   - **Posture break VFX**: a 破 kanji burst at the target, bigger hitstop, and a short "vulnerability" state with a visible aura.

### Enemy AI design philosophy

- **Readable, not reactive.** Enemies run pattern tables instead of reacting to player inputs. This is Sekiro/Souls-like. Players memorize patterns through repetition; patterns are randomized in order but not in content, so memorization pays off and yet a given encounter still surprises.
- Each enemy has a **pattern table of 2-4 attacks** for basic/elite, 5-6 for boss. Each entry: (wind-up animation, commit animation, recovery animation, damage, posture damage, parry/perilous flag, post-attack weighting).
- Enemies have distinct **phases**: approach (position) → telegraph (commit to a pattern) → attack (execute) → recovery (punishable).
- **Punish recovery, not active frames.** Good play = you dash past an attack and hit them during recovery. This is the core feedback loop that teaches the player to read.
- Difficulty escalates through **archetype complexity and pattern count**, not through "tighter frame windows." A frame-perfect boss is bad design — it's unfair rather than hard.

### Open tuning questions (not blocking the design — flagged for implementation phase)

- Exact HP/damage values per enemy tier.
- Exact frame counts for every enemy attack (each attack needs a timing table).
- Exact hitstop values (0.05/0.10/0.15/0.18 are starting points — will need playtesting).
- Rage numbers if rage stays in MVP.

---

## Section C — Build-Crafting Engine (Technique System)

Techniques are the MVP's sole axis of build variety. Everything in this section is designed to produce runs that feel *different* without requiring the player to pick a class or learn a new base moveset.

### Technique categories

Three categories, in rough order of frequency in the pool:

**A. Passive augments (most common, ~60% of pool)**
"Always on" modifiers that deform existing actions. No new buttons, no new resources.

Examples:
- *Descending Leaf* — your dash ends in a sword stab dealing 8 damage.
- *Iron Palm* — light attacks have a 20% chance to stagger on hit.
- *Widow's Kiss* — heavy attacks apply a 3-second bleed (1.5 damage/sec).
- *Sparrow Wing* — first light attack after a dash has +30% damage.
- *Stone Posture* — blocking reduces incoming damage by an additional 10%.

**B. Conditional triggers (less common, ~30% of pool)**
Fire on specific combat moments. Reward mechanical play. Create "earned" feelings.

Examples:
- *Mountain's Echo* — after a perfect parry, your next attack is a guaranteed posture break.
- *Breath of Returning Spring* — on successful posture break, restore 15 HP.
- *Flowing Water* — after dashing through an attack, your next attack heals 5 HP.
- *Thousand-Mile Gaze* — after killing an enemy, gain 3 seconds of +50% move speed.

**D. Stance swaps (rare, 2-3 in MVP pool)**
Replace your base moveset with a new kit. Massive per-pickup transformation. Very wuxia.

Examples for MVP:
- *Drunken Form (醉拳)* — your dash becomes an evasive roll with extended i-frames. Light attacks become stumbling strikes with unpredictable angles. Heavy attacks lock you into a slow recovery but deal +40% damage and break posture harder. Costs full rage to activate; lasts until you take 20 HP of damage.
- *Tiger Stance (虎形)* — light attacks become clawing three-hit combos at higher speed. Block costs more posture but reflects 10% damage back. Heavy attack becomes a forward leap-strike covering more distance. Costs full rage to activate; lasts 15 seconds.

Stance swaps are exclusive — only one active at a time. Picking a new one replaces the old.

### Technique slots and stacking

**Techniques don't compete for slots — they stack.** A single run can end with 6-8 techniques active simultaneously on top of the base kit. This produces emergent builds that didn't exist at design time.

Technique categories (organizational, not exclusive):
- **Attack mods** — affect light/heavy attacks
- **Defense mods** — affect block/parry/dash
- **Movement mods** — affect dash, jump, ground speed
- **Trigger effects** — fire on specific events
- **Stance swap** — exclusive; only one active

Multiple techniques in the same category stack. Two attack mods both apply to your attacks. The player can develop implicit synergies ("oh, *Sparrow Wing* and *Descending Leaf* combo — my dash-stab hits for huge damage because it counts as the first attack after a dash") without the system explicitly flagging it.

### Acquisition flow

Techniques enter the loadout through:

| Source | Pool | Count offered | Cost |
| --- | --- | --- | --- |
| Duel reward | A/B pool | 3 random | Free (pick 1) |
| Elite duel reward | A/B pool, rare-weighted | 3 random | Free (pick 1) |
| Ambush reward | A/B pool | 3 random | Free (pick 1) |
| Master encounter | A/B/D pool, rare-weighted | 3 random | Free (pick 1) |
| Event (some) | Specific technique or pool | 1 specific | Variable (HP, gold, or free) |
| Shop | A/B pool | 3 random | 20-50 gold each |
| Boss reward | D pool or legendary A/B | 1 guaranteed legendary | Free |

Rerolling is *not* available in MVP. Shops can be entered multiple times in different nodes but stock is fixed per-node.

### MVP pool size and composition

- **~12 A-type (passive augments)** — cover all action categories (attack/defense/movement)
- **~6 B-type (conditional triggers)** — distributed across parry/kill/dash/posture-break triggers
- **2 D-type (stance swaps)** — Drunken Form + Tiger Stance
- **Total: 20 techniques**

A typical run picks up 6-8 techniques, so ~30-40% of the pool is experienced per run. Two full runs feel notably different; 5-10 runs feel *substantially* different. This is enough variety to prove the core thesis without requiring a content treadmill.

### Economy

- **Gold** — single currency in MVP. Earned from fights (duel: ~15, elite: ~30, ambush: ~25, boss: ~100). Spent at shops and some events.
- **Shop pricing** — techniques 20-50g (rarer = more expensive), HP potion 20g (heals 30% max HP), posture potion 15g (heals 50% max posture), remove-technique 25g (removes a technique from your loadout — lets you cut dead weight).
- **No qi/mana in MVP.** Rage is the only meta-resource and only exists if D techniques ship.

### Synergies

For MVP: **rely on implicit synergies**, not explicit ones. Implicit = "my techniques happen to combo in play"; explicit = "Technique X says it's enhanced by Technique Y." Implicit synergies are easier to design, cheaper to balance, and more rewarding to discover. Explicit synergies are a growth-phase addition (they compound design cost).

Design rule: **every technique should combine interestingly with at least 3 others**, checked manually during pool design. The "interesting combination" test is: does having both techniques produce a play pattern that neither alone produces? If yes, ship it.

### Open questions (flagged for implementation phase)

- Exact rarity weights per source
- Exact cost curves
- Whether to allow the same technique to appear twice in a run (stack?) or one-copy-only
- Whether a dedicated "insight" currency earned from masters should exist as a secondary currency, separate from gold

---

## Section D — Chapter 1 Content Scope

This section defines the specific content that ships in the MVP. Everything listed here is required; everything NOT listed here is out of scope.

### Chapter theme

**Chapter 1 — Jianghu (江湖, "the martial world")**
The wandering world of traveling martial artists, bandits, and minor sect warriors. Dusty roads, bamboo forests, roadside inns, cliff paths. Color mood: warm earth tones, dusty orange, occasional jade green. This is the "start of the journey" — the player is a nameless wanderer entering a violent martial world.

### Enemy archetypes (5 total for MVP)

Each archetype has: a name, a pattern table (2-6 attacks), a silhouette shape, and a difficulty weight.

| # | Name | Role | Pattern count | Difficulty |
| --- | --- | --- | --- | --- |
| 1 | **Bandit Swordsman** | Common duel fodder | 3 (slash, thrust, overhead) | Easy |
| 2 | **Bandit Spearman** | Common, reach specialist | 2 (long thrust, wide swing) | Easy |
| 3 | **Wandering Ronin** | Common-to-mid, first real challenge | 4 (slash, thrust, sweep, 1 perilous) | Medium |
| 4 | **Sect Disciple** | Elite; mirror-match | 5 (slash, thrust, sweep, parry-counter, jump-attack) | Hard |
| 5 | **Masked Assassin** | Elite; teleport gimmick | 4 (smoke-thrust, flicker-slash, backstab, 1 perilous teleport grab) | Hard |

Enemy content load: 5 archetypes × ~4 attacks each × ~4-6 frames per attack phase = **roughly 100 silhouette frames total** to author for enemies. Plus idle, walk, hit-reaction, death per archetype (~30 more frames). Total enemy art: ~130 frames.

### Boss (1 for MVP)

**"The Smiling Blade" — Zhao Feng (笑刀 赵锋)**
A former sect elder turned jianghu mercenary. Wears a wide straw hat that shadows his face except for a perpetual smile. His signature move is *Thousand-Mile Slash*, a long-range thrust that lunges half the screen.

- **2 phases.** Phase 1 at 100% HP, phase 2 triggers at 50% HP (dialog beat: *"You're better than I thought. Let me try."*).
- **6 attack patterns total** across both phases (4 in P1, 4 in P2, 2 shared).
- **1 unparryable grab** — if it connects, it deals 25% max HP damage (meaningful but not instant-kill). Teaches the player: some attacks can't be parried.
- **Signature move: Thousand-Mile Slash.** Long wind-up (0.6s), screen-covering thrust, unblockable, must be dashed. Used once per phase.
- **Fight length:** 3-5 minutes.
- **Reward:** 100 gold + guaranteed legendary technique (drawn from a special pool of ~4 "boss legendary" techniques that only drop here).

Boss content load: ~40-60 silhouette frames.

### Node types on the map (8 types, already defined in brainstorm visual)

| Node type | Frequency per chapter | Mechanic |
| --- | --- | --- |
| **Duel** | 5-7 per map | 1v1 standard fight. Std reward. |
| **Elite Duel** | 1-2 per map | 1v1 harder fight. Rare-weighted reward. |
| **Ambush** | 1-2 per map | 1v2 or 1v3 gauntlet. Power fantasy moment. |
| **Master** | 0-1 per map | Pick 1 of 3 rare techniques (free). |
| **Event** | 2-3 per map | Story choice with outcome. |
| **Shop** | 1-2 per map | Spend gold on stock. |
| **Rest** | 1-2 per map | Heal 30% HP or upgrade a technique. |
| **Boss** | 1 (end of chapter) | Zhao Feng, 2-phase duel. |

Generated map has ~15 nodes and ~4 paths. Any one player path visits ~7-8 nodes including the boss. Map generation should guarantee: at least 1 master node reachable on every path, at least 1 rest node reachable on every path, boss always reachable.

### Events (6 for MVP)

Each event is a paragraph of text + 2-3 choices + outcome. Events are data-driven JSON in `data/Events/`.

| # | Name | Choices | Outcome |
| --- | --- | --- | --- |
| 1 | **Roadside Villager** | Help / Ignore | Help: +30 gold, –10 HP (bandit trap). Ignore: nothing. |
| 2 | **Travelling Merchant** | Trade / Leave | Trade: opens rare-pool shop with better stock. Leave: nothing. |
| 3 | **Shrine Offering** | Offer gold / Offer blood / Leave | Gold (pay 30g): random technique. Blood (pay 10 HP): random technique. Leave: nothing. |
| 4 | **Drunken Master** | Accept timing test / Decline | Test: press J three times rhythmically (generous window). Pass: random B-type technique. Fail: –15 HP. Decline: nothing. |
| 5 | **Bandit Camp** | Sneak / Infiltrate | Sneak: nothing. Infiltrate: triggers ambush fight, doubled reward on victory. |
| 6 | **Abandoned Scroll** | Read | Read: random A-type technique, no cost. |

### Shop inventory (fixed slots, rolled per-node)

- 3 random techniques (20-50 gold, rarer = more expensive)
- 1 HP potion (20 gold, heals 30% max HP)
- 1 posture potion (15 gold, heals 50% max posture)
- 1 "forget technique" option (25 gold, lets player remove one technique from loadout)

### Arena art (MVP)

**1 Chapter-1-themed background: bamboo road at dusk.**
- Pure silhouette art: black bamboo trees, dark mountain silhouettes in the far background.
- Warm gradient sky (orange → dusk purple).
- Foreground platform: stone-plus-grass silhouette.
- No diorama frame. No window elements. No parallax layers yet (that's growth).
- Single arena art pack. Combat camera frames it consistently.

Arena content load: ~6 silhouette assets (sky gradient, two mountain layers, three bamboo tree variants, platform).

### Total MVP content budget

| Category | Count | Est. art/content units |
| --- | --- | --- |
| Enemy archetypes | 5 | ~130 frames silhouette animation |
| Boss | 1 | ~60 frames |
| Player character | 1 (Hu) | ~80 frames (base + animations for all new heavy/dash/parry/etc.) |
| Arena | 1 | ~6 silhouette assets |
| Techniques | 20 | ~20 icons + text blurbs + gameplay code |
| Events | 6 | ~6 event JSON blobs + text + art stubs |
| Node types | 8 | UI/icon for each on map |
| SFX | ~30 | impact, whoosh, parry ring, break, menu clicks, etc. |
| Music | 2 loops | Combat loop, map/menu ambient |

This is a *real* MVP content load but it's scoped to be shippable. Everything larger than this goes in the growth ladder.

---

## Section E — MVP Scope Boundary and Growth Ladder

### What ships in the MVP (authoritative inclusion list)

1. Chapter 1 fully playable with procedural map generation, 15 nodes, all 8 node types.
2. Core combat: light attack, heavy attack, block, parry, dash, jump.
3. Sekiro-pace tuning as specified in Section B.
4. Input buffering (0.15s).
5. Animation-frame-event-driven hit windows (refactor from current parallel-timer approach in `combat_system.gd`).
6. Posture system (kept; already implemented).
7. Rage system (kept as the activation gate for D-type techniques; if D techniques get cut from MVP, remove rage entirely).
8. 5 enemy archetypes + 1 boss as specified in Section D.
9. 20 techniques (12 A-type, 6 B-type, 2 D-type) + acquisition flow.
10. Gold economy + shop node type.
11. 6 events.
12. Silhouette art for all characters, enemies, boss, arena backgrounds.
13. Combat SFX (impact, whoosh, parry, break, footstep, etc.) and 2 music loops (combat + ambient).
14. Single playable character (Hu) with no character select.
15. Full run flow: main menu → start run → Chapter 1 map → combat/events → reward → map → boss → victory/defeat → restart.

### What is explicitly OUT of MVP

| Cut | Why | Returns in |
| --- | --- | --- |
| Chapters 2 and 3 | Content budget; validates core loop first | Milestones 2 & 3 |
| Multiple playable characters | Build-crafting axis is techniques for MVP | Milestone 4 (schools) |
| Martial school system | Needs a second axis working; MVP is single-axis | Milestone 4 |
| Qi cultivation paths | Third build axis; too much for MVP | Milestone 5 |
| Weapon variety (dao/jian/staff) | Fourth build axis; deep content | Milestone 7 |
| Meta-progression (unlocks between runs) | Retention feature, not core-experience | Milestone 6 |
| Full pixel art + VINIK24 palette | Art pass is Milestone 1 | Milestone 1 |
| Diorama stage with Chinese window frame | Art pass, plus new technical work | Milestone 1 |
| Daily challenges, ascensions, leaderboards | Endgame/retention | Post-Milestone 6 |
| Narrative cutscenes and voice acting | Growth layer atop Ch1-3 | Post-Milestone 3 |
| Save-mid-run | Each run is a single sitting | Post-Milestone 3 |
| Explicit synergy-aware techniques | Implicit synergies first | Milestone 4 or later |
| Active-ability techniques with cooldowns (C-type) | Adds new button + new resource | Milestone 5 (with cultivation) |
| Reroll option in shops | Adds an extra economy layer | Growth |

### Growth ladder (ordered post-MVP milestones)

Each milestone is a self-contained addition that builds on the one before. A given milestone is not "required" for any later one unless explicitly called out — the order reflects the recommended sequence, not a dependency graph.

**Milestone 1 — Art Pass** (the "wuxia feel" spine)
- Replace silhouette art with full pixel art at VINIK24 palette.
- Add diorama stage presentation: Chinese-style window frame, 3-5 background parallax layers.
- Character, enemy, boss sprites authored at target fidelity.
- Effects pass: ink-splash parry VFX, kanji burst on posture break, aura on rage activation.
- **Payoff:** The game goes from "readable prototype" to "clearly a wuxia game." This is the biggest visual step and it's deliberately *after* the core loop is validated, not before — so art doesn't get wasted on a combat loop that didn't work out.

**Milestone 2 — Chapter 2: Sect Conflict (门派)**
- New arena theme: temple courtyards, training pavilions, mountaintop halls.
- 4 new enemy archetypes flavored as sect martial artists (mirror-match feel; they have techniques of their own).
- 1 new chapter boss: a sect grandmaster with 3 phases.
- 8 new techniques (weighted toward Chapter 2 enemies' flavor).
- 4 new events (sect-flavored: tournament challenges, disciple recruitment, inner-court politics).
- Chapter transition flow: map shows Chapter 2 after defeating Chapter 1 boss.
- **Payoff:** Run length doubles to ~45 min. Real roguelike feel kicks in.

**Milestone 3 — Chapter 3: Demon Gate (魔道)**
- New arena theme: moonlit graveyard, infernal platforms, abyssal caves.
- 5 new enemy archetypes flavored as supernatural foes that break conventional combat rules (one phases through walls, one has ranged projectiles, one summons adds, etc.).
- 1 new chapter boss: a demon lord with 3 phases and asymmetric mechanics.
- 8 new techniques (with "demonic" / internal-cultivation flavor).
- 4 new events (supernatural encounters: haunted shrines, cursed relics, ghost masters).
- Full 3-act run experience ships.
- **Payoff:** A complete game. Runs are ~60 min end-to-end. This is the point at which WU is a "finished" roguelike.

**Milestone 4 — Martial Schools** (add second build axis)
- 3 martial schools: Shaolin (balanced combo), Taiji (redirect/parry-counter), Drunken (evasion + unpredictable).
- Each school is a new starter character with a different base moveset (different light/heavy attack patterns).
- Each school has a biased technique pool (rewards draw from your school's flavor with higher weight).
- Character select screen before run.
- **Payoff:** Adds a second axis of build variety. Runs within the same school feel different (techniques), runs across schools feel *very* different (base moveset). This is the point where the v1 design doc's martial-trinity vision starts to appear.

**Milestone 5 — Qi Cultivation** (add third build axis + active abilities)
- Pick 1 of 5 cultivation paths at run start: Fire / Water / Metal / Wood / Earth.
- Each path = a resource mechanic + passive modifiers.
- Qi is a new spendable resource for **C-type techniques** (active abilities with cooldowns), which enter the pool here.
- Path-specific signature moves unlocked at cultivation-level breakpoints (reached during the run).
- **Payoff:** Third build axis. Combinations of school + cultivation + techniques produce genuine "oh my god, that build" moments.

**Milestone 6 — Meta-progression**
- Permanent unlocks earned from runs: new starting options, new events, new challenge modifiers.
- Ascension levels (Slay-the-Spire-style difficulty modifiers).
- Sect reputation (unlock new starting equipment).
- **Payoff:** Retention layer. Players come back for the long tail.

**Milestone 7 — Weapons**
- Dao, jian, staff, unarmed as selectable starting weapons.
- Each weapon = different moveset base (Monster Hunter-style).
- Compounds with schools (Shaolin staff plays differently from Shaolin empty-hand).
- **Payoff:** Fourth build axis. The v1 design doc's full vision becomes reality.

**Beyond Milestone 7:** daily challenges, leaderboards, replay system, narrative layers, sound/music pass, seasonal events, NG+. These are all "polish and retention" items that should be prioritized based on player feedback after Milestone 7.

### Milestone ordering logic

- **MVP first** — validate the core loop. Fastest to "is this fun?" signal.
- **Art pass second** — make it look like a real game before players judge it visually. Without this, early feedback will always be "it looks like a prototype."
- **Chapters 2-3 third** — complete the run structure, hit full game length.
- **Then build variety (schools → cultivation → weapons)** — in order of scope cost. Each axis added compounds with the previous.
- **Meta-progression and long-tail content last** — these don't matter until the core game is fun enough for players to want more.

---

## Traceability notes

**Decisions deferred to implementation phase (not this spec):**
- Exact damage/posture/HP numbers for tuning.
- Exact frame counts per enemy attack.
- Exact reward rarity weights.
- Exact shop pricing.
- Node map generator specifics (branching density, guarantee rules, visual layout on screen).

These are the things that require playtesting, not design. They belong in the implementation plan.

**Code changes this design will require** (high-level, not exhaustive — real plan goes in the next step):
- Refactor `combat_system.gd` to drive hit windows from animation frame events instead of parallel timers.
- Expand `fighter.gd` with heavy attack support.
- Add a buffered input system. The existing `input_tracker.gd` only does edge detection (press vs hold); it does not buffer inputs across frames. A new lightweight buffer layer is needed that records (action, timestamp) pairs and exposes "was action X pressed within the last N ms" queries.
- Implement node map generator for procedural chapters (partial exists in `run_state.gd`).
- Implement technique system (new file: `technique.gd` + JSON data in `data/Techniques/`).
- Implement event system (new file: `event.gd` + JSON data in `data/Events/`).
- Implement shop system.
- Add heavy-attack, block-held, and dash-direction handling to player input.
- Add color-coded attack telegraph VFX (silver for parryable, red for perilous).
- Add the `Rage` consumption for D-type techniques (or remove rage if D cut).

**Code changes this design will NOT require** (things already in good shape):
- The JSON data loading pipeline (`data_manager.gd`) — reuse it for new data types.
- The reward option system (`reward_option.gd`) — expand it from stat bumps to techniques.
- The particle system, damage number system, camera shake, slow-mo — all in place.
- The animation set / asset catalog — extend with more clips, don't rearchitect.

**Next step after design approval:** invoke `superpowers:writing-plans` to turn this design into a phased implementation plan with review checkpoints.

---

## Open questions for user review

Before this spec is ready to become an implementation plan, the following are worth the user confirming:

1. **Rage in/out of MVP?** Keep rage as a meaningful D-technique resource, or drop rage for MVP and re-add in Milestone 5 with qi? Recommendation: **keep** and ship 2 D-techniques that use it.
2. **Specific MVP technique flavors?** The examples given in Section C are placeholders for flavor. A full pool of 20 named techniques needs to be authored during implementation — is there interest in drafting the pool names/effects now as part of the spec, or leave it to implementation?
3. **Chapter 1 boss name.** "The Smiling Blade — Zhao Feng" is a placeholder. Do you have an existing named character from your wuxia inspiration, or is this a place to invent one fresh?
4. **Single chapter or opening tutorial?** Does Chapter 1's first node need to be a "tutorial duel" that forces the player to use parry once successfully, or should we trust players to learn from Master encounters and event text alone? Recommendation: **trust players** — modern roguelikes generally don't hard-tutorial, and a tutorial node adds scope. But if you prefer a gentle guide, we flag it.
5. **Input device support in MVP.** Current code is keyboard-only. Should MVP include controller support, or is that post-MVP polish?

Once these are resolved, the spec is implementation-ready and we can move to writing the implementation plan.
