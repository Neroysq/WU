# Combat Set Install — rev 3 (FINAL, full-density, orientation reverted)

**Date:** 2026-07-09 · Supersedes rev 2 and the flip spec's mirrored-install steps.
**Everything user-approved.** Provenance: `art/canon/canon.manifest.json`.

## What ships
- **6 clips, 97 frames each** at `art/canon/hu/clips/{attack_light, attack_heavy,
  guard_deflect, dash, jump, entry}/f%03d.png` — FULL DENSITY on purpose: timelines
  subsample freely to hit any speed; do NOT install all 97 as keyposes (pick per
  phase; a 12–20 frame timeline is typical; keep the option to re-pick later).
- **6 held statics** at `art/canon/hu/held/`: hit, stun_a, stun_b, relaxed, fall, land —
  replace vp_hit / vp_stun_a/b / vp_fall / vp_land; `relaxed` is the entry-draw start
  and future out-of-combat idle.
- Pins k1–k7 (reference/provenance; k1 = idle base).

## Orientation: REVERTED to original (this supersedes the player-right install)
- Player spawns LEFT, `facing = 1`; enemy RIGHT, `facing = -1` (combat_setup.gd,
  capture setups — undo the flip commit's spawn changes).
- ALL art is right-facing native. **No mirroring anywhere at install.**
- `nativeFacing`: set hu.manifest.json back to `1` (keep the mechanism — it's harmless
  and future-useful). Player renders unflipped when facing right; the existing runtime
  flip handles facing-left moments exactly as pre-flip.

## Install mechanics
- Targets: BASE `assets/animation_manifests/hu.manifest.json` + the base clip
  timelines it references (NOT skins/). entry_draw replaces the vd_* sequence
  (main.gd COMBAT_ENTRY prep).
- Use `tools/install_raw_frames.gd` (`./run.sh --install-raw-frames`) — frames are
  256×256, content bottom-anchored y=246, x-centered; footAnchor from content bbox;
  weaponTip needed on attack ACTIVE keyposes only (steel-extreme heuristic + per-clip
  override file, as built).
- Timelines: phases per rev 2 §6 (events, fromAttackDef, smear track over heavy's
  strike). Deflect hold-loop = the braced mid segment. Idle = k1 static; walk pins
  to k1 (regen later if needed).

## Verify (exact)
1. `./run.sh --import && ./run.sh --test` → failed: 0 · `./run.sh --anchor-sanity`.
2. `./run.sh --shot-combat` → player LEFT facing RIGHT, blade viewer-side; hit/stun/
   fall/land show the NEW held poses (no old-era Hu anywhere).
3. Matchup capture w/ build (spec file per run.sh:141): blade length equal across
   action frames; sword never changes hands; entry draw plays at combat start.
4. In-game scale vs idle + head-size constancy spot-check (~10%).

## Addendum (2026-07-10, final harvests — supersedes the 256×256 frame contract)

- Clips are now **variable-canvas envelope frames** (light 471×257 · heavy 325×320 ·
  deflect 253×229 · dash 304×229 · jump 249×319 · entry 257×309), spatially
  REGISTERED: the character holds one position across a clip's frames; only the
  pose moves. Nothing is cropped.
- `install_raw_frames.gd`: compute footAnchor from content bbox per frame as
  specced — do NOT assume 256×256 or bottom-anchored-at-246; use each frame's
  actual content. Spatial registration means anchors will be consistent within
  a clip by construction.
- **Heavy recovery**: the source jump-cuts from the low chop to guard (~2
  frames). ACCEPTED by the user — the timeline should ease/hold across that
  transition rather than expecting smooth source frames.
- White impact flash (≤2 frames, light clip) is §3c-compliant; keep.
