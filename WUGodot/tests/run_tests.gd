extends SceneTree

const _TEST_MODULES: Array[String] = [
	"res://tests/test_attack_definition.gd",
	"res://tests/test_attack_state.gd",
	"res://tests/test_attack_data.gd",
	"res://tests/test_input_buffer.gd",
	"res://tests/test_technique.gd",
	"res://tests/test_technique_engine.gd",
	"res://tests/test_technique_combat.gd",
	"res://tests/test_technique_registry.gd",
	"res://tests/test_boon_factory.gd",
	"res://tests/test_boon_loadout.gd",
	"res://tests/test_boon_offer.gd",
	"res://tests/test_boon_text.gd",
	"res://tests/test_boon_rehome.gd",
	"res://tests/test_content_matrix.gd",
	"res://tests/test_rng_service.gd",
	"res://tests/test_combat_setup.gd",
	"res://tests/test_apply_choices.gd",
	"res://tests/test_player_policy.gd",
	"res://tests/test_decision_policy.gd",
	"res://tests/test_combat_sim.gd",
	"res://tests/test_run_driver.gd",
	"res://tests/test_encounter_resolver.gd",
	"res://tests/test_difficulty_runstate.gd",
	"res://tests/test_jump_hooks.gd",
	"res://tests/test_venom_effect.gd",
	"res://tests/test_jolt_effect.gd",
	"res://tests/test_deflect_effect.gd",
	"res://tests/test_momentum_effect.gd",
	"res://tests/test_wind_duel_hooks.gd",
	"res://tests/test_intent_mark_effect.gd",
	"res://tests/test_ai_brain.gd",
	"res://tests/test_boss_controller.gd",
	"res://tests/test_event_runner.gd",
	"res://tests/test_map_generator.gd",
	"res://tests/test_background_renderer.gd",
	"res://tests/test_text_wrapping.gd",
	"res://tests/test_menu_input.gd",
	"res://tests/test_run_flow.gd",
	"res://tests/test_scene_controllers.gd",
	"res://tests/test_animation_set.gd",
	"res://tests/test_animation_clock.gd",
	"res://tests/test_animation_manifest.gd",
	"res://tests/test_anchor_math.gd",
	"res://tests/test_anchor_measure.gd",
	"res://tests/test_animation_clip_timeline.gd",
	"res://tests/test_animation_graph.gd",
	"res://tests/test_move_skin_resolver.gd",
	"res://tests/test_move_skin_presenter.gd",
	"res://tests/test_presenter_offset.gd",
	"res://tests/test_presenter_bounds.gd",
	"res://tests/test_strike_pose_rule.gd",
	"res://tests/test_collision_shape_math.gd",
	"res://tests/test_hitbox_template.gd",
	"res://tests/test_presentation_collision.gd",
	"res://tests/test_master_normalizer.gd",
	"res://tests/test_master_geometry.gd",
	"res://tests/test_heavy_capsule_pose.gd",
	"res://tests/test_interactive_playtest_daemon.gd",
	"res://tests/test_duel_ratios_probe.gd",
	"res://tests/test_enemy_block_no_parry.gd",
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
