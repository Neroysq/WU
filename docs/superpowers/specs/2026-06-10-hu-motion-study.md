# Hu Motion Study — Smooth, Accurate, Fun

Date: 2026-06-10
Status: deep-dive study + proposal (no implementation)
Rev 2: review pass — acceptance reworded to attack *commit* (tap-vs-hold model) with windup@0.06 ≈ 2 frames; P0 marked test-touching (timeline assertions pin old timing; added the recover-at-active_end assertion as part of the fix); hit-confirm squash moved P3→P4 (needs a new signal); P4 notes the collision stack must gain a contact-point API (`query_hit_info`); P1 sized honestly (foot-pivot rotation + previous-rotation dither snapshot); heading corrected to seven packages.

Rev 3 (post-playtest recalibration): the P0/P1 slice shipped, but the playtest verdict on the transform-heavy windup was "the character just looks weird" — **transform-based animation hit its ceiling**: rigid sprites under rotation read as cardboard cutouts, and sustained non-integer scale breaks the texel grid (reads as a rendering defect, not motion). Consequences: (a) **P3 is re-scoped to masked transients only** — pure-translation offsets, shader smears, and fast (<100 ms) impact pops adjacent to motion; no sustained scale, no rotation on held poses; the shipped windup transforms should be stripped back to offsetX-recoil + smear; (b) **exaggeration is delivered by DRAWN poses** (P5 grows: coiled comical windup, recover retract, unique heavy arc — via the aiexp reference-conditioned regen) and **smoothness by drawn in-betweens** (P6, with Arm E upgraded to a first-class Seedance video-transition experiment that can also mint the missing windup arc).
Scope: Hu's moment-to-moment motion quality. Excludes: enemy roster, audio (B1), color-tone drift (aiexp report), pipeline (done).
Method: read every live motion artifact (clips, graph, presenter sampling, fallback path, legacy offsets), recomputed all timings against the current `Attacks.json` windows, cross-checked against the exact-mode captures (`/tmp/wu-exact-shots`), and measured where the data contradicts the intent. The saved art direction — **wild, exaggerated, comical; unreal but clear and fun** — is the grading rubric for "fun".

---

## 1. Current motion inventory (what actually renders today)

| state | render path | frames | motion tracks | legacy `sin/cos` | notes |
|---|---|---|---|---|---|
| IDLE | presenter | 2 @ 1.6 s loop | **none** | computed but **not rendered** | 2-frame swap, no breathing motion |
| WALKING | presenter | 4 @ fixed 0.6 s loop | **none** | bob computed, **not rendered** | foot-slide off nominal speed |
| ATTACKING_LIGHT | presenter | 4 keyposes | offsetX, scaleY, smear | sin lunge computed, not rendered | **keypose timing broken** (§2.1) |
| ATTACKING_HEAVY | presenter | 5 keyposes | offsetX, scaleY, smear | – | timing healthy (recover at `active_end`) |
| BLOCKING | FighterVisual | 2 @ 8 fps | – | `sin(t*8)*3` y-wobble | hard pop in/out |
| HIT_REACTION | FighterVisual | 2 @ 10 fps | – | `cos(t*20)*8` x-shake | + state-exit logic in fighter.gd |
| STUNNED | FighterVisual | 2 @ 8 fps loop | – | x/y jitter | |
| DASHING | FighterVisual | 2 @ 16 fps | – | sin hop arc | **no afterimage/smear** (design doc promises one) |
| JUMP/FALL/LAND | FighterVisual | 2/1/2 | – | y bobs | land→idle exit logic in fighter.gd |

Presenter samples exactly three track names (`fighter_presenter.gd:92-94`): `offsetX`, `scaleY`, `smear`. No `offsetY`, no `rotation`, no `scaleX` — richer motion **cannot be authored** today, only drawn.

Key structural fact discovered: the presenter ignores `fighter.animation_offset`, so when idle/walk/attacks migrated to the presenter, the legacy procedural motion for those states **silently stopped rendering** (good riddance for the attack double-lunge, but the walk bob and idle life went with it and nothing replaced them). Meanwhile `fighter.gd:241-279` still computes all of it every frame, and still owns **state-exit transitions** (hit→idle at 0.3 s, land→idle at 0.2 s, walk→idle velocity threshold) — motion code and state logic are entangled there.

## 2. Findings

### Accuracy (the data contradicts the design)

**A1 — The light attack's keypose timing is broken — this is the single highest-value fix in this study.** `hu_light`: duration 0.5 s, windup ends at norm 0.36, active 0.36–0.60. The clip authors:

| keypose | authored t | actually visible | should be |
|---|---|---|---|
| `guard` (an *idle look-alike*) | 0.00 | **0 → 0.30 = 150 ms** | ≤ 40 ms |
| `windup` | 0.30 | 0.30 → 0.36 = **30 ms (~2 frames)** | ~0.08 → 0.36 (~140 ms) |
| `strike_extended` | `windup_end` ✓ | 0.36 → **1.0** (320 ms — all of active *and* recovery) | 0.36 → `active_end` |
| `recover` | 1.00 | **never** — `pose_at` shows it only at t = 1.0, the frame the state exits | `active_end` → 1.0 (200 ms) |

Felt consequences: pressing attack shows **9 frames of "nothing happened"** (guard = idle pose), the anticipation pose is subliminal, and the recovery shows a frozen full-extension strike — which players read as "the attack is still out" when it isn't (a real parry/punish-timing misread). The heavy clip already does this correctly (`recover` keyed at `active_end`); the light clip simply predates the marker support.

**A2 — Light tracks are misaligned with the real combat windows.** Smear runs 0.48–0.70, but active is 0.36–0.60: **the first half of the hit window has no smear**, and the lunge peaks (0.55) and squash dips (0.52) near active *end* — impact emphasis lands after the impact. (Tracks are numeric by design; these numbers were authored against older timings and never re-derived.)

**A3 — Walk foot-slides.** Fixed 0.6 s cycle, but velocity is lerped (accel/decel) and modified (+15% A7, stance changes): distance-per-cycle varies from ~0 to 220 px against a fixed-stride animation. The classic fix is rate-matching: cycle rate ∝ |velocity|.

**A4 — Known art defects** (already tracked): light `recover` frame is forward-held rather than a retract; `heavy_3` is a duplicated follow-through.

**A5 — Defender-side feedback is the weakest accuracy point.** Being hit shows: 2 frames + a legacy cos-shake + particles spawned at a *fixed body offset* (not the contact point) + knockback velocity with no visual support (no flash on the victim, no directional smear, no recoil lean). The attacker got all the juice attention; the defender communicates almost nothing about *where and how hard* they were hit.

### Smoothness

**S1 — Two render paths, and the fallback seven still pop and wobble.** Block/hit/stun/dash/jump/fall/land hard-swap frames with no crossfade and carry the `sin/cos` jitter — visibly a different motion language than the presenter states sitting next to them.

**S2 — Presenter ambient states have *less* life than the legacy path did.** Idle = 2 pictures alternating every 0.8 s, walk = 4 pictures, zero tracks. The presenter is *capable* of curves on ambient clips (ambient clock already ticks them) — they were simply never authored.

**S3 — The track vocabulary is too small.** Only offsetX/scaleY/smear are sampled. No `offsetY` (bobs, hops, landing dips), no `rotation` (lean into lunges, stagger tilt — applied about the foot anchor), no `scaleX` (area-conserving squash/stretch — currently squash just shrinks Hu, violating the volume illusion).

**S4 — No exit blending.** Enter is dither-or-snap (correct), but a finished attack snaps recover→idle with no settle; cancels snap mid-pose. Cheap fix: a few frames of dither on *uncommitted* exits (attack-finished→idle), never on commits.

### Fun (graded against "wild, exaggerated, comical")

**F1 — The exaggeration values are timid.** Squash 0.92 (light) / 0.88 (heavy) — an 8–12% dip with **no scaleX compensation**; lunge offsets 18/26 px on a 354 px character (~5–7%). Comical-style references run 20–30% squash *with* matching stretch, anticipation pops, and overshoot. The rig supports bolder values today; the data doesn't ask for them.

**F2 — No anticipation, no follow-through.** The deferred `commitPose` idea (synthesis §3.1.4) never landed: attacks have no 1-frame "loading" pop, recoveries have no overshoot-and-settle. These two are the cheapest "feels alive" wins in animation.

**F3 — Dash has no identity.** Two frames, a sin hop, no smear, no afterimage (the design doc explicitly lists "Dash (with afterimage)"). The shader's smear and the presenter's two-sprite machinery make ghosting cheap.

**F4 — Idle has no personality.** For a wuxia hero with a saved "wild/comical" direction, a 2-frame breath is a missed characterization moment (weight shifts, sash sway via rotation, a periodic flourish).

**F5 — Impact framing is generic.** Hitstop (50/100 ms) and shake exist, but particles don't spawn at the blade-contact point (the capsule gives us the exact position), the victim doesn't flash, and light/heavy impacts read nearly the same apart from numbers.

## 3. Proposal — seven packages (P0–P6), ordered by value-per-effort

### P0 — Fix the light attack timeline (data + timeline-test updates, do first)
Re-author `hu_attack_light.timeline.json` against the *current* windows (windup_end 0.36, active_end 0.60):
- keyposes: `guard`@0 → `windup`@**0.06** (30 ms) → `strike_extended`@`windup_end` → `recover`@`active_end` (mirror the heavy clip's correct shape);
- tracks re-derived: smear 0.36→0.66 (covers the whole active window + follow-through), lunge peak ~0.42–0.48 (impact emphasis *at* impact), squash dip 0.40–0.55;
- **not zero-risk — tests pin the old timing**: `test_animation_clip_timeline.gd:20` asserts `offsetX(0.55) > 17`, which the earlier lunge peak breaks. Update those assertions to the new values *and add the missing one that encodes the core fix*: `pose_at(active_end + ε) == "recover"` (plus `pose_at(windup_end + ε) == "strike_extended"` stays);
- acceptance: **attack *commit*** (light commits on key-release, heavy at the 0.25 s hold — per the tap-vs-hold input model, `combat_scene.gd:451`; "press" is not the commit point) **→ first visibly distinct pose within ≤ 2 rendered frames** (windup@0.06 = 30 ms ≈ 2 frames at 60 fps); recover pose actually renders for its full `active_end`→1.0 span; capture strip confirms.
This alone fixes the perceived commit latency and the "attack still out" misread.

### P1 — Presenter motion vocabulary (small-but-not-trivial code) + velocity-matched walk
- Sample three new tracks: `offsetY`, `rotation` (degrees, pivoted at the foot anchor), `scaleX` — defaulting to today's behavior when absent. **Honest sizing**: `offsetY`/`scaleX` are a few lines, but foot-pivoted rotation is real transform work — the sprite is positioned by `-foot × S` with `centered=false`, so rotation needs either a pivot parent node per sprite or explicit rotate-about-foot math in the placement; and the **dither-exit snapshot** (`_sprite_previous`) currently copies only texture/position/scale (`fighter_presenter.gd:139-148`) — it must also snapshot rotation (and scaleX) or every dither out of a rotated pose un-rotates mid-fade.
- **Area-conserving squash by default**: when a clip authors `scaleY` without `scaleX`, derive `scaleX = 1/scaleY` (clamped) so squash reads as weight, not shrinking.
- **Walk rate-matching**: ambient clip time advances at `combat_dt × clampf(|velocity.x| / move_speed, 0.3, 1.6)` for clips flagged `"rate": "velocity"` — kills foot-slide for free across speed buffs.

### P2 — Migrate the fallback seven to the presenter (closes the two-language gap)
Manifest poses + clips + graph states for block/hit/stun/dash/jump/fall/land (canonical slots already installed and anchored). Critically: the **state-exit logic** living in `fighter.gd:241-279` (hit→idle 0.3 s, land→idle 0.2 s, walk-idle threshold) moves to explicit timers in combat code, *then* the whole `_update_animation` match block and the player's FighterVisual path are deleted. This is the previously-planned B4(a), now concretely scoped to Hu; the enemy keeps FighterVisual until the roster rollout.

### P3 — Exaggeration pass (data-only, rides on P1's vocabulary; the "wild/comical" payoff)
Concrete starting values (tune by capture):
- **Attacks**: anticipation pop at windup start (`scaleX 1.08/scaleY 0.94`, 50 ms), strike stretch *along the lunge* (`scaleX 1.12/scaleY 0.90` for the first 60 ms of active), recovery **overshoot** (offsetX −6 then settle to 0, `ease out`). *(Impact squash **on hit-confirm** is NOT data-only — the presenter only receives timeline events today, while hit confirmation happens later in `combat_system.resolve_hits`; it needs a new hit-confirmed signal with attacker/defender context, so it moves to **P4** where the plumbing lives.)*;
- **Walk**: `offsetY` bob ±3 px synced to the cycle, `rotation` lean 2–3° into movement direction;
- **Idle**: breathing `scaleY 1.00→1.015` over the loop + a weight-shift `offsetX ±1`; consider a flourish pose every N loops later;
- **Dash**: `rotation` 6–8° forward lean, smear 0.6 throughout, **afterimage**: re-use `_sprite_previous` as a fading ghost stamped every ~60 ms (presenter already owns two sprites + dissolve);
- **Jump/land**: stretch 1.06 rising, squash 0.85/`scaleX 1.10` for 80 ms on landing;
- **Hit/stun (defender)**: rotation tilt away from the blow (replaces the cos-shake with something directional).

### P4 — Impact & defender feedback (the event/plumbing package — this is where the code risk lives)
- **Hit-confirmed signal**: new `hit_confirmed(attacker, defender, ctx)` emission from `combat_system.resolve_hits` → presenter; drives both the victim feedback below and P3's attacker impact-squash (moved here from P3).
- **Victim flash**: presenter `set_flash` on damage taken (player side); enemy via the existing FighterVisual tint until the roster migrates.
- **Contact-point particles**: the collision stack currently answers only hit/no-hit (`capsule_intersects_rect` → bool; `query_hit` → bool) — it does **not** produce a contact point. Add a `query_hit_info()` / `capsule_rect_contact()` returning the closest-approach point (the segment-rect distance math already computes the features; expose the witness point). Then spawn particles there instead of the fixed body offset; scale count/spread by `is_heavy`.
- **Directional knockback smear** on the victim for ~80 ms (shader `smear_dir` = knockback direction).
- Differentiate light vs heavy impact grammar: heavy = longer hitstop (kept), bigger contact burst, victim rotation tilt; light = sharper, smaller.

### P5 — Art asks (fold into the upcoming aiexp reference-conditioning regen)
A real light-`recover` retract frame; a unique `heavy_3`; one in-between for strike→recover if budget allows; optional dash frame #3. These ride the tone/build regen rather than being their own run.

### P6 — Frame-generation experiment (multi-arm, master-space)

**Premise:** more frames per action can add smoothness — but only if two facts are respected:
1. **Our smooth masters are the right substrate.** Flow interpolators fail on pixel art (hard edges, palette) but excel on the soft 1536×1024 masters; in-betweens generated in master space and pushed through the exact-mode pipeline inherit palette/texel/anchor consistency by construction.
2. **Drawn frames are key poses, NOT time-averaged samples.** Keyposes occupy unequal screen time (light: windup 28% / strike 24% / recover 40% of the clip), so each in-between needs (a) the right **generation alpha** (interpolators accept arbitrary timesteps — the visual midpoint of an accelerating strike is *not* α=0.5) and (b) the right **playback keypose time** in the timeline (spacing vs timing). A per-action *tween manifest* declares both: `{between: [windup, strike], alphas: [0.6, 0.85], play_at: [0.22, 0.31]}`-style. Naive uniform insertion would make attacks floatier, not smoother — in-betweens bunch toward the slow side of each interval (ease-in to strikes, ease-out from impacts).

**Arms** (identical downstream pipeline + capture strips for all):
- **A — control**: current frames with P0 timing fixed.
- **B — flow in-betweens (primary)**: `rife-ncnn-vulkan` (one brew install) on master pairs: walk 4→8, idle 2→4, strike→recover +1, windup→strike +1–2 at eased alphas. Cheap, local, deterministic.
- **C — ffmpeg `minterpolate`**: near-zero cost baseline (already installed); expected worst — include only to calibrate.
- **D — generate more frames upstream**: aiexp `attack:8 / walk-cycle:8` custom specs. Tests whether the generator's own in-betweens beat interpolation — but re-exposes per-frame consistency drift (the known disease); worth one arm, especially after the reference-conditioning request ships.
- **E — video-model transitions (Seedance, first-class arm)**: generate the transition *between two existing masters* with a first/last-frame-conditioned video model (Seedance-class i2v), extract in-betweens. This is the only arm that handles **articulated** motion (blade arcs, limb reconfiguration, cloth follow-through) — the interval class where flow smears and rigid transforms read as cardboard. Recipe:
  1. Composite the two keyframe masters onto a flat key color (video models need RGB); ~1 s @ 24 fps, motion prompt per pair (e.g. guard→strike: *"pulls the sword back low, coils, then thrusts fully forward"* — note this can **mint the missing anticipation pose**, not just in-betweens);
  2. Extract frames **by pose progress, not uniform time** (the tween-manifest principle — eased selection, bunched toward the strike);
  3. Re-key (remove-bg), then standard pipeline: `MasterGeometry` remeasure → idle-reference scale → exact-mode pixelize → palette/texels re-normalized by construction (mid-clip style softening is largely recoverable; **identity drift is not** — faces/costume morphing is the kill criterion, same disease as tone/build drift; short transitions limit it).
  4. Pilot pairs: guard→strike (light — doubles as the windup-pose hunt), strike→recover, heavy_windup→heavy_strike, plus walk_1→walk_2 as a control where flow already works (B-vs-E comparison on equal footing).
  Risks: no determinism, per-generation cost, RGB re-keying edge quality, platform-dependent conditioning support/resolution — verify on the available Seedance variant before building tooling. **Upstream request filed**: `docs/aiexp-requests/2026-06-10-video-first-animation.md` asks for the stronger form — `animate-video`, whole-action generation from a reference image (frames temporally coherent by construction, frame density a free sampling parameter); Arm E doubles as its manual pilot.
  **Note:** E's success would also revise the P3 rollback story — drawn in-betweens deliver the anticipation/follow-through that runtime transforms failed to fake, and the banned-list (no in-betweens on windup→strike) is *suspended for E only*, since these are real drawings rather than morphs.

**Where extra frames are allowed**: walk/idle/hit/block/recover intervals. **Where they are banned**: the strike impact moment and dash — pose-to-pose snap with smear is the wild/comical language; smoothing it is a downgrade (a deliberately *non*-goal).

**Evaluation**: side-by-side capture strips + in-game A/B per arm; texel-consistency check via sidecar heights (must match master-derived expectations like every other frame); foot-anchor spread still 0; the comic-panel rubric for snap states; foot-slide measurement for walk (with and without P1 rate-matching — B and P1 compose: rate-matching fixes *rate*, in-betweens fix *granularity*).

**Integration note**: the presenter path is frame-count-agnostic (manifest poses + timeline keyposes are arbitrary); only the installer's canonical slot map pins counts (e.g. walk at 4) — widen per arm. If an arm wins decisively, consider filing an aiexp `tween` command so it lives upstream.

## 4. Sequencing & verification

1. **P0 now** — pure JSON, biggest accuracy win, zero risk.
2. **P1 + P3 together** — vocabulary + the data that uses it (P3 values are meaningless without P1; P1 is unobservable without P3).
3. **P6 arms A–C** — can run in parallel with P1/P3 (master-space work, independent of presenter code); decide from the strips which states get extra frames.
4. **P2** — unify render paths, delete legacy motion + entangled state-exits (needs care: it's the only package touching combat-adjacent logic).
5. **P4** — impact pass.
6. **P5 + P6 arm D** — ride the next aiexp regen (reference-conditioning + more-frames specs together).

Verification per package: capture strips (`--shot-combat`) compared before/after per state; the A1 acceptance (≤2 frames to first new pose on attack press); a foot-slide check (walk distance-per-cycle ≈ constant across A7 on/off); and a feel-pass with the wild/comical rubric — *"would this read in a screenshot as a comic panel?"* is the bar for P3.

## 5. What this study deliberately does not touch

Audio (B1 — the single biggest *feel* multiplier overall, but orthogonal to motion), enemy motion (rides the roster rollout + P2's pattern), tone drift (aiexp), input/cancel timing (already correct via the three-clock + buffer work), and any combat-balance values.
