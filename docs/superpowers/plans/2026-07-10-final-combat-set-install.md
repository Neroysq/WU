# Final Combat Set Install — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. This is an asset-install plan: tests are the game's own suite + captures + the user's playtest eyeball (final gate ✋).

**Goal:** Install the FINAL user-accepted Hu combat set (6 full-density clips + 6 held statics), revert combat orientation to player-left, and remove the last old-era Hu assets.

**Specs of record:** `docs/superpowers/specs/2026-07-09-combat-set-install-rev3.md` + its **2026-07-10 addendum** (variable-canvas frames — read it before Task 2) · orientation ground truth + REVERSAL section in `2026-07-08-combat-orientation-flip.md` · provenance `art/canon/canon.manifest.json`.

**Assets (all right-facing native, NO mirroring anywhere):**
- Clips (`f%03d.png`, spatially REGISTERED, VARIABLE canvas; **97 frames each EXCEPT jump = 96** — count files, never assume):
  `art/canon/hu/clips/attack_light/` (471×257) · `attack_heavy/` (325×320) ·
  `guard_deflect/` (253×229) · `dash/` (304×229) · `jump/` (249×319, 96f) · `entry/` (257×309)
- Held statics (256×256): `art/canon/hu/held/{hit,stun_a,stun_b,relaxed,fall,land}.png`
- Pins `art/canon/hu/k1..k7.png` (k1 = idle base; reference only otherwise)

---

## Task 1: Orientation revert (small, do first — everything verifies against it)

**Files:** `WUGodot/scripts/sim/combat_setup.gd:20-21`, any capture/spawn setups from the flip commit, `WUGodot/assets/animation_manifests/hu.manifest.json:3`.

- [ ] **Step 1:** `combat_setup.gd`: `player.facing = 1`, `enemy.facing = -1` (revert the flip). Grep for other spawn-side/`gap`-sign changes from commit `b72dafb` (`git show b72dafb --stat`) and revert those sites (combat_scene spawn, capture setup).
- [ ] **Step 2:** `hu.manifest.json`: root `"nativeFacing": 1`. Keep the mechanism in code (per-pose overrides default to root). Enemy manifests untouched.
- [ ] **Step 3:** `./run.sh --import && ./run.sh --test` → `failed: 0`. `./run.sh --shot-combat` → player on LEFT facing RIGHT, blade viewer-side. Commit `fix(combat): revert orientation — player left, art right-facing native`.

## Task 2: Frame install tooling (variable canvas)

**Files:** `WUGodot/tools/install_raw_frames.gd`, `run.sh` (`--install-raw-frames`).

- [ ] **Step 1:** Update the installer per the rev-3 ADDENDUM: accept any canvas size; `footAnchor = (content bbox center x, content bbox bottom)` per frame from the ACTUAL frame content (no 256/246 assumptions). Frames within a clip are registered, so anchors come out consistent — assert that (per-clip footAnchor x/y spread < 4px → warn if larger).
- [ ] **Step 2:** weaponTip: the manifest loader REQUIRES weaponTip on every pose (`animation_manifest.gd:11` `_REQUIRED_ANCHORS`) and `anchor_sanity.gd:54` measures every pose's tip. So: **emit a MEASURED weaponTip for EVERY installed pose** (steel-extreme heuristic); hand-tuned overrides (`art/canon/hu/clips/<clip>/weapontip_overrides.json`) only need care on attack ACTIVE poses. Add any pose whose heuristic tip is legitimately weird (sheathed entry frames!) to anchor_sanity's `OVERRIDE_ALLOWLIST` rather than weakening the validator.
- [ ] **Step 2b2 (anchor_sanity grouping — P2):** `anchor_sanity.gd:34` groups by `pose_name.get_slice("_", 0)` — under the new ids EVERY `hu_*` pose collapses into one group per canvas width (and the 256px held statics + pins share one spread gate). Change the grouping to the CLIP STEM: everything up to the trailing `_<digits>` (`hu_light_038` → `hu_light`; statics like `hu_hit` group alone). This is also what makes Task 2's "per-clip footAnchor spread" assert meaningful.
- [ ] **Step 2c (pose-id convention — pin it):** the current labeler emits `%02d` indices (`install_raw_frames.gd:115`), which collides with 97-frame clips and this plan's f%03d references. **Convention: pose id = `<clip>_<3-digit stem from the filename>`** (f038.png → `hu_light_038`). Update the labeler to derive labels from filename stems (zero-padded 3), and use these exact ids everywhere downstream (timelines, STRIKE_POSE_BY_ID, aliases, tests).
- [ ] **Step 3:** Run the installer per clip into the sprites dir (e.g. `WUGodot/assets/sprites/characters/hu/<clip>/`), emitting manifest pose entries. Commit `feat(tools): variable-canvas raw-frame install + hu combat sprites`.

## Task 3: Timelines (subsample the 97 — do NOT install all frames as keyposes)

**Files:** `WUGodot/assets/animation_clips/{hu_attack_light, hu_attack_heavy, held_block, held_dash, held_jump, idle, walk, entry_draw}.timeline.json` + manifest.

Suggested default picks (indices into f%03d; retime freely later — that's why density exists):
- [ ] **light**: windup 0,8,16,24 · active 30,34,38,42,46 · recovery 56,68,80,90,96. Events at the anchors; `duration: fromAttackDef`. White-flash frames (~30-34) are §3c-legal — keep ≤2 of them.
- [ ] **heavy**: windup 0,10,20,30,40,50 · active 58,64,70 · recovery 74,78, then **EASE THE SOURCE JUMP-CUT** (user-accepted): hold ~78 slightly longer, then 82,88,96 — do not look for smooth source frames between the chop and guard; there are none.
- [ ] **deflect** (`held_block`): rise 0,8,16 · hold-loop over the braced segment (~24-64: pick 4 evenly, loop) · return 72,84,96.
- [ ] **dash** (`held_dash`): 0,6,12 (crouch) · flight 20,32,44,56,68 · land/return 80,90,96.
- [ ] **jump** (`held_jump` + fall/land states): rise 0,8,16,28,40 · apex 48,56 · descend 68,80 · land 88,95. (held_fall/held_land statics from Task 4 cover the physics-driven fall/land states.)
- [ ] **entry** (`entry_draw.timeline.json`, replaces the vd_* sequence): stand 0,10,20,30 · hilt 40,50 · draw 60,66,72 · settle 80,88,96. Retime BOTH timing sites: `combat_scene.gd:23` `ENTRY_DRAW_DURATION: 1.6` (live combat, seconds) AND `main.gd:20` COMBAT_ENTRY `frames: 112` (capture harness) to the new clip length.
- [ ] **idle**: k1 static (already installed — verify it survived Task 1/2). **walk**: pins to k1 (unchanged this pass).
- [ ] **Timeline tests — rewrite ALL pose-id assertions in `tests/test_animation_clip_timeline.gd`, not just two:** `:37` pins `hu_light_00/01/04/05/10/15`, `:76` pins `hu_heavy_02/04/05/10` (+ smear-track sampling), `:91` pins `hu_jump_00/hu_jump_07` and `vp_stun_b`, `:98` pins the vd_* entry sequence with `fixed_duration 1.6`. Every one changes under the 3-digit ids + new picks + new entry duration. Update each assertion alongside its timeline, in the SAME commit, so the suite never goes red between commits.
- [ ] **Collision keys (P1 — do not skip):** `presentation_collision.gd:10` hard-codes `STRIKE_POSE_BY_ID = {"hu_light": "hu_light_05", "hu_heavy": "hu_heavy_08"}`. Update BOTH to the chosen final ACTIVE-EXTENSION pose names (light ≈ your pick near f038 full extension; heavy ≈ f064 low impact), and update `tests/test_heavy_capsule_pose.gd:10` to match. Visuals looking right while collision samples a stale/windup pose is the failure this prevents.
- [ ] Commit per clip or as one `feat(anim): final combat timelines from full-density canon`.

## Task 4: Held statics (kills the last old-era Hu)

**Files:** `held_hit.timeline.json` (vp_hit), `held_stunned.timeline.json` (vp_stun_a/b), `held_fall.timeline.json` (vp_fall), `held_land.timeline.json` (vp_land) + manifest poses.

- [ ] **Step 1:** Install `art/canon/hu/held/{hit,stun_a,stun_b,fall,land}.png` as manifest poses (installer from Task 2; single statics) with these EXACT ids — do not invent variants: **`hu_hit`, `hu_stun_a`, `hu_stun_b`, `hu_fall`, `hu_land`, `hu_relaxed`**. Repoint the four held timelines at those ids. `hu_relaxed` installs unused for now (future out-of-combat idle; note in manifest).
- [ ] **Step 2:** Grep the manifest for remaining `v[dhilpw]_` pose references reachable from any live timeline — there should be NONE after this task (report stragglers rather than silently leaving them).
- [ ] **Step 2b (alias policy — P2):** the LEGACY ALIASES (`guard`, `windup`, `strike_extended`, `recover`, `heavy_windup`, `heavy_strike`, `heavy_recover`, `breath`) are load-bearing: collision falls back to `strike_extended`/`guard` (`presentation_collision.gd:8,102`) and `test_animation_manifest.gd:26` validates all of them. **Policy: REPOINT every alias to the corresponding final canon pose** (guard/breath → k1 idle pose; windup/strike_extended/recover → the light windup/active/recovery picks; heavy_* → the heavy picks). Do not delete them; do not leave them on old sprites.
- [ ] **Step 3:** Commit `feat(anim): held poses — hit/stun/fall/land from canon (old-era Hu fully retired)`.

## Task 5: Verify (exact commands) + hand back

- [ ] `./run.sh --import && ./run.sh --test` → `failed: 0`
- [ ] `./run.sh --anchor-sanity` → OK
- [ ] `./run.sh --shot-combat <out_dir>` → all 15 shots: player LEFT facing RIGHT; new art in EVERY state incl. hit_react/stunned/fall/land; `tools/assert_nonblank.py` per shot
- [ ] `./run.sh --shot-action COMBAT_ENTRY <dir>` → the entry draw plays frame by frame with the new art (the 15-shot set does NOT cover entry — this is the check for it)
- [ ] Action-state captures — the matchup spec DEFAULTS to `state: "01_idle"` (`main.gd:391`), so idle-only specs verify nothing about attacks. Use explicit states:
  `{"kind":"matchup","state":"04_light_active","build":[{"boon_id":"wind_descending_leaf","tier":"epic"}]}` and `{"kind":"matchup","state":"07_heavy_active",...}` (or `./run.sh --shot-action ATTACKING_LIGHT/ATTACKING_HEAVY <dir>`): blade fully visible at light's full extension (the envelope canvas exists for exactly this); sword never changes hands; sizes constant across each action
- [ ] ✋ **STOP — hand the build to the user for the playtest.** That playtest is the juice-first pivot's re-judgment gate; report the shot set + any deviations alongside.

## Out of scope (deferred, on record)
Forward-dash variant · walk regen · K7 wrist-point install · hero-sound iteration · enemy canon (next art phase).

## Post-playtest addendum (2026-07-10, user findings)

- [ ] **Keypose density too low:** resample every timeline to ~28–36 keyposes
  (every 2–3 frames in active/fast phases; every 4–5 in windup/recovery/holds;
  deflect's hold-loop can stay sparse). All 97 poses are already in the manifest —
  this is timeline JSON only. Update the pose-id assertions in
  test_animation_clip_timeline.gd in the same commit.
- [ ] **Walk animation:** pending a user-approved Seedance roll (k1→k1 gait
  cycle); harvest + timeline + walk.timeline.json rewire when it lands.
