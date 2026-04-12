extends SceneTree

const _TEST_MODULES: Array[String] = [
	"res://tests/test_attack_definition.gd",
	"res://tests/test_attack_state.gd",
	"res://tests/test_input_buffer.gd",
	"res://tests/test_technique.gd",
	"res://tests/test_technique_engine.gd",
]

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []

func _init() -> void:
	for module_path in _TEST_MODULES:
		if not ResourceLoader.exists(module_path):
			continue
		var module_script: Script = load(module_path)
		if module_script == null:
			_failed += 1
			_failures.append("could not load %s" % module_path)
			continue
		var module: RefCounted = module_script.new()
		if not module.has_method("run_all"):
			_failed += 1
			_failures.append("%s missing run_all()" % module_path)
			continue
		var results: Dictionary = module.run_all()
		_passed += int(results.get("passed", 0))
		_failed += int(results.get("failed", 0))
		for failure in results.get("failures", []):
			_failures.append("%s: %s" % [module_path, str(failure)])

	print("\n=== TEST RESULTS ===")
	print("passed: %d" % _passed)
	print("failed: %d" % _failed)
	if _failed > 0:
		for failure in _failures:
			print("  FAIL %s" % failure)
		quit(1)
	else:
		quit(0)
