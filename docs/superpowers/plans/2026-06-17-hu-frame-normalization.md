# Hu Frame Normalization Pass — Implementation Plan

**Date:** 2026-06-17
**Spec:** `docs/superpowers/specs/2026-06-17-hu-frame-normalization-design.md`
**Goal:** Normalize Hu's 229 unique `v*` pose assets for head size, baked drift, and grounded foot line while preserving attack balance gates and the video-first render path.

---

## 0. Guardrails

- **Step 0 is a separate commit.** Salvage volatile `/private/tmp/wu-reanim` sources into the repo before any transform or re-pixelize work.
- **No finished-pixel size scaling.** Size changes happen from salvaged masters/keyframes, followed by exact pixelize.
- **Reach STOP is mechanical.** Capture before/after reach data with a comparator; if reach leaves tolerance or enemy band, stop with a table before committing runtime art.
- **Gate 2 still owns feel.** Any normalized clip that changes visible motion needs `--shot-action`/`--shot-combat` evidence and user approval before commit.

---

## 1. Step 0 — Salvage Sources

Copy the durable sources into `art/masters/hu/normalization/`:

| Action | Source | Destination |
|---|---|---|
| entry | `/private/tmp/wu-reanim/entry-pix/entry/{masters_pristine,masters,pixelize}` | `art/masters/hu/normalization/entry/` |
| heavy | `/private/tmp/wu-reanim/heavy-pix/heavy/{masters_pristine,masters,pixelize}` | `art/masters/hu/normalization/heavy/` |
| light | `/private/tmp/wu-reanim/light-pix/light/{masters_pristine,masters,pixelize}` | `art/masters/hu/normalization/light/` |
| walk | `/private/tmp/wu-reanim/walk-run3/walk/{masters,frames}` | `art/masters/hu/normalization/walk/` |
| idle ref | `/private/tmp/wu-reanim/idle-pix/idle/masters_pristine/master_001.*` | `art/masters/hu/normalization/idle_ref/` |

Also write `art/masters/hu/normalization/manifest.json` with source paths, file counts, chosen walk take (`walk-run3`), and the shipped frame labels for each action. Commit:

`art: salvage Hu normalization masters`

---

## 2. Baseline Snapshots

Before changing art:

1. Save reach baseline from `./run.sh --probe-reach` into a machine-readable artifact, e.g. `art/masters/hu/normalization/baseline_reach.json`.
2. Emit a pose inventory from `hu.manifest.json`: 229 unique `v*` poses, 8 aliases and their source pose.
3. Capture baseline visual evidence:
   - `./run.sh --shot-combat /tmp/wu-normalize-baseline-combat`
   - `./run.sh --shot-action ATTACKING_LIGHT /tmp/wu-normalize-baseline-light`
   - `./run.sh --shot-action ATTACKING_HEAVY /tmp/wu-normalize-baseline-heavy`

These snapshots are references; do not commit `/tmp` captures.

---

## 3. Tooling

Implement the current-tool gaps from spec §5a:

1. **Measurement tool**: read salvaged masters/keyframes and emit `measurements.json` with `pose`, source file, head bbox, contact foot, grounded/exempt class, and confidence flags.
2. **Solver**: read measurements and emit `transforms.json` with per-pose `scale`, `offsetX`, `offsetY`, grounding mode, and optional manual override source.
3. **Review page builder**: generate a self-contained HTML page showing head bbox, contact foot, and ground line overlays; manual overrides are edited into a JSON file and re-solved.
4. **`scale_masters.gd` transform input**: accept a transform file; restore from `masters_pristine` before each run; use the salvaged idle reference for base scale when the run lacks an `idle` action.
5. **`install_video_frames.gd` grounding input**: apply x/y blit translations from `transforms.json`; y-ground grounded poses, skip y-grounding for dash/jump/fall; preserve existing exact-mode sidecar checks.
6. **Reach comparator**: snapshot before/after `--probe-reach` values and fail with a table when an attack exceeds tolerance or enemy ranges leave the agreed band.

Add focused tests for parsing/solving/comparison plus existing full gates.

---

## 4. Pilot: Idle Ref + Guard Alias + Light

Pilot scope:

- Use idle reference only to set target head height.
- Normalize light masters (`vl_*`) and refresh `guard`, `strike_extended`, `recover`, `windup` aliases from their `v*` sources.
- Split `fighter.gd` attack offset by attack id; enable `useFighterOffset` on `hu_attack_light`; leave heavy at zero.

Gates:

- Review page: no unapproved detector outliers.
- `./run.sh --test`, `--import`, `--anchor-sanity`.
- Reach comparator. If it trips: ✋ STOP with before/after table.
- `--shot-action ATTACKING_LIGHT`; ✋ Gate 2 before committing light normalization.

---

## 5. Rollout

After pilot approval:

1. Normalize entry (`vd_*`) and walk (`vw_*`), then Gate 2 evidence for entry and walk/combat strip.
2. Normalize heavy (`vh_*`), refresh heavy aliases, and keep heavy presenter travel disabled unless Gate 2 explicitly approves it.
3. Re-derive held poses (`vp_*`) from committed `art/keyframes/hu/*` sources; keep existing `useFighterOffset` carriers.
4. Do not re-derive idle unless the idle measurement review says the shipped idle wobble is visibly bad.

Each batch runs full gates and the reach comparator. Stop on reach drift or failed visual evidence.

---

## 6. Final Acceptance

Before the final commit:

- `./run.sh --test` → `failed: 0`
- `./run.sh --import` → clean
- `./run.sh --anchor-sanity` → `ANCHOR SANITY: OK`
- Reach comparator passes or approved re-sync is committed
- `--shot-combat` all 15 states
- Head-aligned montage page for all 229 unique `v*` assets
- Alias audit: all 8 aliases point to refreshed source `v*` poses

Final commit after Gate 2:

`art: normalize Hu video pose scale and grounding`
