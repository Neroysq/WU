# WU Animation Revamp — Synthesis & Amendments

Date: 2026-06-08
Status: review synthesis (companion to the base spec)
Base: `docs/superpowers/specs/2026-06-08-wu-animation-system-revamp.md`
Revision: 2 — incorporates a code-review pass that found five correctness issues
affecting the first slice and the no-float goal. Fixes are in §3.3 (tap-vs-hold
input), §3.4 (footAnchor as primary root), §3.5 (input/hold clock policy), §3.6
(reach from anchors, not `range_units`), and §5 (Phase 1.5 manifest stub). See
the per-section "Rev 2" notes.

## 0. How to read this document

This is **not** a replacement for the base spec. It adopts the base spec's
architecture wholesale — the hybrid model, `FighterPresenter`, timeline clips,
asset manifests, semantic poses, timeline-authored hitboxes, the three-truths
separation, and the phased migration. All of that stands.

This document does three things the base spec does not:

1. **Reviews it** — verdict, what is load-bearing, what is under-specified or
   risky (Section 2).
2. **Amends it** — seven concrete technical additions/corrections that change
   *how* pieces should be built, keyed to base-spec sections (Section 3).
3. **Re-sequences it** for the stated goal — "smooth and responsive combat,
   AI-friendly" — and tightens the first shippable slice (Sections 4–6).

Where this doc and the base spec disagree, the disagreement is called out
explicitly. Everything else defers to the base spec.

## 1. The original ask, restated

> "Revamp the animation system to allow smooth and responsive animations,
> especially in combat, that is AI-friendly."

Three priorities, in order: **smooth**, **responsive**, **AI-friendly**. The
base spec adds a fourth heavily-weighted theme — **collision intuitiveness /
fairness** (Sections 4.5, 6.5, 9). That is a legitimate and related goal, but it
is *not* one of the three the request named. This matters for sequencing
(Section 4): collision geometry is the most expensive part of the base spec and
should not gate the smoothness/responsiveness wins.

## 2. Review verdict

### 2.1 What the base spec gets right (keep, do not relitigate)

- **Hybrid: JSON is truth, Godot nodes are substrate.** Correct, and correctly
  justified by the existing F5 hot-reload + AI-generation investment. (§1, §7)
- **Three truths: combat / animation / presentation.** This is the single best
  idea in the spec. Combat stays deterministic and headless-testable; animation
  is diffable text; presentation is a replaceable detail. (§5)
- **Sparse AI poses + synthesized motion, not "generate more frames."** Names
  the root cause exactly. (§4.1, Non-Goals)
- **`duration: "fromAttackDef"` — clip time mapped onto combat seconds.** Kills
  the timing/visual decoupling at the root. (§4.3, §8)
- **Collision authored on the timeline, queried by deterministic combat.** The
  right way to make "what you see is what hits." (§6.5, §9) — but see §3.4 below
  for *how* the query must actually be implemented.
- **Validation strategy + measurement-first Phase 0.** Prove "floating" with
  geometry, not impressions. (§4.7, §11 Phase 0, §12)

### 2.2 What is under-specified or risky (this doc addresses each)

| # | Gap / risk in base spec | Addressed in |
|---|---|---|
| R1 | Crossfade between pixel-art sprites can ghost/mud under nearest-neighbor filtering; alpha-blend is named but the pixel-art hazard is not. | §3.2 |
| R2 | Crossfading *into* committed actions (attack/dash) adds perceived input latency — directly fights "responsive." Enter-crossfade policy is given as flat per-state values with no rule. | §3.3 |
| R3 | Normalized clip time is mapped to `AttackState.elapsed`, but **hitstop** (global freeze in `combat_scene.gd`) is not reconciled. If elapsed keeps ticking during hitstop, active windows and events slide. | §3.5 |
| R4 | "Area2D + CollisionShape2D" is named for the authoritative hit query *and* for debug. Area2D overlap reporting is physics-frame-deferred and order-dependent — not frame-exact deterministic. | §3.4 |
| R5 | Manifest coordinates are absolute source pixels (e.g. `weaponTip [220,130]`) but facing/mirroring and the pivot contract are not specified. Fighters flip via `facing` today (`combat_system.gd:update_facing`). | §3.4 |
| R6 | Authoring hitbox capsules per attack × 7 archetypes is real manual labor — in tension with "less manual churn / AI-friendly." | §3.6 |
| R7 | aiexp metadata may be hallucinated (the aiexp request itself flags this). Spec says "fail closed" but defines no trust/verify step. | §3.7 |
| R8 | The smoothness mechanism (smear, squash/stretch, anticipation) is listed as tracks but the *technique* — what actually makes 4 frames read as fluid motion — is not described. | §3.1 |
| R9 | Six phases + ~14 new files is a large surface. The minimal "felt" win is buried. | §4, §5 |

None of these invalidate the spec. They change implementation details and
sequencing.

## 3. Amendments & additions

### 3.1 The smoothness engine, made concrete (amends §4.1, §6.3)

The base spec lists `offsetX/offsetY/scaleY/smearStrength/trailAlpha` tracks but
not the technique. The perceived smoothness from 2–4 sparse poses comes from
**four stacked tricks**, in priority of impact:

1. **Transform interpolation (continuous), not pose interpolation (discrete).**
   The keyposes still snap (you cannot tween between two distinct AI bitmaps —
   see §3.2), but the *transform* of the held pose moves continuously: position,
   rotation, squash/stretch, lean. A held "strike" frame that simultaneously
   slides forward (`offsetX`), pitches into the swing (`rotation`), and
   stretches along the motion vector reads as motion even though the bitmap is
   static. This is the workhorse. It directly replaces the hardcoded
   `sin()`/`cos()` in `fighter.gd:241-278`.

2. **Squash & stretch keyed to impact.** `scaleY` dips and `scaleX` swells one
   beat before `active_end`, snapping back after — the classic anticipation→
   impact→settle. Conserve area (stretch one axis, squash the other) so the
   silhouette doesn't visibly grow, which also protects against the
   apparent-size-drift problem.

3. **Directional smear (shader), not just a trail.** `smearStrength` should drive
   a UV-space smear in `fighter_presenter.gdshader`: sample the sprite multiple
   times along the facing/motion vector with decaying alpha, producing a
   1–2 frame motion blur on the strike. This is what makes a single active frame
   feel like a fast slash. The existing weapon-tip trail (§6.5,
   `fighter_visual.gd:282-302`) becomes a *complement* to smear, anchored to the
   real `weaponTip` marker rather than a guessed offset.

4. **Anticipation / commit poses.** Add an optional `commitPose` to attack states
   — a 1-frame "the swing is coming" snap shown on frame 0 of the attack with
   zero crossfade (see §3.3), before the windup pose. This buys readability
   *and* responsiveness: the player sees instant commitment, then the eased
   windup fills the remaining seconds.

Net: smoothness is a property of the **transform + shader layer**, and the
sprite frames are deliberately sparse anchors. The track schema in §6.3 already
supports this; this section is the missing "why/how."

### 3.2 Crossfade is wrong for adjacent pixel-art poses (amends §6.1, §6.3)

Alpha-blending two nearest-neighbor pixel-art bitmaps during a crossfade
produces a translucent double-exposure that reads as muddy ghosting, *especially*
for poses that overlap spatially (idle↔walk, windup↔strike). The base spec's
`enterCrossfade` should therefore be split into two distinct mechanisms:

- **Ambient transitions** (idle↔walk, land→idle, block→idle): keep a short
  alpha/**dither-dissolve**. Prefer an ordered-dither (Bayer) threshold dissolve
  in the shader over straight alpha — it preserves the crisp pixel edges and
  reads as intentional rather than blurry. ~60–90 ms.

- **Commitment transitions** (→attack, →dash, →parry, →hit-react, →stun):
  **near-zero or zero crossfade.** These must *snap*. Smoothness here comes from
  the transform/smear layer (§3.1), not from blending bitmaps. This is also the
  responsiveness rule (§3.3).

Recommendation: rename/extend the field to make intent explicit, e.g.
`enter: { mode: "dither" | "snap", time: 0.07 }`. Default ambient = dither,
default committed = snap. This is a small schema change with large felt impact
and removes a whole class of "why does the attack look mushy" bugs before they
happen.

### 3.3 Responsiveness rule: commit snaps, ambient blends (amends §8)

The base spec's §8 says "gameplay should never wait for animation" (correct) but
its per-state `enterCrossfade` values (`ATTACK_LIGHT: 0.04`, `DASH: 0.03`) still
introduce a blend on the most latency-sensitive transitions. Make the rule
explicit and structural — and frame it around **commitment**, not key-presses:

> The frame an action is *committed* (the combat model accepts the intent and
> starts the state), its first committed pose renders that same frame with zero
> enter blend. Crossfades are reserved for transitions the player did not
> commit.

**Rev 2 — "committed," not "pressed" (was wrong for WU's input model).**
WU's attack input is tap-vs-hold and the commit point is *not* key-down. In
`combat_scene.gd:252-267`: key-down only clears `_heavy_committed_attack`;
**heavy** commits when the key is *held* past `0.25 s`; **light** commits on
key-*release* (when heavy didn't commit). So at key-down the system genuinely
does not yet know whether a light or heavy is coming. A rule that snaps a
committed attack pose on press would either pick the wrong attack or fire before
commitment. Two acceptable resolutions, pick one at Phase 1:

- **(Recommended) Neutral attack-intent pose on key-down.** Show a single
  non-committal "raising the guard / loading the swing" pose the instant the
  attack key goes down (this *is* responsive feedback), then snap to the real
  `windup` pose of light or heavy at the actual commit point (release, or the
  0.25 s hold threshold). The intent pose doubles as the `commitPose` from §3.1.4
  and reads as deliberate rather than as a misfire.
- **No early pose.** Keep the snap strictly at the commit point and accept that
  the first ~tap latency is the input model's, not the renderer's. Simpler, but
  loses the on-press feedback.

Either way the *renderer* never adds latency: whatever the combat model commits,
the pose snaps that frame. Concretely, wire `input_buffer.gd` → animation graph
cancel-windows (§8 already proposes this) so buffered intent is consumed the
instant the `cancelInto` window opens, the committed pose snaps, and the *only*
smoothing on commit is the transform/smear layer.

This is the difference between "responsive" and "responsive-looking but mushy,"
and it is invisible to the current architecture because immediate-mode draw has
no blend at all today — i.e., **do not regress responsiveness by adding the very
crossfade that makes idle/walk nicer.**

### 3.4 The authoritative hit query must be shape math, not Area2D (amends §6.5, §9)

This is the most important correction. The base spec lists `Area2D` +
`CollisionShape2D` for the attack hitbox/hurtbox/parry zones (§6.1) and also
asks `CombatSystem` to take "deterministic overlap snapshots" (§9). These two
are in tension:

- `Area2D` overlap state (`get_overlapping_areas()` /
  `area_entered`) is updated by the **physics server on physics frames** and is
  reported with **one frame of latency** and **engine-defined ordering**. Moving
  a shape and querying it in the same frame yields stale results. Combat resolves
  in `update_timers`/`resolve_hits` on a logic tick tied to `AttackState.elapsed`
  — not on a physics callback.

**Amendment:** split the two roles.

- **Authoritative query:** evaluate authored shapes with direct geometry math at
  the exact combat tick — `Geometry2D.intersect_polygons` / segment-capsule /
  rect-rect tests on the timeline hitbox transformed to world space. Frame-exact,
  order-free, headless-testable (this is what §12's "hitbox fixtures overlap at
  expected distances" tests actually need — they cannot run a physics step).
- **Debug visualization only:** the `Area2D`/`CollisionShape2D` nodes under
  `FighterPresenter` exist so the editor's "Visible Collision Shapes" and the
  remote inspector can render them. They are driven *from* the same authored
  shapes, never queried for combat truth.

This keeps the determinism the spec rightly insists on (§9 "Keep Deterministic
Combat") and avoids a subtle, hard-to-debug class of "the hit registered a frame
late" bugs.

**Coordinate & mirroring contract (fills R5).** Specify once, globally:

- Manifest pixel coordinates are authored **right-facing canonical** (character
  faces +X), in source-canvas pixels, origin top-left.
- **Rev 2 — `footAnchor` is the primary per-frame root anchor, not `bottom_center`.**
  The earlier draft mapped pixels from the `bottom_center` pivot *and* said
  `footAnchor` resolves to the root — those only agree if the foot is exactly
  bottom-center on every frame, which is precisely the drift the metadata exists
  to eliminate. Correct mapping, per frame:

  ```text
  world(px) = root + mirror( (px - footAnchor) * renderScale ),  mirror flips X when facing == -1
  ```

  where `root` is the presenter `Node2D.position` = the combat ground/contact
  point (§6.1). Anchoring on the *measured foot* (not the bitmap bottom) is what
  actually plants the character; per-frame foot drift cancels out instead of
  becoming a float. Anchors, hitboxes, hurtboxes, the smear vector, and the
  weapon trail all transform through this same expression — author once, both
  facings and all frames work.
- `bottom_center` remains only as a **legacy fallback** for poses with no
  `footAnchor` yet (early migration / decorative clips). The §3.7 verification
  gate fails-closed for combat poses missing a trustworthy `footAnchor`, so a
  shipped fighter never silently falls back to bottom-center on a gameplay frame.
- Facing is owned by `combat_system.gd:update_facing`. Per-frame `offset.y`/
  `offset.x` collapse to zero once metadata lands (§3.7) — they are no longer the
  anchoring mechanism, `footAnchor` is.

### 3.5 The clock: hitstop must own normalized time (new; addresses R3)

`combat_scene.gd` implements hitstop by freezing the combat update
(`_hitstop_timer`), plus slow-motion and camera shake. The base spec maps
`normalized_clip_t = AttackState.elapsed / AttackDefinition.duration` (§8) but
never says which clock `elapsed` and the timeline use during a freeze.

**Amendment — single combat clock, presentation may diverge:**

- During **hitstop**, the *combat clock* (and therefore `AttackState.elapsed`,
  active windows, and timeline gameplay events like `attack_active_start`) must
  **pause**. Otherwise an active window can open or close inside the freeze and
  the hit you "see land" resolves on the wrong frame.
- During **slow-motion**, the combat clock scales by the slow-mo factor; the
  timeline rides the same scaled clock so visuals and active windows stay
  locked together (this is the whole point of `fromAttackDef`).
- **Presentation-only** effects (smear decay, trail fade, crossfade dissolve,
  flash) may run on unscaled real time so a frozen frame still "pops" — but they
  must read the combat clock for anything that gates gameplay.

Make `FighterPresenter.sync_from_fighter(fighter, delta)` receive **two deltas**:
`combat_dt` (scaled, frozen during hitstop) and `presentation_dt` (real). The
timeline samples on `combat_dt`; shader/trail decay on `presentation_dt`. This
is a small signature change with correctness consequences and should be fixed in
Phase 1 before events move onto the timeline (Phase 3), not after.

**Rev 2 — input is a third clock, and it is currently mis-wired.** The two-clock
split above governs animation/presentation but not *input aging*, which has its
own correct policy. Today `combat_scene.gd:191-192` advances both the attack
hold-timer (`_input_tracker.update_hold_timers([attack_key], delta)`) and the
input buffer (`_input_buffer.advance(delta)`) on **real `delta`**, while combat
runs on the frozen/scaled `dt`. During a hitstop (`_time_scale == 0`, `dt == 0`)
the buffer keeps aging and the hold keeps charging even though combat is frozen —
so a buffered "light" can silently expire inside a freeze, and a held attack can
cross the 0.25 s heavy threshold during a freeze the player can't react to.
Specify the policy explicitly:

- **Hold-duration (tap-vs-hold discrimination): real time.** The player is
  physically holding the key; the 0.25 s heavy threshold should reflect
  wall-clock hold, so this correctly uses `presentation_dt`/real `delta` — but it
  must **not advance while combat is frozen** (don't let a freeze auto-promote a
  tap into a heavy). Practically: charge on real time, but pause charging while
  `combat_dt == 0`.
- **Buffered actions: must not expire during hitstop/action freeze.** Age the
  input buffer on a clock that is paused during freeze (i.e., gate
  `_input_buffer.advance` on `combat_dt > 0`, or pass it `combat_dt`). The 150 ms
  buffer window (`input_buffer.gd:4`) should measure *actionable* time, not
  real time that includes frames where no action could be consumed.

So there are three clocks: **combat** (frozen by hitstop, scaled by slow-mo),
**presentation** (real, for decorative decay), and **input** (real-rate but
gated off during freeze so neither buffers nor hold-charge advance while the
player is locked out). Fix this in Phase 1 alongside the presenter signature.

### 3.6 Bootstrap hitboxes; don't hand-author 7×N capsules (amends §6.5, R6)

Authoring capsule geometry for every attack of every archetype is exactly the
kind of per-asset manual churn the revamp is supposed to *reduce*. Make hitbox
geometry **derived by default, overridable by exception**:

- Define **weapon-class templates** (`unarmed`, `sword`, `spear`, `staff`,
  `fan`, `grab`) that generate a default active-window shape from **pose
  geometry**: the `chestAnchor`→`weaponTip` segment (both from manifest metadata)
  plus `is_heavy`/`is_grab` flags. Sword → wide short arc around the tip; spear →
  long thin capsule along chest→tip; grab → disc around the boss arm. Reach comes
  from where the weapon *actually is* in the strike pose, not a scalar.
- **Rev 2 — do not derive shape reach from `range_units`.** `range_units` is the
  exact invisible scalar the revamp is removing; feeding it back into shape
  generation re-imports the mismatch (the capsule would agree with the number,
  not with the art). Reach is derived from `chestAnchor`/`weaponTip`. Then run it
  the other way: **validate `range_units` against the derived reach** (warn/fail
  if they disagree beyond tolerance), or **derive `range_units` from the strike
  geometry** and keep it only as the AI's spacing hint for movement/AI decisions
  — never as hit truth. The §12 test "hitbox fixtures overlap at expected
  distances" then checks geometry, and a separate test asserts
  `range_units ≈ derived_reach`.
- A clip only carries an explicit `hitboxes` block when it needs to *override*
  the template (e.g., Iron Bear's `mountain_breaker`).
- This means a brand-new generated character gets correct-enough hitboxes for
  free from its manifest + weapon class, and an AI agent tunes feel by editing
  one scalar (`range_units`) or swapping the weapon class — not by drawing
  capsules. It also keeps §12's "every active attack clip has at least one
  hitbox" invariant satisfiable automatically.

This directly serves the "AI-friendly / less churn" priority while still
delivering §4.5's "collision matches the animation."

### 3.7 Metadata trust: verify before you trust (amends §10, §14.4, R7)

The aiexp request (`docs/aiexp-requests/2026-04-30-stable-camera-and-scale.md`,
Problem 3) explicitly warns the model may hallucinate bboxes/anchors. The base
spec's §14.4 says "fail closed for combat clips" but defines no check. Add a
**verification gate in the install step** (`tools/install_regen_256.py` is the
natural home — it already computes eroded `bottom_padding`):

- Cross-check each claimed `footAnchor`/`bbox`/`headRow` against a cheap
  eroded-silhouette measurement of the actual PNG.
- Within tolerance → trust the metadata, write it to the manifest, set
  `offset` toward zero.
- Outside tolerance → for **combat-critical poses** (windup/strike/recover,
  hurtbox sources) **fail the install** with a precise message; for decorative
  poses, **warn and fall back** to the measured value.

This makes §10's "validation can fail bad batches before they enter the game"
real, and lets §14.4's "fail closed" coexist with the reality that early
metadata will be imperfect. The trust gate is what lets per-frame `offset`
churn actually drop to zero (the Phase 6 acceptance criterion) without shipping
a floating character on a bad batch.

## 4. Re-sequencing for the stated goal

The base spec's six phases are sound but ordered around the *full* vision
(including collision fairness). For the **named** goal — smooth + responsive +
AI-friendly — re-weight as two parallel tracks:

- **Track A — Feel (serves the actual request, do first):**
  Phase 0 (measure/overlay) → Phase 1 (graph shim + crossfade + transform
  tracks, with the §3.2/§3.3/§3.5 corrections) → Phase 2 (`FighterPresenter`
  for Hu: two-sprite dither-dissolve, snap-on-commit, shader flash+smear,
  foot-anchor root) → Phase 3 (timeline events replace the bespoke
  `attack_active_started` + phase special-case).

- **Track B — Fairness (the base spec's collision work, parallelizable, not a
  blocker):** Phase 4 (hitbox pilot, built on §3.4 shape-math + §3.6 templates)
  → continues into Phase 5/6.

Track A delivers ~all of "smooth and responsive" and most of "AI-friendly"
before any hitbox geometry exists. Track B can start once `FighterPresenter`
and the `weaponTip` markers exist (mid Phase 2) and proceed independently. Do
not let Track B's authoring burden delay the felt win.

## 5. Revised minimal first slice (tightens base spec §16)

The base spec's first slice is right; tighten it with the corrections above:

1. **Phase 0 unchanged** — measurement tests + debug overlay (ground point,
   foot anchor, body rect, scalar range, current state + normalized clip time).
   This is the cheapest, highest-leverage step; it ends the "are they floating?"
   debate with numbers.
2. **Animation graph shim** — but bake in the **two-clock** signature (§3.5) and
   the **snap-vs-dither** enter policy (§3.2/§3.3) from the start; retrofitting
   the clock later is painful.
3. **Phase 1.5 — Hu manifest stub (Rev 2, new).** The first slice needs
   `footAnchor` (§3.4) and `weaponTip` (§3.1/§5.5) for Hu *before* the full
   manifest/schema work (base spec Phase 5). Don't block on it: hand-author a
   tiny `hu.manifest.json` for just the poses the proof uses (`guard`, `windup`,
   `strike_extended`, `recover`), with `footAnchor`/`weaponTip`/`chestAnchor`
   measured once. It is throwaway-compatible with the real Phase 5 manifest
   format. **Provisional fallback:** until even the stub exists, allow the
   presenter to read the existing `weaponTipOffset`/`yOffset` from
   `DefaultProfiles.json` (`fighter_visual.gd:24`) as a clearly-marked TODO — so
   the trail/anchor work is never gated on metadata that doesn't exist yet.
4. **`FighterPresenter` for Hu** — two `Sprite2D` (dither dissolve), root
   foot-anchoring (on `footAnchor`, §3.4), shader hit-flash **and smear**,
   transform-curve playback. Smear is cheap once the shader exists and is the
   biggest single "smooth" contributor for sparse frames — include it in slice 1,
   don't defer.
5. **Keep old combat range math** (base spec agrees) — collision geometry is
   Track B.
6. **One vertical proof** — Hu light attack rendered through the presenter with:
   neutral attack-intent pose on key-down → commit-snap at the real light/heavy
   commit point (§3.3), eased windup transform, squash on impact, smear on
   active, trail from the `weaponTip` (stub or provisional offset, §step 3),
   timeline-driven flash. If that one attack feels good, the model is validated;
   then breadth.

## 6. Risk register (new; consolidates R1–R9)

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Crossfade ghosting on pixel art (R1) | High | Med | Dither-dissolve + snap-on-commit (§3.2) |
| Added input latency from blending commits (R2) | High | High | Zero enter-blend on committed states (§3.3) |
| Active windows slide during hitstop (R3) | Med | High | Two-clock model, combat clock pauses (§3.5) |
| Area2D frame-late / non-deterministic hits (R4) | High | High | Shape-math query; Area2D for debug only (§3.4) |
| Mirroring/pivot bugs on facing flip (R5) | Med | Med | Right-facing canonical coords + single mirror transform (§3.4) |
| Hitbox authoring churn for 7×N attacks (R6) | High | Med | Weapon-class templates, override by exception (§3.6) |
| Hallucinated metadata floats a character (R7) | Med | High | Verify-vs-eroded-bbox install gate, fail-closed for combat poses (§3.7) |
| Smear/squash not actually built → still looks like frame-swap (R8) | Med | High | Smear in first slice; transform-first interpolation (§3.1, §5) |
| 6-phase / 14-file scope stalls the felt win (R9) | Med | Med | Track A / Track B split; ship feel before fairness (§4) |
| Commit-pose fires on wrong/early attack vs tap-vs-hold input (R10, rev2) | High | High | "Committed" not "pressed"; neutral intent pose + snap at real commit (§3.3) |
| `bottom_center` mapping floats characters despite `footAnchor` (R11, rev2) | High | High | `footAnchor` is the primary per-frame root; bottom_center legacy-only (§3.4) |
| Buffer/hold age during hitstop → eaten inputs, auto-promoted heavies (R12, rev2) | Med | High | Three-clock policy; gate input aging off during freeze (§3.5) |
| `range_units` re-imported into hitbox shapes (R13, rev2) | Med | Med | Reach from `chestAnchor`/`weaponTip`; validate/derive `range_units` (§3.6) |
| First slice blocked on metadata that doesn't exist yet (R14, rev2) | Med | Med | Phase 1.5 Hu manifest stub + provisional `weaponTipOffset` (§5) |

## 7. Open-decisions delta (extends base spec §14)

The base spec's recommendations in §14 stand. Additions/answers:

- **§14.1 Curve format** — agree: JSON arrays + named easing now. Add: support a
  small fixed easing vocabulary (`linear|in|out|inOut|spring`) so an AI agent
  picks from an enum the validator can check, rather than free-form Bezier it
  can get subtly wrong.
- **§14.2 Shape types** — agree: rect + capsule. Add: capsule is the default for
  the §3.6 templates (chest→tip segment + radius); polygon reserved for grabs/
  bosses, as the spec says.
- **§14.4 Metadata strictness** — extend with the §3.7 *verification* gate. "Fail
  closed" should mean "fail when metadata is absent **or demonstrably wrong vs.
  the pixels**," not just absent.
- **New — clock ownership (§3.5):** decide now that combat owns the authoritative
  clock and presentation may diverge for non-gameplay effects. This is a
  Phase-1 decision, not a deferred one.
- **New — enter-transition policy (§3.2/§3.3):** decide now that committed states
  snap and ambient states dither. Also Phase-1, because it shapes the graph
  schema (`enter: {mode, time}`).

## 8. Bottom line

Adopt the base spec. It is the correct architecture and the correct
recommendation. This synthesis changes three things that the base spec leaves
open and that materially affect whether the result actually feels smooth,
responsive, and stays AI-friendly:

1. **Build the smoothness, don't blend the bitmaps** — transform-first
   interpolation + squash/stretch + shader smear are the engine; crossfade is a
   garnish for ambient transitions only, and a hazard on committed ones
   (§3.1–§3.3).
2. **Keep combat frame-exact** — authoritative hits are shape math on a single
   combat clock that hitstop pauses; Area2D is for the eyes, not the resolver
   (§3.4–§3.5).
3. **Keep the churn low** — derive hitboxes from weapon-class templates, verify
   AI metadata before trusting it, and ship the *felt* win (Track A) before the
   *fairness* win (Track B) (§3.6–§3.7, §4).

If useful, the next artifact would be a concrete implementation plan
(file-by-file, with the schema definitions for `enter`, the two-clock presenter
signature, and the weapon-class hitbox templates) — say the word and I'll draft
it without touching code.
