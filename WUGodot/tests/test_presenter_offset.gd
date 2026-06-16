extends RefCounted

const TimelineScript = preload("res://scripts/visual/animation_clip_timeline.gd")
const PresenterScript = preload("res://scripts/visual/fighter_presenter.gd")

const HELD_CLIP_JSON := """
{
  "id": "test_held",
  "duration": 0.4,
  "useFighterOffset": true,
  "keyposes": [ { "t": 0.0, "pose": "guard" } ]
}
"""
const VIDEO_CLIP_JSON := """
{
  "id": "test_video",
  "duration": 0.4,
  "keyposes": [ { "t": 0.0, "pose": "guard" } ]
}
"""
const GRAPH_JSON := """
{
  "states": {
    "HELD_TEST": { "clip": "test_held", "enter": { "mode": "snap", "time": 0.0 } },
    "VIDEO_TEST": { "clip": "test_video", "enter": { "mode": "snap", "time": 0.0 } }
  }
}
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
	_write("user://test_held.timeline.json", HELD_CLIP_JSON)
	_write("user://test_video.timeline.json", VIDEO_CLIP_JSON)
	_write("user://test_offset.graph.json", GRAPH_JSON)

	var held: Variant = TimelineScript.load_from_file("user://test_held.timeline.json")
	var video: Variant = TimelineScript.load_from_file("user://test_video.timeline.json")
	if held.use_fighter_offset and not video.use_fighter_offset:
		passed += 1
	else:
		failed += 1
		failures.append("useFighterOffset should parse true and default false")

	var real_held: Variant = TimelineScript.load_from_file("res://assets/animation_clips/held_hit.timeline.json")
	var real_stunned: Variant = TimelineScript.load_from_file("res://assets/animation_clips/held_stunned.timeline.json")
	var real_dash: Variant = TimelineScript.load_from_file("res://assets/animation_clips/held_dash.timeline.json")
	if real_held.use_fighter_offset and real_stunned.use_fighter_offset and real_dash.use_fighter_offset:
		passed += 1
	else:
		failed += 1
		failures.append("Phase 5 held clips should opt into fighter.animation_offset")

	var catalog: AssetCatalog = AssetCatalog.new()
	var presenter: Variant = PresenterScript.new(catalog)
	presenter.configure(
		"res://assets/animation_manifests/hu.manifest.json",
		"user://test_offset.graph.json",
		["user://test_held.timeline.json", "user://test_video.timeline.json"],
		2.0
	)
	var fighter: Fighter = EnemyFactory.create_player()
	fighter.position = Vector2(500.0, 600.0)
	fighter.animation_offset = Vector2(8.0, -3.0)

	presenter.update(fighter, "HELD_TEST", 0.016, 0.016, Vector2.ZERO)
	var held_pos: Vector2 = presenter.position
	presenter.update(fighter, "VIDEO_TEST", 0.016, 0.016, Vector2.ZERO)
	var video_pos: Vector2 = presenter.position
	presenter.free()

	if held_pos.is_equal_approx(Vector2(508.0, 597.0)) and video_pos.is_equal_approx(Vector2(500.0, 600.0)):
		passed += 1
	else:
		failed += 1
		failures.append("held state should add animation_offset (got %s), video state should not (got %s)" % [str(held_pos), str(video_pos)])

	return {"passed": passed, "failed": failed, "failures": failures}
