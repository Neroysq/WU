class_name MapScene
extends RefCounted

const SceneContext = preload("res://scripts/scene_context.gd")
const MenuInput = preload("res://scripts/ui/menu_input.gd")
const UiDraw = preload("res://scripts/ui/ui_draw.gd")
const DepthBandScript = preload("res://scripts/ui/depth_band.gd")
const MenuSceneScript = preload("res://scripts/scenes/menu_scene.gd")
const LoadoutViewScript = preload("res://scripts/scenes/loadout_view.gd")

var selection_idx: int = 0

func enter(_ctx: Variant, _payload: Dictionary = {}) -> void:
	selection_idx = 0

func update(ctx: Variant, input: Variant, _delta: float) -> void:
	var next_nodes: Array[MapNode] = ctx.run_state.get_available_next()
	if next_nodes.is_empty():
		ctx.end_message = "Run Clear!"
		ctx.goto(SceneContext.SCENE_GAME_OVER)
		return

	selection_idx = clampi(selection_idx, 0, next_nodes.size() - 1)
	var before_idx: int = selection_idx
	if input.left:
		selection_idx = maxi(0, selection_idx - 1)
	if input.right:
		selection_idx = mini(next_nodes.size() - 1, selection_idx + 1)
	if selection_idx != before_idx:
		MenuInput.play_ui_move()

	var hovered_idx: int = _get_hovered_map_index(ctx, input.mouse_pos, next_nodes)
	if hovered_idx >= 0:
		selection_idx = hovered_idx

	if input.accept or (hovered_idx >= 0 and input.mouse_clicked):
		MenuInput.play_ui_confirm()
		var chosen: MapNode = next_nodes[selection_idx]
		ctx.run_state.advance_to(chosen.id)
		selection_idx = 0
		_apply_travel_decision(ctx, RunFlow.travel_decision(chosen, ctx.player, ctx.run_state))

func draw(ctx: Variant, canvas: CanvasItem) -> void:
	UiDraw.background(canvas, DepthBandScript.band_for_context(ctx))
	_draw_map_wash(canvas)
	_draw_bamboo_silhouettes(canvas, float(GameConstants.VIEW_HEIGHT) - 6.0, 0.38, ctx.cursor_flash)

	var next_nodes: Array[MapNode] = ctx.run_state.get_available_next()
	var tiers: int = ctx.run_state.max_tier + 1
	var top: int = 180
	var bottom: int = GameConstants.VIEW_HEIGHT - 200
	var tier_height: int = int((bottom - top) / maxi(1, tiers - 1))

	for node in ctx.run_state.nodes:
		for to_id in node.next_ids:
			var target: MapNode = ctx.run_state.get_node(to_id)
			if target == null:
				continue
			var from_pos: Vector2 = _get_map_node_position(ctx, node, tiers, top, tier_height)
			var to_pos: Vector2 = _get_map_node_position(ctx, target, tiers, top, tier_height)
			var base_color: Color = Color(GameConstants.COLOR_PANEL_BORDER.r, GameConstants.COLOR_PANEL_BORDER.g, GameConstants.COLOR_PANEL_BORDER.b, 0.28)
			var brush_color: Color = Color(GameConstants.COLOR_TEXT_HINT.r, GameConstants.COLOR_TEXT_HINT.g, GameConstants.COLOR_TEXT_HINT.b, 0.12)
			var normal: Vector2 = (to_pos - from_pos).normalized().orthogonal() * 2.0
			canvas.draw_line(from_pos, to_pos, base_color, 4.0)
			canvas.draw_line(from_pos + normal, to_pos + normal, brush_color, 2.0)
			canvas.draw_line(from_pos - normal * 0.5, to_pos - normal * 0.5, brush_color, 1.0)

	for node in ctx.run_state.nodes:
		var pos: Vector2 = _get_map_node_position(ctx, node, tiers, top, tier_height)
		var node_color: Color = _get_node_color(node.node_type)
		if node.cleared:
			node_color = node_color.darkened(0.55)
		canvas.draw_circle(pos, 22.0, Color(node_color.r, node_color.g, node_color.b, 0.14))
		canvas.draw_circle(pos, 12.0, node_color)
		_draw_node_glyph(canvas, pos, _get_node_glyph(node.node_type), 15)
		if next_nodes.has(node):
			var idx: int = next_nodes.find(node)
			if idx == selection_idx:
				var ring_pulse: float = 2.0 + sin(ctx.cursor_flash * 6.0) * 1.5
				canvas.draw_arc(pos, 22.0 + ring_pulse, 0.0, TAU, 48, GameConstants.COLOR_PANEL_ACCENT, 3.0, true)
				canvas.draw_arc(pos, 30.0 + ring_pulse, 0.0, TAU, 48, Color(GameConstants.COLOR_PANEL_ACCENT.r, GameConstants.COLOR_PANEL_ACCENT.g, GameConstants.COLOR_PANEL_ACCENT.b, 0.22), 2.0, true)
				UiDraw.menu_cursor(canvas, pos + Vector2(-34.0, 6.0), ctx.cursor_flash)

	var header: Rect2 = Rect2(42.0, 34.0, float(GameConstants.VIEW_WIDTH) - 84.0, 92.0)
	UiDraw.panel(canvas, header)
	UiDraw.text(canvas, "九仙山", 74.0, 78.0, GameConstants.COLOR_TEXT_HEADING, 32, true)
	UiDraw.text(canvas, "Path Select", 196.0, 78.0, GameConstants.COLOR_TEXT_SUBHEADING, 20)
	UiDraw.text(canvas, "Gold: %d" % ctx.player.gold, GameConstants.VIEW_WIDTH - 220.0, 78.0, GameConstants.COLOR_TEXT_ACCENT, 22)
	UiDraw.text(canvas, "Arrows / A-D to move · Enter / J or click to travel", 74.0, 106.0, GameConstants.COLOR_TEXT_BODY, 16)
	_draw_node_legend(canvas, 74.0, 150.0)

	if not next_nodes.is_empty():
		var selected_node: MapNode = next_nodes[selection_idx]
		var footer: Rect2 = Rect2(42.0, float(GameConstants.VIEW_HEIGHT) - 116.0, float(GameConstants.VIEW_WIDTH) - 84.0, 64.0)
		UiDraw.panel(canvas, footer)
		UiDraw.text(canvas, "Selected Route", footer.position.x + 26.0, footer.position.y + 34.0, GameConstants.COLOR_TEXT_HINT, 15)
		UiDraw.text(canvas, _get_node_type_label(selected_node.node_type), footer.position.x + 26.0, footer.position.y + 56.0, GameConstants.COLOR_TEXT_HEADING, 22)
		UiDraw.text(canvas, "Branches narrow after the master's gate and rest shrine.", footer.end.x - 420.0, footer.position.y + 46.0, GameConstants.COLOR_TEXT_BODY, 15)

	LoadoutViewScript.draw(canvas, ctx, Rect2(float(GameConstants.VIEW_WIDTH) - 390.0, 140.0, 348.0, 500.0), ctx.cursor_flash)

func _apply_travel_decision(ctx: Variant, decision: Dictionary) -> void:
	if bool(decision.get("mark_cleared", false)):
		ctx.run_state.mark_current_node_cleared()
	match str(decision.get("scene", "map")):
		"combat":
			ctx.combat_gold_multiplier = int(decision.get("combat_gold_multiplier", 1))
			ctx.request_combat(decision.get("node") as MapNode)
		"event":
			ctx.goto(SceneContext.SCENE_EVENT, {"event_data": decision.get("event_data", {})})
		"shop":
			ctx.notice_message = ""
			ctx.notice_timer = 0.0
			ctx.goto(SceneContext.SCENE_SHOP, {"items": decision.get("items", [])})
		"rest":
			ctx.goto(SceneContext.SCENE_REST)
		"reward":
			ctx.goto(SceneContext.SCENE_REWARD, {"rewards": decision.get("rewards", [])})
		"boon_offer":
			ctx.goto(SceneContext.SCENE_BOON_OFFER, decision)
		_:
			ctx.goto(SceneContext.SCENE_MAP)

func _get_hovered_map_index(ctx: Variant, mouse_pos: Vector2, next_nodes: Array[MapNode]) -> int:
	if mouse_pos == Vector2.INF:
		return -1
	var tiers: int = ctx.run_state.max_tier + 1
	var top: int = 180
	var bottom: int = GameConstants.VIEW_HEIGHT - 200
	var tier_height: int = int((bottom - top) / maxi(1, tiers - 1))
	for i in range(next_nodes.size()):
		var pos: Vector2 = _get_map_node_position(ctx, next_nodes[i], tiers, top, tier_height)
		if mouse_pos.distance_to(pos) <= 22.0:
			return i
	return -1

func _get_map_node_position(ctx: Variant, node: MapNode, tiers: int, top: int, tier_height: int) -> Vector2:
	var y: int = top + node.tier * tier_height
	var count_in_tier: int = ctx.run_state.count_in_tier(node.tier)
	var idx_in_tier: int = ctx.run_state.index_in_tier(node)
	var left: int = 180
	var right: int = GameConstants.VIEW_WIDTH - 180
	var x: int = (left + right) / 2
	if count_in_tier > 1:
		x = left + idx_in_tier * (right - left) / (count_in_tier - 1)
	return Vector2(x, y)

func _draw_map_wash(canvas: CanvasItem) -> void:
	var wash_color: Color = Color(GameConstants.COLOR_MOUNTAIN_BLUE.r, GameConstants.COLOR_MOUNTAIN_BLUE.g, GameConstants.COLOR_MOUNTAIN_BLUE.b, 0.16)
	canvas.draw_circle(Vector2(420.0, 360.0), 220.0, wash_color)
	canvas.draw_circle(Vector2(960.0, 430.0), 300.0, Color(GameConstants.COLOR_EARTH_DARK.r, GameConstants.COLOR_EARTH_DARK.g, GameConstants.COLOR_EARTH_DARK.b, 0.18))
	canvas.draw_circle(Vector2(1500.0, 320.0), 260.0, wash_color)
	canvas.draw_rect(Rect2(0.0, float(GameConstants.VIEW_HEIGHT) - 240.0, GameConstants.VIEW_WIDTH, 240.0), Color(GameConstants.COLOR_EARTH_DARK.r, GameConstants.COLOR_EARTH_DARK.g, GameConstants.COLOR_EARTH_DARK.b, 0.28), true)

func _draw_bamboo_silhouettes(canvas: CanvasItem, base_y: float, opacity: float, cursor_flash: float) -> void:
	MenuSceneScript.new()._draw_bamboo_silhouettes(canvas, base_y, opacity, cursor_flash)

func _draw_node_legend(canvas: CanvasItem, x: float, y: float) -> void:
	var entries: Array[Dictionary] = [
		{"type": MapNode.NodeType.BATTLE, "label": "Duel"},
		{"type": MapNode.NodeType.ELITE, "label": "Elite"},
		{"type": MapNode.NodeType.AMBUSH, "label": "Ambush"},
		{"type": MapNode.NodeType.MASTER, "label": "Master"},
		{"type": MapNode.NodeType.EVENT, "label": "Event"},
		{"type": MapNode.NodeType.SHOP, "label": "Shop"},
		{"type": MapNode.NodeType.REST, "label": "Rest"},
		{"type": MapNode.NodeType.BOSS, "label": "Boss"},
	]
	var cursor_x: float = x
	for entry in entries:
		var color: Color = _get_node_color(int(entry["type"]))
		canvas.draw_circle(Vector2(cursor_x + 7.0, y - 5.0), 7.0, Color(color.r, color.g, color.b, 0.28))
		canvas.draw_circle(Vector2(cursor_x + 7.0, y - 5.0), 4.5, color)
		_draw_node_glyph(canvas, Vector2(cursor_x + 7.0, y - 5.0), _get_node_glyph(int(entry["type"])), 11)
		UiDraw.text(canvas, str(entry["label"]), cursor_x + 20.0, y, GameConstants.COLOR_TEXT_HINT, 13)
		cursor_x += 92.0

func _draw_node_glyph(canvas: CanvasItem, pos: Vector2, glyph: String, size: int) -> void:
	var width: float = float(UiDraw.measure_text(glyph, size, true))
	var x: float = pos.x - width * 0.5
	var y: float = pos.y + float(size) * 0.36
	UiDraw.text(canvas, glyph, x + 1.0, y + 1.0, Color(GameConstants.COLOR_INK_BLACK.r, GameConstants.COLOR_INK_BLACK.g, GameConstants.COLOR_INK_BLACK.b, 0.58), size, true)
	UiDraw.text(canvas, glyph, x, y, GameConstants.COLOR_SCROLL_WHITE, size, true)

func _get_node_color(node_type: int) -> Color:
	match node_type:
		MapNode.NodeType.BATTLE:
			return GameConstants.COLOR_MISTY_BLUE
		MapNode.NodeType.ELITE:
			return GameConstants.COLOR_EARTH_LIGHT
		MapNode.NodeType.AMBUSH:
			return GameConstants.COLOR_VERMILLION_RED
		MapNode.NodeType.MASTER:
			return GameConstants.COLOR_PURPLE_MID
		MapNode.NodeType.EVENT:
			return GameConstants.COLOR_SKY_BLUE
		MapNode.NodeType.SHOP:
			return GameConstants.COLOR_GOLD_BRIGHT
		MapNode.NodeType.REST:
			return GameConstants.COLOR_JADE_GREEN
		MapNode.NodeType.BOSS:
			return GameConstants.COLOR_RED_DARK
		_:
			return GameConstants.COLOR_PAPER

func _get_node_glyph(node_type: int) -> String:
	match node_type:
		MapNode.NodeType.BATTLE:
			return "斗"
		MapNode.NodeType.ELITE:
			return "精"
		MapNode.NodeType.AMBUSH:
			return "伏"
		MapNode.NodeType.MASTER:
			return "師"
		MapNode.NodeType.EVENT:
			return "事"
		MapNode.NodeType.SHOP:
			return "商"
		MapNode.NodeType.REST:
			return "息"
		MapNode.NodeType.BOSS:
			return "王"
		_:
			return "?"

func _get_node_type_label(node_type: int) -> String:
	match node_type:
		MapNode.NodeType.BATTLE:
			return "Duel"
		MapNode.NodeType.ELITE:
			return "Elite Duel"
		MapNode.NodeType.AMBUSH:
			return "Ambush"
		MapNode.NodeType.MASTER:
			return "Master"
		MapNode.NodeType.EVENT:
			return "Event"
		MapNode.NodeType.SHOP:
			return "Shop"
		MapNode.NodeType.REST:
			return "Rest"
		MapNode.NodeType.BOSS:
			return "Boss"
		_:
			return "Unknown"
