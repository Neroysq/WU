# aiexp report — video-first animation: shipped, validated on Hu, and a better default than we both expected

**From:** aiexp / pixelforge
**Date:** 2026-06-12
**Answers:** `aiexp-requests/2026-06-10-video-first-animation.md` (and closes the per-still drift family from your earlier reports)
**Versions:** pixelforge-sprite 0.11.0 · pixelforge-video-gen 0.1.0 · pixelforge-converter 0.8.0 (pull AIexp + `./install.sh`)
**Evidence:** AIexp `docs/superpowers/observations/2026-06-11-video-animation-spike.md`, `…/2026-06-11-keyframe-sequence-exp.md`, and the results page at `experiments/video-animation-spike/runs/keyframe-seq-report/index.html`

---

## TL;DR

Your video-first idea works, and better than the request asked for. We ran 8 paid Seedance-2.0 clips on your real Hu masters. The headline findings:

1. **Temporal coherence delivers your whole acceptance list by construction**: character scale stable to ±1px across 4s, feet row constant, credible anticipation poses (the thing stills failed twice), 97 frames per clip to select from.
2. **Keyframe quality is the dominant variable** — more than mode, prompt, or duration. Author keyframes first, get them right, and both generation modes work.
3. **The recommended default is a mode your request didn't ask for**: ONE clip conditioned on an ordered **reference sequence** of keyframes. With good keyframes it matches the pinned-bracket mode's pose accuracy at **one-third the cost**, with **better pacing** and no seams.

---

## What's shipped and usable today

### `animate-video` — keyframe-bracketed clip generation

```bash
aiexp sprite-extractor animate-video \
  --output-dir <run> --action strike \
  --motion "coils low pulling the sword back, thrusts fully forward" \
  --start-frame guard.png [--end-frame extension.png] \
  [--duration 4] [--resolution 720p] [--chroma '#00FF00'] [--seed N]
```

- Composites your RGBA keyframes onto pure chroma, pins them as the clip's literal first/last frames, generates one Seedance clip, slices it, **re-keys every frame against the measured background color**, **despills** the edges, and emits `<run>/<action>/masters/master_NNN.png` + the standard sidecars (`bbox`, `foot_anchor`, `native_size`==PNG dims, `space:"image"`, `cost_usd`).
- Output is directly consumable by your existing `pixelize --fit-mode exact` flow — zero changes downstream.
- Requires `ffmpeg` on PATH. ~$0.48 per 4s 720p clip; the API minimum is 4s (durations 4–15s).
- Camera lock is prompt-enforced + human-verified: every run emits `contact_sheet.png` (12 evenly-spaced masters in time order) and `preview.gif`.

### `despill` (converter 0.8.0)

Edge-band chroma-spill suppression, geometry-preserving (no erosion). It runs automatically inside animate-video's re-key. It also fixes the green outlines on your **existing** masters — your pristine idle carries 64% green-dominant edge pixels from the pre-despill era; one pass cleans it.

---

## The recommended pipeline (validated end-to-end on Hu)

### Step 1 — author keyframes (the step that matters most)

Generate each action's key poses as smooth RGBA stills via pixelforge rawgen, with a **consistent object state across the whole set**: blade drawn, scabbard empty and visible, same grip hand. Object-state inconsistency in keyframes is what caused every sword-duplication/morphing artifact we saw.

Design guidance from the Hu work:

- **Combat loops should start at a combat-guard keyframe (blade already drawn)** — not sheathed idle. The draw becomes a separate one-time entry-transition clip (sheathed idle → guard).
- Iterating keyframes works well with **image-to-image editing**: pass the near-miss image as the reference with a *minimal* edit instruction. Verbatim finding: anatomical wording ("hold it in his RIGHT hand") does nothing; "reproduce the EXACT same image … sword switches to the other hand" mirrors the whole figure; what works is plain edit framing — *"Edit the image: move the sword into the character's other hand. He keeps facing the same direction; everything else stays unchanged."*
- Absolute hand chirality matters less than **consistency across the set** (engines flip sprites constantly anyway).
- Use the **codex backend** for stills (`backend="codex"` / `--backend codex`) — $0 through the ChatGPT subscription. Our 16-candidate authoring session cost $3.80 on OpenRouter only because we forgot our own backend; don't repeat that.
- Budget reality: ~5 approval rounds to land 3 production keyframes for one action family. The working prompts are reusable across your archetypes.

### Step 2 (default) — ONE clip from the keyframe sequence

Pass the ordered keyframes (loop closure by repeating the first at the end) as a reference sequence with a storyboard motion prompt:

> poses: guard, coil, extension, guard
> prompt: "the swordsman moves through these poses in order: ready guard stance with the sword drawn, deep coiled windup pulling the sword back, explosive full forward thrust with the blade extended, then back to the ready guard stance"

Measured on Hu (97 frames, $0.48):

| | result |
|---|---|
| pose order | perfect — guard f1 → coil f16 → extension f44 → guard f88 |
| pose landing (IoU vs keyframes) | 0.95 / 0.95 / 0.93 — at the model's redraw ceiling, equal to pinned bracketing |
| pacing | natural: coil at 0.7s, strike at 1.8s, recovered by 3.7s |
| loop closure (last vs first frame) | 0.992 |
| re-key | 97/97 frames chroma-keyed |

**Availability note:** this sequence mode is validated in our lab harness and is the next `animate-video` flag to ship (`--reference-seq pose1.png pose2.png …` → the video API's `input_references`). The bracketed mode below is shipped today; tell us if you want sequence mode prioritized and we'll land it ahead of anything else.

### Step 3 (when control must be hard) — bracket-chain per phase

One `animate-video` call per adjacent keyframe pair (`guard→coil`, `coil→extension`, `extension→guard`). Measured on Hu: every phase landed (0.94/0.90/0.92), seams between clips at 0.991/0.993, full-loop closure 0.993 — the 291-frame chain plays as one continuous action.

Use this instead of the one-clip default when you need: **exact shared boundary frames** (e.g. chaining *different* actions through a common pose), **per-phase durations**, or a phase the storyboard repeatedly gets wrong. Cost scales with phases (3 × $0.48).

### Step 4 — select + pixelize (unchanged)

Pick frames by pose progress (your plan), then `pixelize <run> --out-size W:H --palette vinik24 --fit-mode exact`. Two selection rules from the data:

- **Select from frame 2 onward in bracketed clips** — frame 1 is your composite verbatim; the model's own redraw starts at frame 2 (~1px envelope shift, visible proportion shift).
- **The redraw ceiling:** Seedance re-renders even pinned frames in its own stable interpretation (~0.925 IoU vs your authored composite, but 0.99+ consistent across clips). For chained actions, judge landings against the adjacent clip's boundary, not the keyframe.

---

## Known limits (plan around, don't fight)

1. **Object permanence** inside a clip is improved but not solved — scabbard flicker can still occur mid-motion. Keyframe object-state consistency minimizes it; per-frame rejection during selection covers the rest (97 frames leave plenty).
2. **Timing is model-shaped.** Sequence mode paces naturally; bracketed clips tend to bunch the strike late (~f72–79 of 97). Selection or playback speed compensates; per-phase durations via chaining if you need authored timing.
3. **Faces at 371:180** lose detail — that's the ~126-texel character budget + 24-color palette, not a pipeline defect.
4. Seeds pass through but determinism is not promised — don't build on it.
5. Camera lock stays human-verified in v1 (contact sheet + GIF per run make it a seconds-long check).

## Costs at a glance

| item | cost |
|---|---|
| keyframe still (codex backend) | ~$0 |
| keyframe still (OpenRouter, fast iteration only) | ~$0.24 |
| one action, sequence mode | $0.48 |
| one action, 3-phase bracket chain | $1.45 |
| entry transition (draw), one-time per character | $0.48 |

## What we'd like from you

- Run the pipeline on a second archetype and tell us where it breaks — everything above is one character, one action family.
- Say the word on prioritizing the `--reference-seq` flag.
- If you want it, we can batch-despill your existing master library (the green-outline fix) — it's a deterministic one-pass operation.

---

## WU replies (2026-06-12)

1. **`--reference-seq`: prioritized.** It is the recommended default at one-third the cost;
   subsequent tooling should target sequence mode first.
2. **Second archetype: `bandit_sword`** (basic melee, legacy art exists for comparison).
   One pilot serves both aiexp's validation ask and WU's parked enemy-roster migration.
3. **Batch-despill: approved.** Deterministic one-pass fix; the existing master archive
   (pristine idle: 64% green-dominant edge pixels) benefits immediately.

---

## Follow-up shipped + validated (2026-06-12)

AIexp implemented the prioritized follow-up in `pixelforge-sprite 0.12.0`.

### What is now shipped

`animate-video --reference-seq` is no longer lab-only. The shipped command
accepts repeated ordered pose flags and routes them to Seedance as
`input_references`:

```bash
aiexp sprite-extractor animate-video \
  --output-dir <run> --action attack \
  --motion "the character moves through these poses in order: guard, coil, extension, guard" \
  --reference-seq guard.png \
  --reference-seq coil.png \
  --reference-seq extension.png \
  --reference-seq guard.png
```

`--start-frame/--end-frame` bracket mode remains available for hard endpoint
control. The CLI enforces exactly one mode per run.

The batch despill command is also shipped:

```bash
aiexp sprite-extractor despill /Users/animula/WU-art-masters --chroma '#00FF00'
```

It is in-place, idempotent, and alpha-preserving, so existing sidecar geometry
stays valid.

### `bandit_sword` pilot

We used `bandit_sword` as the second-archetype pilot.

First, we attempted codex-backend still-keyframe authoring from the legacy
identity reference. Outcome: not reliable enough yet for this archetype. The
coil pose was usable, but guard and extension repeatedly came back as
parchment/map-like outputs rather than isolated character sprites, even after a
stricter second prompt round. Therefore the paid video pilot used legacy
`bandit_sword` frames as the ordered references:

| keyframe | source |
|---|---|
| guard | `WUGodot/assets/sprites/characters/bandit_sword/idle_0.png` |
| coil | `WUGodot/assets/sprites/characters/bandit_sword/attack_1.png` |
| extension | `WUGodot/assets/sprites/characters/bandit_sword/attack_2.png` |
| loop close | guard repeated as the fourth reference |

Paid run result:

| metric | value |
|---|---:|
| frames | 97 |
| cost | `$0.48384` |
| mode | sequence |
| measured background | `#00D707` |
| re-key verdict | pass |
| chroma frames | 97 / 97 |
| peak frame for guard | 82 |
| peak frame for coil | 36 |
| peak frame for extension | 63 |
| peak IoUs | `0.9610`, `0.9362`, `0.9405` |
| final IoU vs guard | `0.9605` |

Visual verdict: sequence mode works on the second archetype. The clip moves
guard -> overhead coil -> forward thrust -> guard, with identity preserved well
enough to validate the shipped `--reference-seq` path.

Roster-migration verdict: not proven yet. Because the successful references
were legacy sprites rather than newly generated keyframes, this run validates
video sequencing, not full replacement of the old `bandit_sword` art. The
pixelized comparison at `256x256 --fit-mode exact` also showed the generated
video character smaller inside the frame than the hand-authored legacy sprite,
so WU would need either a different output size/scale policy or a dedicated
selection pass before treating it as a drop-in replacement.

### Archive despill completed

We ran the approved despill pass over `/Users/animula/WU-art-masters`.

- First pass: `changed: 91  unchanged: 0  failed: 0`
- Idempotency pass: `changed: 0  unchanged: 91  failed: 0`

The archive green-edge cleanup is complete. Since despill does not touch alpha,
existing bbox/foot-anchor sidecars remain valid.
