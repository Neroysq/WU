# Hu Video-First Re-Animation — Design Spec

**Date:** 2026-06-12
**Status:** Draft for review
**Builds on:** `2026-06-10-hu-motion-study.md` (Rev 3 — P5 drawn exaggeration, P6 drawn in-betweens, Arm E video transitions), `docs/aiexp-requests/2026-06-10-video-first-animation.md`, `docs/aiexp-responses/2026-06-12-video-first-animation-report.md` (sequence mode shipped in pixelforge-sprite 0.12.0)
**Proven in-repo:** commit `0e46e4e` — light attack rebuilt from 30 Seedance frames, 60fps-dense timeline, all gates green, feel-tested

---

## 1. Goal

Replace all of Hu's visual states with video-generated, temporally coherent art, under **manual keyframe approval**: no paid video is generated and nothing is installed without the user approving the keyframes first (Gate 1) and the in-game motion last (Gate 2).

Art direction (standing): **wild, exaggerated, comical — unreal but clear and fun.**

## 2. Decisions (resolved with user, 2026-06-12)

| decision | choice |
|---|---|
| Scope | Full set, one plan — all 11 visual states |
| Stance flow | **Guard-start**: every action begins/ends at one shared sword-out combat guard. The iaido draw becomes a one-time combat-entry flavor clip |
| Keyframe approval | Local web page (evidence-page style); user verdicts in chat; approved set recorded with provenance |
| Reactive states | **SF6 economy**: hit / stunned / block / dash / jump phases are *held poses*, not animated clips. Frame density goes only where motion is the content |

### Why held poses for reactive states (investigated 2026-06-12)

`fighter.gd:240-275` already carries these states procedurally: HIT_REACTION is 0.3s fixed with a ±8px recoil shake; STUNNED wobbles on sin/cos offsets; BLOCKING bobs; DASHING arcs; jump/fall are physics-driven. Their durations are gameplay-variable and interruptible on any frame — a single readable pose + juice (hitstop, shake, sparks) is the genre-correct treatment, and single stills can be maximally exaggerated (huge recoil, spiral eyes) precisely because no video has to tween through them.

This economy only works multi-channel (SF6's stated philosophy: readability through pose + hitstop + VFX + audio together). The existing carriers — hitstop, camera shake, particles, damage numbers, procedural offsets — are therefore **load-bearing dependencies** of the held-pose decision, and the presenter must preserve them (see §5a). Audio remains out of scope (B1) but the held poses must read without it.

### Presenter parity is a prerequisite (review finding, 2026-06-12)

Today the presenter does **not** reproduce those carriers: `FighterPresenter.update()` samples only timeline tracks and never reads `fighter.animation_offset` (`fighter_presenter.gd:86-99`), and when the presenter handles a state, `FighterVisual.draw()` is skipped (`combat_scene.gd:511-520`). Migrating the fallback-seven without parity would silently drop the recoil shake, stun wobble, block bob, and dash arc — exactly the juice the held-pose economy depends on. §5a makes parity an explicit, test-gated work item that lands **before** any state migrates.

## 3. Action slate

### Video-generated (5 clips × ~$0.48)

| action | keyframe slots (all start/end at guard) | motion prompt sketch | loop |
|---|---|---|---|
| idle | guard → deep-breath → guard | subtle breathing, weight shifts | yes (closure ≥0.99) |
| walk | contact-A → passing → contact-B → contact-A | side-view walk cycle, sword held ready | yes |
| light attack | guard → coil → full thrust → guard | coils pulling sword back, explosive thrust, recover | no |
| heavy attack | guard → huge telegraphed windup → crushing strike → recover → guard | massive exaggerated overhead/lunging blow | no |
| entry draw (flavor, last) | sheathed idle → iaido draw → guard | one-time combat-entry swagger | no |

### Held poses — stills only, no video (~9 keyframes)

| state | poses | kept procedural motion |
|---|---|---|
| hit | 1 big comical recoil | ±8px recoil shake (existing) |
| stunned | 1–2 dizzy (ping-pong) | sin/cos wobble (existing) |
| block | 1 brace | bob (existing) |
| dash | 1 low blur-lunge | arc offsets (existing) + smear/afterimage |
| jump / fall | rise, peak, fall | real ballistic movement |
| land | 1 crouch | landing bob (existing) |

Total approval surface: ~14 video-anchor keyframes + ~9 held poses ≈ **23 stills**.

## 4. Pipeline (per action)

```
0. GUARD ANCHOR    the first approved keyframe; conditions every other still
1. KEYFRAME SLATE  pixelforge rawgen stills, codex backend (~$0); iterate via
                   image-to-image with plain edit framing ("Edit the image: …
                   everything else stays unchanged"); object-state consistency
                   across the whole set (blade drawn, scabbard visible, same grip)
2. ✋ GATE 1        web approval page; user verdicts; approved frames recorded in
                   keyframes.manifest.json with prompt/seed/backend provenance
3. VIDEO           aiexp sprite-extractor animate-video --reference-seq <ordered
                   approved keyframes, first repeated last for loops> --motion
                   "<storyboard prompt>" (camera-lock verified via contact_sheet.png)
4. SELECT          frames by pose progress, 60fps-dense where the motion supports
                   it (light-attack precedent: windup 1:1, recovery literal frames);
                   reject object-permanence glitch frames individually
5. NORMALIZE       scale_masters (idle-reference base scale) → pixelize
                   --fit-mode exact (uniform texel density — this also covers the
                   bandit-pilot "character smaller in frame" issue by construction)
6. INSTALL         tools/install_video_frames.gd (generalized, retry-safe): crop to
                   family-standard foot x=224, AnchorMeasure anchors, manifest update
7. TIMELINE        per-action timeline JSON (markers for attacks; rate_mode velocity
                   for walk; fixed loop durations for idle); held poses wire into the
                   presenter as single-pose states
8. GATES           ./run.sh --test, --import, --anchor-sanity, --shot-combat strip,
                   --shot-action <state> temporal export (see below)
9. ✋ GATE 2        in-game feel test + temporal artifacts review; commit only on
                   user verdict
```

**Temporal verification (review finding).** Still captures cannot catch this pipeline's actual failure modes — foot sliding, object flicker, pacing bunching, bad loop closure. A new `--shot-action <STATE> <out-dir>` harness drives the presenter through one full clip in-game and exports: every rendered frame as PNG, an assembled contact-sheet strip with phase markers (windup/active/recovery boundaries drawn on the strip), and an animated GIF at gameplay speed. Loop states export two consecutive cycles so closure seams are visible. Gate 2 reviews the GIF + strip alongside live play; the aiexp-side `contact_sheet.png`/`preview.gif` cover generation-time camera lock, this covers install-time truth.

Held-pose states skip steps 3–4: approved stills go straight to normalize → install → presenter wiring.

## 5. New infrastructure

| unit | responsibility |
|---|---|
| `tools/build_keyframe_review.py` | Static approval page: per action, candidate stills at game zoom beside current in-game art; reads/writes `keyframes.manifest.json` |
| `art/keyframes/keyframes.manifest.json` | Approved keyframe registry: action → slot → file, prompt, seed, backend, approval date. The provenance record that makes regeneration reproducible |
| `tools/install_video_frames.gd` | Generalization of the proven /tmp installer (light-attack run): parameters for run dir, action, pose prefix, foot-x policy; idempotent/retry-safe like `132aa89` |
| `--shot-action` harness | In-game temporal export per state: all rendered frames + phase-marked contact strip + gameplay-speed GIF; two cycles for loops (§4 temporal verification) |
| per-action timeline JSONs | `hu_attack_heavy` rewrite, `idle`/`walk` rewrites, new single-pose wiring for the fallback seven |
| presenter P2 migration | The fallback-seven states (block/dash/jump/fall/land/hit/stunned) move off the legacy `character_hu.json` AnimationSet onto manifest poses + presenter — gated on §5a parity |

### 5a. Presenter parity prerequisites (must land before any fallback-seven state migrates)

1. **Procedural-carrier parity — opt-in per state.** `FighterPresenter` applies `fighter.animation_offset` to its rendered position **only for states whose clip declares `"useFighterOffset": true`** (default `false`). Held/reactive states (hit, stunned, block, dash, jump, fall, land) opt in — their recoil shake/wobble/bob/arc lives in `fighter.gd` and must carry over. Video clips (light, heavy, idle, walk, entry draw) stay opted out: `fighter.animation_offset` also contains the legacy attack lunge (`fighter.gd:244`) and walk bob (`fighter.gd:271`), and blanket application would stack that legacy motion onto in-frame video travel — double-lunge and foot slide. Decision: consume the fighter-side offset (opt-in) rather than re-encode carriers as timeline tracks — duplicating them would fork the truth against enemies still rendered by `FighterVisual`, and these are masked transients, exactly the category the motion study leaves outside timelines. Test-gated both ways: an opted-in state renders displaced by `animation_offset`; an opted-out clip ignores a non-zero offset.
2. **Bounds provider.** `combat_scene._draw_fighter()` derives `body_rect` from `FighterVisual.get_body_rect()` (`combat_scene.gd:567-568`), and telegraph/parry/stun/bleed/grab overlays all hang off that rect. Before the legacy set can be retired, a presenter-/manifest-backed bounds API (current pose's `hurtbox` × `renderScale` at fighter position) must exist and be used for presenter-owned states. Test-gated: bounds from the presenter path match the drawn sprite's body box within tolerance for a known pose.

`character_hu.json` is retired only when both hold for every Hu state (acceptance §8).

## 6. Combat-truth integration

- **Heavy attack** gets the reach re-sync treatment light already received: new strike pose tip distance → `PresentationCollision` authored capsule re-measure, `STRIKE_POSE_BY_ID` update, reach-consistency tests, `range_units` check ("match the visible blade" rule).
- **Collision source for dense timelines** (review finding): video attacks show several poses across the active window (light currently spans va_053→va_068 while active), but `PresentationCollision` picks one pose per attack id. Rule: `STRIKE_POSE_BY_ID` maps to the **max-extension active pose** — the active-window keypose with the largest `|weaponTip.x − footAnchor.x|` — chosen at timeline-authoring time and asserted by a test that scans the clip's active keyposes against the manifest. Rationale: hit resolution commits at the attack's true reach; intermediate active poses differ by ≤ a few px of tip travel in the video data (extension-hold plateau), so per-active-frame capsule sampling is deferred as a future upgrade, noted for the SF6-style box-viewer plan.
- **anchor_sanity**: per-pose tip ceiling stays a coarse absurdity guard (560); foot-x spread ceiling 24 enforced by the installer's crop policy.
- Combat timings (`Attacks.json`) do not change in this project. Timeline markers (`windup_end`, `active_end`) absorb pacing differences, as proven on the light attack.
- Hit/stun/block/dash gameplay is untouched; only their art and render path change.

## 7. Sequencing

Each action lands independently (generate → approve → install → feel-test → commit), in this order:

0. **Foundations** (pure code, no generation): §5a parity (animation_offset + bounds provider), `--shot-action` temporal harness, generalized installer, review-page builder — everything later steps gate on
1. **Guard anchor + idle** (establishes the conditioning image and the loop pipeline)
2. **Walk** (second loop; velocity rate_mode already in place)
3. **Light attack** guard-start regeneration (current iaido video stays live until this passes Gate 2)
4. **Heavy attack** (+ reach re-sync, max-extension collision rule)
5. **Held poses batch** (hit, stunned, block, dash, jump, fall, land) — migration allowed because §5a landed in step 0
6. **Entry draw** flavor clip; retire `character_hu.json` once every state passes §8

## 8. Acceptance criteria

Per action: keyframes user-approved (Gate 1); camera lock verified; installed frames pass test suite + anchor sanity + import clean; `--shot-action` GIF + phase-marked strip show no foot slide, flicker, or loop seams; user feel-test approval (Gate 2).

Overall: all 11 states render from manifest poses; §5a parity holds (presenter applies `animation_offset` for opted-in held states and provably ignores it for video clips; overlays use presenter-backed bounds for presenter-owned states — all test-gated); attack collision sources are the max-extension active pose (asserted by test); legacy `character_hu.json` retired for Hu **only after** every state passes the above; 295+ tests green throughout; identity consistent across actions (every still conditioned on the same approved guard); wild-and-comical exaggeration visibly present in hit/stun/heavy.

## 9. Constraints and risks (from aiexp measurements)

| risk | mitigation |
|---|---|
| Redraw ceiling (~0.925 IoU vs authored keyframe) | Judge landings against adjacent clip boundaries, not the authored still; approval page shows the *video's* peak frames at Gate 2, not just authored stills |
| Object permanence (scabbard flicker) | Keyframe object-state consistency; per-frame rejection at selection (97 frames leave plenty) |
| Model-shaped timing | Sequence mode paces naturally (measured); timeline markers re-map to combat timing regardless |
| Source frame-doubling in slow segments (~12fps effective) | Accept for v1; fold "generate at 48/60fps or slow-motion" into the next aiexp ask |
| No seed determinism | `keyframes.manifest.json` provenance makes *keyframes* reproducible; videos are select-from-output, never regenerate-to-match |
| Still authoring can fail for some subjects (bandit pilot: parchment outputs) | Hu's reference is proven (hu-refs-seq run); if a pose family resists, fall back to image-to-image edits from the nearest approved still |

## 10. Cost estimate

~$2.50 video (5 × $0.48) + ~$0 stills (codex backend) + regeneration headroom ≈ **under $5 total**. Budget ~5 approval rounds per action family for keyframe authoring (aiexp's measured rate).

## 11. Out of scope

- Enemy roster migration (bandit_sword pilot is aiexp's track; roster gets its own plan after Hu proves the full pipeline)
- Gains-affect-appearance (future feature; this pipeline's keyframe registry is the natural hook for it later)
- SF6-style collision box viewer (separate parked plan)
- Audio, combat balance changes
