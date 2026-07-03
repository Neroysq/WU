# Identity Content Pass Results (九仙山 slice 1)

Baseline plan: `docs/superpowers/plans/2026-07-03-identity-content-pass.md` at `76f25e3`.

## Outcome

Implemented the slice-1 identity revamp as a display/content pass:

- Schools are now the Nine's animal styles: Snake, Ox, Crane, Bear, Swallow, Eagle. School ids, signatures, and theme colors stayed fixed.
- Boons and technique display names were renamed in place where the old animal identity conflicted with the new table. Internal ids/effect types/numbers stayed fixed.
- Six school pictogram PNGs ship under `WUGodot/assets/icons/schools/`, with `UiDraw.school_mark()` using the PNG when present and falling back to hanzi text when missing.
- Title, enemy names, events, boss beats, ending text, map header, reward/forget/shop/rest/event/reward backgrounds, and loadout/combat chips were updated to the 九仙山 fiction.
- Depth-band palette is wired through covered scene backgrounds and capture specs via `tier_band`/`tier`; menu, settings, and endings remain static by design.
- Capture plumbing now covers `victory`, `game_over`, and `forget`, plus seeded forget techniques and UI depth-band overrides.

## Notable Implementation Notes

- `soft_drunken_form` is now **Yielding Crane** in boon display text, stance display payload, and boon-text describer. The internal effect type remains `stance_drunken`.
- Technique names shown by reward/forget surfaces were also cleaned up (`Crane's Beak`, `Swallow Wing`, `Swallow Skim`, `Yielding Crane`, `Bear Stance`) so old display copy does not leak through those views.
- Xiong Tie's boss beat renderer now accepts `caption := ""`; the intro beat has no death caption, and the death beat uses the new hollow gate text.
- `_save_viewport_png()` now waits two process frames rather than `RenderingServer.frame_post_draw`, which made capture commands return reliably in this environment.

## Capture Inventory

Generated under `/tmp/wu_identity_captures`:

| Gate | Files |
|---|---|
| School-choice icon coverage | `school_choice_a.png`, `school_choice_b.png` |
| Boon offer icons | `boon_offer_icon.png` |
| Combat chips/loadout | `combat_loadout_icons.png` |
| Map loadout | `map_loadout_icons.png` |
| Forced event copy | `event_shrine.png` |
| Boss intro beat | `boss_intro.png` |
| Endings/forget | `victory.png`, `game_over.png`, `forget.png` |
| Depth pairs | `map_foothill.png` / `map_high.png`, `combat_foothill.png` / `combat_high.png`, `boon_foothill.png` / `boon_high.png`, `reward_foothill.png` / `reward_high.png` |

All 18 captures passed `python3 tools/assert_nonblank.py`. The `map_high.png` spot-check shows the colder high-altitude wash while preserving map readability.

## Verification

- `./run.sh --import` passed.
- `./run.sh --test` passed: **631 passed, 0 failed**.
- Stale-string scan over `WUGodot/data`, `WUGodot/scripts`, and `WUGodot/tests` found no old identity strings for the renamed surfaces.
- 30-seed greedy/heuristic playtest on this implementation: `win_rate=0.40`, `avg_depth=5.6`, `timeouts=0`.
- Clean-worktree baseline at `76f25e3`, same command after import: `win_rate=0.40`, `avg_depth=5.6`, `timeouts=0`.

The current implementation therefore shows no gameplay drift versus the exact pre-pass baseline. The older plan note of `~0.49` was from an earlier balance state, not this HEAD.

## User Review

The pass is ready for visual review from the capture set. The main subjective calls are the six school icons and the strength of the depth-band wash.

## User eyeball verdicts (2026-07-03, via review board)
1. **Map must be UPSIDE-DOWN — we are climbing.** Current layout puts tier 0 at the top and the boss at the bottom, which reads as a descent. **Fix directive (display-only, one function):** in `map_scene.gd:_get_map_node_position` (`:137-139`), invert the vertical axis — `y = top + (tiers - 1 - node.tier) * tier_height` — so the start/foothills sit at the BOTTOM and the gate/summit at the TOP. All callers (edges, nodes, hover/click at `:59-69`, `:132`) route through this function, so hit-testing follows automatically. Check the next-node picker highlight still reads well; re-capture `map_foothill`/`map_high` + assert_nonblank. (Bonus: the bamboo silhouettes at the screen bottom now correctly read as the foothills.)
2. **Depth-band wash: ACCEPTED as-is.** There IS a visible difference. Queued enhancement (later atmosphere pass, art track): **cloud/mist effects that thicken with altitude**.
3. **School icons: provisionally accepted; revamp queued.** Proper pictograms come later — likely produced with **pixelforge** — and BEFORE that, the project needs a **consistent art style design** (the art-track opener).

**Slice 1 status: ACCEPTED** with the map-inversion fix as the one follow-up change.
