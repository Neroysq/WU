# WU Combat Foundation — Playtest Checklist

Launch `Main.tscn` in the Godot editor and run a single combat encounter
against the Bandit. Work through every checkbox. A failing item goes back
to the task it belongs to.

## Base moveset

- [ ] Movement speed feels Sekiro-slow and clearly slower than the old prototype.
- [ ] Jump is a single jump, with no double jump and no air dash.
- [ ] Tapping `J` produces a light attack with visible wind-up.
- [ ] Holding `J` for at least ~0.25s produces a heavy attack with noticeably larger damage.
- [ ] Holding `K` reduces damage on incoming hits; releasing `K` ends block.
- [ ] Tapping `K` within ~0.15s of an incoming silver attack triggers a parry.
- [ ] Tapping `K` on a red perilous attack does not parry; the player must dash.
- [ ] Dash has a brief startup, invulnerable middle, and brief recovery tail.
- [ ] `L` prints the stance scaffold message and causes no visible side effect.

## Readability

- [ ] Silver attacks are clearly parryable and red attacks clearly feel perilous.
- [ ] Wind-up telegraphs come from the attack itself, not a separate pre-attack stall.
- [ ] Late attack inputs during recovery chain on the first legal frame.
- [ ] The debug overlay shows attack id, phase, dash phase, input buffer contents, and rage-ready state.

## Feedback

- [ ] Normal hits have brief hitstop and modest camera shake.
- [ ] Heavy hits have longer hitstop and stronger shake.
- [ ] Parries freeze first, then drop into a short slow-motion beat.
- [ ] Posture breaks have the biggest hitstop, shake, and `破` feedback.
- [ ] Damage numbers appear on every hit without desync from the visible slash.

## Verification

- [ ] `cd WUGodot && godot --headless --script res://tests/run_tests.gd` prints `passed: 24` and `failed: 0`.
