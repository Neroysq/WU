# aiexp feature request — video-first animation generation (`animate-video`)

**From:** WU project
**Date:** 2026-06-10
**Tool:** `aiexp sprite-extractor` (new command), `pixelforge` animation pipeline
**Builds on:** `2026-06-09-decouple-generation-and-pixelization.md` (smooth masters / deferred pixelize — the substrate) and `2026-06-10-pixelize-uniform-scale.md` (`--fit-mode exact` — what makes extracted frames texel-consistent for free). Partially supersedes the reference-frame color/build consistency report we owed you: this feature's reference-image conditioning is its strongest form; residual stills-side asks (e.g. re-toning existing frames) may still come separately.
**Prior art / feasibility demos:** "Seedance 2.0 效率拉满！我的全自动AI游戏动画生产流水线" (https://www.youtube.com/watch?v=WH2ZKtu5r74) and "工具链 — 游戏动画生产流水线" (ForFuner, https://www.youtube.com/watch?v=NnTKpF6Sm54) — fully automated Seedance-2.0-based game-animation pipelines of exactly this shape.

**TL;DR:** Generate an **entire action as one video** (character reference image + motion prompt, Seedance-2.0-class backend), then slice → re-key → emit frames as smooth masters. The decisive property: **frames from a single video are temporally coherent by construction** — same character, same lighting, continuous articulated motion. This collapses the entire per-still drift family we've been reporting (color-tone drift, build drift, scale drift, missing keyposes) into one solved-by-construction property, and makes **frame density a free sampling parameter** instead of a generation cost (a 4-keypose snappy clip and a 10-frame smooth clip from the *same* video).

---

## Motivation (what we learned the hard way)

WU's actions are 2–4 independently generated keyposes each. Smoothing and enlivening them has failed three ways:

1. **Per-still generation drifts**: across independent stills the character's color tone, build, and scale wander (all previously reported); key poses come out wrong (our windup frames read like strikes — twice).
2. **Runtime transforms** (offset/scale/rotation curves): shipped, play-tested, rejected — sustained non-integer scale breaks the texel grid, and rotating a rigid sprite reads as a cardboard cutout. Transforms are now restricted to masked transients.
3. **Optical-flow interpolation** (RIFE-class on masters): fine for cyclic small motion, fails exactly where it matters — large articulated deltas (a sword arc smears into soup).

Real *drawn* frames are the only channel that works, and a video model draws an entire action's worth of them **coherently** in one shot. The linked demos show this is practical end-to-end today.

## Why this belongs in aiexp rather than consumer scripts

The mechanics are your existing competencies: model-backend abstraction (capability registry), background removal (video output is RGB — every frame needs re-keying; you own remove-bg), run-dir layout, and per-frame sidecars (`bbox`/`foot_anchor`/`native_size`, post-0.10.0 semantics). Consumer-side we'd duplicate all of it badly.

## Proposed command

```bash
aiexp sprite-extractor animate-video <run> \
    --reference hu_static.png --action attack \
    --backend seedance --prompt "side view, static locked camera: a young wuxia swordsman coils low pulling his sword back, then thrusts fully forward, settles back to guard" \
    --duration 2.0 --keep all
```

1. Generate one video from the character **reference image** + motion prompt.
2. Re-key every frame (remove-bg), emit frames as **smooth masters** in the run dir (`<action>/masters/`) with standard sidecars (`bbox`, `foot_anchor`, `native_size` == PNG dims, `space: "image"`).
3. The consumer's existing scale-normalize → `pixelize --fit-mode exact` makes them texel-/palette-consistent — mid-video style softening is re-normalized by construction.
4. `--keep all` returns every frame; the consumer selects (see the selection note). Optional later: `--keep pose-progress:N`.

### Frame-selection note (important, easy to get wrong)

Game keyframes are **poses, not time-averaged samples** — they occupy unequal screen time, and motion is eased (a strike accelerates). Video output is uniform-fps; the *useful* frames sit at specific points of **pose progress**, bunched toward the slow end of each phase. Default must be `--keep all` + consumer-side selection; if you implement `--keep pose-progress:N`, select by motion energy/pose distance, never by uniform time.

### Requirements

- **Camera lock is a hard requirement.** Video models love to dolly/zoom; sprite extraction needs a static side-view camera. Prompt-enforce + verify in the tool (frame-to-frame background motion ≈ 0) + reject/retry on failure. A drifting camera poisons every downstream foot anchor.
- **Identity preservation.** *Within* one video it is largely free (temporal coherence). The remaining axes: mid-clip drift on long generations (keep actions ≤ a few seconds; surface per-frame outputs so consumers can reject drifted frames individually) and **cross-action consistency** (every action conditioned on the same reference image).
- **Loopable actions** (walk/idle): prompt for cyclic motion + trim-to-loop detection (first ≈ last pose) — even a heuristic saves consumers real work.
- **Sidecar correctness** per the 0.10.0 fixes: `native_size` == emitted PNG, one declared coordinate space.
- **Capability registry**: reference-image conditioning support, max duration/resolution/fps per backend (Seedance 2.0 lite/pro, Kling, etc.) — gate and document per model, as you do for image backends.
- **Seeds** where the backend supports them (determinism for re-runs is valuable, not assumed).

## Acceptance criteria (WU consumer)

`animate-video` for one full action (light attack, ~2 s) from Hu's reference image:

- produces re-keyed master frames that pass our existing gates unchanged: `MasterGeometry` resolves them, scale-normalize + `pixelize --fit-mode exact` yields texels at the same density as primary frames, foot anchors resolvable;
- the action arc contains a visually credible **anticipation** pose (sword pulled back, body coiled) — the pose our still-based generations have repeatedly failed to produce;
- static camera verified (no background drift);
- **frame-density freedom**: we can build both a 4-keypose clip and a 10-frame smooth clip from the *same* video, picking frames by pose progress;
- intra-action identity/tone stable by construction; cross-action consistency holds when two actions are generated from the same reference image.

## Priority (WU's perspective)

1. **`animate-video` with `--keep all` + sidecars + the camera-lock check** — the pipeline shape the linked demos prove out; it subsumes most of our open art problems (tone, build, missing poses, frame density) in one feature.
2. **Capability registry entries** for at least one Seedance-2.0-class backend with reference-image conditioning.
3. `--keep pose-progress:N` selection — nice-to-have once (1) proves out.

Meanwhile we may run a manual pilot (hosted Seedance endpoint + remove-bg by hand) to validate camera-lock and identity early; we'll share results.
