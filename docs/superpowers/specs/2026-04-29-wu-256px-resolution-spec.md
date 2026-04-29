# WU 256-px Resolution Upgrade

**Date:** 2026-04-29
**Status:** Locked. Decision based on the side-by-side pilot at `http://localhost:8765/wu-clarity/` (Hu generated at 64 / 128 / 256 native, all three displayed at WU's actual on-screen size).
**Supersedes:** the 64×64 character canvas convention used since the milestone-1 art pass (`docs/superpowers/specs/2026-04-14-art-pass-design.md`).
**Revision:** 5 — rev 4 fixed the shimmer-gate preconditions and the bracket pseudo-code. Rev 5 corrects the jump-clip mapping (Hu's three jump PNGs are wired across three clips: JUMPING / FALLING / LANDING) and adds the full repo path at the first `DefaultProfiles.json` mention so implementers don't accidentally create a sibling file.

This spec locks in a **4× linear** native-canvas upgrade (64 → 256) for character sprites so WU's character-detail-per-feature matches the reference at `http://localhost:8765/phase-h-ronin/character.png`. Backgrounds are unaffected.

---

## Decision

| Axis | Old (milestone-1) | New |
|---|---|---|
| Native character canvas | **64 × 64** | **256 × 256** |
| Character bbox target | ~52 px tall (81%) | **~205 px tall (80%)** — same ratio so existing yOffset math holds |
| Runtime scale (FTG feel) | 6.3 – 7.1 × | **1.7 – 1.9 ×** |
| On-screen char height | ~340–410 vp | ~340–410 vp (held constant) |
| On-screen px per source px | ~6.5 | **~1.7** (4× denser per character feature) |
| Source per-action sheet width | 4 × 64 = 256 | 4 × 256 = **1024** |
| Backgrounds | 1920 × 1080 1:1 | unchanged |
| Storage per frame | ≈ 4 KB | ≈ 64 KB (~16×) |
| Generation cost per frame | 1× | ~16× |

The on-screen character size stays the same; the change is **density**. Two combatants still fit comfortably on the 1920-wide arena.

---

## Why 256 and not 128

The pilot generated Hu at 64 / 128 / 256 with the same prompt and seed, then displayed them all at the on-screen size the player actually sees during combat (~360 vp tall). Per-character-feature density at that display size:

| Native | Runtime scale | On-screen px / source px | Visual reading |
|---|---:|---:|---|
| 64 | ~6.5 × | 6.5 | chunky pixels, sword grip blurs into hand, robe is solid blocks |
| 128 | ~3.25 × | 3.25 | sleeve folds and sword sheath line readable; face features hinted; **2 ×** denser than 64 |
| 256 | ~1.6 × | 1.6 | matches reference image's cloak-ripple / face-wrap / weapon-grip detail; **4 ×** denser than 64 |

128 would have been a clean intermediate step but the reference image's authored density is at ~256 native, and at WU's on-screen character size, the difference between 128 and 256 is the difference between "denser pixel art" and "the reference's actual look." We chose to match the reference.

**Risks accepted:**
- ~16× storage for character art. Not a concern at WU's archetype count (7 characters × ~10 actions × ~4 frames = 280 frames × 64 KB ≈ 18 MB total).
- ~16× generation cost (one regen run). Aiexp's Phase H per-model size strategies (commit `cdbff3f`) handle 256 cleanly; pilot was first-try-success.
- Image-model frame-to-frame consistency is harder at higher resolution. The pilot regen for Hu was clean across all 4 actions × 5 frames, but if a future character drifts mid-sheet we'll add the `--seed` chain or hand-tune the bad frame.

---

## Migration

### 1. aiexp generation parameters

Pass `--size 256` everywhere. Pilot commands that worked:

```bash
AIEXP=/Users/animula/GitReps/AIexp/.venv/bin/aiexp

# Static (per character)
"$AIEXP" pixel-art run \
  --prompt-text "<per-character description>" \
  --palettes vinik24 --size 256 --kind sprite --remove-bg

# Animation set — base actions (all 7 characters)
ACTIONS_BASE="walk-cycle,idle,attack-windup:2:false:weapon raised high body coiled weight on back foot,attack-strike:1:false:full lunge forward weapon fully extended past frame body stretched out,attack-recovery:1:false:weapon trailing back off-balance returning to neutral,block,hit-react,stunned"

# Animation set — Hu adds dash + jump on top of the base
ACTIONS_HU="${ACTIONS_BASE},dash,jump"

# Use ACTIONS_HU for hu, ACTIONS_BASE for the other 6 archetypes:
"$AIEXP" sprite-extractor animate \
  --character "<staged static.png>" \
  --describe "<short character description>" \
  --actions "$ACTIONS_HU" \
  --palette vinik24 --size 256 --output-dir <stage-dir>
```

Hit-react failed twice with `peer closed connection` chunked-read errors during the previous regen at 64 native — symptom is upstream-network, not size-dependent. Still expected at 256. Retry once on failure.

### 2. `WUGodot/data/VisualProfiles/DefaultProfiles.json` rescale

Two fields per profile. Third one (`weaponTipOffset`) **does not change** — see the correction below.

- **`scale`** divided by 4 (native canvas grew 4×, viewport scale shrinks 4× to keep on-screen size constant).
- **`yOffset`** stays in world-pixel space; recompute from each character's new static `padB` after regen: `yOffset = padB_at_256 × new_scale`. Use existing values as a placeholder until bboxes are measured.
- **`weaponTipOffset`** is **already in world/viewport-pixel space** (verified at `fighter_visual.gd:276-280`: the field is read directly into a world-space `Vector2(facing * tip_distance, weapon_tip_offset.y)` added to `fighter.position`, with no `* scale` anywhere). The on-screen size of the character is held constant by §1, so the world-space tip distance also stays constant. **Do not multiply weaponTipOffset by 4.** Leave the existing values.

Worked-out target table:

| profile | scale 64 → 256 | weaponTipOffset (unchanged) |
|---|---|---|
| player_humanoid (hu) | 6.5 → **1.625** | (76, -34) |
| enemy_humanoid_basic (bandit_sword) | 6.3 → **1.575** | (74, -34) |
| enemy_humanoid_basic_spear | 6.3 → **1.575** | (126, -42) |
| enemy_humanoid_ronin | 6.5 → **1.625** | (84, -34) |
| enemy_humanoid_elite (disciple) | 6.7 → **1.675** | (88, -38) |
| enemy_humanoid_assassin | 6.7 → **1.675** | (92, -34) |
| enemy_humanoid_boss (iron_bear) | 7.1 → **1.775** | (132, -58) |

### 3. File paths and per-action frame-count contract

PNG paths in the animation JSONs (`assets/animations/character_*.json`) stay unchanged. **However, the per-action frame counts produced by aiexp do not all match WU's expected slot count**, and the install step must downsample three actions:

| Action (WU clip) | aiexp default frames (`actions.yaml`) | WU JSON slots | Action |
|---|---:|---:|---|
| walk-cycle / WALKING | 4 | 4 | 1:1 |
| idle / IDLE | 2 | 2 | 1:1 |
| attack-windup → attack_0..1 | 2 (custom) | 2 | 1:1 |
| attack-strike → attack_2 | 1 (custom) | 1 | 1:1 |
| attack-recovery → attack_3 | 1 (custom) | 1 | 1:1 |
| **block / BLOCKING** | **3** | **2** | **downsample: pick frames 1 and 3** |
| **hit-react / HIT_REACTION** | **3** | **2** | **downsample: pick frames 1 and 3** |
| stunned / STUNNED | 2 | 2 | 1:1 |
| **dash / DASHING** (hu) | **4** | **2** | **downsample: pick frames 1 and 4** |
| jump (hu) — `jump_0..2` PNG slots | 3 | 3 PNG slots, **split across 3 clips** | PNG copy 1:1; clip wiring stays as-is |

Two acceptable resolutions:

- **Option A (selected — keep WU JSONs as-is):** install step downsamples block/hit-react/dash by sampling endpoints. Drop-in for current animation JSONs; no JSON edits.
- Option B: extend Hu/enemy JSONs to use 3 frames for BLOCKING and HIT_REACTION (and 4 for DASHING), giving smoother reactions. Requires JSON edits across all 7 characters; bumps frame storage further. Defer to a follow-up density pass.

**Inlined `sample_indices` algorithm** (the spec is self-contained; Phase 3 implements its own installer using this contract):

```python
def sample_indices(src_n: int, wu_n: int) -> list[int]:
    """Pick wu_n evenly spaced 0-based indices from src_n source frames.
    Endpoints are always included when wu_n >= 2."""
    if wu_n >= src_n:
        return list(range(src_n))
    if wu_n == 1:
        return [0]
    return [round(i * (src_n - 1) / (wu_n - 1)) for i in range(wu_n)]
```

Concrete results for the three downsampled actions:
- `block` (3 → 2): `sample_indices(3, 2) = [0, 2]` → source frames 1 and 3.
- `hit-react` (3 → 2): `[0, 2]` → source frames 1 and 3.
- `dash` (4 → 2): `sample_indices(4, 2) = [0, 3]` → source frames 1 and 4.

Phase 3 ships its own `tools/install_regen_256.py` (or similar) implementing the contract above; no `/tmp/` dependency.

### 4. Code audit — what does NOT need changing

- `fighter_visual.gd` reads texture dimensions at draw time and scales by `profile.scale`. Already-resolution-agnostic.
- `animation_set.gd` parses frame paths, doesn't care about pixel dimensions.
- `combat_scene.gd` telegraph outline / weapon arc are world-space. No pixel-space constants.
- `attack_state.gd`, `combat_system.gd`, `fighter.gd` — gameplay-side, not visual.
- Texture filter is already `nearest` in `project.godot:38` (`textures/canvas_textures/default_texture_filter=0`). 256-native art on `nearest` reads as crisp pixel art at integer scales. **Caveat:** the proposed runtime scales (1.575–1.775) are *fractional*, so under sub-pixel motion (movement, camera shake, telegraph pulse) some source pixels will render as 1 viewport-pixel wide and adjacent ones as 2 — visible as shimmer. This needs to be evaluated in motion before locking; see verification.

### 5. Code audit — what DOES need changing

- **`DefaultProfiles.json`** — the two fields per profile (`scale` and `yOffset`) listed above. `weaponTipOffset` stays unchanged.
- **`fighter_visual.gd:276-280`** — already verified during rev 2: `weapon_tip_offset` is read directly into a world-space `Vector2`. **No change needed.**
- **`Fighter.half_width`** in `fighter.gd:37` is currently `22.0` and **does not depend on visual scale**. Decision: keep it. Combat collision geometry should not change with art density. Confirmed during the FTG-scale bump that this decoupling is intentional.

### 6. Sprite directories

Same paths under `WUGodot/assets/sprites/characters/{archetype}/`. The PNGs grow from ~4 KB to ~64 KB each. Repository size grows by ~14 MB across the 7 characters.

---

## Rollout phases

### Phase 1 — pilot (DONE)

Hu regenerated at 256: static + walk-cycle + 3-phase attack. First-try-success, faithfulness 1.00, all 4 actions clean. Output staged at `/tmp/wu_res_pilot/256/`. Comparison page at `http://localhost:8765/wu-clarity/` confirms the visual jump.

### Phase 1.5 — install pilot Hu, rescale, and motion-shimmer gate (NEW)

**Blocks Phase 2.** Before regenerating the other 6 characters, install the pilot Hu at 256 into WU and confirm the fractional scale doesn't shimmer in motion.

1. **Regenerate the missing Hu actions at 256** before installing. The Phase 1 pilot at `/tmp/wu_res_pilot/256/` only covered static + walk-cycle + 3-phase attack. To run the shimmer test in-game without mixing 256-native and 64-native frames (which would render at wildly different on-screen sizes under the new `scale = 1.625` and invalidate the test), generate the rest of Hu's action set at 256:

    ```bash
    AIEXP=/Users/animula/GitReps/AIexp/.venv/bin/aiexp
    "$AIEXP" sprite-extractor animate \
      --character /tmp/wu_res_pilot/256/static.png \
      --describe "young Chinese swordsman in blue robe with gold sash, topknot hair, sword at hip" \
      --actions "idle,block,hit-react,stunned,dash,jump" \
      --palette vinik24 --size 256 \
      --output-dir /tmp/wu_res_pilot/256/run_rest
    ```

    Adds ~6 actions × ~3 min ≈ 20 min plus retries. Combined with the Phase 1 outputs, Hu now has the full 256 set.

2. Install **all** Hu 256 sprites into `WUGodot/assets/sprites/characters/hu/`: static, walk, idle, attack (windup/strike/recovery), block, hit-react, stunned, dash, jump. Use the §3 frame-mapping contract (downsample block/hit-react/dash). Other characters stay at 64 native temporarily — that's fine; this is a stand-alone Hu test, and Hu's clips don't depend on enemy art.
3. Edit `DefaultProfiles.json` for `player_humanoid` only: `scale: 1.625`, leave `weaponTipOffset` unchanged, set `yOffset` from the new static's measured `padB`.
4. `./run.sh --reimport` and launch a duel.
5. **Capture motion**: walk Hu left and right, dash, idle (verify no shimmer when stationary either), and perform attacks. For camera shake, use the hit/parry shake from a regular duel; the boss-beat sequence is also acceptable if testing via the boss node. Record video or a frame sequence.
6. **Inspect for shimmer**: source pixels rendering as 1 vp wide should not flicker into 2 vp width frame-to-frame on stationary character features. Walk and dash sub-pixel motion are the worst-case test.
7. **Decision branch:**
   - If shimmer is acceptable → proceed to Phase 2 with `scale ≈ 1.6` per profile.
   - If shimmer is unacceptable → pick a fix:
     - (a) Snap to integer scale 2.0 (character grows ~22% on screen; re-tune yOffset).
     - (b) Snap to half-integer 1.5 (uniform 1.5-pixel grain; character ~6% smaller).
     - (c) Downscale source canvas to a value that integer-divides into the target screen size at the chosen scale.
   - Document the resolution at the bottom of this spec before unblocking Phase 2.

This phase is intentionally a single-character test. Doing it before Phase 2 means a rejected decision costs ~30 min of Hu top-up regen + rescale, not 60 min of full-batch regen.

### Phase 2 — full character regen at 256

Run the same aiexp pipeline (static + full action set including phase-split attack) for all 7 characters at `--size 256`. Stage to `/tmp/wu_regen_256/{character}/run/`.

Action lists:
- **hu**: walk-cycle, idle, attack-windup:2:false, attack-strike:1:false, attack-recovery:1:false, block, hit-react, stunned, dash, jump
- **bandit_sword, bandit_spear, ronin, disciple, assassin**: walk-cycle, idle, attack-windup:2:false, attack-strike:1:false, attack-recovery:1:false, block, hit-react, stunned
- **iron_bear (boss)**: same as enemy set; consider extending hit-react/stunned counts later

**Estimated wall time at parallel = 4:** ~30–60 min total. The pilot's 256-native walk-cycle alone took 244 s (~4 min) and individual actions ranged 140–245 s in `metadata.json`. With 8 actions × ~3 min = ~24 min per character serially; at parallel = 4 across 7 characters, expect 30–45 min plus ~10 min for chunked-read retries (Phase D OpenRouter network blip seen during prior runs). Budget a working hour, not 8 minutes.

### Phase 3 — install + rescale + reimport

- Implement `tools/install_regen_256.py` (in-repo) using the `sample_indices` contract from §3. Frame mappings:
  - `walk-cycle/frame_001..004 → walk_0..3` (1:1)
  - `idle/frame_001..002 → idle_0..1` (1:1)
  - `attack-windup/frame_001..002 → attack_0..1` (1:1)
  - `attack-strike/frame_001 → attack_2` (1:1)
  - `attack-recovery/frame_001 → attack_3` (1:1)
  - `block/frame_001,003 → block_0,1` (downsample 3 → 2)
  - `hit-react/frame_001,003 → hit_0,1` (downsample 3 → 2)
  - `stunned/frame_001..002 → stunned_0..1` (1:1)
  - `dash/frame_001,004 → dash_0,1` (downsample 4 → 2; hu only)
  - `jump/frame_001..003 → jump_0..2` (1:1; hu only). The three PNGs are wired across three clips in `WUGodot/assets/animations/character_hu.json`: `JUMPING = jump_0, jump_1`; `FALLING = jump_2`; `LANDING = jump_2, idle_0`. The install step only copies the PNGs; the clip wiring stays untouched.
- Update `DefaultProfiles.json` per the table in §2.
- `./run.sh --reimport`
- `./run.sh --test` (must remain 173/173).

### Phase 4 — visual re-shoot

Capture the 16-state playtest sweep again and compare against `/tmp/wu-playtest-2026-04-27/`. Combat and reward shots will show the largest deltas; UI/menu shots should be unchanged.

### Phase 5 — commit

Single commit: `art: upgrade character sprites to 256×256 native canvas`. Includes regenerated PNGs (7 dirs × ~17 frames = ~120 PNGs), `DefaultProfiles.json`, and this spec.

---

## Verification checklist

- [ ] Pilot hero strip at `http://localhost:8765/wu-clarity/` confirms 256 matches the reference's clarity at WU's on-screen size.
- [ ] All 7 characters regenerated at 256 with no missing frames.
- [ ] PNGs are exactly 256 × 256 with `hasAlpha: yes` (`sips -g pixelWidth -g pixelHeight -g hasAlpha`).
- [ ] `DefaultProfiles.json` updated with new `scale` (~1.6–1.8) and tuned `yOffset`. `weaponTipOffset` values stay unchanged.
- [ ] `./run.sh --reimport` clean.
- [ ] `./run.sh --test` passes (173+).
- [ ] Re-shoot of `10_combat_duel.png` shows visible character detail upgrade vs the 2026-04-27 baseline.
- [ ] `13_combat_boss.png` re-shoot still reads as a coherent boss arena (boss sprite at scale 1.775 should be the largest silhouette on screen).
- [ ] Two characters in the duel arena still fit horizontally at the new scale; no clipping or unwanted overlap.
- [ ] **Sub-pixel shimmer check.** With the pilot Hu at 256 native + `scale = 1.625`, run a captured walk + dash + camera-shake sequence and confirm pixel widths don't visibly twinkle/shimmer under motion. If shimmer is unacceptable, options: (a) snap `scale` to the nearest integer (e.g. 2.0 → larger character) and re-tune yOffset; (b) snap to a half-integer (e.g. 1.5) which keeps a uniform 1.5-pixel grain; (c) downscale the source canvas to a value that integer-divides into the viewport at the chosen scale. Document the resolution before Phase 2 batches all 7 characters.

---

## Out of scope

- Frame density per action (still 4 frames for attack, 4 for walk, 2 for idle/stunned, etc.). The user's separate aiexp track (reference-chained generation, more frames per action) addresses this independently of resolution.
- 256 for backgrounds — backgrounds stay 1920×1080 1:1.
- 256 for UI assets / fonts — those are not native pixel art; they render via Godot's vector pipeline with the CJK font theme.
- Refactoring `Fighter.half_width` or other gameplay constants — collision geometry is intentionally decoupled from visual scale.
- Per-archetype style direction (line weight, shading, palette accent variation). The reference is a single character's authoring style; matching it across all 7 archetypes consistently is a separate art-direction pass.

---

## What "done" looks like

A side-by-side of the same combat scene captured before and after this spec lands:
- Character cloak ripples, weapon grips, face wraps, hat textures all visible per character feature.
- Pixel grain reads as ~1.7 viewport-px per source-px — denser than the chunky milestone-1 look, matching the reference's texture density.
- Two combatants still readable at their gameplay distance; no readability regression.
- Game still runs at 60 fps with no performance impact (256 PNGs at scale 1.7 are still trivially small textures).

---

## Revision notes (rev 2, 2026-04-29)

Five review corrections after the rev 1 draft:

1. **`weaponTipOffset` direction was reversed.** Rev 1 said the offsets were source-pixel-space and asked for ×4. `fighter_visual.gd:276-280` reads them directly into a world-space `Vector2(facing * tip_distance, weapon_tip_offset.y)` added to `fighter.position` with no `* scale`. They're already in world/viewport space; multiplying ×4 would have moved trails 4× too far (Hu 76 → 304 wp = ~360 wp from body centre, well outside the screen at 1920 viewport). Rev 2 leaves the values unchanged.
2. **128 density math was internally contradictory.** Rev 1 said 128 renders at 1.7 px/source-px after a 3.5× scale — those numbers can't both be true. At scale 3.5×, 128 native gives 3.5 viewport-px per source-px (2× denser than 64, not 4×). Rev 2 corrects the table: 64 = 6.5, 128 = 3.25, 256 = 1.6. Rejection of 128 stands but the math now matches the actual screen-density delta.
3. **Frame-count contract was incomplete.** aiexp's `actions.yaml` defaults differ from WU's per-clip frame counts: block (3 vs 2), hit-react (3 vs 2), dash (4 vs 2). Without explicit handling, install would either drop frames silently or break on missing slots. Rev 2 adds a per-action mapping table and selects Option A (downsample at install) so existing animation JSONs stay drop-in.
4. **Time estimate was way under.** Pilot metadata showed 140–245 s per action at 256 native, not the 17 s typical at 64. Full 8-action × 7-character regen at parallel 4 is ~30–60 min, not 5–8.
5. **Fractional-scale shimmer wasn't acknowledged.** Rev 1 said nearest filter "reads crisp at any scale." Fractional scales (1.575–1.775) cause sub-pixel motion to render some source pixels as 1 vp wide and neighbours as 2 vp — shimmer under movement and camera shake. Rev 2 adds a verification item that captures motion and demands an explicit motion-shimmer assessment before Phase 2 commits.

---

## Revision notes (rev 3, 2026-04-29)

Five review corrections, all on issues rev 2 introduced or didn't fully clean up:

1. **Shimmer gate was not actually in the rollout order.** Rev 2 added the shimmer concern as a verification item but Phase 2 still ran the full 7-character regen first. Rev 3 inserts **Phase 1.5** (install pilot Hu only, rescale, run motion capture, decide) so a shimmer rejection costs 5 min of Hu rescale, not 60 min of full-batch regen.
2. **Verification checklist still said "4× weaponTipOffset".** Rev 2 corrected the migration table but missed the residual statement at the bottom checklist (line 176). Fixed: `weaponTipOffset values stay unchanged`.
3. **Phase 3 install text contradicted §3's downsample table.** "block/hit/stunned/dash/jump 1:1" was wrong for block/hit/dash. Fixed: explicit per-action mapping listing the downsample frames (block 1,3 / hit-react 1,3 / dash 1,4) and the 1:1 actions separately.
4. **Spec depended on `/tmp/install_regen_v2.py`.** Not in the repo, not reproducible. Rev 3 inlines the `sample_indices` algorithm directly into §3 (with worked-out indices for each downsampled action) and asks Phase 3 to write its own `tools/install_regen_256.py` in-repo using that contract. No `/tmp/` dependencies.
5. **"Three fields per profile" stale.** Rev 2 dropped weaponTipOffset from the rescale list but the §5 audit summary still said three. Fixed: "two fields per profile (`scale` and `yOffset`); `weaponTipOffset` stays unchanged."

---

## Revision notes (rev 4, 2026-04-29)

Two corrections to rev 3:

1. **Phase 1.5 was self-invalidating.** Rev 3 said "install pilot Hu's static + walk + 3-phase attack" but then asked the tester to run dash, idle, and camera-shake combat. The unmodified Hu clips reference idle_0..1, dash_0..1, hit_0..1, stunned_0..1, block_0..1 — those would still be 64-native PNGs rendered at the new `scale = 1.625`, appearing as tiny 100-vp-tall sprites alongside the 416-vp-tall 256-native walk and attack frames. The shimmer test would be useless against that resolution-mismatched backdrop. Rev 4 inserts a top-up regen step (idle + block + hit-react + stunned + dash + jump at 256 native) before the install, so the entire Hu set is at 256 during the test. Estimated extra time: ~20 min plus retries.
2. **Bracket pseudo-code in the shell example was copy-paste unsafe.** The `stunned[,dash,jump if hu]` form looks like a real command but isn't. Rev 4 splits the action list into two clean shell variables (`ACTIONS_BASE` for the 6 enemy archetypes and `ACTIONS_HU` for the player) so the example is paste-runnable.

---

## Revision notes (rev 5, 2026-04-29)

Two corrections:

1. **Jump-clip wiring drift.** Rev 4 said "jump / JUMPING (hu) — 3 frames 1:1." Verified against `WUGodot/assets/animations/character_hu.json`: the three jump PNGs are wired across three clips, not one — `JUMPING = jump_0, jump_1` (2 frames), `FALLING = jump_2` (1 frame), `LANDING = jump_2, idle_0` (2 frames). The install step's PNG copy is still 1:1 (`jump/frame_001..003 → jump_0..2`); the *clip* wording was misleading. Rev 5 reworded the §3 mapping table row and the §6 install bullet to make the PNG-vs-clip distinction explicit and call out that the clip wiring stays untouched (only the underlying PNGs change).
2. **`DefaultProfiles.json` path was unqualified.** First mention at §2 said only the bare filename. The actual file lives at `WUGodot/data/VisualProfiles/DefaultProfiles.json`. Rev 5 puts the full repo-relative path at the first §2 heading mention so implementers don't hunt or accidentally create a wrong sibling file.
