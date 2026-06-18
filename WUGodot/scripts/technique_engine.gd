class_name TechniqueEngine
extends RefCounted

const TechniqueRegistryScript = preload("res://scripts/techniques/technique_registry.gd")
const TechniqueEffectScript = preload("res://scripts/techniques/technique_effect.gd")

var _technique_ids: Array[String] = []
var _effects: Array = []
var _active_stance_id: String = ""
var _effect_state_archive: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

func has(id: String) -> bool:
	return _technique_ids.has(id)

func has_effect(id: String) -> bool:
	return _effect_by_id(id) != null

func technique_ids() -> Array[String]:
	return _technique_ids.duplicate()

func add(id: String, fighter: Fighter) -> void:
	if has(id):
		return
	var effect: Variant = TechniqueRegistryScript.create_effect(id)
	if effect != null:
		_install_effect(effect, fighter)
		return
	_technique_ids.append(id)

func remove(id: String, fighter: Fighter) -> void:
	if not has(id):
		return
	if _active_stance_id == id:
		deactivate_stance(fighter)
	var effect: Variant = _effect_by_id(id)
	if effect != null:
		if effect.once_per_run:
			_effect_state_archive[id] = effect.state()
		effect.on_remove(fighter)
		_effects.erase(effect)
	_technique_ids.erase(id)

func add_effect(effect: Variant, fighter: Variant) -> void:
	if effect == null or _effects.has(effect):
		return
	if not str(effect.id).is_empty() and _effect_by_id(effect.id) != null:
		return
	if effect.exclusive_group != "":
		for existing in _effects.duplicate():
			if existing.exclusive_group != effect.exclusive_group:
				continue
			if _technique_ids.has(existing.id):
				remove(existing.id, fighter)
			else:
				remove_effect(existing, fighter)
	_effects.append(effect)
	_sort_effects()
	effect.on_add(fighter)

func remove_effect(effect: Variant, fighter: Variant) -> void:
	if effect == null or not _effects.has(effect):
		return
	if _active_stance_id == effect.id:
		deactivate_stance(fighter)
	effect.on_remove(fighter)
	_effects.erase(effect)

func _install_effect(effect: Variant, fighter: Variant) -> void:
	if effect.exclusive_group != "":
		for existing in _effects.duplicate():
			if existing.exclusive_group == effect.exclusive_group:
				remove(existing.id, fighter)
	if has(effect.id):
		return
	_technique_ids.append(effect.id)
	if _effect_state_archive.has(effect.id):
		effect.restore(_effect_state_archive[effect.id] as Dictionary)
	_effects.append(effect)
	_sort_effects()
	effect.on_add(fighter)

func _sort_effects() -> void:
	_effects.sort_custom(func(a: Variant, b: Variant) -> bool:
		if a.priority == b.priority:
			return a.id < b.id
		return a.priority < b.priority
	)

func _effect_by_id(id: String) -> Variant:
	for effect in _effects:
		if effect.id == id:
			return effect
	return null

func _active_stance_effect() -> Variant:
	if _active_stance_id.is_empty():
		return null
	return _effect_by_id(_active_stance_id)

func update(dt: float, fighter: Fighter) -> void:
	for effect in _effects:
		effect.update(dt, fighter)
	var stance_effect: Variant = _active_stance_effect()
	if stance_effect != null and stance_effect.has_method("is_expired") and stance_effect.is_expired():
		deactivate_stance(fighter)

func on_combat_start(fighter: Fighter) -> void:
	for effect in _effects:
		effect.on_combat_start(fighter)

func on_combat_end(fighter: Fighter) -> void:
	for effect in _effects:
		effect.on_combat_end(fighter)

func reset_combat_state(fighter: Fighter) -> void:
	on_combat_start(fighter)

func dispatch_outgoing_hit(ctx: Variant) -> void:
	for effect in _effects:
		effect.modify_outgoing_hit(ctx)

func dispatch_block(ctx: Variant) -> void:
	for effect in _effects:
		effect.modify_block(ctx)

func dispatch_post_hit(ctx: Variant) -> void:
	for effect in _effects:
		effect.post_hit(ctx)

func dispatch_jump(fighter: Variant) -> void:
	for effect in _effects:
		effect.on_jump(fighter)

func dispatch_land(fighter: Variant) -> void:
	for effect in _effects:
		effect.on_land(fighter)

func dispatch_aerial_hit(ctx: Variant) -> void:
	for effect in _effects:
		effect.modify_aerial_hit(ctx)

func dispatch_parry_success(fighter: Fighter) -> bool:
	var handled := false
	for effect in _effects:
		if effect.has_method("handles_parry_success") and effect.handles_parry_success():
			handled = true
		effect.on_parry_success(fighter)
	return handled

func on_dash_end(fighter: Fighter = null, enemy: Fighter = null) -> Dictionary:
	var merged: Dictionary = {}
	for effect in _effects:
		var result: Dictionary = effect.on_dash_end(fighter, enemy)
		for key in result.keys():
			merged[key] = result[key]
	return merged

func on_dash_through(fighter: Fighter = null) -> void:
	for effect in _effects:
		effect.on_dash_through(fighter)

func on_kill(fighter: Fighter) -> void:
	for effect in _effects:
		effect.on_kill(fighter)

func on_posture_break(fighter: Fighter) -> bool:
	var before: float = fighter.health_current
	for effect in _effects:
		effect.on_posture_break_dealt(fighter)
	return fighter.health_current > before

func check_lethal_save(fighter: Fighter) -> bool:
	for effect in _effects:
		if effect.try_lethal_save(fighter):
			return true
	return false

func roll_stagger() -> bool:
	for effect in _effects:
		if effect.roll_stagger(_rng):
			return true
	return false

func activate_stance(fighter: Fighter) -> bool:
	if not _active_stance_id.is_empty():
		return false
	var stance_effect: Variant = null
	for effect in _effects:
		if effect.exclusive_group == "stance":
			stance_effect = effect
			break
	if stance_effect == null:
		return false
	if fighter.rage_current < fighter.rage_max:
		return false
	fighter.rage_current = 0.0
	_active_stance_id = stance_effect.id
	stance_effect.on_stance_activate(fighter)
	return true

func deactivate_stance(fighter: Fighter) -> void:
	var effect: Variant = _active_stance_effect()
	if effect != null:
		effect.on_stance_deactivate(fighter)
	_active_stance_id = ""

func is_stance_active() -> bool:
	return not _active_stance_id.is_empty()

func active_stance() -> String:
	return _active_stance_id

func active_stance_display_name() -> String:
	var effect: Variant = _active_stance_effect()
	return effect.display_name if effect != null else ""

func get_light_override() -> Variant:
	var effect: Variant = _active_stance_effect()
	return effect.attack_override(false) if effect != null else null

func get_heavy_override() -> Variant:
	var effect: Variant = _active_stance_effect()
	return effect.attack_override(true) if effect != null else null

func should_auto_chain_light(def: Variant) -> bool:
	var effect: Variant = _active_stance_effect()
	return effect != null and effect.should_auto_chain_light(def)

func on_stance_damage(amount: float, fighter: Fighter) -> bool:
	var effect: Variant = _active_stance_effect()
	if effect == null:
		return false
	if effect.on_stance_damage(amount, fighter):
		deactivate_stance(fighter)
		return true
	return false

func set_echo() -> void:
	for effect in _effects:
		if effect.has_method("set_armed"):
			effect.set_armed()

func consume_echo() -> bool:
	for effect in _effects:
		if effect.has_method("consume_echo") and effect.consume_echo():
			return true
	return false

func consume_flowing_water() -> bool:
	for effect in _effects:
		if effect.has_method("consume_flowing_water") and effect.consume_flowing_water():
			return true
	return false

func has_sparrow_bonus() -> bool:
	for effect in _effects:
		if effect.has_method("has_bonus") and effect.has_bonus():
			return true
	return false

func consume_sparrow() -> void:
	for effect in _effects:
		if effect.has_method("consume_bonus"):
			effect.consume_bonus()

func save_state() -> Dictionary:
	var effect_state: Dictionary = {}
	for effect in _effects:
		effect_state[effect.id] = effect.state()
	return {
		"technique_ids": _technique_ids.duplicate(),
		"active_stance_id": _active_stance_id,
		"effects": effect_state,
		"effect_state_archive": _effect_state_archive.duplicate(true),
	}

func load_state(data: Dictionary, fighter: Fighter) -> void:
	var ids: Array = data.get("technique_ids", []) as Array
	for raw_id in ids:
		var id: String = str(raw_id)
		if not has(id):
			add(id, fighter)
	var effect_state: Dictionary = data.get("effects", {}) as Dictionary
	for id in effect_state.keys():
		var effect: Variant = _effect_by_id(str(id))
		if effect != null:
			effect.restore(effect_state[id] as Dictionary)
	_effect_state_archive = (data.get("effect_state_archive", {}) as Dictionary).duplicate(true)
	for effect in _effects:
		effect.after_restore(fighter)
	var saved_stance: String = str(data.get("active_stance_id", ""))
	if not saved_stance.is_empty():
		_active_stance_id = saved_stance
		var stance_effect: Variant = _active_stance_effect()
		if stance_effect != null:
			stance_effect.on_stance_activate(fighter)
