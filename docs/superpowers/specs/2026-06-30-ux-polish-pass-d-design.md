# UX Polish Pass (Category D) — Design

**Date:** 2026-06-30
**Status:** draft (pre-plan) — for user review
**Origin:** the four "Category D" polish items from the live design-review backlog (`backlog-design-reviews` memory). Four small, independent draw-layer fixes in one pass. All verified by re-capturing the affected screens (`--shot-combat` / `--capture {kind:ui}`).

**Scope:** draw/layout only, no gameplay/data changes. Each item is independent; commit separately.

---

## D1 — Boon-draft: short common no longer hollow
**Now:** offer cards are a fixed 360px (`boon_offer_scene.gd:154`) in a 580px panel (`:146`), sized for the tallest content (a 4-line cumulative epic). A 1-line common (e.g. `wind_crane_step` "+15% move speed") leaves ~60% of the card empty below the top-anchored content.
**Fix:** **trim the card to what the real content needs**, keeping top-alignment + consistent baselines across the row (not vertical-centering, which desyncs baselines):
- offer `box_height 360 → ~310` (`_get_offer_box_rect`).
- panel `height 580 → ~530` (`_get_offer_panel_rect`), recentered, so the modal stays tight (margins symmetric).
- Tune so the longest real epic (4 cumulative clauses) still fits without crowding the card edge, AND a 1-line common reads balanced.
**Verify (forced extremes, the §-validation recipe from the composition spec):**
```bash
cat > /tmp/d1.json <<'JSON'
{"kind":"ui","screen":"boon_offer","school":"wind",
 "forced_offers":[{"boon_id":"wind_descending_leaf","tier":"epic"},
                  {"boon_id":"wind_crane_step","tier":"common"}]}
JSON
./run.sh --capture /tmp/d1.json /tmp/d1.png   # then: python3 tools/assert_nonblank.py /tmp/d1.png
```

## D2 — Map: per-type glyphs + de-clashed colors
**Now:** node types are color-only (`map_scene.gd _get_node_color`), and two pairs clash: Ambush `VERMILLION_RED` vs Boss `CRIMSON #bf2652` (both red); Elite `EARTH_LIGHT #df7126` vs Shop `GOLD_BRIGHT #f8c83c` (orange vs gold). Color-only also fails colorblind players.
**Fix (recolor + glyph; glyph is the primary differentiator):**
- **Add a per-type hanzi glyph** drawn in each node and in the legend — on-brand (the game uses hanzi throughout), palette-free, instantly distinct, colorblind-safe. Cover **all rendered types incl. EVENT** (the start node is `NodeType.EVENT`, `run_state.gd:35`, and map_scene already colors/labels it at `:180/:201` but it is **missing from the current legend** — add it): Duel `斗` · Elite `精` · Ambush `伏` · Master `師` · Event `事` · Shop `商` · Rest `息` · Boss `王`. Draw a small centered glyph at each node (`map_scene.gd` node render ~`:64-69`) and beside each legend swatch (`_draw_node_legend` ~`:152-167`, and add the Event row). Keep it legible at the node's 12px radius (small glyph over/above the node — implementer's call after a capture).
- **Nudge the worst color pairs within the existing palette** (don't invent colors — palette is VINIK24-constrained): Ambush `VERMILLION_RED` vs Boss `CRIMSON` (both red) and Duel `MISTY_BLUE` vs Event `LIGHT_BLUE` (both blue) both clash — make **Boss a darker/deeper crimson** (distinct + ominous), and confirm Duel/Event and Elite/Shop read apart. With glyphs present, a small nudge suffices; reuse existing `GameConstants` constants only.
**Verify:**
```bash
echo '{"kind":"ui","screen":"map"}' > /tmp/d2.json
./run.sh --capture /tmp/d2.json /tmp/d2.png   # then: python3 tools/assert_nonblank.py /tmp/d2.png
```
Each node type distinguishable by glyph at a glance; legend shows glyph + label + color for all 8 types incl. Event.

## D3 — Rest: drop the redundant locked strikethrough
**Now:** locked rest options draw both a "Locked" chip AND a strikethrough line through the title (`rest_scene.gd:62`). The chip already communicates the state; the strikethrough reads as "removed," not "locked," and is redundant.
**Fix:** delete the `canvas.draw_line(...)` at `rest_scene.gd:62`. Keep the "Locked" chip + the dimmed `label_color`/`hint_color` (those already signal disabled).
**Verify:**
```bash
echo '{"kind":"ui","screen":"rest"}' > /tmp/d3.json
./run.sh --capture /tmp/d3.json /tmp/d3.png   # then: python3 tools/assert_nonblank.py /tmp/d3.png
```
Locked rows show the chip + dimming, no strikethrough.

## D4 — Mid-fight: show the actual equipped boons (not just school chips)
**Now:** during combat the compact panel shows `技藝 N` + active-**school** chips (`combat_scene.gd:864-869`), but not *which* boons — the player's specific build is only visible by pausing.
**Fix (restrained — combat clutter is the risk):** expand the compact panel to list the **equipped boons per filled slot**, compact and school-colored, sourced from `_boon_loadout.serialize()["slots"]` (same data `loadout_view.gd:14` uses). Keep it small/low-opacity and bounded (only filled slots; abbreviate long names) so it doesn't compete with the fight. If it reads cluttered in the capture, fall back to slot-pips (one school-colored dot per filled slot) rather than names.
**Verify:** `--shot-combat` can't set a loadout (it takes only a dir/archetype, `run.sh:115`). Use a **`kind:"matchup"` capture with a `build`** — `_apply_capture_build` (`main.gd:379,491`) reads `build` as an array of `{boon_id, tier}` and applies it before combat setup:
```bash
cat > /tmp/d4.json <<'JSON'
{"kind":"matchup","archetype":"bandit_swordsman","state":"01_idle",
 "build":[{"boon_id":"wind_descending_leaf","tier":"epic"},
          {"boon_id":"wind_crane_step","tier":"common"}]}
JSON
./run.sh --capture /tmp/d4.json /tmp/d4.png   # then: python3 tools/assert_nonblank.py /tmp/d4.png
```
The compact loadout panel (bottom-left, clear of the capture-mode debug overlay) shows the equipped boons; HUD still readable, fight not obscured. If it reads cluttered, switch to the slot-pip fallback.

---

## Validation (whole pass)
- `./run.sh --import` + `./run.sh --test` green (draw-only; no test asserts pixel rects).
- Re-capture all four surfaces (D1 boon_offer, D2 map, D3 rest, D4 combat) and eyeball; `assert_nonblank` on each.

## Out of scope
- Map node *icons as sprites* (hanzi glyphs are the chosen lightweight route).
- Any boon/rest/map data or behavior change.
- Boon-draft rarity/composition beyond the D1 height trim (already shipped).

## Sequencing (independent; commit per item)
1. D3 (delete one line) → capture rest.
2. D1 (card/panel height trim) → forced-offer capture.
3. D2 (glyphs + Boss recolor) → map capture.
4. D4 (equipped-boon compact list, pip fallback) → combat capture.
