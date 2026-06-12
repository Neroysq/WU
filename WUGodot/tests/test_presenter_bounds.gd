extends RefCounted

const PresenterScript = preload("res://scripts/visual/fighter_presenter.gd")
const ManifestScript = preload("res://scripts/visual/animation_manifest.gd")

const BARE_JSON := """
{ "id": "b_bare", "duration": 0.4, "keyposes": [ { "t": 0.0, "pose": "guard" } ] }
"""
const HELD_JSON := """
{ "id": "b_held", "duration": 0.4, "useFighterOffset": true,
  "keyposes": [ { "t": 0.0, "pose": "guard" } ] }
"""
const XFORM_JSON := """
{ "id": "b_xform", "duration": 0.4,
  "keyposes": [ { "t": 0.0, "pose": "guard" } ],
  "tracks": {
    "offsetX": [ { "t": 0.0, "v": 30.0 } ],
    "scaleX":  [ { "t": 0.0, "v": 1.2 } ]
  } }
"""
const ROT_JSON := """
{ "id": "b_rot", "duration": 0.4,
  "keyposes": [ { "t": 0.0, "pose": "guard" } ],
  "tracks": {
    "rotation": [ { "t": 0.0, "v": 90.0 } ]
  } }
"""
const GRAPH_JSON := """
{ "states": {
  "B_BARE":  { "clip": "b_bare",  "enter": { "mode": "snap", "time": 0.0 } },
  "B_HELD":  { "clip": "b_held",  "enter": { "mode": "snap", "time": 0.0 } },
  "B_XFORM": { "clip": "b_xform", "enter": { "mode": "snap", "time": 0.0 } },
  "B_ROT":   { "clip": "b_rot",   "enter": { "mode": "snap", "time": 0.0 } }
} }
"""

func _write(path: String, content: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(content)
	f.close()

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	DataManager.initialize()
	_write("user://b_bare.timeline.json", BARE_JSON)
	_write("user://b_held.timeline.json", HELD_JSON)
	_write("user://b_xform.timeline.json", XFORM_JSON)
	_write("user://b_rot.timeline.json", ROT_JSON)
	_write("user://b_graph.graph.json", GRAPH_JSON)

	var catalog: AssetCatalog = AssetCatalog.new()
	var presenter: Variant = PresenterScript.new(catalog)
	presenter.configure(
		"res://assets/animation_manifests/hu.manifest.json",
		"user://b_graph.graph.json",
		["user://b_bare.timeline.json", "user://b_held.timeline.json", "user://b_xform.timeline.json", "user://b_rot.timeline.json"],
		2.0
	)
	var fighter: Fighter = EnemyFactory.create_player()
	fighter.position = Vector2(500.0, 600.0)
	fighter.facing = 1
	fighter.animation_offset = Vector2.ZERO

	var manifest: Variant = ManifestScript.load_from_file("res://assets/animation_manifests/hu.manifest.json")
	var pose: Dictionary = manifest.get_pose("guard")
	var foot: Vector2 = pose["footAnchor"]
	var hb: Rect2 = pose["hurtbox"]

	presenter.update(fighter, "B_BARE", 0.016, 0.016, Vector2.ZERO)
	var expected := Rect2(
		500.0 + (hb.position.x - foot.x) * 2.0,
		600.0 + (hb.position.y - foot.y) * 2.0,
		hb.size.x * 2.0,
		hb.size.y * 2.0
	)
	var got: Rect2 = presenter.get_body_rect(fighter, Vector2.ZERO)
	if got.position.distance_to(expected.position) < 1.0 and (got.size - expected.size).length() < 1.0:
		passed += 1
	else:
		failed += 1
		failures.append("bare bounds: expected %s got %s" % [str(expected), str(got)])

	fighter.facing = -1
	presenter.update(fighter, "B_BARE", 0.016, 0.016, Vector2.ZERO)
	var mirrored: Rect2 = presenter.get_body_rect(fighter, Vector2.ZERO)
	var expected_left := 500.0 + (foot.x - hb.position.x - hb.size.x) * 2.0
	if absf(mirrored.position.x - expected_left) < 1.0 and absf(mirrored.size.x - expected.size.x) < 0.01:
		passed += 1
	else:
		failed += 1
		failures.append("mirrored bounds: expected x %f got %f" % [expected_left, mirrored.position.x])
	fighter.facing = 1

	fighter.animation_offset = Vector2(8.0, -3.0)
	presenter.update(fighter, "B_HELD", 0.016, 0.016, Vector2.ZERO)
	var held: Rect2 = presenter.get_body_rect(fighter, Vector2.ZERO)
	if held.position.is_equal_approx(expected.position + Vector2(8.0, -3.0)):
		passed += 1
	else:
		failed += 1
		failures.append("held bounds should include animation_offset: expected %s got %s" % [str(expected.position + Vector2(8.0, -3.0)), str(held.position)])
	fighter.animation_offset = Vector2.ZERO

	presenter.update(fighter, "B_XFORM", 0.016, 0.016, Vector2.ZERO)
	var xf: Rect2 = presenter.get_body_rect(fighter, Vector2.ZERO)
	var exp_left := 500.0 + 30.0 + (hb.position.x - foot.x) * 2.0 * 1.2
	var exp_w := hb.size.x * 2.0 * 1.2
	if absf(xf.position.x - exp_left) < 1.0 and absf(xf.size.x - exp_w) < 1.0:
		passed += 1
	else:
		failed += 1
		failures.append("transformed bounds: expected left %f w %f got left %f w %f" % [exp_left, exp_w, xf.position.x, xf.size.x])

	presenter.update(fighter, "B_ROT", 0.016, 0.016, Vector2.ZERO)
	var rot: Rect2 = presenter.get_body_rect(fighter, Vector2.ZERO)
	var exp_rot_w := hb.size.y * 2.0
	var exp_rot_h := hb.size.x * 2.0
	var exp_rot_left := 500.0 + (foot.y - hb.end.y) * 2.0
	if absf(rot.size.x - exp_rot_w) < 1.0 and absf(rot.size.y - exp_rot_h) < 1.0 and absf(rot.position.x - exp_rot_left) < 1.0:
		passed += 1
	else:
		failed += 1
		failures.append("rotated bounds: expected w %f h %f left %f got w %f h %f left %f" % [exp_rot_w, exp_rot_h, exp_rot_left, rot.size.x, rot.size.y, rot.position.x])
	presenter.free()

	return {"passed": passed, "failed": failed, "failures": failures}
