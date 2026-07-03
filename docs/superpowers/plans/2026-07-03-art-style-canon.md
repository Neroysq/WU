# Art Style Canon Production (山高墨濁) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **This is an art-production plan: the tests are proofs + user pick-gates (✋), not unit tests.** Every sheet: shotgun candidates → generate proofs → ✋ user picks → record in canon manifest.

**Goal:** Produce the six-sheet approved reference canon + the STYLE_BIBLE token doc, with derived proofs (silhouette/24px/palette/runtime-size), pixelforge bake-off on icons, and provisional-icon replacement.

**Architecture:** `art/canon/` extends the existing `art/keyframes/` provenance system (`canon.manifest.json`, same schema + `generator`). Proof tooling in `tools/art/`. Generation via the proven aiexp pipeline (`AIEXP=/Users/animula/GitReps/AIexp/.venv/bin/aiexp`, `--palettes vinik24 --size 256`) and pixelforge (invocation recorded in Task 3).

**Spec:** `docs/superpowers/specs/2026-07-03-art-style-bible-design.md`

---

## Task 1: STYLE_BIBLE.md draft

**Files:** Create `docs/art/STYLE_BIBLE.md`.

- [ ] **Step 1:** Transcribe spec §1–5 into the token doc with these sections: The Three Laws · Character Tokens (6-heads baseline; silhouette test per school: Bear low-rooted wide / Crane one vertical line / Ox charging mass / Swallow mid-circle step / Snake coiled low / Eagle reaching seize; burst-grammar allowlist: limb smears, 2–3× anticipation squash, comic face swaps, white impact frames — action beats ONLY) · Ink-Stain Grammar (stages 清/touched/marked/claimed; stains grow from hands/forearms/eyes; overlay-not-baked for pool_class touched-ness; school-tinted immortal ink; wrongness drawn IN the ink) · Scene Tokens (4 band skies of one mountain; band palette registers: foothill=warm, mid=neutral, high=cold, gate=ink-extremes; ink-wash clouds) · Icon Tokens (silhouette-first, 2–3 tones, 24px-legible, one family) · Generators (aiexp commands verbatim from the 256px spec; pixelforge section filled by Task 3) · Canon Index (filled as sheets land).
- [ ] **Step 2:** Note atop the doc: *"Tokens describe the approved canon. When canon and tokens disagree, canon wins and tokens get fixed (Task 11)."* Commit `docs(art): style bible token doc (draft)`.

## Task 2: Proof tooling

**Files:** Create `tools/art/vinik24.json`, `tools/art/palette_audit.py`, `tools/art/make_proofs.py`.

- [ ] **Step 1:** Extract the 24 VINIK24 hexes into `tools/art/vinik24.json` from the aiexp palette data (`grep -ri vinik /Users/animula/GitReps/AIexp --include=*.json --include=*.py -l` and read the palette definition; fallback: download from lospec.com/palette-list/vinik24). Do NOT hand-type from memory.
- [ ] **Step 2 (environment, explicit):** these tools need real image ops (quantize/slice/scale) — use the **AIexp venv interpreter**, which has PIL: `PYART=/Users/animula/GitReps/AIexp/.venv/bin/python` (verify `"$PYART" -c "import PIL"`; if it ever lacks PIL, create `python3 -m venv .venv-art && .venv-art/bin/pip install pillow` at repo root and use that). All `tools/art/*.py` invocations in this plan run under `$PYART`. (This repo itself has no venv — do not write bare `pip install`.)
- [ ] **Step 3:** `palette_audit.py <img...>` — counts pixels not in vinik24.json (alpha 0 exempt); prints per-file off-palette count; exit 1 if any nonzero.
- [ ] **Step 4:** `make_proofs.py <sheet.png> --out <dir> [--kind char|icon|scene]` — the **exact runtime-scaling contract** (the viewer route made concrete; no engine changes in this plan):
  - `char`: `runtime.png` = nearest-neighbor ×1.8 (the 256px spec's runtime scale midpoint — on-screen character ≈ what combat shows); `silhouette.png` = alpha-threshold → pure black at the same scale.
  - `icon`: `24px.png` = each icon nearest-neighbor-scaled to 24×24, rendered in a row on the game's panel color.
  - `scene`: `runtime.png` = panel scaled to fit the 1920-wide arena backdrop proportion.
  - Always emits `review.html` (candidates + proofs side by side, following `tools/build_keyframe_review.py`'s pattern) for each ✋ gate.
- [ ] **Step 5:** Commit `feat(tools): art canon proof tooling`.

## Task 3: Pixelforge tooling discovery

**Files:** Modify `docs/art/STYLE_BIBLE.md` (Generators section); Create `art/canon/canon.manifest.json` (empty skeleton).

- [ ] **Step 1:** With the user, record pixelforge's exact invocation (CLI/UI, model, params) into the Generators section — inputs it accepts (reference image? prompt? palette?), output format/size.
- [ ] **Step 2:** Define the **normalization recipe** so bake-off candidates compare like-for-like: scale to target canvas → quantize to vinik24.json → background removal → `palette_audit.py` must pass. Record as commands in the doc.
- [ ] **Step 3:** Create `art/canon/canon.manifest.json` skeleton: `{"sheets": {}}`, entries per approved sheet using the keyframes schema + `generator`: `{file, prompt, backend, generator, seed, approved, notes}`. Commit.

## Task 4: Icon row — the pixelforge bake-off ✋

**Files:** Create `art/canon/icons/` candidates + proofs; Modify `canon.manifest.json`, `WUGodot/assets/icons/schools/*.png` (on approval).

- [ ] **Step 1 (brief — same for BOTH generators):** *"Set of six pixel-art animal pictogram icons, one visual family: bear head, ox head, standing crane, swallow in flight, coiled snake, eagle head. Silhouette-first, 2–3 tones from the VINIK24 palette, dark background transparent, strong readable shapes, consistent stroke weight and framing, wuxia seal-mark feel. 24×24 target legibility."* Generate ≥2 candidate rows per generator (aiexp: `pixel-art run --prompt-text ... --palettes vinik24 --size 64 --kind sprite --remove-bg`, downscale; pixelforge: per Task 3 recipe).
- [ ] **Step 2:** Normalize all candidates (Task 3 recipe); run `palette_audit.py`; `make_proofs.py --icon` → 24px rows; assemble `review.html`.
- [ ] **Step 3:** ✋ **STOP — user picks the winning row AND the winning generator** (this decides the small-asset default). Record both in the manifest (`generator` field; note the loser's provenance in `notes`).
- [ ] **Step 4 (provisional-icon replacement — explicit slice map, no guessing):** slice the approved row into six individual PNGs and install by this **fixed animal→id mapping** (display animals to data ids, from the identity spec):
  | row position | animal | installs as |
  |---|---|---|
  | 1 | Bear | `WUGodot/assets/icons/schools/iron.png` |
  | 2 | Ox | `WUGodot/assets/icons/schools/thunder.png` |
  | 3 | Crane | `WUGodot/assets/icons/schools/soft.png` |
  | 4 | Swallow | `WUGodot/assets/icons/schools/wind.png` |
  | 5 | Snake | `WUGodot/assets/icons/schools/venom.png` |
  | 6 | Eagle | `WUGodot/assets/icons/schools/sword.png` |
  Slice at equal-width cells from the row; output each icon at the **same pixel dimensions as the file it replaces** (inspect the current PNGs at implement time) so `Schools.json` paths and the renderer keep working unchanged. If the repo carries a combined icon source sheet (e.g. a `school_icons_sheet.png` from slice 1), regenerate/replace it from the same canon row so source and installed files can't drift. Then `./run.sh --import`, re-run slice-1 icon captures (school-choice ×2, boon-offer, matchup-with-build, map-with-build) + `./run.sh --test` (`test_school_icons` green). Commit `feat(art): canon school icons replace provisional set`.

## Task 5: Hu turnaround ✋

- [ ] **Step 1 (brief):** *"Young Chinese pilgrim swordsman, light frame, ~6-head proportion, expressive earnest face, plain blue traveling clothes with white under-layer, straight sword sheathed; no school markings. Idle stance and mid-step walk, side view, 256px pixel art, VINIK24."* Shotgun 3 candidates via aiexp static command; current Hu sprite attached as the density/build reference.
- [ ] **Step 2:** Normalize + proofs (silhouette at gameplay height, runtime.png) + review.html. Include current in-game Hu beside candidates for the scale/read comparison (per the judge-art-in-game memory).
- [ ] **Step 3:** ✋ user picks → `art/canon/hu/turnaround.png` + manifest entry. Commit.

## Task 6: Hu corruption strip (4 stages) ✋

- [ ] **Step 1 (brief):** *"Same character 4 times, left to right: (1) clean; (2) black ink stain at collar and sword hand, knuckles darkening; (3) ink veins up forearms and neck, eyes darkened, stain slightly offset from body; (4) half-swallowed — torso and sword arm mostly ink, and the stain's edge forms faint WRONG shapes: an extra finger silhouette, a hint of a grin where no mouth is. Body stays intact — the ink lies. Pixel art 256px, VINIK24, ink pure black with cold blue-purple edge tones."* Base = the approved Task-5 Hu (image-to-image so stages stay on-model).
- [ ] **Step 2:** Proofs incl. runtime.png at gameplay size (stage differences MUST read at gameplay size — that's the whole diegetic-corruption UX). ✋ user picks → canon + manifest. Commit.

## Task 7: Xiong Tie ✋

- [ ] **Step 1 (brief):** *"Massive Chinese martial-arts master, bear-like bulk breaking normal proportion (fills the frame), iron-grey robes, exposed forearms like tree trunks, low rooted stance radiating immovability; iron-dark ink fully integrated into his silhouette's shadows — the corruption is part of him, calm and total. Dignified, not monstrous. 256px pixel art, VINIK24."* Shotgun 3.
- [ ] **Step 2:** Proofs (silhouette must read Bear-school low-rooted; runtime.png vs current in-game iron_bear for scale). ✋ user picks → canon + manifest. Commit.

## Task 8: Dropout Blade (mook register) ✋

- [ ] **Step 1 (brief):** *"Scruffy failed kung-fu student turned bandit: ill-fitting hand-me-down training clothes, cocky grin, sloppy imitation of a proper sword stance (recognizably bad form), comic readable face. NO ink/corruption. 256px pixel art, VINIK24."* Shotgun 3.
- [ ] **Step 2:** Proofs; runtime.png beside current bandit_swordsman. ✋ user picks → canon + manifest. Commit.

## Task 9: Six-school stance sheet ✋ (the silhouette gate's source asset)

- [ ] **Step 1 (brief):** *"Six martial artists in one row, same body scale, each frozen in their school's signature stance, designed to be tellable apart in PURE BLACK SILHOUETTE: (1) Bear — low rooted wide horse stance, massive base; (2) Ox — mid-charge, shoulder leading, mass driving forward; (3) Crane — one vertical line, single-leg, arms folded like wings on the centerline; (4) Swallow — mid circle-step, body curved in turning flight; (5) Snake — coiled low, spine curved, one arm striking like a head; (6) Eagle — tall reach, clawed hand seizing downward. Generic disciples (not the immortals), simple dark clothes, 256px pixel art, VINIK24."* Shotgun 2–3 sheets.
- [ ] **Step 2:** Proofs: `make_proofs.py --kind char` — the **silhouette.png of this sheet at gameplay size IS the bible's §2 hard-rule test**: six stances tellable apart in pure black. Include it prominently in review.html.
- [ ] **Step 3:** ✋ user picks (judging silhouettes first, detail second) → `art/canon/schools/stances.png` + manifest. This sheet is the stance canon for every future school practitioner/enemy. Commit.

## Task 10: Scene strip — four skies of one mountain ✋

- [ ] **Step 1 (brief, one image, four vertical panels or four files):* the SAME mountain from the same vantage:* (1) foothill — warm dawn, generous sky, the peak distant and lovely; (2) mid — paler, higher, the peak slightly too tall; (3) high — cold thin light, black ink pooling in the valleys, ridge geometry beginning to disagree; (4) gate — near-black, the summit fills the frame, wrong. Wide parallax-layer format (e.g. 960×320 per panel), painted pixel-art style, VINIK24 band registers (warm/neutral/cold/ink)."* Shotgun 2–3 sets.
- [ ] **Step 2:** Proofs: palette audit per panel + `make_proofs.py --kind scene` (the exact viewer contract from Task 2 — no engine staging in this plan; in-engine backdrop install is a later production slice). ✋ user picks → canon + manifest. Commit.

## Task 11: Token reconciliation + record ✋

- [ ] **Step 1:** Re-read STYLE_BIBLE.md against the six approved sheets; fix every token that disagrees with canon (canon wins). Fill the Canon Index section.
- [ ] **Step 2:** Run the full acceptance: `palette_audit.py` on all canon files (0 off-palette), silhouette gate = the Task-9 stance sheet's silhouette.png (six schools tellable apart — user confirms), 24px icon row, runtime proofs reviewed. `./run.sh --test` green (icons replaced in Task 4).
- [ ] **Step 3:** ✋ **STOP — present the assembled canon (one review page) for the final bible sign-off.** Then commit `docs(art): style bible + canon complete` and hand off to the first production slice.

## Self-Review
- **Spec coverage:** §6A doc (T1) · proofs incl. exact runtime-scaling contract (T2, gates in every sheet task + T11) · pixelforge discovery/normalization/provenance (T3, T4) · canon sheets in cheapest-risk order (T4–T10; the six-school stance sheet T9 added as the silhouette gate's source — a seventh sheet extending the spec's six, in its spirit: the §2 hard rule needs a testable asset) · provisional-icon replacement w/ explicit slice map (T4 Step 4) · canon-extends-keyframes schema (T3) · acceptance = sheets+proofs+tokens (T11). Out of scope respected (no production beyond sheets; icons are the one allowed install per the spec's provisional-icon rule).
- **Placeholder scan:** every brief is real copy; pixelforge specifics are an explicit discovery task with defined outputs (not a TBD); VINIK24 hexes deliberately extracted, not hand-typed.
- **Consistency:** manifest schema fields match `art/keyframes/README.md` + `generator`; proof names (`silhouette/runtime/24px`) consistent across T2 and sheet tasks; briefs use the T1 tokens.
