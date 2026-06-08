# WU Animation System Revamp - AI-Friendly Combat Presentation Architecture

Date: 2026-06-08
Status: proposal / review synthesis
Scope: combat animation, collision presentation, asset pipeline, validation strategy

## 1. Executive Decision

WU should move to a hybrid animation architecture:

- Keep JSON and generated asset manifests as the source of truth.
- Compile that source into Godot runtime presentation nodes: `Node2D`, `Sprite2D`, `ShaderMaterial`, `Marker2D`, `Area2D`, and `CollisionShape2D`.
- Keep `Fighter`, `AttackDefinition`, `AttackState`, and `CombatSystem` as the deterministic combat core.
- Do not make `AnimationPlayer`, `AnimationTree`, or `.tres` files the primary authored format yet.

This combines the strongest parts of both directions:

- The current project already benefits from text-authored data, hot reload, generated sprites, and AI-editable JSON.
- Godot already provides the right runtime primitives for smooth presentation, debug visibility, collision shapes, shaders, and editor inspection.
- Full Godot-native animation authoring would improve blending, but it would weaken the AI-friendly workflow by moving intent into editor-authored resources that are harder to diff, generate, review, and validate.

The recommended target is:

```text
AI-generated art + metadata
        |
        v
asset manifest JSON + animation graph JSON
        |
        v
validated compiler/runtime loader
        |
        v
FighterPresenter Godot node tree
        |
        v
deterministic CombatSystem queries presentation hitboxes during active windows
```

The important design distinction is that Godot becomes the presentation substrate, not the authoring truth.

## 2. Non-Goals

This revamp should not:

- Replace deterministic combat with raw physics simulation.
- Depend on generating many more AI frames per action as the main smoothness fix.
- Keep repairing every generated frame with manual `offset` values forever.
- Move core combat timing into animation playback.
- Require designers or agents to edit opaque binary/editor resources as the main workflow.

More frames help, but they do not solve anchoring, collision clarity, timing authority, or responsive cancel behavior. The system needs a better contract, not just denser sprites.

## 3. Current Architecture Map

### Data Layer

Current files:

- `WUGodot/assets/animations/character_*.json`
- `WUGodot/scripts/visual/animation_set.gd`
- `WUGodot/data/VisualProfiles/DefaultProfiles.json`

Current job:

- Map high-level clip names like `IDLE`, `WALKING`, `ATTACKING_LIGHT`, and `DASHING` to frame paths.
- Store `fps`, looping, frame offsets, and optional attack phase frame lists.
- Store per-profile scale, y-offset, body rectangle, weapon-tip offset, and tint data.

This is useful, but it is still a frame-list format. It does not describe animation intent, contact anchors, hitbox geometry, transition rules, cancel windows, or event markers.

### Gameplay State Layer

Current files:

- `WUGodot/scripts/fighter.gd`
- `WUGodot/scripts/attack_state.gd`
- `WUGodot/scripts/attack_definition.gd`

Current job:

- `Fighter` owns `current_animation`, `_attack_state`, `animation_time`, and `animation_offset`.
- `AttackDefinition` owns combat timing: `duration`, `windup_end`, `active_end`, range, posture, parryability, perilous status, and damage.
- `AttackState` maps elapsed time to phase and active-window state.

This separation is directionally correct. Combat timing should remain deterministic and owned by the combat model. The weak point is that presentation animation is only partially bound to this model and only for attacks.

### Visual Runtime Layer

Current files:

- `WUGodot/scripts/visual/fighter_visual.gd`
- `WUGodot/scripts/combat_scene.gd`

Current job:

- `FighterVisual.draw()` resolves the current clip, advances frame indices, and draws textures directly through `canvas.draw_texture_rect`.
- `combat_scene.gd` draws telegraph outlines, a weapon line, particles, feedback, hitstop, slow motion, and HUD overlays.
- Recent combat-feel work added telegraph tint, active flash, attack phase playback, and a hand-drawn weapon trail.

This works for a prototype, but it forces every presentation feature to be hand-built in immediate-mode drawing. Crossfade, smear, hit flash, material animation, collision visualization, and editor inspection all become custom work.

### Orchestration Layer

Current files:

- `WUGodot/scripts/combat_system.gd`
- `WUGodot/scripts/combat_scene.gd`
- `WUGodot/scripts/input_buffer.gd`

Current job:

- `CombatSystem.resolve_hits()` applies parry, block, hit, posture, technique, and death logic.
- Hit detection is range math, not authored geometry:

```text
horizontal: abs(defender.x - attacker.x) <= attack_range + defender.half_width
vertical:   abs(defender.y - attacker.y) <= defender.height + margin
```

- `InputBuffer` supports responsive input, but animation state has no declarative cancel-window contract.

The core problem is not that the combat model is wrong. The problem is that the visible animation and the invisible collision model are not the same artifact.

## 4. Diagnosis

### 4.1 Smoothness Is Structurally Capped

Current attack playback is still fundamentally frame swapping:

- State changes reset frame index and timer.
- Attack clips are phase-snapped to sparse frame lists.
- A 4-frame attack often becomes: two windup poses, one active pose, one recovery pose.
- A long heavy windup can hold two stills for a large fraction of a second.

The system tries to compensate with hardcoded motion:

- attack lunge in `fighter.gd`
- hit shake in `fighter.gd`
- dash arc in `fighter.gd`
- walking bob in `fighter.gd`
- weapon trail in `fighter_visual.gd`

That is evidence that the sprite frames are being treated as sparse key poses already. The runtime should accept that reality and synthesize smoothness intentionally through curves, crossfades, shader smear, and transform tracks.

### 4.2 Animation Truth Is Scattered

There is no single declarative answer to:

- What state should play now?
- What can interrupt this state?
- How does this state blend from the previous state?
- Which frame or pose owns the active hit?
- What visual event fires at active start?
- Where is the weapon tip?
- Where is the foot contact?
- What collision shape is valid during this pose?

Instead:

- `current_animation` is set imperatively in multiple files.
- Attack phase logic is partly in `AttackState`, partly in `FighterVisual`.
- Juice is hardcoded with `sin()` and `cos()` constants.
- Active flash uses a bespoke signal.
- Hit detection does not read the rendered attack geometry.

This makes the system hard for humans and agents to modify safely. An AI agent can edit JSON, but the actual behavior emerges from several files of imperative glue.

### 4.3 Combat Timing And Visual Timing Are Coupled By Special Case

`AttackDefinition` is the correct source for attack seconds. However, the visual layer only binds to it for attack phase frame selection. Other animation states still play by fixed FPS, and attacks still use sparse frame lists rather than a continuous timeline.

The desired model is:

```text
AttackDefinition owns seconds.
Animation clip owns normalized intent.
Runtime maps normalized clip markers onto AttackDefinition phase windows.
```

That way, if a light attack changes from 0.50s to 0.44s, the visual anticipation, active flash, weapon trail, and hitbox timing all retime together.

### 4.4 AI Asset Drift Is Being Treated As Animation Data

Generated sprites currently need per-frame offsets and profile y-offsets to keep feet grounded. That is a symptom of unstable source images, not animation intent.

Recent 256px work improved resolution, but it did not remove the underlying contract problem:

- Generated frames can have different apparent body sizes.
- Foot contact can drift.
- Some attack frames imply different ground lines.
- Weapon tips are guessed from profile constants and attack range.
- Per-frame `offset` values become hand-authored compensation that must be redone after regeneration.

The existing aiexp request at `docs/aiexp-requests/2026-04-30-stable-camera-and-scale.md` points in the right direction: stable camera, reference frame, anchor line, and metadata. The runtime needs to consume that metadata directly rather than reverse-engineering anchors from eroded bounding boxes.

### 4.5 Collisions Are Not Intuitive Because They Are Invisible Abstractions

Current combat range checks are simple and deterministic, which is good for reliability. But they do not match the animation:

- A spear thrust should have a long narrow hitbox.
- A sword sweep should have a shorter wider arc.
- A grab should connect around the boss arm/body, not the same scalar range as every other attack.
- A parry should have a visible guard/contact zone.
- A dodge-through technique should depend on crossing the active threat zone, not just being invulnerable near an enemy.

Players judge combat fairness visually. If the hand-drawn weapon trail says one thing and the scalar range check says another, the combat will feel wrong even when the code is consistent.

### 4.6 Immediate-Mode Drawing Blocks Cheap Godot Wins

The current `draw_texture_rect` approach makes every visual feature custom:

- Crossfade must be manually implemented.
- Hit flash is tint math.
- Smear must be custom geometry.
- Trail history must be custom drawing.
- Collision debug overlays must be drawn separately.
- Editor inspection cannot show a live node hierarchy for each fighter.

Godot already has useful primitives for this:

- `Sprite2D`
- `ShaderMaterial`
- `Area2D`
- `CollisionShape2D`
- `Marker2D`
- tweens or curve evaluation
- visible collision shapes
- remote inspector
- editor preview scenes

The mistake would be to ignore those tools. The second mistake would be to make them the only source of truth.

### 4.7 Tests Miss Presentation Correctness

Current headless tests validate many combat mechanics, and recent tests validate some animation phase parsing. They do not yet validate:

- grounded foot-anchor stability
- apparent sprite size stability across frames
- hitbox/hurtbox overlap at expected distances
- weapon-tip metadata presence
- state graph transition legality
- cancel-window validity
- timeline event ordering
- visual-event alignment with combat active windows

This is why screenshot/playtest regressions keep surfacing late. The current tests prove mechanics. They do not prove combat presentation.

## 5. Design Principle: Three Truths, One Contract

The revamp should separate three forms of truth.

### Combat Truth

Owned by:

- `AttackDefinition`
- `AttackState`
- `Fighter`
- `CombatSystem`

Responsibilities:

- damage
- posture
- parryability
- perilous/blockability
- duration
- windup/active/recovery seconds
- death
- resources
- technique effects

Combat truth must remain deterministic and testable without rendering.

### Animation Truth

Owned by:

- animation graph JSON
- timeline clip JSON
- asset manifest JSON
- schema validation

Responsibilities:

- state transitions
- crossfade durations
- cancel/interrupt windows
- key poses
- transform tracks
- event markers
- anchor metadata
- hitbox/hurtbox shapes
- semantic pose naming

Animation truth must be readable, diffable, generated, hot-reloadable, and easy for AI agents to edit.

### Presentation Substrate

Owned by:

- `FighterPresenter`
- Godot node tree
- shaders
- collision areas
- debug overlays

Responsibilities:

- drawing sprites
- blending/crossfading
- shader flash/smear
- transform curves
- weapon trails
- collision shape evaluation
- editor/debug visualization

Presentation substrate should be replaceable implementation detail. It should be compiled from animation truth, not hand-authored as the only canonical data.

## 6. Proposed Architecture

### 6.1 New Runtime Layer: FighterPresenter

Add a presenter node per fighter:

```text
FighterPresenter (Node2D)
  SpriteCurrent (Sprite2D)
  SpritePrevious (Sprite2D)       # crossfade source
  HurtboxArea (Area2D)
    HurtboxShape (CollisionShape2D)
  PushboxArea (Area2D)
    PushboxShape (CollisionShape2D)
  AttackHitboxArea (Area2D)
    AttackHitboxShape (CollisionShape2D)
  ParryArea (Area2D)
    ParryShape (CollisionShape2D)
  FootAnchor (Marker2D)
  ChestAnchor (Marker2D)
  WeaponTipAnchor (Marker2D)
  HitOriginAnchor (Marker2D)
```

`FighterPresenter` syncs from the gameplay fighter each tick:

```gdscript
presenter.sync_from_fighter(fighter, delta)
presenter.play_state(resolved_state, attack_definition, attack_state)
presenter.update_collision_shapes()
presenter.update_shader_uniforms()
```

The root `Node2D.position` is the combat ground/contact point. This is important: y-offset, frame offset, and foot anchor should all resolve to a stable ground point. If the fighter appears to float, the presenter should make the source of error visible:

- root ground point
- foot anchor
- sprite bottom
- hurtbox
- pushbox
- attack hitbox

### 6.2 Animation Graph JSON

Replace scattered enum mutation with a declarative state graph.

Example:

```json
{
  "states": {
    "IDLE": {
      "clip": "idle",
      "enterCrossfade": 0.06,
      "priority": 0
    },
    "WALKING": {
      "clip": "walk",
      "enterCrossfade": 0.08,
      "priority": 1
    },
    "ATTACK_LIGHT": {
      "clip": "attack_light",
      "duration": "fromAttackDef",
      "enterCrossfade": 0.04,
      "priority": 5,
      "cancelInto": {
        "DASH": "recovery",
        "ATTACK_LIGHT": "recovery",
        "PARRY": "recovery"
      },
      "interruptibleAfter": "recovery"
    },
    "DASH": {
      "clip": "dash",
      "enterCrossfade": 0.03,
      "priority": 6,
      "cancelInto": {
        "ATTACK_LIGHT": 0.75
      }
    }
  }
}
```

Rules:

- State names stay close to the existing `AnimationState` names for migration.
- `duration: "fromAttackDef"` means the runtime maps the clip timeline to `AttackDefinition.duration`.
- Cancel windows can reference normalized time or combat phase names.
- State priority resolves conflicting intents.
- Existing imperative state assignment becomes intent input, not final animation authority.

### 6.3 Timeline Clip JSON

A clip should become a normalized timeline, not just a frame list.

Example:

```json
{
  "clips": {
    "attack_light": {
      "duration": "fromAttackDef",
      "keyposes": [
        { "t": 0.00, "pose": "guard" },
        { "t": 0.28, "pose": "windup" },
        { "t": 0.48, "pose": "strike_extended" },
        { "t": 1.00, "pose": "recover" }
      ],
      "tracks": {
        "offsetX": [
          { "t": 0.00, "v": 0.0, "ease": "out" },
          { "t": 0.45, "v": 18.0, "ease": "inOut" },
          { "t": 1.00, "v": 0.0, "ease": "out" }
        ],
        "offsetY": [
          { "t": 0.00, "v": 0.0 },
          { "t": 0.50, "v": -4.0 },
          { "t": 1.00, "v": 0.0 }
        ],
        "scaleY": [
          { "t": 0.00, "v": 1.0 },
          { "t": 0.47, "v": 0.92, "ease": "in" },
          { "t": 0.60, "v": 1.0, "ease": "out" }
        ],
        "smearStrength": [
          { "t": 0.42, "v": 0.0 },
          { "t": 0.48, "v": 1.0 },
          { "t": 0.62, "v": 0.0 }
        ],
        "trailAlpha": [
          { "t": 0.40, "v": 0.0 },
          { "t": 0.50, "v": 1.0 },
          { "t": 0.72, "v": 0.0 }
        ]
      },
      "events": [
        { "t": "windup_end", "event": "attack_active_start" },
        { "t": "active_end", "event": "attack_active_end" },
        { "t": 0.48, "event": "weapon_swing" },
        { "t": 0.50, "event": "camera_shake", "amount": 4.0 },
        { "t": 0.50, "event": "sfx", "id": "slash_light" }
      ]
    }
  }
}
```

This turns the current hardcoded `sin()` and `cos()` presentation effects into data. Sparse AI frames become keyposes. The runtime supplies the missing motion.

### 6.4 Asset Manifest JSON

Generated art needs metadata. The manifest should describe each frame as an anchored pose.

Example:

```json
{
  "id": "hu",
  "sourceCanvas": [256, 256],
  "renderScale": 1.625,
  "poses": {
    "guard": {
      "path": "res://assets/sprites/characters/hu/idle_0.png",
      "footAnchor": [128, 238],
      "headRow": 42,
      "bbox": [82, 40, 176, 238],
      "hurtbox": { "shape": "rect", "rect": [92, 76, 166, 238] },
      "chestAnchor": [128, 112],
      "weaponTip": [165, 126]
    },
    "strike_extended": {
      "path": "res://assets/sprites/characters/hu/attack_2.png",
      "footAnchor": [128, 238],
      "headRow": 44,
      "bbox": [76, 42, 214, 238],
      "hurtbox": { "shape": "rect", "rect": [92, 76, 166, 238] },
      "weaponTip": [220, 130]
    }
  }
}
```

Requirements:

- Grounded poses must have stable `footAnchor`.
- Body scale should be normalized upstream or fail validation.
- Weapon trails use `weaponTip`; they do not guess from range.
- Hurtboxes come from metadata or hand-authored overrides.
- Frame offsets should trend toward zero as the pipeline matures.

### 6.5 Hitbox Tracks

Attack collision should be authored as timeline geometry, not inferred only from scalar range.

Example:

```json
{
  "hitboxes": [
    {
      "from": "windup_end",
      "to": "active_end",
      "shape": "capsule",
      "a": [135, 126],
      "b": [218, 134],
      "radius": 14,
      "tags": ["slash", "parryable"]
    }
  ]
}
```

Rules:

- `AttackDefinition` remains the authority for damage and timing.
- Hitbox tracks define the presented shape during active windows.
- The runtime converts frame-local/source-pixel coordinates into world coordinates using the same scale and anchor as the sprite.
- `CombatSystem` queries overlap, then applies existing parry/block/damage logic.
- Scalar `range_units` remains as fallback and AI spacing hint, not the only hit truth.

This directly addresses unintuitive collision. What the weapon appears to threaten becomes the same geometry the combat query uses.

## 7. Leveraging Godot Without Losing AI Friendliness

### Recommended Godot Runtime Tools

Use:

- `Sprite2D` for current and previous sprite frames.
- `ShaderMaterial` for hit flash, alpha dissolve, directional smear, and palette-safe effects.
- `Node2D` transforms for offset, lean, squash/stretch, and root motion presentation.
- `Marker2D` for foot, chest, weapon tip, hit origin, and parry center.
- `Area2D` plus `CollisionShape2D` for hurtbox, pushbox, attack hitbox, and parry zone.
- Godot visible collision shapes and remote inspector for playtest debugging.
- Optional generated `AnimationPlayer` preview scenes for designers, but not as canonical data.

Avoid:

- Making `.tscn` or `.tres` resources the only animation source.
- Tying combat resolution to nondeterministic physics callbacks.
- Hiding cancel rules inside AnimationTree transitions.

### Why Not Full AnimationPlayer/AnimationTree As Source Of Truth

Full Godot-native authoring gives useful editor tools, but it creates costs that matter for WU:

- Harder for AI agents to generate and diff safely.
- Harder to enforce schema-level validation.
- Harder to keep hot-reload as a normal development loop.
- Harder to reuse animation templates across generated characters.
- Easier for combat timing and visual timing to drift again.

Use Godot's runtime machinery. Keep the authored contract in text.

## 8. Timing And Responsiveness Model

### Attack Timing

For attacks:

```text
AttackDefinition.duration       -> clip total seconds
AttackDefinition.windup_end     -> timeline marker windup_end
AttackDefinition.active_end     -> timeline marker active_end
AttackState.elapsed             -> current clip time
```

The mapping should be direct:

```text
elapsed_seconds / attack_definition.duration = normalized_clip_t
```

Named markers like `windup_end` and `active_end` resolve from the attack definition, not from frame indices.

### Cancel Windows

Cancel windows should be data:

```json
{
  "cancelInto": {
    "DASH": "recovery",
    "ATTACK_LIGHT": 0.72,
    "PARRY": "active_end"
  }
}
```

`InputBuffer` can remain the input storage mechanism. The animation graph answers whether the buffered intent can be consumed now.

### Responsiveness Rule

Gameplay should never wait for the animation to finish unless the combat rules say the state is locked. Presentation should absorb abrupt state changes with:

- short crossfades
- transition poses
- transform easing
- smear
- priority rules

This preserves the current responsive feel while making transitions legible instead of poppy.

## 9. Collision Model

### Keep Deterministic Combat

Do not make Godot physics the authority for combat. The correct authority remains:

- active windows from `AttackState`
- damage and properties from `AttackDefinition`
- defender status from `Fighter`
- technique effects from `TechniqueEngine`

### Use Godot Shapes For Presentation Queries

During active frames:

```text
CombatSystem asks attacker.presenter for active hit shapes.
CombatSystem asks defender.presenter for hurtbox/parry/block shapes.
The resolver checks deterministic overlap snapshots.
Existing parry/block/damage code applies the outcome.
```

This gives the benefits of authored collision geometry without surrendering the combat model to uncontrolled physics order.

### Debug Requirements

The debug overlay should show:

- root ground point
- foot anchor
- hurtbox
- pushbox
- active attack hitbox
- parry box
- weapon-tip trail
- active phase marker
- current state and normalized clip time

This should be toggled in playtest. If a character floats, the overlay must immediately reveal whether the problem is source art, foot anchor metadata, y-offset, scale, or root placement.

## 10. AI-Friendly Asset Contract

### Authoring-Friendly

AI agents should be able to safely change animation feel by editing text:

- JSON schema for animation graph, clips, manifests, hitboxes, and events.
- Semantic pose names instead of frame-slot coupling.
- Validation tests with precise failure messages.
- Shared clip templates for humanoids.
- Character-specific override files for scale, anchors, and hitboxes.

Example:

```text
humanoid_light_slash.template.json
character_hu.manifest.json
character_ronin.overrides.json
```

The agent should not need to know that `attack_2.png` is the strike frame. It should use `strike_extended`, and the manifest maps that pose to the file.

### Generation-Friendly

The asset pipeline should request and preserve metadata:

- stable foot anchor
- stable camera framing
- first-frame scale reference
- body bounding box
- silhouette bounding box
- head row
- feet row
- weapon tip
- pose tag

This matches the direction already documented in `docs/aiexp-requests/2026-04-30-stable-camera-and-scale.md`.

Once generation metadata is reliable:

- per-frame offset correction should mostly disappear
- eroded-bbox y-offset guessing can be removed
- weapon trails can follow real weapon-tip anchors
- hitboxes can be generated or bootstrapped from pose metadata
- validation can fail bad batches before they enter the game

## 11. Migration Plan

### Phase 0 - Measure And Expose The Current Problems

No behavior change.

Add tools/tests to measure:

- frame dimensions
- foot-anchor drift
- apparent body height drift
- y-offset consistency
- weapon-tip metadata presence
- grounded-state floating
- hitbox/range mismatch fixtures

Add a combat debug overlay mode that draws:

- ground line
- body rect
- hurtbox
- current scalar range
- foot anchor, even if initially inferred

Acceptance:

- Running the playtest can prove or disprove "characters are floating" with geometry, not impressions.
- A generated contact sheet can show per-action scale drift.

### Phase 1 - Add Animation Graph Shim Behind Existing JSON

Keep current files working.

Implement:

- `AnimationGraph` loader with a compatibility shim from current `AnimationSet`.
- transition crossfade data with conservative defaults.
- transform tracks with defaults that reproduce current offsets.
- validation for state names and clip references.

Visible win:

- state changes stop hard-popping.
- existing lunge/bob/shake values can move from `fighter.gd` into data gradually.

### Phase 2 - Introduce FighterPresenter For Hu Only

Implement `FighterPresenter` for the player while enemies keep the old draw path.

Features:

- two `Sprite2D` nodes for crossfade
- shader hit flash
- root ground anchor
- foot marker
- current frame transform track
- optional visible collision overlay

Keep old combat range math.

Acceptance:

- Hu no longer visually floats during idle, walk, dash, jump, hit, and attack.
- Crossfade removes obvious frame pops.
- Existing tests still pass.

### Phase 3 - Timeline Events Replace Attack Visual Special Cases

Move:

- active flash trigger
- weapon swing cue
- hitbox activation marker
- camera shake cue
- sfx cue

into timeline events.

Remove:

- bespoke `attack_active_started` visual contract
- phase-snapped frame special case inside `FighterVisual`

Acceptance:

- attack active flash is emitted from the general event system.
- event timing is validated against `AttackDefinition`.
- retuning attack windows retimes presentation automatically.

### Phase 4 - Hitbox/Hurtbox Pilot

Pilot with:

- Hu light attack
- Hu heavy attack
- one bandit sword attack
- one spear attack
- Iron Bear grab

Use authored rect/capsule shapes in the timeline.

Combat resolution remains deterministic:

- shape overlap determines whether the attack connects
- existing parry/block/damage code determines result

Acceptance:

- spear hits line up with spear reach
- sword sweep does not hit far outside the visible arc
- grab contact matches the boss animation
- debug overlay proves collision readability

### Phase 5 - Schema, Manifests, And Shared Templates

Add:

- JSON Schema or equivalent GDScript validation
- semantic pose manifest
- humanoid shared clip templates
- per-character overrides
- manifest-to-runtime compiler

Migrate:

- Hu
- bandit sword
- bandit spear
- ronin
- assassin
- disciple
- Iron Bear

Acceptance:

- no frame paths are referenced directly from clip timelines
- clips reference semantic poses
- validation catches missing anchors, missing hitboxes, and invalid cancel windows

### Phase 6 - Close The AI Generation Loop

After upstream aiexp metadata is available:

- regenerate one archetype with stable anchor metadata
- compare against current manual-offset pipeline
- remove most per-frame offsets for that archetype
- delete bbox/y-offset guessing for that archetype
- expand to the full roster only after the pilot is visually stable

Acceptance:

- regenerated frames import with stable feet
- weapon trails use metadata
- hitboxes can be bootstrapped from metadata
- manual offset churn drops sharply

## 12. Validation Strategy

### Headless Tests

Add tests for:

- every referenced pose has a texture
- every texture has expected dimensions
- grounded poses have foot-anchor drift within tolerance
- apparent body height variation is within tolerance
- clip events are sorted by time
- `attack_active_start < attack_active_end < duration`
- attack timeline markers match `AttackDefinition` windows
- cancel-window references point to valid states and phases
- every active attack clip has at least one hitbox
- every fighter has a hurtbox and pushbox
- hitbox fixtures overlap at expected distances and miss outside expected distances

### Visual Test Artifacts

Generate:

- per-character contact sheets with ground line and foot markers
- per-action timeline strips
- combat screenshots with collision overlay
- before/after crossfade capture
- active-window screenshots for each enemy archetype

### Playtest Checks

For each archetype:

- idle feet stay planted
- walk does not resize the character
- dash does not shrink/grow unexpectedly
- light attack contact matches weapon arc
- heavy attack contact matches anticipation and active frame
- parry/block feedback appears at contact point
- jump/fall/land do not create floating at rest
- hit reaction does not move the ground contact incorrectly

## 13. File-Level Target Architecture

Likely new files:

```text
WUGodot/scripts/visual/animation_graph.gd
WUGodot/scripts/visual/animation_clip_timeline.gd
WUGodot/scripts/visual/animation_graph_compiler.gd
WUGodot/scripts/visual/fighter_presenter.gd
WUGodot/scripts/visual/presentation_collision_bridge.gd
WUGodot/scripts/visual/animation_debug_overlay.gd
WUGodot/scripts/visual/timeline_event_bus.gd
WUGodot/scripts/visual/shaders/fighter_presenter.gdshader
WUGodot/tests/test_animation_graph.gd
WUGodot/tests/test_animation_manifest.gd
WUGodot/tests/test_presentation_hitboxes.gd
```

Likely new data:

```text
WUGodot/assets/animation_graphs/humanoid.graph.json
WUGodot/assets/animation_graphs/boss_iron_bear.graph.json
WUGodot/assets/animation_clips/humanoid_light_slash.timeline.json
WUGodot/assets/animation_clips/humanoid_heavy_slash.timeline.json
WUGodot/assets/animation_manifests/hu.manifest.json
WUGodot/assets/animation_manifests/bandit_sword.manifest.json
```

Likely modified files:

```text
WUGodot/scripts/fighter.gd
WUGodot/scripts/combat_scene.gd
WUGodot/scripts/combat_system.gd
WUGodot/scripts/visual/fighter_visual.gd
WUGodot/scripts/visual/animation_set.gd
WUGodot/tests/run_tests.gd
```

The key migration rule: keep `FighterVisual` as an adapter until `FighterPresenter` fully replaces it. Do not big-bang the renderer, collision, and asset contract at once.

## 14. Open Decisions

### 14.1 Curve Format

Options:

- JSON arrays with named easing values.
- Godot `Curve` resources generated from JSON.
- Inline cubic Bezier control points.

Recommendation:

- Start with JSON arrays and named easing values.
- Add generated Godot `Curve` preview later if designer editing needs it.

### 14.2 Shape Types

Options:

- rect only
- rect + capsule
- polygon
- generated bitmap masks

Recommendation:

- Start with rect + capsule.
- Use polygons only for boss/grab/special attacks if necessary.
- Avoid bitmap masks for MVP combat because they are harder to reason about and test.

### 14.3 AnimationPlayer Preview

Options:

- no AnimationPlayer
- generated preview-only AnimationPlayer
- AnimationPlayer as source of truth

Recommendation:

- Generate preview-only AnimationPlayer scenes after the JSON runtime is stable.
- Do not make AnimationPlayer the source of truth.

### 14.4 Metadata Strictness

Options:

- warn on missing anchors
- fail install on missing anchors
- allow fallback inference

Recommendation:

- Fail closed for combat clips.
- Warn for non-combat decorative clips.
- Allow explicit fallback only during migration.

## 15. Why This Is The Right Revamp

The current system's problems come from a mismatch:

- The art pipeline produces sparse, drifting AI keyposes.
- The runtime treats those images as stable sprite-sheet animation frames.
- The combat model uses abstract scalar ranges.
- The player judges fairness from visible weapon and body motion.

The fix is not simply "use Godot animation tools" or "generate more frames." The fix is a clearer contract:

```text
Sparse AI poses become semantic anchored keyposes.
Animation timelines synthesize motion with curves and events.
Godot nodes render, blend, shade, and expose collision geometry.
Combat remains deterministic and queries that geometry at active times.
Tests validate the contract before playtest.
```

That gives WU:

- smoother animation without requiring perfect AI frame density
- responsive combat without animation lock
- visible collision that matches animation
- less manual offset churn
- better playtest debugging
- a workflow AI agents can actually edit and verify

## 16. Final Recommendation

Adopt the hybrid architecture.

Do not throw away the JSON pipeline. Do not move the entire source of truth into Godot editor resources. Instead, build a small compiler/runtime layer that turns AI-friendly text manifests into Godot presenter nodes.

The first shippable slice should be:

1. Add measurement tests and collision/anchor debug overlay.
2. Add a compatibility animation graph wrapper around current JSON.
3. Build `FighterPresenter` for Hu only with Sprite2D crossfade, root foot anchoring, and shader hit flash.
4. Keep old combat range math until the visual presenter is stable.
5. Pilot authored hitboxes on Hu light/heavy and one bandit attack.

This path attacks the three observed issues directly:

- Different sprite sizes while animated: solved by manifests, anchor validation, and transform-stable presenter root.
- Collisions not intuitive or matching animation: solved by timeline hitbox/hurtbox geometry queried by deterministic combat.
- Animations not smooth enough: solved by crossfade, timeline curves, shader smear, and event-driven presentation on top of sparse keyposes.

