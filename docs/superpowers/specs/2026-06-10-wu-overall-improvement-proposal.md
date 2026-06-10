# WU — Whole-Repo Review & Overall Improvement Proposal

Date: 2026-06-10
Status: proposal (review synthesis across all layers)
Scope: everything — architecture, combat depth, presentation & art pipeline, content, feel, persistence/UX, tests/tooling, docs

> **Rev 2 (review fixes):** FighterVisual deletion re-sequenced behind migrating Hu's fallback states (block/dash/hit/stun/jump still return `FALLBACK` at `combat_scene.gd:522`) *and* enemies (B4); technique registry expanded from "hooks" to a full **lifecycle + state model** (timers, deferred/once-per-run state, stance exclusivity, persisted effect state) with characterization tests (A2); A1 and A2 split into **separate** first plans; persistence reframed around scattered-RNG reality (save generated state, or central seed streams first) (C1); thin-Hu read downgraded to **unresolved diagnosis** requiring a master→PNG→render comparison (§2.3, B5); enemy count corrected to 5 archetypes + 1 boss (§2.4).

---

## 0. Executive summary

WU's **foundation is now genuinely strong**: a deterministic, headless-tested combat core; a JSON-driven animation presenter with measured anchors and art-matched collision; a proven AI-art pipeline (smooth masters → scale-normalized pixelize → canonical slots); and 239 passing tests behind a one-command runner. That foundation was the right thing to build first, and it works.

The gap is now **everything around the fight**. Measured against the project's own three pillars (GAMEPLAY_DESIGN_DOC.md):

| Pillar | State | Verdict |
|---|---|---|
| **Excellent action feel** | Mechanics excellent; **zero audio**; art consistency issues (tone drift, Hu's build); enemies still on the legacy render path | ~70% — closest to done |
| **Diverse combat builds** | 20 techniques, but IDs hardcoded into combat resolution; attack stats live in code; rewards are 4 flat stat bumps; 1 character | ~35% |
| **Replayability** | No save/load, **no meta-progression at all**, 6 enemies/1 boss/6 events/2 arenas, no encounter variants | ~25% — biggest gap |

The proposal: **four phases** — (1) cheap engineering enablers that multiply all later velocity, (2) finish the *feel* pillar (audio + enemy art/collision rollout + art-consistency fixes), (3) attack the *replayability* pillar (persistence, meta-progression, content breadth), (4) deepen *builds* (data-driven effects unlock it; layered "gains change appearance" expresses it). Each phase is independently shippable.

---

## 1. What is strong (do not churn)

- **Deterministic combat core** (`Fighter`/`AttackDefinition`/`AttackState`/`CombatSystem` as `RefCounted`, no physics dependence) — headless-testable by construction; the three-clock model (combat/presentation/input) handles hitstop correctly.
- **Animation truth in text**: presenter graph/timeline/manifest JSON, hot-reloadable, schema'd by tests; foot-anchored rendering with measured per-pose anchors; capsule collision that matches the visible blade (`presentation_collision.gd`), with scalar fallback for everything un-migrated.
- **Asset pipeline**: smooth masters → reference-scaled, density-uniform pixelize → canonical slots, with idempotent re-runs, sidecar-trusted anchors, reinstall-safe override files, and a deterministic capture hook (`--shot-combat`) for visual gates.
- **Test/tooling culture**: 23 headless modules / 239 assertions; `run.sh` one-liners for test/import/sanity/measure/install/capture; plans and aiexp feature requests documented in-repo.
- **Balance method**: reach derived from geometry, enemies tuned to an explicit fairness band (70–85% of Hu's reach) with per-archetype identity preserved.

Everything below builds on this; nothing proposes replacing it.

## 2. Findings by layer

### 2.1 Architecture & code health

- **`main.gd` is a 1,251-line monolith** — router + renderer + input + state for 9 scene types in one file (54% of the meta-game layer). Duplicated menu-navigation input handling across reward/shop/event/rest; 12+ repeats of the `mark_current_node_cleared(); _current_scene = X` pattern; 4 separate `RandomNumberGenerator` instantiations.
- **`combat_scene.gd` has grown to 899 lines** (draw + HUD + capture hook + presenter wiring + debug overlay); acceptable now, but the next feature lands it in the same trouble.
- **Tuning data in code**: gold rewards (`main.gd:483-492`), shop items/prices (`shop_generator.gd:34-51`), node-type probabilities (`run_state.gd:61-86`), rest heal % (`main.gd:297`) — all invisible to F5 hot-reload.
- **Two render paths coexist** (presenter for Hu's idle/walk/light/heavy; `FighterVisual` for everything else incl. all enemies). Intentional migration state, but it costs: presenter states lost the telegraph body-tint and weapon trail (a known slice limitation), and every new visual feature must be built twice or gated.

### 2.2 Combat depth (the "builds" engine)

- **Technique IDs are hardcoded into combat resolution** — 8 scattered `.has("A1"/"B5"/"A4"/...)` checks inside `combat_system.gd` (e.g. `:110, :307, :328, :332, :346, :365, :386, :421`), plus dual apply/unapply match statements in `technique_engine.gd:55-113`. Adding a technique = editing 3+ files; a typo silently does nothing. This is the **single biggest blocker to build diversity**.
- **All ~30 attack definitions live in code** (`attack_catalog.gd`, 472 lines of static constructors). No F5 tuning, no per-run modifiers, no modding. Enemy JSON already references attacks by id — the data seam exists; the data doesn't.
- **AI is reactive-only**: distance + RNG rolls; no memory ("player parried 3× → mix up timing"), no threat model, no aggression ramp (the legacy path had one!). Archetype gimmicks (assassin teleport, bear phase-2 speedup, mountain-breaker roll) are hardcoded in `combat_system.gd:164-218` rather than expressed in the AI/JSON layer.
- **Dozens of magic constants** (grab = 25% max HP, combo bonus formula, B5 threshold 30%, D2 timer 15 s, echo break, bleed DPS…) — each a recompile to tune.

### 2.3 Presentation & art pipeline

- **Open art-quality issues (user-confirmed on screen)**: (a) **Hu reads thin/weak next to enemies** — *diagnosis unresolved*. The source silhouette measures a plausible 0.32 aspect, which points at build/stance in the art (narrow at-rest pose vs. enemies' wide stances + bulky costumes), but silhouette aspect alone does not prove the render path innocent; the on-screen read is unnaturally narrow. **Required before choosing a fix:** a three-way comparison — source master → installed PNG → rendered screenshot at identical character height — to decide between art regeneration (wider stance/build), a profile X-scale correction, or per-pose retouch. (b) **per-frame color-tone drift** — *confirmed*: palette is locked but the generator lights each frame differently (block/parry frames are a visibly different tune than idle/attack). (c) minor: `heavy_3` is a duplicated follow-through; light recover is forward-held.
- **Root cause is generation-side frame inconsistency** (scale solved; tone & build not). The fix class is **reference-frame conditioning** (generate all frames conditioned on the idle reference for build, framing, *and* lighting) — the natural third aiexp request after `2026-04-30` (scale/anchor) and `2026-06-09` (decouple gen/pixelize).
- **Enemies haven't been through the pipeline**: legacy 256px frames, hand-offset animation JSONs, fractional render scales (1.575–1.775 vs Hu's integer 2), no manifests → no authored hitboxes (Strategy C blocked), and the same size/density inconsistencies Hu had.
- **Art direction** (saved preference): *wild, exaggerated, comical — unreal but clear and fun*. The presenter's transform/smear/squash machinery is built for exactly this and is currently used timidly (one modest squash track). The current sprites are also more "grounded" than that target.

### 2.4 Content vs vision

- **Actual**: 6 enemy definitions total (5 non-boss archetypes + the IronBear boss), 1 playable character, 20 techniques, 6 events, ~4 reward types, 2 arenas, 5 node types.
- **Design doc promises with zero implementation**: Demon Spirits (rule-breaking enemies), Grandmasters beyond IronBear, Sparring/Demon-Hunt encounter types, qi cultivation paths, weapon styles, 6 martial-school characters, ascension/daily challenges. Realization ≈ 40% (gameplay doc) / 25% (art doc).
- **Stored feature intent** (memory): *any gain should visibly change the character* — equipment/techniques/relics on the sprite. This demands **composable layered rendering**, which should be designed into the next art-pipeline iteration rather than retrofitted.

### 2.5 Feel — the missing half

- **Audio is completely absent** — zero `AudioStream`/SFX anywhere. Combat has particles, shake, hitstop, slow-mo, damage numbers… and total silence. This is the single cheapest large win in the repo: even 8–10 sounds (light/heavy hit, parry, block, posture break, dash, whoosh, footsteps, UI) would transform feel.
- **Haptics** (designed) also absent; no controller support at all (KEY_* hardcoded, no InputMap actions).

### 2.6 Persistence & UX

- **No save/load**: a crash loses the run; `RunState` is serializable in shape but never persisted. No settings menu, no difficulty selection, no rebinding (W/J/K hardcoded), no meta-stats between runs.
- Smaller UX debts found in code review: ambush sequence shows no "2 of 3" progress; forget-technique purchase is uncancellable; Master node can silently yield fewer/no rewards; rest/heal % invisible to the player.

### 2.7 Tests, tooling, docs

- **Strong**: animation/collision/technique/AI/map-gen all covered headlessly; visual gates via capture hook.
- **Untested**: the entire run flow (`main.gd` transitions), `CombatSystem.resolve_hits` end-to-end, shop/reward/economy, EnemyFactory. These are exactly the files that would be refactored in Phase A — tests must come first/with.
- **Docs drift**: design docs read as present-tense fact at ~40% reality; README omits single-character status; the excellent plan/spec history in `docs/superpowers/` is the de-facto true documentation.

---

## 3. The proposal

Four phases, ordered to maximize compounding: enablers → feel → replayability → builds. Each phase is shippable alone; within phases, items are ordered.

### Phase A — Engineering enablers (small, multiplies everything later)

1. **Attacks to JSON** (`data/Attacks/*.json`, loader in DataManager, `attack_catalog.gd` becomes a thin accessor). Unlocks F5 balance tuning, per-run modifiers, modding; removes 472 lines of constructor code. The enemy JSONs already reference attacks by id — close the seam.
2. **Technique effect registry**: replace the scattered `.has("X")` checks with declarative, data-registered effects. **Important: techniques are not just stateless hook callbacks** — the current engine carries timers (D2 stance 15 s, B4 gaze), deferred next-combat state, once-per-run flags (B6 phoenix), stance exclusivity, active-stance damage accounting, and stored stat deltas (`technique_engine.gd:7` onward). The registry design must therefore define the **effect lifecycle and state model first**: `on_add`/`on_remove` (stat deltas, symmetric), `on_combat_start`/`on_combat_end` (reset/deferred state), `update(dt)` (timers), trigger hooks (`on_hit`, `on_parry`, `on_dash_end`, `on_posture_break`, …), plus `exclusive_group` (stances), `once_per_run` flags, and **persisted effect state** (so Phase C's save system can serialize mid-run technique state). New techniques then become data + one handler, not a 3-file surgery. This is the foundation for the entire builds pillar — and the riskiest Phase A item, so it gets characterization tests around every existing technique behavior before any logic moves.
3. **Split `main.gd`**: one scene-controller per scene type + a shared menu-navigation helper; `main.gd` becomes a ~200-line router. Bring run-flow under headless test while moving it (transition table tests; reward/shop generation tests).
4. **Meta-tuning JSON**: gold/prices/probabilities/heal % out of code.
5. **InputMap actions** replace hardcoded keycodes (free rebinding + controller readiness).

### Phase B — Finish the feel pillar (the game's identity)

1. **Audio pass 1** (highest feel-per-effort in the repo): bus setup + ~10 core SFX wired to the already-existing signals (`hitstop`, `damage_dealt`, `camera_shake`, parry/block branches, dash, posture break, UI confirm). Design doc already specifies the list.
2. **Enemy art-pipeline rollout** (one archetype first — bandit_sword — then the roster): smooth masters → pixelize at per-character T → canonical slots → **manifests with measured anchors** → integer render scales. Fixes their size/density inconsistency, retires per-frame offsets, and produces the data Strategy C needs. Fold in the **assassin oversized-sprite** fix.
3. **Strategy C — authored enemy hitboxes**: with enemy manifests in hand, register enemies in `PresentationCollision` (spear long-capsule, sword arc, bear grab disc), retiring the scalar-vs-geometry asymmetry and the last "invisible range" unfairness.
4. **Presenter migration — all remaining states, then enemies, then delete `FighterVisual`**: Hu still depends on FighterVisual for block/dash/hit/stun/jump/fall/land (everything that returns `FALLBACK` in `combat_scene.gd:522` — only IDLE/WALKING/ATTACKING_LIGHT/ATTACKING_HEAVY route to the presenter today). Order: (a) migrate Hu's fallback states (clips + graph states), (b) migrate enemies (graph/timelines per archetype), (c) port the telegraph tint + weapon trail into the presenter/shader, and only then (d) delete `FighterVisual`. The two-render-path tax ends at (d), not before.
5. **Art consistency fixes (generation-side)**: first run the §2.3(a) three-way diagnosis (master → installed PNG → rendered) to settle the thin-Hu cause; file the third aiexp request — **reference-frame conditioning for color-tone and build/silhouette**; then, per the diagnosis, regenerate Hu (wider, weightier combat-ready idle fits the wild/comical direction) and/or apply the render-side correction; re-tone the block frames; replace the duplicated `heavy_3`/forward-held recover.
6. **Exaggeration pass**: now that the timeline/shader rig exists, actually use it — bigger squash/stretch, anticipation pops, smears, oversized telegraphs, comical timing per the saved art direction. Data-only (timeline JSON), cheap, high identity payoff.

### Phase C — Replayability (the weakest pillar)

1. **Run persistence**: serialize run state to `user://`; continue-run on launch; crash-safe autosave at node transitions. (Prerequisite for everything meta.) **Design constraint:** RNGs are currently scattered and independently randomized across `RunState`, `EnemyFactory`, `ShopGenerator`, `RewardOption`, `CombatSystem`, `AiBrain`, `TechniqueEngine`, and event paths — naïve "save the seed" replay will not be stable. Either (a) introduce a **central run-RNG with named seed streams** first, or (b) sidestep replay entirely by **saving the already-generated state** (map nodes, pending shop/reward/event contents) rather than seeds. (b) is simpler and recommended for v1.
2. **Meta-progression v1**: persistent profile (runs, wins, kills, techniques-used) + a modest unlock track (start-of-run boons, alternate starting technique, cosmetic) — enough to make run N+1 feel connected, without building the full heritage system yet.
3. **Content breadth, in this order**: (a) **second boss** (chapter 2 anchor), (b) **Demon Spirit archetype** — the designed "breaks conventional rules" enemy exercises the effect registry and AI hooks from Phase A, (c) **events 6 → ~15** (pure data), (d) **third arena/biome** with the existing background renderer, (e) **encounter variants** (sparring win-conditions, ambush with progress UI) once (a–c) exist.
4. **AI depth**: per-archetype behavior data (phase tables, gimmicks like teleport moved from `combat_system.gd` into AI/JSON), light state-memory (parry-counter response, low-HP aggression ramp — the legacy path already had one).

### Phase D — Build diversity (payoff of A + C)

1. **Reward pool rework**: school-tagged techniques, synergy hints, rare/cursed offers — possible cheaply once effects are data.
2. **Qi cultivation v1**: one run-level choice (path) that modifies the effect registry's parameters — small system, big build identity.
3. **"Gains change appearance"** (stored feature): design **layered character rendering** into the pipeline (base + weapon + equipment layers sharing anchors), pilot with 2–3 visible upgrades on Hu. This is also the moment to spec layered generation in aiexp.
4. **Second playable character** only after layering exists (it halves the art cost of every subsequent character).

### Sequencing rationale

- A before everything: each item is days-not-weeks and de-risks/accelerates B–D (e.g., Demon Spirit needs the effect registry; balance work needs JSON attacks).
- B before C: feel is the pillar nearest completion and the game's stated identity; finishing it makes every later playtest more truthful.
- Audio (B1) is deliberately the first non-engineering item: absurdly high ROI, zero coupling.
- C2's meta-progression is intentionally *v1-small*: the doc's full heritage/reputation system is a later expansion once retention data exists.

---

## 4. Risks & guardrails

- **Refactor risk (Phase A)**: `combat_system.gd` effect extraction touches live balance — port one technique at a time behind the existing 239-test suite, and add `resolve_hits` characterization tests *before* moving logic.
- **Pipeline regressions (Phase B)**: enemy rollout reuses the Hu playbook — keep the per-archetype visual gates (capture hook) and reach-consistency tests; expect per-archetype `SCALE_NORM`/anchor calibration like Hu needed.
- **Generator dependence**: tone/build consistency may land slowly upstream; the fallback (consumer-side re-toning to the idle palette assignment; manual pose redraws for key frames) is acceptable for a 7-character roster but doesn't scale — keep the aiexp request the primary path.
- **Scope creep (Phases C/D)**: the design doc is a 3-year vision; this proposal deliberately implements *v1 slices* (meta-progression v1, cultivation v1). Resist building the full systems on first pass.

## 5. Explicitly not proposed (YAGNI)

- Engine/editor-authored animation (`AnimationTree`) — the JSON/presenter direction is working; stay the course.
- Online features, leaderboards, daily challenges — need persistence + players first.
- Full 6-school character roster — blocked on layered rendering economics (D3/D4).
- Physics-based combat, netcode, 3D diorama frame — out of scope for the current loop.

---

## 6. Suggested first moves (if this proposal is adopted)

1. Phase A1 (attacks-to-JSON) as its own plan — the smaller, lower-risk data migration; it establishes the loading pattern.
2. Then Phase A2 (technique effect registry) as a **separate plan file** — the bigger refactor, gated on characterization tests of every existing technique behavior. **Hard rule: A1 and A2 are separate plan *files* in `docs/superpowers/plans/`, not bullets within one plan** — the known failure mode is implementation drift back into a mega-refactor. A1 must land (committed, suite green) before A2's plan is executed; an A2 task may not touch attack-data loading, and an A1 task may not touch technique resolution.
3. Phase B1 (audio) as a parallel, independent plan — no dependency on anything.
4. File the aiexp **reference-frame conditioning** request (tone + build) now — longest external lead time — and run the §2.3(a) thin-Hu diagnosis alongside it.
5. Then B2 (bandit_sword pipeline pilot) to template the enemy rollout.

Each becomes its own spec/plan per the existing workflow (brainstorm → spec → plan → implement-with-review), which has demonstrably worked well in this repo.
