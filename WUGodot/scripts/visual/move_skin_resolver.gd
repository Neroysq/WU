class_name MoveSkinResolver
extends RefCounted

const STATE_SLOT: Dictionary = {
	"ATTACKING_LIGHT": "light",
	"ATTACKING_HEAVY": "heavy",
	"DASHING": "dash",
	"BLOCKING": "block",
	"JUMPING": "jump",
	"FALLING": "jump",
}

static func slot_for_state(state_name: String) -> String:
	return str(STATE_SLOT.get(state_name, ""))

static func variant_key(school: String, state_name: String) -> String:
	return "%s:%s" % [school, state_name]

static func resolve(state_name: String, base_clip_id: String, slot_school_map: Dictionary, variant_ids: Dictionary) -> Dictionary:
	var slot: String = slot_for_state(state_name)
	if slot.is_empty() or not slot_school_map.has(slot):
		return {"clip_id": base_clip_id, "recolor_school": ""}
	var school: String = str(slot_school_map[slot])
	if school.is_empty():
		return {"clip_id": base_clip_id, "recolor_school": ""}
	var key: String = variant_key(school, state_name)
	if variant_ids.has(key):
		return {"clip_id": str(variant_ids[key]), "recolor_school": ""}
	return {"clip_id": base_clip_id, "recolor_school": school}
