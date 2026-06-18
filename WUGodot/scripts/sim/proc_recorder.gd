class_name ProcRecorder
extends RefCounted

static var _active: bool = false
static var _boon_procs: Dictionary = {}
static var _status_applications: Dictionary = {}

static func begin() -> void:
	_active = true
	_boon_procs.clear()
	_status_applications.clear()

static func end() -> Dictionary:
	var result: Dictionary = snapshot()
	_active = false
	return result

static func reset() -> void:
	_boon_procs.clear()
	_status_applications.clear()

static func active() -> bool:
	return _active

static func record_effect(effect_id: String) -> void:
	if not _active:
		return
	if effect_id.find("#") == -1:
		return
	var boon_id: String = effect_id.split("#", true, 1)[0]
	if boon_id.is_empty():
		return
	_boon_procs[boon_id] = int(_boon_procs.get(boon_id, 0)) + 1

static func record_status(status_id: String, amount: int = 1) -> void:
	if not _active or status_id.is_empty() or amount <= 0:
		return
	_status_applications[status_id] = int(_status_applications.get(status_id, 0)) + amount

static func snapshot() -> Dictionary:
	return {
		"boon_procs": _boon_procs.duplicate(true),
		"status_applications": _status_applications.duplicate(true),
	}

