extends RefCounted

const AnimationSetScript = preload("res://scripts/visual/animation_set.gd")
const AssetCatalogScript = preload("res://scripts/visual/asset_catalog.gd")
const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")
const AttackDefinitionScript = preload("res://scripts/attack_definition.gd")
const FighterScript = preload("res://scripts/fighter.gd")
const FighterVisualScript = preload("res://scripts/visual/fighter_visual.gd")

const LIVE_CHARACTER_IDS: Array[String] = [
	"hu",
	"bandit_sword",
	"bandit_spear",
	"ronin",
	"disciple",
	"assassin",
	"iron_bear",
]

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var catalog: Variant = AssetCatalogScript.new()
	var set: Variant = AnimationSetScript.load_from_file("res://assets/animations/character_hu.json", catalog)
	var light_clip: Dictionary = set.get_clip("ATTACKING_LIGHT")
	var phases: Array = light_clip.get("phases", []) as Array
	if phases.size() == 3:
		passed += 1
	else:
		failed += 1
		failures.append("ATTACKING_LIGHT should parse three phase blocks")

	if (light_clip.get("frames", []) as Array).size() == 4:
		passed += 1
	else:
		failed += 1
		failures.append("ATTACKING_LIGHT should expose four frames")

	var idle_clip: Dictionary = set.get_clip("IDLE")
	if (idle_clip.get("phases", []) as Array).is_empty():
		passed += 1
	else:
		failed += 1
		failures.append("IDLE should keep fixed-FPS playback with no phase blocks")

	var visual: Variant = FighterVisualScript.new(catalog)
	var fighter: Variant = FighterScript.new()
	visual.configure({"animationSet": "res://assets/animations/character_hu.json", "scale": 1.0, "yOffset": 0.0}, fighter)
	var attack_def: Variant = AttackCatalogScript.hu_light()
	fighter._attack_state.start(attack_def)
	fighter.current_animation = FighterScript.AnimationState.ATTACKING_LIGHT

	fighter._attack_state.elapsed = 0.0
	visual.update(fighter, 0.0)
	if visual._frame_index == 0:
		passed += 1
	else:
		failed += 1
		failures.append("phase playback should use attack_0 at windup start")

	fighter._attack_state.elapsed = attack_def.windup_end * 0.75
	visual.update(fighter, 0.0)
	if visual._frame_index == 1:
		passed += 1
	else:
		failed += 1
		failures.append("phase playback should use attack_1 late in windup")

	fighter._attack_state.elapsed = attack_def.windup_end
	visual.update(fighter, 0.0)
	if visual._frame_index == 2:
		passed += 1
	else:
		failed += 1
		failures.append("phase playback should switch to attack_2 at active boundary")

	fighter._attack_state.elapsed = attack_def.active_end
	visual.update(fighter, 0.0)
	if visual._frame_index == 3:
		passed += 1
	else:
		failed += 1
		failures.append("phase playback should switch to attack_3 at recovery boundary")

	fighter.current_animation = FighterScript.AnimationState.IDLE
	visual.update(fighter, 0.20)
	if visual._frame_index == 1:
		passed += 1
	else:
		failed += 1
		failures.append("fixed-FPS playback should still advance non-phased clips")

	for char_id in LIVE_CHARACTER_IDS:
		var path: String = "res://assets/animations/character_%s.json" % char_id
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			failed += 1
			failures.append("%s did not parse as JSON" % path)
			continue
		var clips: Dictionary = (parsed as Dictionary).get("clips", {}) as Dictionary
		for clip_name in ["ATTACKING_LIGHT", "ATTACKING_HEAVY"]:
			var clip: Dictionary = clips.get(clip_name, {}) as Dictionary
			var raw_frames: Array = clip.get("frames", []) as Array
			var raw_phases: Array = clip.get("phases", []) as Array
			var expected_prefix: String = "heavy" if char_id == "hu" and clip_name == "ATTACKING_HEAVY" else "attack"
			if raw_frames.size() == 4 and str((raw_frames[3] as Dictionary).get("path", "")).ends_with("%s_3.png" % expected_prefix) and raw_phases.size() == 3:
				passed += 1
			else:
				failed += 1
				failures.append("%s %s should reference %s_0..%s_3 and three phase blocks" % [char_id, clip_name, expected_prefix, expected_prefix])

	return {"passed": passed, "failed": failed, "failures": failures}
