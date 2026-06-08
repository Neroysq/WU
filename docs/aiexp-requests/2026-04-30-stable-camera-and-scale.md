# aiexp feature request — stable camera, stable per-frame scale, edge-clip avoidance

**From:** WU project
**Date:** 2026-04-30
**Tool:** `pixelforge-sprite` / `aiexp sprite-extractor animate`
**Context:** WU regenerated all 7 character archetypes at 256-px native canvas. The visual jump is excellent, but two AI-pose-consistency problems and one canvas-composition problem make per-frame foot-anchoring and same-scale animation expensive to fix downstream. This request bundles four related improvements that would let a consumer drop sprite sheets into a game without per-frame post-processing.

Evidence is from the 124-frame WU sprite set generated against `openai/gpt-5.4-image-2` at `--size 256`. Comparison page at `http://localhost:8765/wu-frames-compare/`.

---

## Problem 1 — Camera height drifts across frames within an action set

### What we observe

Within a single archetype's action set, the AI generated frames at wildly different vertical positions inside the 256 × 256 canvas. Measured eroded-bbox `padB` (pixels of empty space between silhouette bottom and canvas bottom) for Hu:

| frame | padB |
|---|---:|
| `static.png` | 19 |
| `idle_0.png` | 35 |
| `walk_0.png` | 51 |
| `walk_2.png` | 51 |
| `attack_0.png` (windup) | 42 |
| `attack_2.png` (strike) | 66 |
| `hit_0.png` | 39 |
| `dash_0.png` | 57 |

Same character, same prompt, same model. The "ground" in the generated image moves up and down by ~50 source-pixels frame-to-frame. After upscaling at the consumer's runtime scale (1.625× for Hu), that's an **80 viewport-pixel float drift** across the animation set.

### Why it matters for consumers

Game engines render sprite frames against a fixed ground line. If the AI doesn't keep "where the feet are" stable across frames, every consumer must compute per-frame `offset.y` corrections by measuring eroded silhouette bboxes. Even with that, fringe pixels and pose ambiguity (is this frame's bbox-bottom a foot, or a trailing leg/staff?) introduce errors. The right place to fix this is in generation, not post-processing.

### Proposed feature: `--anchor-frames` flag

Add a flag to `aiexp sprite-extractor animate` (and the underlying `pixelforge.sprite.api` calls) that injects the following constraint into every frame's prompt:

```
The character's feet must rest on the same horizontal line in every frame.
That line is at vertical pixel ROW 240 of a 256-pixel canvas.
The space below pixel ROW 240 must remain empty (background) in every frame.
```

The exact line position would be parameterised:

- `--anchor-line-pct 0.93` (default) → feet at 93% from the top of the canvas, i.e., row 238 of 256.
- `--anchor-line-pct 0.5` for action games where mid-canvas anchoring works better.

This gives consumers a known foot-position contract. Per-frame `offset.y` becomes zero across the entire action set; jumps and dashes can opt out by skipping clips at the consumer side (already supported by the consumer's animation system).

### Out of scope for this request

- Frames intentionally airborne (jump apex, dash mid-flight). Consumers can skip those at install time.
- Multi-character sheets (a future feature; for now one character per generation).

---

## Problem 2 — Character scale drifts across frames within an action set

### What we observe

Same-archetype, same-prompt frames have eroded-bbox **height** ranges of 100–125 source-px, meaning some frames are roughly **2× taller** than others:

| character | bbox h min | bbox h max | range | screen drift at runtime scale |
|---|---:|---:|---:|---|
| hu | 110 | 214 | **104** | ~169 vp |
| bandit_sword | 131 | 232 | **101** | ~164 vp |
| bandit_spear | 128 | 240 | **112** | ~182 vp |
| ronin | 109 | 232 | **123** | ~200 vp |
| disciple | 116 | 235 | **119** | ~193 vp |
| assassin | 132 | 243 | **111** | ~180 vp |
| iron_bear | 178 | 224 | **46** | ~75 vp |

iron_bear is notably more consistent than the others — possibly because the boss prompt's "massive frame, bare chest under open robe, iron staff held horizontal across shoulders" pinned proportions. The implication: prompts can absolutely keep scale stable, but only if the prompt forces it.

### Why it matters

Even with foot-anchor normalisation, characters appear to **shrink and grow during animation**. Walking Hu visibly loses ~80 viewport-pixels of height between frames. There is no way for the consumer to compensate without resampling individual PNGs, which destroys the pixel-art feel under nearest-neighbour rendering.

### Proposed feature: `--first-frame-as-reference` flag

Add a flag that:

1. Generates the first frame (`idle_0` by default) at the requested size and canvas.
2. Measures the eroded bbox of that frame.
3. **Injects the measured bbox into every subsequent frame's prompt** as a target:

   ```
   The character's silhouette in this frame must occupy the same pixel
   height as the reference frame: HEIGHT pixels tall, top of head at row
   TOP_ROW, feet at row BOTTOM_ROW. Adjust pose to fit within those rows.
   The character must NOT be larger or smaller than the reference.
   ```

4. Optionally pass the reference frame as a multimodal-image input (most modern image models accept it; gpt-5.4-image-2 does), which is a stronger signal than text alone.

This is "reference-chained generation" with the chain rooted at idle. Combined with Problem 1's anchor line, it eliminates both float and scale drift in one pass.

### Default behaviour

Off by default to preserve current behaviour. When on, latency grows by one extra serial generation (idle first, then the rest in parallel). Acceptable for the use case.

---

## Problem 3 — Multimodal text output as a per-frame metadata channel

### What we observe

Modern image models (gpt-5.4-image-2, Imagen 3, etc.) can return both text and image content in a single response. We're currently asking only for the image and dropping any incidental text.

### Why it matters

If the model can describe what it generated — bbox of silhouette, claimed scale, claimed floor level, pose tag — we get a strongly-typed metadata channel that doesn't require post-process bbox detection. Eroded bbox + connected components + heuristics for "where the feet really are" can all be replaced by structured model output.

### Proposed feature: `--ask-metadata` flag

When set, append to the prompt:

```
After producing the image, output a JSON object describing the result:
{
  "silhouette_bbox": [left, top, right, bottom],
  "feet_row": <row index where feet rest>,
  "head_row": <row index of top of head>,
  "pose_tag": "<idle|windup|strike|recover|stagger|fall|...>",
  "confidence": <0..1>
}
```

Persist the JSON next to the PNG in the run dir. Consumers (and the existing `pixelforge.sprite` runner) can then trust the metadata over their own bbox heuristics.

This complements Problems 1 and 2 — the model self-reports whether it actually anchored at the requested line, which lets the runner verify or auto-retry.

### Risks

- Model may hallucinate bboxes that don't match the actual image. Need a verification pass (eroded-bbox cross-check) before trusting.
- Adds a few hundred output tokens per frame.
- Some models don't reliably produce both image and JSON in a single response. Test per-model and gate behind a capability registry.

---

## Problem 4 — Canvas-edge clipping for extended poses (attack lunges)

### What we observe

Attack-strike frames where the character is "fully extended past the frame edge" (which is what we explicitly prompted for) come back with arms, weapons, or trailing limbs **clipped at the 256-px canvas edge**. The character literally cannot extend past the canvas because the canvas is the model's rendering rectangle.

Observed in WU:

- `bandit_spear/attack_2.png`: spear tip clipped at right edge.
- `iron_bear/attack_2.png`: staff swing arc cut off.
- `hu/attack_2.png`: blade is at the canvas edge with no ink past it.

### Why it matters

A "fully extended strike with weapon past the frame" is genuinely the right pose for combat-feel telegraphing. Clipping it neuters the pose. Consumers either accept the clip or paint the missing weapon tip themselves.

### Proposed feature: `--wide-canvas-for-actions` flag

Allow the consumer to specify a wider source canvas for specific actions (or for "extension-prone" actions by default) and have the splitter understand that. For example:

- Idle / walk / block / hit-react / stunned: 256 × 256 (current).
- Attack-strike, attack-recovery, dash: **384 × 256** or **256 × 256 with the character horizontally centred and 64 px of "extension space" reserved on each side**.

The consumer's animation JSON would need a per-frame `frame_width` field (the existing offset already handles per-frame offsets) — modest schema change.

Alternative simpler form: keep canvas square but **shrink the character's static idle so it occupies only the centre 60% of the canvas**, leaving 20% margin on each side. Lunge poses then fit within the canvas. This is a prompt-only change (no schema change) but reduces effective resolution per frame by ~40%.

### Recommendation

Ship the static-shrink form first (prompt change only). It's free; it costs character density. If the density loss is unacceptable, follow up with the per-frame variable-width canvas.

---

## Priority ranking (WU's perspective)

1. **Problem 1 (camera height) and Problem 2 (scale)** are the highest impact. They produce immediate, visible improvement in animation quality with no asset rework. Both can be implemented as prompt-engineering features without changing the model or schema. Estimated payoff: eliminates the per-frame `offset.y` and per-frame scale-fudge that consumers currently need.
2. **Problem 4 (canvas clipping)** is the next-highest visual-quality win for any action-game consumer.
3. **Problem 3 (model-output metadata)** is the strongest long-term lever — it converts a fragile bbox-detection problem into a structured-data problem — but requires per-model capability testing and verification logic. Defer until after 1+2 ship.

---

## Acceptance criteria for the WU consumer

When these features land, the WU regen pipeline should be able to:

- Run `aiexp sprite-extractor animate ... --anchor-line-pct 0.93 --first-frame-as-reference --ask-metadata`
- Drop the resulting PNGs into `WUGodot/assets/sprites/characters/{archetype}/` with **all per-frame `offset.y` set to zero in the animation JSONs**.
- See feet planted on the ground line and consistent character height across every non-jump action.
- Skip the current eroded-bbox post-processing in `tools/install_regen_256.py`.

We'd file follow-up bug reports if any of those properties don't hold for our 7 archetypes.
