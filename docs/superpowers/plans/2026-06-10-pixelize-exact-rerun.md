# Pixelize `--fit-mode exact` Re-run (fix attack size-pop) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-run the Hu pipeline with aiexp's new `--fit-mode exact` (converter 0.7.0 / umbrella 0.10.0) so every frame shares one uniform scale — eliminating the "character suddenly bigger when attacking" pop — while **preserving Hu's current on-screen height** (354 px, parity with enemies) and re-syncing reach/balance to the now-true strike geometry.

**Architecture:** One constant change (`TARGET_TEXELS` 145 → **177**, because the current height parity rode the old content-fit inflation; with `exact`, T lands literally) → scale → pixelize `--fit-mode exact` → verify `scale_applied` identical across all sidecars + **master-derived per-frame height checks** (and no attack/heavy frame exceeding idle — hit-react legitimately may) → install (root anchors from the transform, never pixel-sidecar `foot_anchor`) → re-derive reach (expect a **drop** from 326/394 — those were derived from ~2× inflated strike frames) → enemy band re-sync (data-only, same recipe as the unsqueeze pass) → captures + playtest. `MasterGeometry`'s pixel-remeasure **stays** (archived pristine sidecars still carry the old lying `native_size`); the uniformity gate stays.

**Prerequisite:** `git pull` in AIexp (editable install — already live after pull). Archive at `~/WU-art-masters/wu-smooth-hu-run2`.

---

## Task 1: Retarget T + re-scale

- [ ] **Step 1:** In `WUGodot/tools/scale_masters.gd`: `TARGET_TEXELS: int = 177` (was 145), with a comment: `# 177 texels x R=2 = 354 px on-screen — height parity with enemy roster; chosen when fit-mode exact made T literal.`
- [ ] **Step 2:** Fresh scratch copy + scale. **Hygiene matters**: the archive contains stale pad-mode `pixelize/` outputs and sidecars, and the installer consumes whatever sits in each `pixelize/` dir — copy clean, then purge:

```bash
rm -rf /tmp/wu-exact-run
rsync -a ~/WU-art-masters/wu-smooth-hu-run2/ /tmp/wu-exact-run/
rm -rf /tmp/wu-exact-run/*/pixelize
./run.sh --scale-masters /tmp/wu-exact-run
```

Expected: `NOTE … pixel-remeasured` lines (old archived sidecars still lie — that fallback is load-bearing here), no uniformity violations, printed common canvas + `out-size W:H`. Canvas will be larger than 1484×720 (T grew 145→177, factor ×1.22) — record the printed out-size.
- [ ] **Step 3:** Commit the constant: `git add WUGodot/tools/scale_masters.gd && git commit -m "feat(pipeline): retarget T=177 for fit-mode exact (preserve height parity)"`

## Task 2: Pixelize exact + verify the new contract

- [ ] **Step 1:**

```bash
aiexp sprite-extractor pixelize /tmp/wu-exact-run --out-size <W>:<H> --palette vinik24 --fit-mode exact
```

- [ ] **Step 2: Verify aiexp's acceptance promises before installing** (don't trust, check):
  - every `pixel_NNN.json` has `scale_applied: [sx, sy]` with sx == sy, **identical across all ~29 frames** (one `python3`/`jq` pass);
  - **per-frame height check derived from the masters, not hardcoded ratios**: for each frame, expected texel height = `scaled_master_bbox.height × scale_applied` — assert the pixel sidecar/installed bbox matches ±2 texels. **This is the real gate.** (Probing showed the light strike is ~0.72× of idle, not the windup-derived 0.58× — don't pin pose ratios; derive them.)
  - Narrow secondary invariant: **no attack/heavy frame exceeds idle's height** — do NOT assert "idle is the tallest frame overall": hit-react is *legitimately* taller than idle (probed 156 vs 146 — raised-arms stagger pose), so the broad form fails a correct install;
  - `content_bbox == [0, 0, scaled_master_canvas_w, scaled_master_canvas_h]` — it is reported in **smooth master-canvas coordinates**, not output texels (probed: `[0,0,1484,720]` with `out_size=[371,180]`). "Full canvas" means the *input* canvas.
  - **Do NOT validate (or later use) the pixel sidecars' `foot_anchor`** — a disposable exact-mode probe showed `foot_anchor.x` spreading **125 px across frames** even with foot-centered input canvases. It is per-frame content-derived and unsafe for root placement; Task 3 derives the real anchors instead.

  Any deviation on the scale/height/bbox checks → stop, file the follow-up with aiexp (they asked), do not install.

## Task 3: Patch installer anchors, install, re-derive reach, band re-sync

- [ ] **Step 1: Patch `install_pixelized.gd` — anchors from the TRANSFORM, not pixel sidecars.** Today (`install_pixelized.gd:80`) it writes the pixel sidecar's `foot_anchor` into the manifest; with exact mode that value drifts ±125 px and would reintroduce horizontal lurch. Replace: read each frame's **scaled-master sidecar** (`<action>/masters/master_NNN.json` — `scale_masters` wrote `foot_anchor = [foot_canvas.x, foot_canvas.y]`, identical for all frames) and the pixel sidecar's `scale_applied`, then:

```gdscript
	# foot in output texels = master canvas foot × the uniform exact-mode factor
	var foot_px: Vector2 = Vector2(float(master_foot[0]), float(master_foot[1])) * float(scale_applied[0])
```

  Same transform for any other geometry the installer derives (`weaponTip`/`hurtbox` from the *measured installed pixels* stay as-is — they're per-frame content by design; only the **root/foot** must come from the shared transform).
  **Add a hard gate before writing anything:** computed `footAnchor.x` spread across all installed frames ≤ **1 texel** (it's a constant by construction; a violation means the transform assumption broke — abort install).
- [ ] **Step 2:** **First** clear `tools/hu_capsule_overrides.json` to `{}` if non-empty (anchors are moving again, and the installer applies overrides INTO the generated manifest — clearing after install would leave stale values baked in). Then `./run.sh --install-pixelized /tmp/wu-exact-run && ./run.sh --import && ./run.sh --anchor-sanity` — note the installer's `yOffset`, update `DefaultProfiles.json` if changed. (If overrides are ever cleared late by mistake: re-run the install — the manifest is generated, clearing alone doesn't regenerate it.)
- [ ] **Step 3: Reach probe — make it a tool, not folklore.** Add `WUGodot/tools/probe_hu_reach.gd` (SceneTree script) + a `run.sh --probe-reach` case: registers Hu with `PresentationCollision`, starts `hu_light`/`hu_heavy`, advances into active, prints `derived_reach`, the resulting `range_units = derived − 22`, and the **enemy band targets** (70–85% of light c2c with per-enemy half-widths 22/24/30 and the `preferredRange = shortest − half_width` rule). Then set `hu_light`/`hu_heavy` `range_units` in `Attacks.json` from its output. Expect a **decrease** vs 326/394 (true-scale strikes).
- [ ] **Step 4:** Enemy band re-sync from the probe's printed targets, same rules as the unsqueeze pass: scale enemy attack `range_units` so the band stays 70–85% of Hu light c2c (spearman top, swordsman bottom, assassin exempt); **recompute** `preferredRange = shortest attack − attacker.half_width` (22/24/30) — never multiply it.
- [ ] **Step 5:** Update the A1 goldens in `test_attack_data.gd` (hu_light/bear_crush_grab etc.) as deliberate balance edits. `./run.sh --test` → 0 failed.
- [ ] **Step 6:** Atomic commit: installer patch + probe tool + `run.sh` + sprites + manifest + `character_hu.json` + profiles + `Attacks.json` + `Enemies/` + goldens.

## Task 4: Verify the user-facing fix

- [ ] **Step 1:** `./run.sh --shot-combat /tmp/wu-exact-shots` → inspect: **attack/heavy strikes read as *lunges*** (lower and longer than idle — not inflated giants; hit-react being slightly taller than idle is correct, raised-arms pose); character scale identical across all 15 states; feet planted; capsule on the blade.
- [ ] **Step 2:** Play a few fights: the attack size-pop is gone; trades feel like the established balance (band ratios preserved by construction); one confirmation fight per archetype.
- [ ] **Step 3:** Final gates: `--test`, `--import`, `--anchor-sanity`, `git diff --check`.

## Notes / non-goals

- **Keep** `MasterGeometry` remeasure + uniformity gate (old archives lie; new generations won't — both guards are now cheap regression insurance, not dead code despite aiexp's note: their "safe to delete" assumes regenerated sidecars, ours are archived).
- **Exact-mode pixel sidecar `foot_anchor` is untrusted by policy** (probed: 125 px X-spread on foot-centered inputs). Root placement always derives from the scaled-master transform × `scale_applied`. Worth a one-liner in the next aiexp follow-up so they know that field is content-derived in exact mode.
- Block-frame **tone drift** is untouched by this pass — the reference-frame color/build consistency report to aiexp is the next artifact (they're expecting it).
- Enemy-roster rollout unblocks after this pass validates `exact` end-to-end on Hu.
