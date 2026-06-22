# Handoff — Venom Light via Seedance (proper motion)

**To:** implementer · **Date:** 2026-06-22
**Supersedes** the 5-keypose stopgap (`venom_hu_attack_light` step-hold). Goal: a **smooth multi-frame** Venom light, generated with Seedance (`aiexp animate-video`) like the combat walk, replacing the keyframe step.

Method per [[video-gen-walk-prompt]]: genre-framed prompt + pin both ends + strike **in place** (presenter handles travel) + judge color on **master PNGs**, never downscaled GIFs.

## 1. Generate (Seedance / aiexp animate-video)
- **Pin start-frame:** `/tmp/venom_light_kf/K1_windup_start.png` (approved coil — anchors Hu's identity/style).
- **Pin end-frame:** `/tmp/venom_light_kf/K5_recovery.png` (approved re-coil, near guard).
- The approved `K2/K3/K4` describe the intended path (coil → full-reach fang-lash + venom spray → held extension); use them to steer the prompt, not as hard pins.

**Prompt (genre-framed):**
> 2D wuxia fighting-game **venom-sect LIGHT sword attack**. From a low coiled serpent stance, **explosively lash the sword forward in a rising fang-thrust to full extension**, flicking venom-green droplets and spray off the blade tip, then **re-coil the blade back toward a low guard**. Fast, snappy, exaggerated wuxia flourish. Striking **in place without translating across the frame**. Keep this character's exact pixel-art style, blue-grey robe, proportions, and palette.

**Negatives:** high knees, deep drifting lunges, floating/hovering, translating across the frame, camera movement, style drift, extra characters, mouth open/shouting.

If the result is too static, push the prompt for more motion ("one explosive full-reach thrust") rather than unpinning.

## 2. Harvest + normalize
- Harvest the output frames; **keep the span that reads windup → active → recovery**, drop dead/duplicate frames.
- Normalize each kept frame onto the Hu action canvas: scale so the **character matches idle** (judge overall char vs idle, not head box) and **recompute `footAnchor`** per frame (build-6 lesson — stale anchors float). Seedance frames from one pinned start are usually size-consistent, so **prefer one clip scale**; only go per-frame if they drift. See [[judge-art-size-overall-in-game]].

## 3. Author (replace the 5-keypose clip)
- Install harvested PNGs under `WUGodot/assets/sprites/characters/hu/venom/` (replace the 5 stopgap poses).
- `skins/venom.manifest.json`: one pose per kept frame (path, footAnchor, weaponTip at blade tip — far-forward on active, base-light hurtbox).
- `skins/venom/venom_hu_attack_light.timeline.json`: keyposes mapping the harvested frames across the phases, evenly through windup (0→`windup_end`), active (`windup_end`→`active_end`), recovery (`active_end`→1.0). Keep `id`, `"duration":"fromAttackDef"`, the `attack_active_start`/`attack_active_end` events at the anchors, and a `smear` track over the lash. Carry a per-frame `scaleX`/`scaleY` track only if normalization needed per-frame scales.

## 4. Verify
- `./run.sh --import && ./run.sh --test` → `failed: 0`; `./run.sh --anchor-sanity` clean.
- Diff-vs-base active capture `cmp` 1; determinism `cmp` 0; `assert_nonblank` ok.
- Drop the harvested frames in `/tmp/venom_light_kf/` (and update `idle.png` ref unchanged) so I can rebuild the **motion preview** to confirm it now reads smooth, not stepped.

## 5. Gate 2 — ✋ STOP
Report in-game stills + the rebuilt motion preview for approval before heavy → dash (which will use this same Seedance pipeline).
