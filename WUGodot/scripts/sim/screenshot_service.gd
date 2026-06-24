class_name ScreenshotService
extends RefCounted

const ProjectionScript = preload("res://scripts/sim/playtest_projection.gd")

static func capture(conductor: Variant, label: String, seq: int, session_dir: String, tree: SceneTree) -> Dictionary:
	if tree == null:
		return {"success": false, "error": "screenshot requires a SceneTree"}
	var shot_dir: String = "%s/shots" % session_dir
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var safe_label: String = label.validate_filename()
	if safe_label.is_empty():
		safe_label = "shot"
	var path: String = "%s/%s_%d.png" % [shot_dir, safe_label, seq]
	var before: Dictionary = conductor.transcript_state()
	var projection: Node2D = ProjectionScript.new()
	projection.configure(conductor.projection_snapshot())
	tree.root.add_child(projection)
	await tree.process_frame
	await tree.create_timer(0.05).timeout
	var image: Image = tree.root.get_viewport().get_texture().get_image()
	var err: int = image.save_png(path)
	projection.queue_free()
	var after: Dictionary = conductor.transcript_state()
	return {"success": err == OK and before == after, "path": path, "error_code": err, "mutated": before != after}
