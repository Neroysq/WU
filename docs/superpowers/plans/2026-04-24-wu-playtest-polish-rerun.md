# WU Playtest Polish — Rerun Findings

**Date:** 2026-04-24
**Source:** Playtest re-run after landing commit `a3d0ab8 polish playtest ui readability and arena presentation`. Captures at `/tmp/wu-playtest-2026-04-24-rerun/` (16 states).
**Companion plan:** `docs/superpowers/plans/2026-04-24-wu-playtest-polish.md` (rev 3) — this file extends that plan with the four issues that surfaced after the first implementation landed.

---

## Findings summary

| # | Priority | Issue |
|---|---|---|
| 1 | P0 | `_wrap_text` type-error aborts wrapped body-copy draw on reward cards and event screens |
| 2 | P1 | Shop footer overlaps the last item row — "Insufficient gold" and the instruction line stack on "Forget Technique / 25g" |
| 3 | P1 | Victory return prompt fades to near-zero alpha during pulse and sits on the dark ground band outside the scroll |
| 4 | P2 | Main menu title card is underweight at 1080p — upper half reads as wasted space |

---

## P0 — `_wrap_text` type error at `main.gd:969`

**Scope.** `_wrap_text` is only reached through `_draw_text_block`, which has three call sites:

- Event body at `main.gd:658` (event runner text).
- Event result message at `main.gd:661`.
- Reward card description at `main.gd:913`.

Shop descriptions (`main.gd:714`) and forget-technique descriptions (`main.gd:785`) draw through plain `_draw_text` and are **not affected by this bug** — they were already rendering in the re-shoot. The earlier framing that lumped shop/forget into this P0 was wrong.

**Evidence.** `/tmp/wu-playtest-2026-04-24-rerun/03_reward_technique.png` — three technique cards render titles with no body descriptions. `/tmp/wu-playtest-2026-04-24-rerun/05_event_choice.png` and `06_event_result.png` — event body/result copy is missing or partial.

**Root cause.** `main.gd:969`:

```gdscript
var words: Array[String] = paragraph.split(" ", false)
```

`String.split()` returns `PackedStringArray` in Godot 4. Assigning it to `Array[String]` is a runtime type error — the function aborts, every caller via `_draw_text_block` receives an empty lines array, and the description draw is silently skipped. The headless test suite never exercises the helper, so `./run.sh --test` stayed green while the screens were broken (see P0-regression section below).

**Fix.** Drop the type annotation on line 969:

```gdscript
var words := paragraph.split(" ", false)
```

`PackedStringArray` supports `.is_empty()`, `.size()`, `[i]` indexing, and iteration, so the rest of `_wrap_text` needs no other changes.

**Verify visually.** Re-shoot only the screens that route through `_draw_text_block`:

- `03_reward_technique.png` — technique descriptions must appear under each card title.
- `05_event_choice.png` — event body copy must appear between title and choices.
- `06_event_result.png` — event result paragraph must render in full.

Shop / forget-technique do **not** need re-verification for this bug (they go through `_draw_text`, which is unaffected). They stay in scope only for the P1 shop-footer fix below.

**Effort.** 2 min + visual verify on the three event/reward shots.

### P0-regression — add a narrow test for the wrapper

**Why.** The bug shipped because `_wrap_text` has no test coverage; typed GDScript on a helper is exactly the class of issue CI should catch. Fixing the one call site without fixing the testing blind spot leaves the next similar bug invisible.

**Proposal.** Extract `_wrap_text` from `main.gd` into a static utility so it can be invoked without scene setup:

```
WUGodot/scripts/util/text_wrapping.gd   # new — class_name TextWrapping; static wrap_lines(font, text, max_width, size)
WUGodot/tests/test_text_wrapping.gd     # new — loads Fonts.body_font(), asserts:
                                        #   - empty input returns [""]
                                        #   - "a b c" wraps to one line at wide max_width
                                        #   - a paragraph with enough words forces a second line
                                        #   - newline-delimited paragraphs produce separate line entries
                                        #   - regression: PackedStringArray-typed intermediates don't throw
```

`main.gd`'s existing `_wrap_text` becomes a thin forwarder: `return TextWrapping.wrap_lines(_font_for_size(size, display), text, max_width, size)`. Adds the test to `tests/run_tests.gd` so `./run.sh --test` now exercises the path that shipped broken.

**Effort.** 20 min (extract + 5 assertions + wire into run_tests.gd).

### Open assumption — CJK wrapping

The wrapper currently splits on spaces only. Chinese body copy in the event / shop flow is not planned for this pass, so the space-split behavior is sufficient. If Chinese body copy lands in a later pass, the wrapper will need a per-glyph break path (Unicode east-asian-width aware). Flagged here so it isn't forgotten — out of scope for this rerun.

---

## P1 — Shop footer collision at `main.gd:717-719`

**Evidence.** In `/tmp/wu-playtest-2026-04-24-rerun/07_shop.png`, the "Forget Technique / 25g" row, the "Insufficient gold." status line, and the "W/S to browse, Enter to buy, Q or Esc to leave" instruction line are all stacked on the same horizontal band near the bottom of the panel.

**Root cause.** Shop panel at `main.gd:684` is `Rect2(300, 122, VIEW_WIDTH-600, 580)`, bottom at `y=702`. With 6 items × 82-px row spacing starting at `y=236`:

- Last row occupies `y=618..688`.
- Description line draws at `y=674`.
- `_shop_message` draws at `panel.end.y - 58 = 644` (inside last row).
- Instructions draw at `panel.end.y - 28 = 674` (exactly overlapping description).

The panel shrink in rev 1 went too far given 6 fixed items.

**Fix.** Grow the panel height to reserve a footer band:

```gdscript
var panel: Rect2 = Rect2(300.0, 110.0, float(GameConstants.VIEW_WIDTH) - 600.0, 740.0)
```

- Height `580 → 740` gives ~60 px of clearance between the last row's description (`y≈674`) and the footer message (`panel.end.y - 58`).
- Top anchor `122 → 110` keeps the panel vertically centred.

**Verify.** Re-shoot `07_shop.png` and confirm no text overlap. If still tight, raise height further (up to 820) — there's room in a 1080-tall viewport.

**Effort.** 5 min.

---

## P1 — Victory prompt faint / clipped at `main.gd:850`

**Evidence.** In `/tmp/wu-playtest-2026-04-24-rerun/15_victory.png` the "Press Enter to return" prompt reads as clipped / almost invisible, similar to the pre-fix game-over pattern.

**Root cause.** Two compounding issues at `main.gd:850-851`:

1. **Pulse alpha floor is the old unfixed formula.** `0.5 + 0.5 * sin(_cursor_flash * 4.0)` → range `[0.0, 1.0]`. Spends half its time under 30 % alpha. The game-over prompt already got fixed to `[0.55, 1.0]` in an earlier pass; victory was missed.
2. **Position is outside the scroll frame.** The prompt draws at `scroll.end.y + 30` — below the scroll, on the dark ground band, where contrast is worst.

**Fix.** Two coordinated edits at `main.gd:850-851`:

```gdscript
var pulse: float = 0.775 + 0.225 * sin(_cursor_flash * 4.0)
_draw_centered_text("Press Enter to return", center_x, scroll.end.y - 28.0, Color(GameConstants.COLOR_TEXT_ACCENT.r, GameConstants.COLOR_TEXT_ACCENT.g, GameConstants.COLOR_TEXT_ACCENT.b, pulse), 18)
```

- Alpha floor raised from `0.0` → `0.55` (same formula as the game-over fix).
- Prompt now draws inside the scroll at `scroll.end.y - 28`, consistent with the shop / rest footer convention.

**Verify.** Re-shoot `15_victory.png`. Prompt should read cleanly against the scroll parchment at both peak and trough of the pulse.

**Effort.** 5 min.

---

## P2 — Main menu title card underweight

**Evidence.** `/tmp/wu-playtest-2026-04-24-rerun/01_main_menu.png` — the title card with its border sits in the **upper** half at roughly 520 × 248 px. The bottom third (bamboo strip + prompt + chapter line) is working well, but there is a wide empty band between the title card and the bamboo strip.

**Current values (verified at `main.gd:541-545`):**

- `title_y = VIEW_HEIGHT * 0.28` — title vertical centre at 28 % viewport height (302 px from top), not 40 %.
- `title_panel = Rect2(center_x - 260, title_y - 92, 520, 248)` — card top at y ≈ 210, bottom at y ≈ 458.
- `"武"` glyph at size **132**, not 160.
- Prompt anchored at `VIEW_HEIGHT * 0.89` (y ≈ 961).
- Between title card bottom (≈ 458) and prompt (≈ 961) sits ~500 px of near-empty space broken up only by the bamboo silhouette strip.

**Fix options** (pick one; or stack them):

- **A. Bigger title card.** Grow the card ~1.4× (520 → 720 wide, 248 → 340 tall) and bump the `"武"` glyph size from 132 → ~200. More presence absorbs the empty band.
- **B. Drop the title anchor downward.** Move `title_y` from `VIEW_HEIGHT * 0.28` → `VIEW_HEIGHT * 0.36` (or as far as `0.40`). This moves the card **down** the screen, shrinking the band between title and bamboo strip. (Correction vs. an earlier draft that said "38 % and this drops it" — 38 % is higher than 28 %, not lower. The fix direction is toward larger percentages.)
- **C. Ornament stroke.** Add a thin horizontal ink stroke above and/or below the title card, ~600 px wide, to anchor it in the empty band without new art assets.

**Recommended:** **A + B** together — enlarge the card to ~720 × 340 and drop `title_y` to `VIEW_HEIGHT * 0.36`. C is cosmetic extra if time allows.

**Verify.** Re-shoot `01_main_menu.png`. The card should sit in the middle third of the screen and connect visually with the bamboo strip below. No large empty band above **or** below the title.

**Effort.** 10 min.

---

## Order of operations

1. **P0 fix + P0-regression test** — one-line fix at `main.gd:969`, plus extract `_wrap_text` into `scripts/util/text_wrapping.gd` and add `tests/test_text_wrapping.gd` so CI catches this class of issue going forward. Unblocks visual verification of reward + event screens.
2. **P1** — shop panel height + victory prompt. Both are small coordinate/alpha edits; bundle them.
3. **P2** — menu title card. Cosmetic; land last so the re-shoot shows all deltas at once.

Total: ~45 min of work (was 25 before the regression test was added), one re-import, one re-shoot.

---

## Preconditions

- Commit `a3d0ab8 polish playtest ui readability and arena presentation` landed (see companion plan rev 3 for full scope).
- Godot 4.6.2+ available via `./run.sh`.
- Playtest capture tooling available to re-shoot the 16 states into `/tmp/wu-playtest-2026-04-24-rerun-v2/` (or similar) for diff against the current `/tmp/wu-playtest-2026-04-24-rerun/`.

---

## Verification checklist after implementation

- [ ] Reward card body descriptions render correctly (no empty cards below the title).
- [ ] Event body copy renders in full on both `05_event_choice.png` and `06_event_result.png`.
- [ ] `_wrap_text` / `TextWrapping.wrap_lines` has dedicated test coverage — `./run.sh --test` now exercises the helper and the new tests fail if the type-error regresses.
- [ ] Shop footer band is visually separated from the last item row (no overlap at either peak or trough pulse). Shop / forget descriptions keep rendering as before (not affected by P0).
- [ ] Victory return prompt stays legible at minimum pulse alpha and sits inside the scroll frame.
- [ ] Main menu composition: title card in the middle third, no dead band above or below. Code now uses `title_y = VIEW_HEIGHT * 0.36` and `"武"` glyph at ~200.
- [ ] `./run.sh --test` passes (139+ tests; expect 139 + N where N is the number of new wrapper assertions).
- [ ] 16-state re-shoot diffs cleanly against `/tmp/wu-playtest-2026-04-24-rerun/` for these four deltas and no regressions elsewhere.

---

## What "done" looks like

No ▯ boxes, no text overlap, no invisible prompts, and a main menu where the title card actually feels like the anchor of the screen. After this pass, the polish work tracked across both this plan and its rev-3 companion should ship together as a single milestone gate.

---

## Revision notes (rev 2, 2026-04-24)

Three items corrected after a second round of review:

1. **P0 blast radius over-stated.** Rev 1 claimed `_wrap_text` broke reward / shop / event and told implementation to re-verify shop + forget-technique. In fact `_wrap_text` is only reached through `_draw_text_block`, which has three call sites: event body (`main.gd:658`), event result (`:661`), and reward card description (`:913`). Shop and forget-technique descriptions go through plain `_draw_text` and were never affected by this bug. P0 verification reduced to reward + event shots.
2. **Testing blind spot remained unaddressed.** Rev 1 noted the bug shipped because the wrapper has no test coverage, but the verification plan still relied only on `./run.sh --test` + a re-shoot. Rev 2 adds a P0-regression step: extract `_wrap_text` into `scripts/util/text_wrapping.gd`, thin-forward from `main.gd`, and add `tests/test_text_wrapping.gd` so CI catches this class of issue going forward. Total effort bumped 25 min → 45 min.
3. **P2 menu numbers were wrong and contradictory.** Rev 1 said "move from 40 % → 38 % drops the card" (38 % is higher, not lower) and cited a `"武"` glyph size of 160 (actual is 132). Rev 2 re-reads `main.gd:541-545` and uses the real current values: `title_y = 0.28 * VIEW_HEIGHT`, glyph 132. Recommended fix is to **raise** the percentage (drop downward) to ~0.36 and enlarge the glyph to ~200.

### Open assumption carried forward

The `_wrap_text` wrapper breaks on spaces only. If Chinese event / shop body copy ships in a later pass, the wrapper needs a per-glyph break path (Unicode east-asian-width aware). The PackedStringArray fix in this rerun is necessary but not sufficient for CJK body-copy wrapping. Flagged here so it isn't forgotten; out of scope for this rerun.
