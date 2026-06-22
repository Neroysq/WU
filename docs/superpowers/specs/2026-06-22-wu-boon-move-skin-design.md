# WU — Boon Move-Skin System (Visual Variance) — Design

**Date:** 2026-06-22
**Status:** draft (pre-plan) — for user review
**Sub-project:** #3 of the "complete fun run" effort (visual variance). Builds on the boon build system (#2) and the technique-effect engine; validated by the playtest harness (visual capture).

**Goal:** A boon infusing a move slot gives that move a **distinct, school-specific animation** — so committing to a 流 (school) visibly transforms how Hu fights, not just his numbers.

**Why:** Today `FighterVisual` always plays Hu's base clips and only tints by `fighter.color_body`. The boon system (#2) already changes mechanics per move slot through the technique engine, but the build is invisible — a Venom light attack and a Sword light attack look identical. #3 closes that gap on the visual side.

---

## 1. Decided (from brainstorming)

- **Scope = boons → per-move visuals only.** Relic/equipment → overall outlook/aura is a **separate, deferred spec ("spec B")** — no relic/equipment system exists yet (Rewards are flat stat boosts), so it has no driver.
- **Separate animations, not FX overlays.** Each (school, move) is a genuinely distinct clip — not a recolor of the base move. (Recolor is only the *fallback* for not-yet-arted cells.)
- **System + one vertical slice.** Build the clip-routing/fallback engine now, and fully animate **one school (Venom 毒)** as the proof. The remaining clips are an ongoing, gated art track.
- **Per-clip timing allowed.** A school's move may carry its own gameplay timing — but this needs **no new timing system** (see §4): the technique engine already supports per-move timing overrides, and the visual layer is timing-agnostic.
- **Fallback = base move + school recolor** for slots without a bespoke clip yet.
- **Validated by the harness** visual capture (a Venom move reads different from base; non-blank; deterministic).

---

## 2. Scope & decomposition

| Subsystem | Driver | Status |
| --- | --- | --- |
| **A — Boon → per-move clip** (this spec) | `BoonLoadout.slots[slot]` → 流 (live, from #2) | **build now** |
| **B — Relic/equipment → outlook & aura** | needs an equipment/relic system | **deferred** (no driver exists) |

The six move slots (from #2): **light, heavy, dash, block, stance, jump**. The six schools (`data/Schools/Schools.json`, each with `themeColor` + `hanzi`): Venom 毒, Thunder 雷, Soft Palm 柔, Iron Body 鐵, Windstep 風, Sword 劍. The full target space is **6 schools × 6 slots = up to 36 clips**, filled incrementally; this spec ships the system + the Venom row.

---

## 3. Model — per-move skin resolution

Every frame, for the player only, `FighterVisual` resolves the move it is about to draw:

```
move animation state  →  slot  →  infusing 流 (from loadout)  →  skin clip?
    ATTACKING_LIGHT       light      e.g. venom                   yes → play skin clip
    ATTACKING_HEAVY       heavy      (none)                       —   → play base clip
    dash/block/stance/jump …                                     no  → base clip + 流 recolor
    IDLE/WALK/HIT/STUNNED/LANDING  → (no slot) → always base, never skinned
```

- **Slot infusion** comes straight from `BoonLoadout.slots[slot]` → boon record → `school`. A slot with no boon resolves to base. Idle/walk/hit/stun/landing map to **no slot** and are never skinned (the persistent silhouette/aura is spec B's domain).
- **Skin present** → play the school's bespoke clip for that state.
- **Skin absent but slot infused** → play the **base clip tinted toward the school's `themeColor`** (graceful identity cue until the bespoke clip lands).
- **Player only.** Enemies have no loadout and are never skinned.

---

## 4. Architecture (data-driven, art-agnostic)

**Art is placeholder.** Current Hu/enemy art will be replaced, so the design stays **art-agnostic**: routing is by data + state name, with fallback when a clip is absent, so swapping the underlying sprites later needs no code change.

- **Per-school overlay animation sets — `assets/animations/skins/<school>.json`** (e.g. `skins/venom.json`). Each holds **only that school's overridden move clips** (the same clip schema `AnimationSet.load_from_file` already loads: `frames`, `fps`, `loop`, and `phases` for attacks). The base set (`character_humanoid.json`) is unchanged. This keeps art organized by school, lets us **lazy-load only equipped schools**, and lets the 36-cell grid fill in file-by-file — a new cell "just works" the moment its file exists.

- **Slot→state map (constant).** `light→ATTACKING_LIGHT`, `heavy→ATTACKING_HEAVY`, `dash→DASHING`, `block→BLOCKING`, `stance→STANCE`, `jump→{JUMPING, FALLING, LANDING}` (the jump slot owns the airborne states). Any state not in this map is never skinned. (Exact base-state enum names to be matched to `Fighter.AnimationState` during planning; the map is the single source of truth for state→slot.)

- **Loadout → visual handoff.** `FighterVisual` gains a `set_move_skins(slot_school_map: Dictionary)` (slot → school id), called at **combat setup** from the player's `BoonLoadout` (loadout is fixed for the duration of a combat, so it is set once per fight). On set, it lazy-loads the overlay sets for the referenced schools and caches them.

- **Clip resolution in `FighterVisual`.** After `_resolve_state(fighter)` produces the base state name: look up `state→slot`; if that slot has an infusing school **and** that school's overlay set contains a clip for the state, draw from the overlay clip; otherwise draw the base clip. Recolor (school `themeColor`) is applied in `_compute_draw_tint` when the slot is infused but no skin clip resolved.

- **Timing needs no new system.** Gameplay timing already flows through the **technique engine**: `start_light_attack()/start_heavy_attack()` consult `technique_engine.get_*_override()` (fighter.gd:367–374), and `technique_effect` has per-slot hooks (`attack_override`, `modify_block`, `on_dash_end/through`, `on_jump`, `on_stance_activate/deactivate`). Boons are technique effects, so a Venom boon can already return a custom attack definition (its own windup/active/recovery). `FighterVisual` renders against **phase→progress** (`_frame_index_for_phase` uses `progress_in_phase()`, which is duration-independent), so a skin clip displays correctly against *whatever* timing the active def has. "Per-clip timing allowed" is therefore satisfied by the existing seam — this spec adds **no** gameplay-timing code; custom timings live in the Venom boon effects (their existing rider domain) and are validated by the harness.

All knobs (which clip, which color) live in data → swappable without code.

---

## 5. Vertical slice — Venom (毒), all 6 slots

Six bespoke Venom move clips, generated through the **animation gate** in priority order:

**light → heavy → dash → stance → block → jump**

(attacks first: most visible, and light/heavy already have the weapon-arc hook). Each clip follows the standard gate: **Gate 1 keyframe pose review → scale-vs-idle review → generate → Gate 2 in-game** (see [[review-keyframes-before-generating]], [[judge-art-size-overall-in-game]]). Venom flavor reads as distinct silhouettes, not just green tint — e.g. a venomous palm strike (light), a spray/spit (heavy), a serpentine dash, a coiled guard stance.

Each clip is authored into `assets/animations/skins/venom.json`. Attack clips (light/heavy) must declare `phases` mapping to the move's attack phases so the phase→progress renderer drives them. If a Venom boon defines custom timing, that timing lives in the boon effect (§4), not the clip.

The other five schools ride the **base + recolor** fallback until their clips are generated on the incremental track.

---

## 6. Fallback behavior

A slot infused by a school with no bespoke clip plays the **base move clip tinted toward that school's `themeColor`** (a subtle, readable lerp over `fighter.color_body`, layered under the existing telegraph/active-flash signals so combat readability is never degraded). This guarantees every school reads as *something* immediately, and the bespoke clip silently supersedes the recolor when it lands.

---

## 7. Validation loop

- **Structure tests** (deterministic, scene-free):
  - slot infused + skin clip exists → resolver returns the **skin** clip;
  - slot infused + no skin clip → resolver returns **base** clip and flags **recolor** with the school color;
  - slot not infused → **base**, no recolor;
  - enemy fighter → **never** skinned (no loadout);
  - state with no slot (idle/walk/hit/stun/landing) → never skinned even when boons are equipped.
- **Harness visual capture** (non-headless, real renderer): capture a player **Venom light** attack and a **base light** attack; assert the Venom frame is **non-blank** and **differs** from base (the move-skin actually swapped the clip), and that capture is **deterministic** across runs.
- **Readability check:** with a full Venom loadout, the existing telegraph/active-flash colors still dominate during their windows (recolor/skin must not mask the teaching flash).

---

## 8. Out of scope / YAGNI

- The other five schools' bespoke clips (the incremental art track — each lands later through the gate).
- **Duo/Mastery blended visuals.** v1: a duo boon in a slot uses its **primary school's** clip (or that school's recolor); mastery uses its school's clip. A blended/unique duo look is a later enhancement.
- Idle/walk/persistent silhouette/aura changes — that's **spec B** (relic/equipment).
- Enemy move-skins.
- New gameplay-timing infrastructure (the technique engine already covers it).

---

## 9. Resolved decisions

1. **Scope:** boons → per-move clips only; relic/equipment aura deferred to spec B.
2. **System + Venom slice** (all 6 slots, order light→heavy→dash→stance→block→jump).
3. **Per-clip timing allowed**, served by the existing technique-engine override seam — no new timing system.
4. **Fallback:** base move + school recolor for un-arted slots.
5. **Storage:** per-school overlay animation sets (`assets/animations/skins/<school>.json`), lazy-loaded for equipped schools.
6. **Player only;** idle/walk/hit/stun/landing never skinned.
7. **Art-agnostic** routing (current art is placeholder; see [[character-art-placeholder]]).

---

## 10. Sequencing (phases — full plan after approval)

1. **Skin schema + loader:** overlay animation-set format under `assets/animations/skins/`; lazy-load + cache in `FighterVisual`; `set_move_skins(slot_school_map)`. Tests: load/merge/fallback resolution.
2. **Slot→state map + resolution:** the constant state→slot map; clip resolution (skin → base) and recolor-fallback path in `FighterVisual` draw/tint; wire the player's `BoonLoadout` → `set_move_skins` at combat setup. Tests: §7 structure cases.
3. **Recolor fallback:** `themeColor` tint in `_compute_draw_tint` for infused-but-unskinned slots, under telegraph/flash. Test: readability + recolor flag.
4. **Harness capture test:** Venom-light vs base-light capture assertion (non-blank, differs, deterministic).
5. **Venom slice content:** generate the 6 Venom clips through the gate, in order, each dropped into `skins/venom.json`; verify in-game (Gate 2) and via capture.
6. **Record** which cells are filled and the roadmap for the remaining 30.
