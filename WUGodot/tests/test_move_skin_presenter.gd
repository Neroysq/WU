extends RefCounted

const FighterPresenterScript = preload("res://scripts/visual/fighter_presenter.gd")
const AssetCatalogScript = preload("res://scripts/visual/asset_catalog.gd")

func _configured_presenter() -> Variant:
	var presenter: Variant = FighterPresenterScript.new(AssetCatalogScript.new())
	presenter.configure(
		"res://assets/animation_manifests/hu.manifest.json",
		"res://assets/animation_graphs/humanoid.graph.json",
		[
			"res://assets/animation_clips/hu_attack_light.timeline.json",
			"res://assets/animation_clips/hu_attack_heavy.timeline.json",
			"res://assets/animation_clips/held_dash.timeline.json",
			"res://assets/animation_clips/held_block.timeline.json",
			"res://assets/animation_clips/idle.timeline.json",
		],
		1.625
	)
	return presenter

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	DataManager.initialize()

	var presenter: Variant = _configured_presenter()
	presenter.set_move_skins({"light": "venom", "block": "venom"})

	if presenter.resolve_state_clip_id("ATTACKING_LIGHT") == "venom_hu_attack_light":
		passed += 1
	else:
		failed += 1
		failures.append("infused light should resolve to the venom variant clip id")

	if presenter.resolve_state_clip_id("BLOCKING") == "held_block" and presenter.recolor_school_for("BLOCKING") == "venom":
		passed += 1
	else:
		failed += 1
		failures.append("infused block without a variant should keep base clip and recolor venom")

	if presenter.resolve_state_clip_id("ATTACKING_HEAVY") == "hu_attack_heavy" and presenter.recolor_school_for("ATTACKING_HEAVY") == "":
		passed += 1
	else:
		failed += 1
		failures.append("uninfused heavy should keep base clip, no recolor")

	if presenter.recolor_school_for("IDLE") == "" and presenter.resolve_state_clip_id("IDLE") == "idle":
		passed += 1
	else:
		failed += 1
		failures.append("non-move state IDLE must never be skinned or recolored")

	presenter.set_active_stance_school("thunder")
	if presenter.active_tint_school_for("IDLE") == "thunder":
		passed += 1
	else:
		failed += 1
		failures.append("active stance school should tint even on non-move states")

	presenter.set_active_stance_school("")
	if presenter.active_tint_school_for("IDLE") == "":
		passed += 1
	else:
		failed += 1
		failures.append("clearing active stance should remove the tint")

	presenter.set_active_stance_school("thunder")
	if presenter.active_tint_school_for("BLOCKING") == "venom":
		passed += 1
	else:
		failed += 1
		failures.append("an infused-unskinned move state should recolor with its own school over the stance tint")

	if presenter.handles_state("ATTACKING_LIGHT") and presenter.handles_state("DASHING"):
		passed += 1
	else:
		failed += 1
		failures.append("handles_state should remain true for skinnable states after skins are set")

	var fighter: Fighter = EnemyFactory.create_player()
	var venom_tint: Color = Color.WHITE.lerp(Color.html(str(DataManager.get_school("venom").get("themeColor", "#ffffff"))), 0.35)
	presenter._flash = 0.0
	presenter.update(fighter, "BLOCKING", 0.016, 0.016, Vector2.ZERO)
	if presenter._sprite_current.modulate.is_equal_approx(venom_tint) and presenter._sprite_previous.modulate.is_equal_approx(venom_tint) and float(presenter._mat_current.get_shader_parameter("skin_tint_weight")) == 0.0:
		passed += 1
	else:
		failed += 1
		failures.append("modulate should be the single active tint path for infused-unskinned states")

	presenter._flash = 1.0
	presenter.update(fighter, "BLOCKING", 0.016, 0.0, Vector2.ZERO)
	if presenter._sprite_current.modulate.is_equal_approx(Color.WHITE) and presenter._sprite_previous.modulate.is_equal_approx(Color.WHITE) and float(presenter._mat_current.get_shader_parameter("skin_tint_weight")) == 0.0:
		passed += 1
	else:
		failed += 1
		failures.append("flash should override modulate tint back to white, with shader skin tint disabled")

	presenter.set_active_stance_school("")
	presenter._flash = 0.0
	presenter.update(fighter, "IDLE", 0.016, 0.016, Vector2.ZERO)
	if presenter._sprite_current.modulate == Color.WHITE and presenter._sprite_previous.modulate == Color.WHITE:
		passed += 1
	else:
		failed += 1
		failures.append("non-skinned states should clear the presenter sprite tint")

	var reconfigured: Variant = _configured_presenter()
	reconfigured.set_move_skins({"light": "venom"})
	reconfigured.set_active_stance_school("thunder")
	reconfigured.configure(
		"res://assets/animation_manifests/hu.manifest.json",
		"res://assets/animation_graphs/humanoid.graph.json",
		["res://assets/animation_clips/hu_attack_light.timeline.json", "res://assets/animation_clips/idle.timeline.json"],
		1.625
	)
	if reconfigured._variant_ids.is_empty() and reconfigured._slot_school_map.is_empty() and reconfigured._loaded_skin_schools.is_empty() and reconfigured._active_stance_school == "" and reconfigured._recolor_school == "":
		passed += 1
	else:
		failed += 1
		failures.append("configure() must clear skin caches (variant_ids/slot_school_map/loaded_skin_schools/stance/recolor)")

	if reconfigured.resolve_state_clip_id("ATTACKING_LIGHT") == "hu_attack_light" and reconfigured.recolor_school_for("ATTACKING_LIGHT") == "":
		passed += 1
	else:
		failed += 1
		failures.append("after reconfigure with no skins, light should resolve to the base clip")

	presenter.free()
	reconfigured.free()
	return {"passed": passed, "failed": failed, "failures": failures}
