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

	var light_reach: float = _reach_for(collision, AttackCatalogScript.hu_light())
	var heavy_reach: float = _reach_for(collision, AttackCatalogScript.hu_heavy())
	var light_range: float = maxf(0.0, light_reach - HU_HALF_WIDTH)
	var heavy_range: float = maxf(0.0, heavy_reach - HU_HALF_WIDTH)

	print("HU REACH")
	print("  hu_light derived_reach=%.1f  range_units=%.1f" % [light_reach, light_range])
	print("  hu_heavy derived_reach=%.1f  range_units=%.1f" % [heavy_reach, heavy_range])

	var band_min_c2c: float = light_reach * 0.70
	var band_max_c2c: float = light_reach * 0.85
	var band_min_range: float = maxf(0.0, band_min_c2c - HU_HALF_WIDTH)
	var band_max_range: float = maxf(0.0, band_max_c2c - HU_HALF_WIDTH)
	print("ENEMY BAND")
	print("  target enemy range_units %.1f..%.1f (70-85%% of hu_light c2c %.1f, minus Hu half-width %.1f)" % [band_min_range, band_max_range, light_reach, HU_HALF_WIDTH])
	for enemy_file in ENEMY_FILES:
		_print_enemy_recommendation(enemy_file)

	quit(0)

func _reach_for(collision: Variant, attack_def: Variant) -> float:
	var fighter: Variant = FighterScript.new()
	fighter.position = Vector2(0.0, 900.0)
	fighter.facing = 1
	fighter._attack_state.start(attack_def)
	fighter._attack_state.advance(attack_def.windup_end + 0.01)
	collision.register_fighter(fighter, "hu")
	return collision.derived_reach(fighter)

func _print_enemy_recommendation(enemy_file: String) -> void:
	var enemy_path: String = "res://data/Enemies/%s.json" % enemy_file
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(enemy_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		print("  %s: unreadable" % enemy_file)
		return
	var enemy: Dictionary = parsed as Dictionary
	var half_width: float = float(enemy.get("halfWidth", 22.0))
	var shortest: float = INF
	var ids: Array = enemy.get("pattern_table", []) as Array
	for attack_id_value in ids:
		var attack_id: String = str(attack_id_value)
		var attack_def: Variant = DataManager.get_attack_def(attack_id)
		if attack_def != null:
			shortest = minf(shortest, float(attack_def.range_units))
	if shortest >= INF:
		print("  %s: no attack ranges" % enemy_file)
		return
	print("  %s shortest=%.1f  preferredRange=%.1f" % [enemy_file, shortest, maxf(0.0, shortest - half_width)])
