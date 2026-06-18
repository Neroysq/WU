class_name TechniqueEffect
extends RefCounted

class HitContext extends RefCounted:
	var attacker: Variant = null
	var defender: Variant = null
	var attack_def: Variant = null
	var hp_damage: float = 0.0
	var posture_damage: float = 0.0
	var base_hp_damage: float = 0.0
	var heal_attacker: float = 0.0
	var bleed_timer: float = 0.0
	var bleed_dps: float = 0.0
	var venom_stacks: int = 0
	var venom_timer: float = 0.0
	var venom_dps: float = 0.0
	var venom_slow_multiplier: float = 1.0
	var consume_venom: bool = false
	var extra_hits: Array[Dictionary] = []
	var reflect_to_attacker: float = 0.0
	var messages: Array[String] = []

var id: String = ""
var priority: int = 100
var exclusive_group: String = ""
var once_per_run: bool = false
var params: Dictionary = {}
var display_name: String = ""

func on_add(_fighter: Variant) -> void:
	pass

func on_remove(_fighter: Variant) -> void:
	pass

func on_combat_start(_fighter: Variant) -> void:
	pass

func on_combat_end(_fighter: Variant) -> void:
	pass

func update(_dt: float, _fighter: Variant) -> void:
	pass

# Hook parameters use Variant because child scripts extend this class by path;
# parent-inner-class annotations are fragile in that setup.
func modify_outgoing_hit(_ctx: Variant) -> void:
	pass

func modify_block(_ctx: Variant) -> void:
	pass

func post_hit(_ctx: Variant) -> void:
	pass

func on_parry_success(_fighter: Variant) -> void:
	pass

func on_posture_break_dealt(_fighter: Variant) -> void:
	pass

func on_dash_end(_fighter: Variant, _enemy: Variant) -> Dictionary:
	return {}

func on_dash_through(_fighter: Variant) -> void:
	pass

func on_jump(_fighter: Variant) -> void:
	pass

func on_land(_fighter: Variant) -> void:
	pass

func modify_aerial_hit(_ctx: Variant) -> void:
	pass

func on_kill(_fighter: Variant) -> void:
	pass

func roll_stagger(_rng: RandomNumberGenerator) -> bool:
	return false

func try_lethal_save(_fighter: Variant) -> bool:
	return false

func on_stance_activate(_fighter: Variant) -> void:
	pass

func on_stance_deactivate(_fighter: Variant) -> void:
	pass

func attack_override(_is_heavy: bool) -> Variant:
	return null

func should_auto_chain_light(_def: Variant) -> bool:
	return false

func on_stance_damage(_amount: float, _fighter: Variant) -> bool:
	return false

func state() -> Dictionary:
	return {}

func restore(_data: Dictionary) -> void:
	pass

func after_restore(_fighter: Variant) -> void:
	pass
