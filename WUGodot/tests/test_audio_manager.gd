extends RefCounted

const AudioManagerScript = preload("res://scripts/audio_manager.gd")

const EXPECTED_IDS: Array[String] = [
	"block",
	"dash",
	"enemy_telegraph",
	"hit_heavy",
	"hit_light",
	"hurt",
	"jump",
	"land",
	"parry",
	"posture_break",
	"swing",
	"ui_confirm",
	"ui_move",
]

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	var manager: Variant = AudioManagerScript.new()
	if manager.load_manifest():
		passed += 1
	else:
		failed += 1
		failures.append("AudioManager should load the Sfx.json manifest")

	for id in EXPECTED_IDS:
		if manager.has_sfx(id):
			passed += 1
		else:
			failed += 1
			failures.append("AudioManager missing sfx id %s" % id)

	manager.play("parry")
	manager.play("missing_id")
	manager.free()
	passed += 1

	return {"passed": passed, "failed": failed, "failures": failures}
