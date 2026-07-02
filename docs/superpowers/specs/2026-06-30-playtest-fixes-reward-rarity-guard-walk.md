# Playtest Fixes — Reward Rarity Color + Guard-Walk Slide

**Date:** 2026-06-30
**Status:** directive (small fixes) — from a hands-on playtest of `f91b7ab`
**Scope:** one draw-only fix, one minimal feel stopgap. No systems.

## Fix 1 — Technique rewards show no rarity distinction
**Repro:** the reward screen (得技 "Technique Acquired") offers techniques of different rarity with identical presentation.
**Facts:** techniques have `rarity: 1|2|3` (`data/Techniques/TechniquePool.json` — 9× r1, 8× r2, 3× r3); rarity already drives shop price (`shop_generator.gd:23`) but is **never rendered anywhere**. `reward_scene.gd:73` draws every option via `UiDraw.reward_option` with one accent; `RewardOption` doesn't even carry the field (`reward_option.gd` has no rarity).
**Fix (mirror the boon-offer treatment):**
- Plumb rarity through **every** `RewardOption` creation path — there are three, and two build options manually without `from_dictionary`:
  - `RewardOption` gains `var rarity: int = 1`.
  - `from_dictionary()` (`reward_option.gd:41`) copies `rarity` (default 1).
  - **`random_technique()` (`reward_option.gd:50`)** — add `option.rarity = int(pick.get("rarity", 1))` (the `pick` dict already has it).
  - **`RunFlow.generate_master_rewards()` (`run_flow.gd:~161`)** — same manual construction, same added line.
- **Shop:** `ShopGenerator.generate_shop()` computes `rarity` for the price but **does not put it in the returned item dict** — add `"rarity": rarity` to the `items.append({...})` (`shop_generator.gd:~26`); technique-less rows (potions/services) omit it.
- Render: rarity chip + border tint, mapping rarity → the existing boon colors (1 → common `COLOR_LIGHT_BLUE`, 2 → rare `COLOR_SKY_BLUE`, 3 → epic `COLOR_PURPLE_LIGHT`) — a `rarity_color` param on `UiDraw.reward_option` or a chip drawn by the scene (same look as `boon_offer_scene._draw_offer_card`'s chip). Stat-bump rewards / non-technique shop rows stay as today.
- **Capture support:** `reward_scene.enter` reads `payload.rewards` and the scene accesses `.label`/`.technique_id` — a JSON capture payload delivers **dicts**, which would break attribute access. Have `enter()` convert dict entries via `RewardOption.from_dictionary` (objects pass through unchanged). Shop items are already dicts; no conversion needed.
**Verify (forced mixed-rarity payloads — random captures may not contain all rarities):**
```bash
cat > /tmp/fr_reward.json <<'JSON'
{"kind":"ui","screen":"reward","payload":{"rewards":[
  {"id":"cloud_hands","label":"Cloud Hands","effect":"technique","technique_id":"cloud_hands","rarity":1},
  {"id":"scar_of_past","label":"Scar of the Past","effect":"technique","technique_id":"scar_of_past","rarity":2},
  {"id":"phoenix_rise","label":"Phoenix Rise","effect":"technique","technique_id":"phoenix_rise","rarity":3}]}}
JSON
./run.sh --capture /tmp/fr_reward.json /tmp/fr_reward.png
cat > /tmp/fr_shop.json <<'JSON'
{"kind":"ui","screen":"shop","payload":{"items":[
  {"type":"technique","technique_id":"cloud_hands","label":"Cloud Hands","description":"r1","price":20,"rarity":1},
  {"type":"technique","technique_id":"scar_of_past","label":"Scar of the Past","description":"r2","price":35,"rarity":2},
  {"type":"technique","technique_id":"phoenix_rise","label":"Phoenix Rise","description":"r3","price":50,"rarity":3}]}}
JSON
./run.sh --capture /tmp/fr_shop.json /tmp/fr_shop.png
python3 tools/assert_nonblank.py /tmp/fr_reward.png && python3 tools/assert_nonblank.py /tmp/fr_shop.png
```
(Use real technique ids from `TechniquePool.json` with rarities 1/2/3 — the ids above are placeholders; pick actual ones when implementing.) Chips/tints must visibly differ across the three rows in both captures.

## Fix 2 — Moving while guarding slides a static block pose
**Repro:** hold block + move — the character glides across the ground frozen in the guard pose.
**Facts:** `combat_system.gd:84` allows full-speed movement while `is_blocking` (no penalty exists); `BLOCKING` is a held pose (no block-walk clip exists).
**Decision (user, 2026-06-30): guarding ROOTS you — no movement while blocking/parrying.** (The block-walk animation is parked behind the creative revamp; rather than a sliding stopgap, guarding plants your feet — also a classic stand-your-ground guard feel.)
**Root semantics (precise — "roots" means an instant plant, not a brake, but knockback survives):**
- **On the guard-press edge** (`input_state.block_pressed`, grounded): set `fighter.velocity.x = 0.0` **once** — an instant plant, zero slide. (A lerp-brake with `groundMoveControl 0.25` would slide for ~10 frames — that is NOT "roots".)
- **While held** (`input_state.block_down`, grounded): force `target_speed = 0.0` each frame so input can't re-accelerate — but do **NOT** re-zero `velocity.x` every frame: `resolve_hits` applies **block knockback** to the defender's velocity, and a per-frame zero would erase it, turning guard into an immovable wall (kills blocked-hit pushback and corner spacing). With target 0, knockback applies and the existing lerp bleeds it off naturally.
- Gate on the **input fields**, not `fighter.is_blocking` — `is_blocking` is assigned at `:84`, *after* the movement code (~`:35-40`) runs, so it lags a frame.
- **Do NOT add BLOCKING to the `can_move` exclusion list** — excluded states skip the lerp entirely, freezing residual velocity (glide).
- Suppress the IDLE→WALKING transition (`:41-43`) while `block_down` (guard pose holds; no walk anim while rooted).
- Airborne: unchanged (no rooting mid-air; air block behaves as today).
- Parry is a tap of the same key — the press-edge plant covers the parry moment; no separate handling.
- Enemy side: out of scope (AI movement is its own path; rooting enemies shifts balance). Note for the enemy-animation pass.
- **Log the block-walk clip** in the animation-pass backlog (revamp track) — a guard-walk may return post-revamp as a design choice.
- Balance note: rooting removes guard-mobility entirely. The scripted policies (esp. `parry_duelist`, which holds block) may shift. **Re-run the 3-policy sweep (50 seeds each)**: parry ~0.55–0.62, dash ~0.30, facetank 0.00; flag if parry drops >0.05.
**Tests (unit, grounded):**
- Guard held + move input across N frames (no hits): **horizontal position delta == 0** and `velocity.x == 0` from the press frame onward (not "decays to ~0" — the plant is instant).
- Pressing guard while moving: `velocity.x` is 0 on the press frame.
- A **blocked hit while guarding still displaces** the defender (knockback preserved, then bleeds off) — guard is rooted vs input, not vs impacts.
- Animation stays BLOCKING (never WALKING) while held; a parry still succeeds while rooted; airborne behavior unchanged. `./run.sh --test` green.
**Verify:** manual feel (guard plants you instantly; release moves instantly; blocked hits still nudge you); policy sweep within bands.

## Out of scope
- Block-walk animation (revamp/animation track).
- Audio iteration (hero sounds judged "so-so, serviceable" — deferred; see funness memory).
