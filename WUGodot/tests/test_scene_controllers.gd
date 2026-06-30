extends RefCounted

const SceneContextScript = preload("res://scripts/scene_context.gd")
const MenuInputScript = preload("res://scripts/ui/menu_input.gd")
const MenuSceneScript = preload("res://scripts/scenes/menu_scene.gd")
const SettingsSceneScript = preload("res://scripts/scenes/settings_scene.gd")
const ShopSceneScript = preload("res://scripts/scenes/shop_scene.gd")
const RestSceneScript = preload("res://scripts/scenes/rest_scene.gd")
const EndingSceneScript = preload("res://scripts/scenes/ending_scene.gd")
const MapNodeScript = preload("res://scripts/map_node.gd")
const RunStateScript = preload("res://scripts/run_state.gd")
const EnemyFactoryScript = preload("res://scripts/enemy_factory.gd")

func _make_context(node_type: int = MapNodeScript.NodeType.REST) -> Variant:
	var ctx: Variant = SceneContextScript.new()
	ctx.player = EnemyFactoryScript.create_player()
	ctx.run_state = RunStateScript.new()
	var current: Variant = MapNodeScript.new(1, 1, node_type, [])
	ctx.run_state.nodes.append(current)
	ctx.run_state.current_node_id = current.id
	ctx.run_state.max_tier = 1
	return ctx

func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	DataManager.initialize()

	var ctx: Variant = _make_context()
	ctx.player.health_max = 100.0
	ctx.player.health_current = 50.0
	var rest: Variant = RestSceneScript.new()
	var input: Variant = MenuInputScript.new()
	input.accept = true
	rest.enter(ctx)
	rest.update(ctx, input, 0.016)
	if absf(ctx.player.health_current - 80.0) < 0.01 and ctx.next_scene == SceneContextScript.SCENE_MAP and ctx.run_state.get_current_node().cleared:
		passed += 1
	else:
		failed += 1
		failures.append("rest heal should restore 30% max HP and return to map")

	ctx = _make_context(MapNodeScript.NodeType.SHOP)
	var shop: Variant = ShopSceneScript.new()
	shop.enter(ctx, {"items": [{"type": "potion", "label": "Potion", "price": 999, "description": ""}]})
	input = MenuInputScript.new()
	input.accept = true
	shop.update(ctx, input, 0.016)
	if ctx.notice_timer > 0.0 and shop.items.size() == 1:
		passed += 1
	else:
		failed += 1
		failures.append("failed shop purchase should leave inventory and show notice")

	ctx = _make_context(MapNodeScript.NodeType.SHOP)
	shop.enter(ctx, {"items": []})
	input = MenuInputScript.new()
	input.local_cancel = true
	shop.update(ctx, input, 0.016)
	if ctx.next_scene == SceneContextScript.SCENE_MAP and ctx.run_state.get_current_node().cleared:
		passed += 1
	else:
		failed += 1
		failures.append("shop local cancel should clear current node and return to map")

	ctx = _make_context(MapNodeScript.NodeType.BATTLE)
	var ending: Variant = EndingSceneScript.new()
	ctx.current_scene = SceneContextScript.SCENE_VICTORY
	input = MenuInputScript.new()
	input.accept = true
	ending.update(ctx, input, 0.016)
	if ctx.next_scene == SceneContextScript.SCENE_MAIN_MENU:
		passed += 1
	else:
		failed += 1
		failures.append("ending accept should return to main menu")

	var menu: Variant = MenuSceneScript.new()
	ctx = _make_context()
	input = MenuInputScript.new()
	input.mouse_clicked = true
	menu.update(ctx, input, 0.016)
	if ctx.new_run_requested:
		passed += 1
	else:
		failed += 1
		failures.append("main menu mouse click should request a new run")

	menu.enter(ctx)
	input = MenuInputScript.new()
	input.down = true
	menu.update(ctx, input, 0.016)
	input = MenuInputScript.new()
	input.accept = true
	menu.update(ctx, input, 0.016)
	if ctx.next_scene == SceneContextScript.SCENE_SETTINGS:
		passed += 1
	else:
		failed += 1
		failures.append("main menu Settings option should route to settings scene")

	var settings_scene: Variant = SettingsSceneScript.new()
	ctx = _make_context()
	settings_scene.enter(ctx)
	input = MenuInputScript.new()
	input.local_cancel = true
	settings_scene.update(ctx, input, 0.016)
	if ctx.next_scene == SceneContextScript.SCENE_MAIN_MENU:
		passed += 1
	else:
		failed += 1
		failures.append("settings scene cancel should return to main menu")

	return {"passed": passed, "failed": failed, "failures": failures}
