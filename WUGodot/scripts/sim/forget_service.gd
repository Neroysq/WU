class_name ForgetService
extends RefCounted

static func apply(technique_id: String, fighter: Fighter, run_state: Variant = null) -> Dictionary:
	if fighter == null or fighter.technique_engine == null:
		_mark_cleared(run_state)
		return {"success": false, "message": "No technique engine."}
	var ids: Array[String] = fighter.technique_engine.technique_ids()
	var id: String = technique_id
	if id.is_empty() and not ids.is_empty():
		id = ids[0]
	if id.is_empty() or not ids.has(id):
		_mark_cleared(run_state)
		return {"success": false, "message": "No technique removed."}
	fighter.technique_engine.remove(id, fighter)
	_mark_cleared(run_state)
	return {"success": true, "message": "Forgot %s." % id, "technique_id": id}

static func _mark_cleared(run_state: Variant) -> void:
	if run_state != null:
		run_state.mark_current_node_cleared()

