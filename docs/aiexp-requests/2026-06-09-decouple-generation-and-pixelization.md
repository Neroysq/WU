# aiexp feature request — decouple generation from pixelization (smooth master → scale-normalized pixelize)

**From:** WU project
**Date:** 2026-06-09
**Tool:** `aiexp sprite-extractor` / `pixelforge.sprite.api`
**Builds on:** `docs/aiexp-requests/2026-04-30-stable-camera-and-scale.md` (anchor line, first-frame-reference, ask-metadata, wide-canvas). This request **generalizes and largely supersedes** that one by moving scale/anchor normalization into a deterministic pixelize stage.

**Context:** WU finished an animation-system revamp (foot-anchored presenter, authored capsule collision, measured anchors). In playtest we hit a wall that cannot be fixed on the consumer side: the AI generates each pose **at a different character scale / source resolution**, so the character visibly grows and shrinks between frames, and the pixel-art texel size is inconsistent across the animation. The root cause and why consumer-side fixes fail are documented below; the proposed fix is a two-stage pipeline: **generate a non-pixelized master at the required aspect ratio, then pixelize separately with explicit scale normalization.**

---

## Background — why the consumer cannot fix this

WU's Hu light-attack clip uses four frames. Measured silhouette heights (256-px canvas, eroded bbox, source px):

| pose | source PNG | silhouette h | torso w | notes |
|---|---|---:|---:|---|
| idle (guard) | `idle_0.png` | 179 | 58 | reference |
| windup | `attack_1.png` | 182 | 75 | consistent with idle |
| **strike** | `attack_2.png` | **117** | 76 | **character drawn ~smaller**; blade tip at x=247/256 |
| recover | `attack_3.png` | 160 | 55 | |

At the consumer's render scale (×1.625) the character's on-screen height swings from ~291 px (idle) to ~190 px (strike) — a **36% size pop mid-attack**. Inspecting the art confirms the strike frame draws the *whole character smaller* (smaller head and body), not just a lunge crouch. The model shrank the character so the fully-extended lunge+blade would fit inside the 256-px canvas (the canvas-clipping pressure from the 2026-04-30 request, Problem 4).

We tried to correct this at runtime with a per-pose scale-up (`scaleNorm`). It fails the requirements:

- **Scale up the small frame** → on-screen *size* matches, but its texels become ~25% larger than the other frames → **pixel resolution no longer matches** across the animation (chunky strike). You cannot invent the missing texels.
- **Leave it** → texels match, character looks small.
- **Scale everything else down to match** → pixels match but the character shrinks overall and the good frames lose detail.

**Key conclusion:** *consistent on-screen character size* and *consistent texel resolution* cannot both be obtained at runtime from frames that were drawn at different source resolutions. They are the **same root cause** — inconsistent source resolution — and must be fixed before the asset is pixel art. The clean place to fix it is a high-resolution master plus a controlled pixelize step.

---

## Proposed pipeline

```text
generate (non-pixel)            pixelize (deterministic)
   smooth master                  scale-normalized, palette-locked
   at required ratio      ─────▶   → game-ready pixel frames + metadata
```

Generate once (smooth, full detail, correct framing); pixelize many times to whatever target resolution the game needs. Because normalization happens on the **hi-res master**, scaling a too-small pose up is **lossless** (downsampling from detail, not upscaling pixels), so every output frame can be mapped to the **same character texel size**.

---

## Feature 1 — `generate` a non-pixelized master at a target ratio

Add a generation mode (e.g. `--no-pixelize` / `--render-mode=smooth`) that returns a **high-resolution, non-pixel-art** master per pose.

Requirements:

- **No pixelization / palette quantization** at this stage — full-detail raster (the model's native smooth output).
- **`--canvas-ratio W:H`** (and/or `--canvas-size`) so extension-prone actions (lunges, sweeps, weapon throws) are generated on a **wider canvas** and never shrunk to fit. Per-action ratios should be allowed (idle 1:1, strike 3:2, etc.).
- **Consistent framing intent:** the character should be generated at a consistent *intended* scale across poses. A reference frame input (`--first-frame-as-reference`, from the 2026-04-30 request) helps, but is **not required to be perfect** — the pixelize stage corrects residual scale drift losslessly (see Feature 2). This is the main reason the two-stage split is robust.
- **Optional `--emit-master-metadata`:** alongside each master, output JSON describing it (reusing the 2026-04-30 ask-metadata schema): `silhouette_bbox`, `feet_row`, `head_row`, `weapon_tip`, `pose_tag`, plus a **`character_scale_hint`** (e.g. measured head height or shoulder width in master px) the pixelize stage can use as the normalization reference.

Output: one smooth master PNG per pose (+ optional metadata JSON), in the run dir.

---

## Feature 2 — `pixelize` (separate, deterministic, scale-normalized)

A standalone command (e.g. `aiexp sprite-extractor pixelize <master-dir> --target-height N ...`) that converts smooth masters into game-ready pixel frames. This is where scale + anchor normalization lives.

Parameters:

- **`--target-character-height N`** (texels) — the on-screen character height in target pixels. The pixelize step scales **each master so the character maps to exactly N texels**, using a pose-invariant reference (the master metadata's `character_scale_hint`, e.g. head/shoulder size — *not* silhouette height, which changes with pose). **This is the contract that guarantees consistent character size AND consistent texel size across every frame.**
- **`--anchor foot|center`** + emit the resolved **`footAnchor`** per output frame so the consumer grounds frames without re-measuring.
- **`--palette <vinik24.hex|path>`** — lock output to a fixed palette (WU uses VINIK24, 24 colors).
- **`--downscale area|nearest`** + **`--edge-cleanup`** (preserve outlines, avoid mushy edges) + optional **`--dither <none|bayer|...>`**.
- **`--out-canvas WxH`** — final per-frame canvas; the step crops/centers around the anchor, with enough margin that scaled extended poses (long blades) are not clipped.

Output per frame:

- the pixel-art PNG at the target resolution, character at exactly `--target-character-height` texels, palette-locked;
- a metadata JSON: `footAnchor`, `weaponTip`, `headRow`, `bbox`, `character_height_px` (== N for all frames), so the consumer can trust anchors and assert consistency.

**Determinism:** same master + same params → byte-identical output (so pixelize can run in CI / be re-run when target resolution changes).

---

## The normalization contract (the crux)

For a set of poses sharing a `setId`, after pixelize:

1. **Character texel height is identical** across all poses (== `--target-character-height`). → no size pop, no pixel-resolution mismatch.
2. **Foot anchor is grounded and reported** per frame. → consumer sets per-frame `offset` to zero.
3. **Pose variation is preserved** — only *character scale* is normalized (via the pose-invariant reference), never the pose. A lunge stays a lunge; it is just drawn at the correct character scale on a wide-enough frame.
4. **Extended poses are not clipped** — wide master ratio + adequate `--out-canvas` margin.

This makes the consumer trivial: drop frames in, all per-frame `offset`/`scaleNorm` corrections become identity, render every frame at one integer scale.

---

## Why this supersedes the per-frame workarounds

The 2026-04-30 request asked the *generator* to hold scale/anchor stable per frame (hard for a diffusion model to do perfectly). This request instead **lets generation be imperfect** and fixes scale/anchor **deterministically at pixelize time on hi-res input** — which is both more reliable and re-targetable. The 2026-04-30 anchor-line / first-frame-reference / wide-canvas features remain useful as *inputs* that make the masters closer to consistent, reducing how much the pixelize stage must correct.

---

## Risks / open questions

- **Pixelize quality is the make-or-break.** Naive area-downscale of smooth AI art is not good pixel art; the step needs palette quantization + contrast/edge handling + outline preservation, and may still want optional manual touch-up. This is the bulk of the work; everything else is plumbing.
- **Pose-invariant scale reference.** `character_scale_hint` must be something stable across poses (head/shoulder), not silhouette height. If the model can't emit it reliably, the pixelize step needs its own robust estimator (or a per-pose override).
- **Per-model capability.** Smooth-master quality and metadata reliability vary by model; gate behind a capability registry as the 2026-04-30 request notes.

---

## Acceptance criteria for the WU consumer

When these land, WU's regen pipeline should be able to:

- `aiexp sprite-extractor generate ... --render-mode=smooth --canvas-ratio 3:2 --emit-master-metadata` for extension-prone actions, 1:1 for idles.
- `aiexp sprite-extractor pixelize <run> --target-character-height 160 --anchor foot --palette vinik24 --edge-cleanup --out-canvas 256x256`.
- Drop the pixelized frames into `WUGodot/assets/sprites/characters/<id>/` with **every frame's character at the same texel height** and **`footAnchor` provided per frame**.
- See **no size pop and no pixel-resolution change** across an action (idle/walk/attack), with extended strikes un-clipped.
- Delete the consumer-side `scaleNorm` idea entirely and set all per-frame `offset` to zero.

We'll file follow-up bugs if any of those properties don't hold across WU's 7 archetypes.

---

## Priority ranking (WU's perspective)

1. **Feature 2 `pixelize` with the scale-normalization contract** — the core fix; it is what makes character size *and* texel resolution consistent. Highest impact.
2. **Feature 1 smooth-master generation at target ratio** — needed to feed Feature 2 losslessly and to stop canvas-clipping-driven shrinkage.
3. **`character_scale_hint` metadata** — strongest reliability lever for the normalization; can start with a consumer-side estimator and move upstream later.
