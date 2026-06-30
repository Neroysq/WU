# WU Funness — Strategic Direction (grill verdict)

**Date:** 2026-06-30
**Status:** direction (supersedes the working priority order)
**Origin:** a "grill me on the funness of WU" session, grounded in playtest of `b2d467b`.

## The verdict
**The core fun loop is flat today.** Player's own model: the **duel is the heart**; **build diversity** keeps it from going stale; the **journey** is the strategy/resource layer — and the latter two only matter if the heart is fun. The heart is currently flat across **audio, animation, and actions** ("so so"). Therefore everything built recently (difficulty tuning, per-school hooks, UX polish, the pause menu) is **decoration on a flat core.**

## The fix path (decided)
1. **Juice-first, not redesign.** The combat *system* is proven (it sims, balances, differentiates builds across the harness). The flat part is *feel*, not mechanics. Do **not** rework the action verbs yet; re-judge their *depth* only after the duel is juiced.
2. **Audio pass — NOW (highest ROI in the project).** Wire ~10 serviceable SFX to the signals that already fire (`hitstop`, `damage_dealt`, parry/block branches, posture break, dash, UI), but craft the **hero sounds first**: the deflect **clang** + the posture-break **thud**, with hitstop/slow-mo tuned *to* them. Goal: de-flatten enough to honestly re-judge the duel. Not shipping-grade sound design yet.
3. **Total creative-identity revamp — the foundational project.** Story, characters, scenes, vibes, atmosphere, art direction. **Creative only, NOT gameplay.** This is what the real animation will serve; it's a brainstorm-led creative effort, not a code spec.
4. **Real animation — only after the revamp**, on the new identity. Even the art-agnostic exaggeration/impact pass waits, since the revamp resets characters/scenes.
5. **Then** re-judge action depth (post-juice), and only then resume systems work.

## Roadmap reprioritization
- **PARKED behind core-fun work:** per-school duel hooks (Soft/Iron/Venom/Thunder/Sword), difficulty-tier selection, content breadth (more enemies/bosses), mastery F2, posture-break payoff. No point balancing six schools' *feel* on a flat duel.
- **Exception — stays shippable:** the **Esc-quits-the-game** fix (in-game pause menu, `2026-06-30-ingame-pause-menu-design.md`). It's a real bug (a stray Esc loses the run), not decoration.
- **Next concrete steps:** (a) spec + ship the **audio pass**; (b) open the **creative-identity revamp** brainstorm (bigger, open-ended). The audio pass can go first — it's cheap and unblocks an honest re-judgement of the duel.

## Why this matters
The session spent its energy tuning systems (difficulty v2, schools, UX) on top of a core that the designer judges flat. This note re-centers the project on the heart: **make one sword fight feel thrilling (audio now), settle the creative identity (revamp), then animate it** — before any more systems.
