class_name TechniqueRegistry
extends RefCounted

const TechniqueEffectScript = preload("res://scripts/techniques/technique_effect.gd")
const StatDeltaEffectScript = preload("res://scripts/techniques/effects/stat_delta_effect.gd")
const DashStabEffectScript = preload("res://scripts/techniques/effects/dash_stab_effect.gd")
const StaggerEffectScript = preload("res://scripts/techniques/effects/stagger_effect.gd")
const BleedOnHeavyEffectScript = preload("res://scripts/techniques/effects/bleed_on_heavy_effect.gd")
const SparrowEffectScript = preload("res://scripts/techniques/effects/sparrow_effect.gd")
const BlockChipEffectScript = preload("res://scripts/techniques/effects/block_chip_effect.gd")
const TwinStrikeEffectScript = preload("res://scripts/techniques/effects/twin_strike_effect.gd")
const EchoEffectScript = preload("res://scripts/techniques/effects/echo_effect.gd")
const BreakHealEffectScript = preload("res://scripts/techniques/effects/break_heal_effect.gd")
const FlowingWaterEffectScript = preload("res://scripts/techniques/effects/flowing_water_effect.gd")
const GazeEffectScript = preload("res://scripts/techniques/effects/gaze_effect.gd")
const LowHpBoostEffectScript = preload("res://scripts/techniques/effects/low_hp_boost_effect.gd")
const PhoenixEffectScript = preload("res://scripts/techniques/effects/phoenix_effect.gd")
const StanceDrunkenEffectScript = preload("res://scripts/techniques/effects/stance_drunken_effect.gd")
const StanceTigerEffectScript = preload("res://scripts/techniques/effects/stance_tiger_effect.gd")

static func has_effect(id: String) -> bool:
	var data: Dictionary = DataManager.get_technique(id)
	return data.has("effect") and typeof(data.get("effect")) == TYPE_DICTIONARY

static func create_effect(id: String) -> Variant:
	var data: Dictionary = DataManager.get_technique(id)
	if not data.has("effect") or typeof(data.get("effect")) != TYPE_DICTIONARY:
		return null
	var effect_data: Dictionary = (data.get("effect", {}) as Dictionary).duplicate(true)
	var effect_type: String = str(effect_data.get("type", ""))
	var effect: Variant = null
	match effect_type:
		"stat_delta":
			effect = StatDeltaEffectScript.new()
		"dash_stab":
			effect = DashStabEffectScript.new()
		"stagger":
			effect = StaggerEffectScript.new()
		"bleed_on_heavy":
			effect = BleedOnHeavyEffectScript.new()
		"sparrow":
			effect = SparrowEffectScript.new()
		"block_chip":
			effect = BlockChipEffectScript.new()
		"twin_strike":
			effect = TwinStrikeEffectScript.new()
		"echo":
			effect = EchoEffectScript.new()
		"break_heal":
			effect = BreakHealEffectScript.new()
		"flowing_water":
			effect = FlowingWaterEffectScript.new()
		"gaze":
			effect = GazeEffectScript.new()
		"low_hp_boost":
			effect = LowHpBoostEffectScript.new()
		"phoenix":
			effect = PhoenixEffectScript.new()
		"stance_drunken":
			effect = StanceDrunkenEffectScript.new()
		"stance_tiger":
			effect = StanceTigerEffectScript.new()
		_:
			push_error("TechniqueRegistry: unknown effect type '%s' for %s" % [effect_type, id])
			return null
	effect.id = id
	effect.params = effect_data
	if effect_data.has("display_name"):
		effect.display_name = str(effect_data.get("display_name", ""))
	if effect_data.has("priority"):
		effect.priority = int(effect_data.get("priority", effect.priority))
	return effect
