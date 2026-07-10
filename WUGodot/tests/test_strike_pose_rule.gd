extends RefCounted

const TimelineScript = preload("res://scripts/visual/animation_clip_timeline.gd")
const ManifestScript = preload("res://scripts/visual/animation_manifest.gd")
const CollisionScript = preload("res://scripts/visual/presentation_collision.gd")
const AttackCatalogScript = preload("res://scripts/attack_catalog.gd")

const CASES := [
	{"id": "hu_light", "clip": "res://assets/animation_clips/hu_attack_light.timeline.json"},
	{"id": "hu_heavy", "clip": "res://assets/animation_clips/hu_attack_heavy.timeline.json"},
]

func _active_extensions(clip: Variant, def: Variant, manifest: Variant) -> Dictionary:
	# pose_name -> |tip.x - foot.x| for every keypose inside the active window
	var t_start: float = clip.event_time("attack_active_start", def)
	var t_end: float = clip.event_time("attack_active_end", def)
	var out: Dictionary = {}
	for kp in clip.keyposes:
		var t: float = clip._resolve_t(kp["t"], def)
		if t < t_start - 0.0001 or t > t_end + 0.0001:
			continue
		var pose: Dictionary = manifest.get_pose(str(kp["pose"]))
		if pose.is_empty():
			continue
		var foot: Vector2 = pose["footAnchor"]
		var tip: Vector2 = pose["weaponTip"]
		out[str(kp["pose"])] = absf(tip.x - foot.x)
	return out

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	if CASES.is_empty():
		passed += 1
		return {"passed": passed, "failed": failed, "failures": failures}

	var manifest: Variant = ManifestScript.load_from_file("res://assets/animation_manifests/hu.manifest.json")
	for case in CASES:
		var clip: Variant = TimelineScript.load_from_file(str(case["clip"]))
		var def: Variant = AttackCatalogScript.hu_light() if str(case["id"]) == "hu_light" else AttackCatalogScript.hu_heavy()
		var exts: Dictionary = _active_extensions(clip, def, manifest)
		var best_dist: float = 0.0
		for k in exts:
			best_dist = maxf(best_dist, float(exts[k]))
		# Rule intent: the mapped strike pose must be ACTIVE-window art near full
		# extension (>= 90% of max) — not a stale windup/recovery pose. Exact-max
		# is deliberately not required: the max-extension capsule can start beyond
		# a point-blank enemy and whiff (wind aerial probe regression, 2026-07-10).
		var mapped: String = str(CollisionScript.STRIKE_POSE_BY_ID.get(str(case["id"]), ""))
		var mapped_ext: float = float(exts.get(mapped, -1.0))
		var expected: String = "an active pose with extension >= 90% of max (%.0f)" % best_dist
		if best_dist > 0.0 and mapped_ext >= best_dist * 0.90:
			passed += 1
		else:
			failed += 1
			failures.append("%s: STRIKE_POSE_BY_ID maps '%s' (ext %.0f) but rule requires %s" % [case["id"], mapped, mapped_ext, expected])

	return {"passed": passed, "failed": failed, "failures": failures}
