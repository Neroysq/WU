# Combat Set Install — Implementer Handoff

**Date:** 2026-07-09 · **All art user-approved.** Recipes referenced, not repeated.

## What ships
Canon at `art/canon/hu/` (+ `canon.manifest.json` provenance): pins k1–k7; clips
(16 frames each + previews): `clips/attack_light/` · heavy (candidates/…/heavy/v2) ·
deflect (candidates/…/block) · jump (candidates/…/jump/v7-noflip) ·
back-dash (`clips/dash/`). Promote the three still under candidates/ to
`art/canon/hu/clips/` on install.

## Steps
1. **Batch mirror (deterministic):** ALL player art flips horizontally at install —
   pins k1–k4, k7 and every clip frame (k5/k6 + dash clip are already left-facing;
   do NOT double-flip; jump v7 frames face right → flip). Final convention:
   `2026-07-08-combat-orientation-flip.md` GROUND TRUTH section (player right,
   faces left, NEVER runtime-flipped; enemy keeps runtime flip).
2. **Orientation flip in-game:** spawn/facing changes per that spec + its watchlist
   (world-absolute input, direction signs, HUD sides, enemy double-flip).
3. **Clip install:** per the venom-handoff recipe (skins manifest poses w/
   footAnchor + weaponTip per frame; timeline JSON mapping frames across
   windup/active/recovery; `duration: fromAttackDef`; attack_active events;
   smear track where noted). Idle = k1 (2-frame breath can reuse the old relaxed
   idle treatment later; static k1 acceptable first pass). Walk: pin to k1 —
   generate later if step-hold reads poorly.
4. **Verify:** `./run.sh --import && ./run.sh --test` (failed: 0), anchor-sanity,
   captures nonblank + diff, and the standing rule: judge scale IN-GAME vs idle.
   Acceptance extra: per-clip HEAD-SIZE constancy already validated; spot-check
   in-game.

## Deferred (on record)
Forward-dash variant · K7 wrist-point install (experimental) · hero-sound
iteration · relaxed idle/walk as out-of-combat set · enemy art canon (Xiong Tie
etc. — next canon tasks).
