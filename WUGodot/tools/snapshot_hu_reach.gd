extends SceneTree

const FighterScript = preload("res://scripts/fighter.gd")
const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")
const PresentationCollisionScript = preload("res://scripts/visual/presentation_collision.gd")

const HU_HALF_WIDTH: float = 22.0
const ENEMY_FILES: Array[String] = [
	"BanditSwordsman",
	"WanderingRonin",
	"BanditSpearman",
	"SectDisciple",
	"IronBear",
]

func _init() -> void:
	DataManager.initialize()

	var collision: Variant = PresentationCollisionScript.new()
	collision.register_from_manifest_file("hu", "res://assets/animation_manifests/hu.manifest.json")

	var attacks: Dictionary = {}
	for attack_id in ["hu_light", "hu_heavy"]:
		var attack_def: Variant = AttackCatalogScript.hu_light() if attack_id == "hu_light" else AttackCatalogScript.hu_heavy()
		var reach: float = _reach_for(collision, attack_def)
		attacks[attack_id] = {
			"derivedReach": reach,
			"rangeUnits": float(attack_def.range_units),
			"rangeUnitsFromReach": maxf(0.0, reach - HU_HALF_WIDTH),
		}

	var light_reach: float = float((attacks["hu_light"] as Dictionary)["derivedReach"])
	var band_min_c2c: float = light_reach * 0.70
	var band_max_c2c: float = light_reach * 0.85
	var snapshot: Dictionary = {
		"id": "hu_reach_snapshot",
		"huHalfWidth": HU_HALF_WIDTH,
		"attacks": attacks,
		"enemyBand": {
			"c2cMin": band_min_c2c,
			"c2cMax": band_max_c2c,
			"rangeUnitsMin": maxf(0.0, band_min_c2c - HU_HALF_WIDTH),
			"rangeUnitsMax": maxf(0.0, band_max_c2c - HU_HALF_WIDTH),
		},
		"enemies": _enemy_ranges(),
	}

	var out_path: String = _arg("--out", "")
	var text: String = JSON.stringify(snapshot, "  ")
	if out_path.is_empty():
		print(text)
	else:
		var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
		if file == null:
			printerr("failed to write %s" % out_path)
			quit(1)
			return
		file.store_string(text + "\n")
		file.close()
		print("WROTE %s" % out_path)
	quit(0)

func _reach_for(collision: Variant, attack_def: Variant) -> float:
	var fighter: Variant = FighterScript.new()
	fighter.position = Vector2(0.0, 900.0)
	fighter.facing = 1
	fighter._attack_state.start(attack_def)
	fighter._attack_state.advance(attack_def.windup_end + 0.01)
	collision.register_fighter(fighter, "hu")
	return collision.derived_reach(fighter)

func _enemy_ranges() -> Dictionary:
	var enemies: Dictionary = {}
	for enemy_file in ENEMY_FILES:
		var enemy_path: String = "res://data/Enemies/%s.json" % enemy_file
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(enemy_path))
		if typeof(parsed) != TYPE_DICTIONARY:
			enemies[enemy_file] = {"error": "unreadable"}
			continue
		var enemy: Dictionary = parsed as Dictionary
		var half_width: float = float(enemy.get("halfWidth", 22.0))
		var shortest: float = INF
		var ids: Array = enemy.get("pattern_table", []) as Array
		for attack_id_value in ids:
			var attack_def: Variant = DataManager.get_attack_def(str(attack_id_value))
			if attack_def != null:
				shortest = minf(shortest, float(attack_def.range_units))
		if shortest >= INF:
			enemies[enemy_file] = {"error": "no attack ranges"}
			continue
		enemies[enemy_file] = {
			"shortestRangeUnits": shortest,
			"preferredRange": maxf(0.0, shortest - half_width),
			"halfWidth": half_width,
		}
	return enemies

func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		var text: String = str(arg)
		if text.begins_with(name + "="):
			return text.substr(name.length() + 1)
	return fallback
