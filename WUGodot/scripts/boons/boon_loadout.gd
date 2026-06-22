class_name BoonLoadout
extends RefCounted

const BoonFactoryScript = preload("res://scripts/boons/boon_factory.gd")
const TIER_ORDER: Array[String] = ["common", "rare", "epic", "legendary"]

var slots: Dictionary = {}
var passives: Array[Dictionary] = []
var duos: Array[Dictionary] = []
var masteries: Array[Dictionary] = []

var _engine: Variant = null
var _fighter: Variant = null

func _init(engine: Variant = null, fighter: Variant = null) -> void:
	bind(engine, fighter)

func bind(engine: Variant, fighter: Variant) -> void:
	_engine = engine
	_fighter = fighter

func add_boon(boon_id: String, tier: String = "common") -> bool:
	var boon: Dictionary = DataManager.get_boon(boon_id)
	if boon.is_empty():
		return false
	var kind: String = str(boon.get("kind", ""))
	var record: Dictionary = _make_record(boon, tier)
	match kind:
		"move":
			var slot: String = str(boon.get("slot", ""))
			if slot.is_empty():
				return false
			if slots.has(slot):
				_remove_record(slots[slot] as Dictionary)
			slots[slot] = record
		"passive":
			if _find_record(boon_id) != null:
				return false
			passives.append(record)
		"duo":
			if _find_record(boon_id) != null:
				return false
			duos.append(record)
		"mastery":
			if _find_record(boon_id) != null:
				return false
			masteries.append(record)
		_:
			return false
	_install_record(record)
	return true

func upgrade_boon(boon_id: String) -> bool:
	if not can_upgrade_boon(boon_id):
		return false
	var record: Variant = _find_record(boon_id)
	var boon: Dictionary = record.get("boon", {}) as Dictionary
	var tier: String = str(record.get("tier", "common"))
	var index: int = TIER_ORDER.find(tier)
	_remove_record(record)
	record["tier"] = TIER_ORDER[index + 1]
	record["effects"] = []
	_install_record(record)
	return true

func can_upgrade_boon(boon_id: String) -> bool:
	var record: Variant = _find_record(boon_id)
	if record == null:
		return false
	var boon: Dictionary = record.get("boon", {}) as Dictionary
	var kind: String = str(boon.get("kind", ""))
	if kind == "duo" or kind == "mastery":
		return false
	var tier: String = str(record.get("tier", "common"))
	var index: int = TIER_ORDER.find(tier)
	if index < 0 or index >= TIER_ORDER.size() - 1:
		return false
	var tiers: Dictionary = boon.get("tiers", {}) as Dictionary
	return tiers.has(TIER_ORDER[index + 1])

func is_duo_eligible(boon: Dictionary) -> bool:
	return _requirements_met(boon.get("requires", {}) as Dictionary)

func is_mastery_eligible(boon: Dictionary) -> bool:
	return _requirements_met(boon.get("requires", {}) as Dictionary)

func active_schools() -> Array[String]:
	var schools: Array[String] = []
	for record in _all_records():
		var school: String = str((record.get("boon", {}) as Dictionary).get("school", ""))
		if not school.is_empty() and not schools.has(school):
			schools.append(school)
	return schools

func school_boon_count(school_id: String) -> int:
	var count: int = 0
	for record in _all_records():
		if str((record.get("boon", {}) as Dictionary).get("school", "")) == school_id:
			count += 1
	return count

func move_slot_schools() -> Dictionary:
	var out: Dictionary = {}
	for slot in slots.keys():
		var boon: Dictionary = (slots[slot] as Dictionary).get("boon", {}) as Dictionary
		out[str(slot)] = str(boon.get("school", ""))
	return out

func school_for_effect_id(effect_id: String) -> String:
	if effect_id.is_empty():
		return ""
	for record in _all_records():
		for effect in record.get("effects", []) as Array:
			if effect != null and str(effect.id) == effect_id:
				return str((record.get("boon", {}) as Dictionary).get("school", ""))
	return ""

func serialize() -> Dictionary:
	var slot_data: Dictionary = {}
	for slot in slots.keys():
		slot_data[slot] = _record_identity(slots[slot] as Dictionary)
	return {
		"slots": slot_data,
		"passives": _record_identities(passives),
		"duos": _record_identities(duos),
		"masteries": _record_identities(masteries),
	}

func restore(data: Dictionary) -> void:
	clear()
	var slot_data: Dictionary = data.get("slots", {}) as Dictionary
	for slot in slot_data.keys():
		var identity: Dictionary = slot_data[slot] as Dictionary
		add_boon(str(identity.get("boon_id", "")), str(identity.get("tier", "common")))
	for identity in data.get("passives", []) as Array:
		if typeof(identity) == TYPE_DICTIONARY:
			add_boon(str((identity as Dictionary).get("boon_id", "")), str((identity as Dictionary).get("tier", "common")))
	for identity in data.get("duos", []) as Array:
		if typeof(identity) == TYPE_DICTIONARY:
			add_boon(str((identity as Dictionary).get("boon_id", "")), str((identity as Dictionary).get("tier", "common")))
	for identity in data.get("masteries", []) as Array:
		if typeof(identity) == TYPE_DICTIONARY:
			add_boon(str((identity as Dictionary).get("boon_id", "")), str((identity as Dictionary).get("tier", "common")))

func clear() -> void:
	for record in _all_records():
		_remove_record(record)
	slots.clear()
	passives.clear()
	duos.clear()
	masteries.clear()

func _make_record(boon: Dictionary, tier: String) -> Dictionary:
	return {
		"boon_id": str(boon.get("id", "")),
		"tier": tier,
		"boon": boon.duplicate(true),
		"effects": [],
	}

func _install_record(record: Dictionary) -> void:
	if _engine == null:
		return
	var boon: Dictionary = record.get("boon", {}) as Dictionary
	var effects: Array = BoonFactoryScript.build_boon_effects(boon, str(record.get("tier", "common")))
	record["effects"] = effects
	for effect in effects:
		_engine.add_effect(effect, _fighter)

func _remove_record(record: Dictionary) -> void:
	if _engine == null:
		record["effects"] = []
		return
	for effect in record.get("effects", []) as Array:
		_engine.remove_effect(effect, _fighter)
	record["effects"] = []

func _find_record(boon_id: String) -> Variant:
	for record in _all_records():
		if str(record.get("boon_id", "")) == boon_id:
			return record
	return null

func _requirements_met(requires: Dictionary) -> bool:
	for school in requires.get("schools", []) as Array:
		if not active_schools().has(str(school)):
			return false
	var counts: Dictionary = requires.get("counts", {}) as Dictionary
	for school_id in counts.keys():
		if school_boon_count(str(school_id)) < int(counts[school_id]):
			return false
	return true

func _all_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for slot in slots.keys():
		records.append(slots[slot] as Dictionary)
	for record in passives:
		records.append(record)
	for record in duos:
		records.append(record)
	for record in masteries:
		records.append(record)
	return records

func _record_identity(record: Dictionary) -> Dictionary:
	return {
		"boon_id": str(record.get("boon_id", "")),
		"tier": str(record.get("tier", "common")),
	}

func _record_identities(records: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for record in records:
		out.append(_record_identity(record))
	return out
