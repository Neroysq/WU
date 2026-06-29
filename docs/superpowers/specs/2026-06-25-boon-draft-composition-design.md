# Boon-Draft Composition — Design

**Date:** 2026-06-25
**Status:** draft (pre-plan) — for user review
**Origin:** design-review finding **N1** (composition half). The rarity half (chips + rarity borders + school accent) already shipped; this fixes the remaining issue: the draft floats as a short band with ~60% dead vertical space.

**Goal:** Make the boon-offer screen read as an intentional centered modal that uses the frame, not a 430px band floating in a 1080 frame.

**Scope:** Layout-only in `scripts/scenes/boon_offer_scene.gd` — no new info, no logic/data change. **Moderate scale-up** (chosen over full-frame to avoid cavernous 1-line commons). One intended side effect: `_get_offer_box_rect()` also drives hover/click hit-testing (`:159`, `_get_hovered_offer_index`), so the larger card grows the clickable target — desirable (bigger target), draw-rect and hit-rect stay one and the same. **Only the offer-draft path scales; the school-choice path is left unchanged** (see §2).

---

## 1. Current state (why it floats)
Frame is 1920×1080. `_get_offer_panel_rect()` (`boon_offer_scene.gd:144-147`) makes a **1320×430** panel positioned at `(VIEW_HEIGHT - 430)*0.5 - 38` → y≈287..717. Cards are **224px** at `panel.y + 138` (`_get_offer_box_rect`, :149-157). So the panel occupies ~40% of the height, leaving ~60% empty (split top/bottom, with a 38px upward nudge). Width (1320, centered → ~300px side margins) is fine; **height is the problem**.

## 2. Target composition (moderate)
A centered modal at ~54% of the frame height with symmetric margins; taller cards so descriptions breathe.

- **`_get_offer_panel_rect()`** — make height **conditional on the path** (the method already reads `offers`/`school_choices`): for the **offer** path, height `430 → 580`, centered cleanly `(VIEW_HEIGHT - height) * 0.5` (drop the `- 38.0` nudge) → panel y≈250..830, ~250px symmetric margins. For the **school-choice** path, keep the current `430` + `- 38.0` (unchanged). Width unchanged (`min(1320, VIEW_WIDTH - 180)`).
- **`_get_offer_box_rect()`** — **only the offer branch scales**: card top offset `panel.y + 138 → panel.y + 150`; offer `box_height 224 → 360`. **Leave the school-choice `box_height` at `150`** — school choices render through `UiDraw.reward_option`, whose label/body are fixed at `y+36`/`y+66` (`ui_draw.gd:40-41`); a taller box would go top-heavy. `gap`/`box_width`/x-layout unchanged. (If the school-choice path is ever restyled, redistribute `reward_option` first — out of scope here.)
- **`_draw_offer_card()`** — redistribute content into the taller card so it reads balanced (not top-loaded with a void below):
  - Keep the 6px school-accent top strip and the rarity border.
  - Rarity chip stays at `card.y + 18`; kind/slot stays top-right.
  - Boon name: `card.y + 78 → ~card.y + 100`, size `22 → 24`.
  - Description: `body_y ~card.y + 116 → ~card.y + 150`, line height `19 → 22`, with the wider vertical room for 3-line epics.
  - Add comfortable bottom padding; tune so a 1-line common still looks balanced (content block fills the upper ~two-thirds with intentional breathing room below — consistent across all three cards).
  - Selection lift (`-8`) and cursor unchanged.

Numbers are starting points; tune in-engine so (a) margins read symmetric, (b) the longest real description (3-line epic) fits without overflow, (c) a 1-line common doesn't look hollow.

## 3. Testing / verification
`./run.sh --capture` takes a **spec-file path** (`run.sh:22,142`), not inline JSON. Write a temp spec then capture. Random `boon_offer` captures generate *normal* offers (`main.gd:417`) and may not surface the long case, so use **`forced_offers`** (`main.gd:447`) to pin both extremes — descriptions are **cumulative across tiers** (`boon_text.gd:20,131`), so a high tier stacks all lower riders.

- **Long case (3-line epic) + short case (1-line common)** in one capture — `wind_descending_leaf` at `epic` stacks dash_stab + momentum_deflect + momentum + momentum_flurry (`Boons.json:379`); pair it with a genuinely short common, `wind_crane_step` common = a single `stat_delta` rendering as "+15% move speed" (`Boons.json:446`). (Don't use `wind_descending_leaf` common as the short case — its common already carries a `momentum_deflect` rider, so it's two clauses, not one line.)
  ```bash
  cat > /tmp/wu-boon-spec.json <<'JSON'
  {"kind":"ui","screen":"boon_offer","school":"wind",
   "forced_offers":[{"boon_id":"wind_descending_leaf","tier":"epic"},
                    {"boon_id":"wind_crane_step","tier":"common"}]}
  JSON
  ./run.sh --capture /tmp/wu-boon-spec.json /tmp/wu-boon.png
  ```
  Inspect `/tmp/wu-boon.png`: panel ~54% height, centered with symmetric margins; the epic's full cumulative description fits without crowding the card edge; the short common doesn't look hollow. `python3 tools/assert_nonblank.py /tmp/wu-boon.png` passes.
- **School-choice unchanged** — capture `{"kind":"ui","screen":"school_choice"}` (via its own temp spec file) and confirm it looks exactly as before (panel + boxes untouched).
- **No regression:** `./run.sh --import` + `./run.sh --test` stay green (draw-only; no test asserts pixel rects — confirm nothing else references the old `430`/`224`/`138` constants).

## 4. Out of scope
- Loadout context ("which slot / what it replaces") — considered, deferred; this is composition only.
- Rarity encoding (already shipped).
- Any change to offer generation, selection, or data.

## 5. Sequencing
1. Adjust `_get_offer_panel_rect` + `_get_offer_box_rect` — **offer path only** (conditional height; school-choice branch untouched), recenter.
2. Redistribute `_draw_offer_card` internals for the taller card.
3. Capture via **forced_offers spec files** (long epic + short common, §3) + a school_choice capture; eyeball proportions against the three tuning constraints; confirm import/test green.
