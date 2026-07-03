# WU Art Style Bible

Status: generation-facing extract for the canon pass. Token source is `docs/ART_DESIGN_DOC.md` v2.1 until a row in `art/canon/canon.manifest.json` is approved. Approved canon images overrule this prose; when canon and tokens disagree, canon wins and this doc gets reconciled in Task 11.

## Normative Sources

- Three laws: `docs/ART_DESIGN_DOC.md` §2.
- Technical constants and runtime scale source: §3.
- VINIK24 palette, band registers, and school color migration targets: §3a.
- Craft constants: §3b.
- Character, immortal, school, and mook language: §4.
- Ink readability limits: §5b.
- Scene grammar: §6.
- Icon and UI grammar: §7.
- Reserved threat colors and contrast/CVD floor: §8a-§8b.
- Production law and negative fragment: §9.

This file is the prompt-fragment and runbook layer. It names the relevant token sections but does not replace them.

## Palette

Use `tools/art/vinik24.json`, copied from `/Users/animula/GitReps/AIexp/tools/pixelforge-palettes/src/pixelforge/palettes/data/vinik24.json`. Do not transcribe palette or band values from memory; use `ART_DESIGN_DOC.md` §3a for names and meaning, and the JSON for executable checks.

## Canon Sheet Briefs

### School Icons

One horizontal row of six animal pictograms, equal-width cells, transparent background: Bear, Ox, Crane, Swallow, Snake, Eagle. Each icon must read at 24px, use 2-3 VINIK24 colors, keep a 2px safe pad, and feel like one family with a 1-2px stroke. Slice map is fixed: Bear -> `iron.png`, Ox -> `thunder.png`, Crane -> `soft.png`, Swallow -> `wind.png`, Snake -> `venom.png`, Eagle -> `sword.png`.

Prompt fragment: `six compact animal kung-fu school pictograms in one horizontal sprite sheet, equal-width cells, transparent background, VINIK24 pixel art, 24px legibility, bold silhouettes, 1-2px dark ink stroke, 2px safe padding, Bear Ox Crane Swallow Snake Eagle in that order`.

### Hu

Hu is a young starstruck pilgrim in plain blues, not a disciple. Light frame, expressive earnest face, sword and empty green scabbard. Neutral stance stays grounded; personality lives in reaction and burst frames. Clean stage only for this sheet.

Prompt fragment: `young wuxia pilgrim swordsman, plain deep-blue robe, white pants, black boots, empty green scabbard, drawn sword, expressive earnest face, lean heroic six-head proportions, clean source pose, 256x256 transparent pixel art, VINIK24`.

### Hu Corruption Strip

Four states of the same Hu base silhouette: Clean, Touched, Marked, Claimed. Ink grows from hands, forearms, collar, and eyes. Coverage caps are about 0%, 10%, 25%, 45%. Reserved clean zones remain weapon hand, blade edge, face direction, feet, and active limb. The body stays intact; the ink lies.

Prompt fragment: `four-state corruption strip of the same wuxia pilgrim, clean touched marked claimed, black ink stain overlay grows from sword hand forearms collar eyes, body intact, no flesh mutation, reserved readable blade hand feet face direction, VINIK24 pixel art`.

### Xiong Tie

The Iron Bear immortal is calm, rooted, and massive without losing hitbox trust. Low-rooted wide stance, bear mass, dignified integrated ink, iron-dark aura. Active limb, weapon path, hurtbox center, and feet stay readable.

Prompt fragment: `Xiong Tie Iron Bear immortal, low-rooted wide Hung-gar-inspired stance, huge grounded torso mass, calm dignified boss, integrated black ink aura, mist-blue iron palette, readable feet and hands, 256x256 transparent VINIK24 pixel art`.

### Dropout Blade

The basic mook is comic and readable: hand-me-down training clothes, cocky grin, recognizably bad form, clear sword line. No baked touched-ness; enemy ink is a later runtime overlay keyed by encounter pool_class.

Prompt fragment: `Dropout Blade mook, comic failed disciple swordsman, hand-me-down training clothes, cocky grin, bad kung-fu form, readable sword silhouette, no ink corruption baked in, transparent 256x256 VINIK24 pixel art`.

### Six-School Stances

One row, six generic disciples frozen in school stance, judged in pure black silhouette at gameplay size. Stances: Bear low-rooted wide, Ox charging mass, Crane one vertical line, Swallow mid-circle step, Snake coiled low, Eagle reaching seize. Costume detail is secondary; stance silhouette is the test.

Prompt fragment: `six generic kung-fu disciples in one row, pure stance reference sheet, Bear rooted wide, Ox charging mass, Crane vertical centerline, Swallow circle step, Snake low coil, Eagle reaching seize, silhouette-first, transparent VINIK24 pixel art`.

### Mountain Scene Strip

Four painted skies of one mountain, same composition across altitude bands. Foothill is warm rumor-poster dawn. Mid is paler and the peak grows slightly too tall. High is cold with ink pooling in valleys and ridgelines that disagree. Gate is near-black: summit fills the frame, door-crimson accent, wrong but still readable.

Prompt fragment: `four-panel painted pixel-art mountain sky strip, same mountain composition across foothill mid high gate, warm dawn rumor poster to near-black wrong summit, ink-wash clouds thicken, VINIK24 scene palette, no UI`.

## Negative Fragment

`no anti-alias blur, no off-palette colors, no painterly gradients, no unreadable micro-detail, no flesh mutation, no gore, no body horror, no text labels, no fake UI, no dither on characters or icons`.

## Generator Commands

Use the AIexp venv interpreter for local proof tooling:

```bash
PYART=/Users/animula/GitReps/AIexp/.venv/bin/python
```

The pixelforge stack is exposed through the AIexp venv scripts; wrapper equivalents are `aiexp pixel-art ...` and `aiexp sprite-extractor ...`. Use absolute venv paths when recording provenance so the run is reproducible even if PATH changes.

```bash
/Users/animula/GitReps/AIexp/.venv/bin/pixel-art run --prompt-text "$PROMPT" --palettes vinik24 --size 256 --primary-size 256 --kind sprite --remove-bg
/Users/animula/GitReps/AIexp/.venv/bin/pixelforge-sprite run --photo reference.png --describe "$PROMPT" --palette vinik24 --size 256 --backend codex --output-dir art/canon/candidates/<sheet>/<backend-run>
/Users/animula/GitReps/AIexp/.venv/bin/pixelforge-sprite pixelize art/canon/candidates/<sheet>/<backend-run> --out-size 256:256 --palette vinik24 --fit-mode exact
$PYART tools/art/generate_pixelforge_image.py --prompt "$PROMPT" --palette vinik24 --width 384 --height 64 --remove-bg --out art/canon/candidates/icons/pixelforge/cand_N.png
```

Use `--kind sprite --remove-bg` for transparent icon/character trials. Use `--kind background` for scene strips, without `--remove-bg`.

For the icon bake-off, compare normalized outputs only: same prompt, same VINIK24 quantization, same transparent-background cleanup, same `tools/art/make_proofs.py --kind icon` proof. The pick chooses style, not tooling artifacts.

## Proof Commands

```bash
$PYART tools/art/palette_audit.py art/canon/<sheet>.png
$PYART tools/art/make_proofs.py art/canon/<sheet>.png --kind char --profile player_humanoid --out art/canon/proofs/<sheet>
$PYART tools/art/make_proofs.py art/canon/<icons>.png --kind icon --out art/canon/proofs/icons
$PYART tools/art/contrast_cvd_audit.py --contrast art/canon/proofs/<sheet>/runtime.png --band gate
$PYART tools/art/contrast_cvd_audit.py --cvd
```

## Manifest Row

Each approved sheet row in `art/canon/canon.manifest.json` records:

```json
{
  "file": "art/canon/<sheet>/<approved>.png",
  "prompt": "exact prompt or edit instruction",
  "backend": "aiexp|pixelforge|codex|other",
  "generator": "exact command or model",
  "seed": null,
  "approved": "YYYY-MM-DD",
  "notes": "review notes and rejection history"
}
```

Rejected candidates never become approved manifest rows.

## Acceptance

Canon acceptance requires the approved source sheet plus derived proofs: pure-black silhouette at gameplay size where relevant, 24px icon row where relevant, `palette_audit.py` with zero off-palette pixels, `contrast_cvd_audit.py` recorded for contrast/CVD, and runtime-scale review captures before installation.
