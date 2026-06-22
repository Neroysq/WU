# Handoff — Author the Venom Light Clip (Task 8, 5-keypose)

**To:** implementer · **Date:** 2026-06-22 · Gate-1 poses + scale **approved**.
**Goal:** make `venom_hu_attack_light` render the 5 approved keyposes (replacing the placeholder base-copy), so a Venom-light boon visibly changes Hu's light attack in-game.

Source art: `/tmp/venom_light_kf/K{1..5}_*.png`. Scales: see `2026-06-22-venom-light-install-spec.md`.

## 1. Install the pose art
- Copy the 5 approved PNGs into the repo, e.g. `WUGodot/assets/sprites/characters/hu/venom/venom_light_{windup_start,windup_peak,active,active_end,recovery}.png`.
- `./run.sh --import`.

## 2. Overlay manifest — `WUGodot/assets/animation_manifests/skins/venom.manifest.json`
Add 5 poses (this file is merged over the base manifest by `FighterPresenter._load_skin_manifest`). Per pose set:
- `path` → the installed PNG.
- `footAnchor` → the **true foot point** on the canvas (measure per pose with the existing anchor tooling; the presenter grounds by foot × scale, so this must be the real foot in source pixels).
- `weaponTip` → the blade-tip point (needed for the weapon-arc trail), especially far-forward on `active` / `active_end`.
- `hurtbox` → reuse the base light hurtbox proportions.

Pose names: `venom_light_windup_start`, `venom_light_windup_peak`, `venom_light_active`, `venom_light_active_end`, `venom_light_recovery`.

## 3. Variant clip — `WUGodot/assets/animation_clips/skins/venom/venom_hu_attack_light.timeline.json`
Replace the placeholder copy with the 5-keypose clip. Keep `"id": "venom_hu_attack_light"` and `"duration": "fromAttackDef"` (so it inherits hu_light timing). Map keyposes to the same phase anchors as base, and **encode the per-frame scale as `scaleX`+`scaleY` tracks** (the presenter scales about the foot, so grounding stays automatic — no image resizing, no stale-anchor float):

```json
{
  "id": "venom_hu_attack_light",
  "duration": "fromAttackDef",
  "useFighterOffset": true,
  "keyposes": [
    { "t": 0.00,          "pose": "venom_light_windup_start" },
    { "t": "windup_end",  "pose": "venom_light_windup_peak" },
    { "t": 0.42,          "pose": "venom_light_active" },
    { "t": "active_end",  "pose": "venom_light_active_end" },
    { "t": 0.80,          "pose": "venom_light_recovery" }
  ],
  "tracks": {
    "scaleX": [
      { "t": 0.00, "v": 0.875 }, { "t": 0.36, "v": 0.910 }, { "t": 0.42, "v": 1.023 },
      { "t": 0.60, "v": 0.845 }, { "t": 0.80, "v": 0.970 }
    ],
    "scaleY": [
      { "t": 0.00, "v": 0.875 }, { "t": 0.36, "v": 0.910 }, { "t": 0.42, "v": 1.023 },
      { "t": 0.60, "v": 0.845 }, { "t": 0.80, "v": 0.970 }
    ],
    "smear": [ { "t": 0.38, "v": 0.0 }, { "t": 0.46, "v": 1.0 }, { "t": 0.64, "v": 0.0 } ]
  },
  "events": [
    { "t": "windup_end", "event": "attack_active_start" },
    { "t": "active_end", "event": "attack_active_end" }
  ]
}
```
(0.36 / 0.60 are windup_end / active_end as a fraction of the 0.5s hu_light duration; keep the string anchors on the keyposes/events so they track the real attack def.)

## 4. Verify
- `./run.sh --import && ./run.sh --test` → `failed: 0` (existing move-skin tests still pass; the clip is now real, not a base copy).
- **Visual-diff gate (plan Task 8 Step 4):** capture a Venom-light **active** frame and a base-light active frame; they must now **differ** (`cmp` exit 1) — the bespoke clip is showing, not just the recolor. Also re-confirm determinism (same spec twice → `cmp` 0). Use the Task-7 capture flow (`./run.sh --capture <spec.json>` with `build:[{"boon_id":"venom_light","tier":"common"}]`, `state:"04_light_active"`).
- Sanity: foot stays grounded across all 5 poses; character size reads consistent with idle.

## 5. Gate 2 — ✋ STOP
Run the game with a Venom-light boon equipped; capture/record the light attack in motion. **Report to the user** (in-game shots + the diff-vs-base capture) for Gate-2 approval before moving to heavy → dash.
