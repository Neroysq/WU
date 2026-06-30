class_name RestService
extends RefCounted

static func apply(action: String, fighter: Fighter, run_state: Variant) -> Dictionary:
	match action:
		"heal":
			fighter.health_current = minf(fighter.health_current + fighter.health_max * 0.3, fighter.health_max)
			_mark_cleared(run_state)
			return {"success": true, "message": "Healed 30% max HP.", "next": "map"}
		"forget":
			if fighter.technique_engine != null and not fighter.technique_engine.technique_ids().is_empty():
				return {"success": true, "message": "Choose a technique to forget.", "next": "forget"}
			_mark_cleared(run_state)
			return {"success": false, "message": "No technique to forget.", "next": "map"}
		"upgrade":
			var upgraded: bool = run_state != null and run_state.upgrade_first_boon_with_insight()
			_mark_cleared(run_state)
			return {"success": upgraded, "message": "Boon upgraded." if upgraded else "No boon upgraded.", "next": "map"}
		_:
			_mark_cleared(run_state)
			return {"success": false, "message": "Unknown rest action.", "next": "map"}

static func actions_for(fighter: Fighter, run_state: Variant) -> Array[String]:
	var actions: Array[String] = ["heal"]
	if fighter != null and fighter.technique_engine != null and not fighter.technique_engine.technique_ids().is_empty():
		actions.append("forget")
	if run_state != null and run_state.insight > 0 and not run_state.first_upgradeable_boon_id().is_empty():
		actions.append("upgrade")
	return actions

static func _mark_cleared(run_state: Variant) -> void:
	if run_state != null:
		run_state.mark_current_node_cleared()
