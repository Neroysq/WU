# Boon-Draft Composition — Design

**Date:** 2026-06-25
**Status:** draft (pre-plan) — for user review
**Origin:** design-review finding **N1** (composition half). The rarity half (chips + rarity borders + school accent) already shipped; this fixes the remaining issue: the draft floats as a short band with ~60% dead vertical space.

**Goal:** Make the boon-offer screen read as an intentional centered modal that uses the frame, not a 430px band floating in a 1080 frame.

**Scope:** Pure layout in `scripts/scenes/boon_offer_scene.gd`. No new info, no behavior change, no new data. **Moderate scale-up** (chosen over full-frame to avoid cavernous 1-line commons).

---

## 1. Current state (why it floats)
Frame is 1920×1080. `_get_offer_panel_rect()` (`boon_offer_scene.gd:144-147`) makes a **1320×430** panel positioned at `(VIEW_HEIGHT - 430)*0.5 - 38` → y≈287..717. Cards are **224px** at `panel.y + 138` (`_get_offer_box_rect`, :149-157). So the panel occupies ~40% of the height, leaving ~60% empty (split top/bottom, with a 38px upward nudge). Width (1320, centered → ~300px side margins) is fine; **height is the problem**.

## 2. Target composition (moderate)
A centered modal at ~54% of the frame height with symmetric margins; taller cards so descriptions breathe.

- **`_get_offer_panel_rect()`** — height `430 → 580`; vertical position centered cleanly: `(VIEW_HEIGHT - height) * 0.5` (drop the `- 38.0` nudge). Result: panel y≈250..830, ~250px symmetric top/bottom margins. Width unchanged (`min(1320, VIEW_WIDTH - 180)`).
- **`_get_offer_box_rect()`** — card top offset `panel.y + 138 → panel.y + 150`; offer `box_height 224 → 360`; school-choice `box_height 150 → 220` (proportional bump so the school-pick path stays consistent — it reuses this rect). `gap`/`box_width`/x-layout unchanged.
- **`_draw_offer_card()`** — redistribute content into the taller card so it reads balanced (not top-loaded with a void below):
  - Keep the 6px school-accent top strip and the rarity border.
  - Rarity chip stays at `card.y + 18`; kind/slot stays top-right.
  - Boon name: `card.y + 78 → ~card.y + 100`, size `22 → 24`.
  - Description: `body_y ~card.y + 116 → ~card.y + 150`, line height `19 → 22`, with the wider vertical room for 3-line epics.
  - Add comfortable bottom padding; tune so a 1-line common still looks balanced (content block fills the upper ~two-thirds with intentional breathing room below — consistent across all three cards).
  - Selection lift (`-8`) and cursor unchanged.

Numbers are starting points; tune in-engine so (a) margins read symmetric, (b) the longest real description (3-line epic) fits without overflow, (c) a 1-line common doesn't look hollow.

## 3. Testing / verification
- **Visual (primary):** `./run.sh --capture {"kind":"ui","screen":"boon_offer"}` → inspect the PNG; the panel should fill ~54% height, centered with symmetric margins, cards taller with the description not crowding the card edge. `tools/assert_nonblank.py` passes.
- Also capture **school_choice** (`{"screen":"school_choice"}`) to confirm the school-pick path still lays out correctly with the bumped box height.
- **No regression:** `./run.sh --import` + `./run.sh --test` stay green (this is draw-only; no test asserts pixel rects, but confirm nothing references the old constants).

## 4. Out of scope
- Loadout context ("which slot / what it replaces") — considered, deferred; this is composition only.
- Rarity encoding (already shipped).
- Any change to offer generation, selection, or data.

## 5. Sequencing
1. Adjust `_get_offer_panel_rect` + `_get_offer_box_rect` (panel/card sizing + recenter).
2. Redistribute `_draw_offer_card` internals for the taller card.
3. Capture boon_offer + school_choice, eyeball proportions, tune; confirm import/test green.
