# aiexp bug report / feature request — pixelize rescales per frame (breaks cross-frame character scale) + master sidecar `native_size` mismatch

**From:** WU project
**Date:** 2026-06-10
**Tool:** `aiexp sprite-extractor pixelize` (Problem 1), smooth-master sidecars from `--render-mode smooth` (Problem 2)
**Builds on:** `2026-06-09-decouple-generation-and-pixelization.md` (shipped — thank you; the smooth-master + deferred-pixelize flow is now WU's production pipeline). This report covers two correctness issues we hit in production with that flow, with measured evidence.

**TL;DR:** `pixelize` does not perform the uniform input-canvas → `--out-size` downscale we (and, we believe, the flag semantics) imply — it appears to rescale **each frame relative to its own content**, which silently destroys any cross-frame character-scale normalization the consumer performed on the masters. In-game result: the character visibly **grows ~2× when attacking**. Separately, smooth-master sidecars report a `native_size` that does not match the emitted PNG, which earlier caused a ⅔-width horizontal squeeze in our consumer tooling.

---

## Problem 1 — `pixelize` rescales per frame (content-dependent), not uniformly

### Our setup (the documented two-stage flow)

1. We scale-normalize every smooth master ourselves so the **character** has a consistent smooth-pixel height across all frames (idle reference → all frames scaled by one scalar), foot-aligned on a **common canvas**: all 25 Hu frames at exactly **1484×720**, character heights: standing idle ≈ **580** smooth px, deep attack lunge ≈ **336** smooth px (a lunge is genuinely shorter than standing — that difference is the *pose*, and preserving it is the point of normalization).
2. One pixelize call for the whole run:

```bash
aiexp sprite-extractor pixelize <run> --out-size 371:180 --palette vinik24 --fit-mode pad
```

`1484×720 → 371:180` is exactly **4:1 in both axes**, so a uniform mapping is fully determined: every frame's character should land at `smooth_height / 4` texels.

### What we expected vs what we got

| frame | character in master (smooth px) | expected at uniform 4:1 (texels) | actual output (texels) | applied factor |
|---|---:|---:|---:|---:|
| idle (standing) | 580 | 145 | **177** | ~1/3.27 (×1.22 vs uniform) |
| attack strike (deep lunge) | ~336 | ~84 | **176** | ~1/1.9 (×2.1 vs uniform) |
| heavy strike (deep lunge) | ~336 | ~84 | **176** | ~×2.1 vs uniform |

Output canvases are the requested 371×180 for every frame — but the **content scale differs per frame**. The numbers are consistent with pixelize cropping each frame to its own content and fitting that content into the out-size (`min(out_w/content_w, out_h/content_h)`-style), rather than mapping the input canvas onto the out-size with one factor.

### Why this matters

- It **silently undoes consumer-side scale normalization**. The 2026-06-09 update's contract was "you own scale … pixelize the same masters at different sizes"; per-frame content-fit makes the consumer's scale ownership impossible — whatever we normalize on the masters, the output scale is re-decided per frame by that frame's silhouette extent.
- The artifact is severe and player-visible: a deep lunge (geometrically ~0.58× standing height) renders **as tall as standing**, so the character appears to suddenly inflate ~2× during attacks. Playtest feedback verbatim: *"when attacking, the character feels suddenly bigger than idle."*
- It is invisible on action sets whose frames have similar content extents (our first install "merely" came out 22% larger than requested, uniformly enough to miss) and explodes the moment poses diverge (wide lunges) — i.e., exactly when sprites get good.

### Evidence

We built a side-by-side evidence page from the production run (input master at ½ for inspection; the same master at ÷4 = expected uniform output; the actually-installed sprite at 1:1, equal pixels-per-texel, bottom-aligned): generated from `~/WU-art-masters/wu-smooth-hu-run2` + the fixed scale step, served locally (`/tmp/wu-pixelize-evidence`, http://localhost:8765). Screenshots available on request; the cross-frame strip (idle vs strike at 1:1) makes the inflation unmistakable.

### Proposed fix / feature

1. **`--fit-mode exact`** (or make this the meaning of the existing `pad` when `in_canvas : out_size` is an integer or rational ratio): map the **input canvas** onto `--out-size` with a single uniform factor for **every frame in the run**, no content crop, no per-frame fit. This is the mode a scale-managing consumer needs; per-frame content-fit can remain as an explicit opt-in (`--fit-mode content`).
2. **Document the fit semantics** of each `--fit-mode` (what is cropped, what is fit, per-frame or per-run).
3. **Emit the applied scale factor in every `pixel_NNN.json` sidecar** (e.g. `"scale_applied": [sx, sy]`, plus the content-crop rect if any). Even before #1 ships, this lets consumers detect/compensate; after it ships, it lets them verify.

### Consumer-side workaround (what we'll do meanwhile)

Stamping opaque marker pixels at the canvas corners of every master so each frame's "content" equals the full canvas (forcing the per-frame fit to be identical), stripping the markers post-install. It works but is exactly the kind of hack the two-stage design was meant to eliminate.

---

## Problem 2 — smooth-master sidecar `native_size` does not match the emitted PNG

### What we observe

Masters generated via `--render-mode smooth` are **1536×1024** PNGs, but their sidecars report:

```json
"native_size": [1024, 1024]
```

while the sidecar `bbox` appears to be in **actual PNG pixel space** (its values are only consistent with the 1536-wide image). So the sidecar is internally inconsistent: `native_size` describes some pre-resize intermediate; `bbox`/`foot_anchor` describe the final image.

### Why it matters

Any consumer that trusts `native_size` for geometry math inherits a hidden **1024/1536 = 0.667 horizontal factor**. In WU this produced a ⅔-width squeeze of every installed frame (the player character looked anorexic next to enemies) that took a multi-step diagnosis to trace, precisely because every downstream stage was consistent with every other — only the sidecar-vs-PNG comparison exposed it. We've hardened our tooling (image dims win; geometry remeasured from pixels when the sidecar disagrees), but the sidecar should simply be correct.

### Proposed fix

- `native_size` must equal the emitted PNG's dimensions, and `bbox`/`foot_anchor` must be in that same space (one coordinate system per sidecar, stated in the sidecar, e.g. `"space": "image"`).
- If intermediate render sizes are worth reporting, put them under a distinct key (`"render_size"`), never as `native_size`.

---

## Acceptance criteria for the WU consumer

With both fixes, re-running our production pipeline unchanged (common canvas 1484×720, `--out-size 371:180`, `--fit-mode exact`):

- every frame's character height lands at `smooth_height / 4` texels (idle 145 ± 1, lunge ~84 ± 1) — i.e., **the standing pose is the tallest frame again**;
- one `scale_applied` value, identical across all 25 sidecars;
- master sidecars: `native_size` == PNG dims for every master;
- our corner-marker workaround and pixel-remeasure fallbacks become dead code we can delete.

## Priority (WU's perspective)

1. **Problem 1 / `--fit-mode exact`** — blocks correct character scale in any multi-pose action set; we currently cannot use pixelize as the scale-preserving stage the 2026-06-09 design intended.
2. **Problem 1 / `scale_applied` sidecar field** — cheap, immediately enables detection/compensation.
3. **Problem 2 / sidecar `native_size`** — one-line class of bug on your side, multi-day diagnosis class of bug on the consumer side.

Separate follow-up (not this report): reference-frame conditioning for color-tone and build consistency across generated frames — we'll file it independently.
