class_name RewardScene
extends RefCounted

const SceneContext = preload("res://scripts/scene_context.gd")
const UiDraw = preload("res://scripts/ui/ui_draw.gd")

var rewards: Array = []
var selection_idx: int = 0

func enter(_ctx: Variant, payload: Dictionary = {}) -> void:
	selection_idx = 0
	rewards = payload.get("rewards", [])

func update(ctx: Variant, input: Variant, _delta: float) -> void:
	if rewards.is_empty():
		var current_node: MapNode = ctx.run_state.get_current_node()
		if current_node != null and current_node.node_type == MapNode.NodeType.MASTER:
			ctx.run_state.mark_current_node_cleared()
			ctx.goto(SceneContext.SCENE_MAP)
			return
		rewards = RunFlow.generate_technique_rewards(3, _owned_ids(ctx.player))

	var max_idx: int = rewards.size() - 1
	if input.left:
		selection_idx = maxi(0, selection_idx - 1)
	if input.right:
		selection_idx = mini(max_idx, selection_idx + 1)
	if input.number >= 1 and input.number <= rewards.size():
		_apply_reward_by_index(ctx, input.number - 1)
		return

	var hovered_idx: int = _get_hovered_reward_index(input.mouse_pos)
	if hovered_idx >= 0:
		selection_idx = hovered_idx

	if input.accept:
		_apply_reward_by_index(ctx, selection_idx)
	elif hovered_idx >= 0 and input.mouse_clicked:
		_apply_reward_by_index(ctx, hovered_idx)

func draw(ctx: Variant, canvas: CanvasItem) -> void:
	UiDraw.background(canvas)
	UiDraw.modal_backdrop(canvas)

	var current_node: MapNode = ctx.run_state.get_current_node() if ctx.run_state != null else null
	var is_master_reward: bool = current_node != null and current_node.node_type == MapNode.NodeType.MASTER
	var reward_accent: Color = GameConstants.COLOR_PURPLE_MID if is_master_reward else GameConstants.COLOR_PANEL_ACCENT
	var header_wash: Color = Color(reward_accent.r, reward_accent.g, reward_accent.b, 0.18 if is_master_reward else 0.28)
	var header_cn: String = "拜師" if is_master_reward else "得技"
	var header_en: String = "Master's Teaching" if is_master_reward else "Technique Acquired"
	var panel: Rect2 = _get_reward_panel_rect()
	UiDraw.panel(canvas, panel)
	var header_bar: Rect2 = Rect2(panel.position.x + 18.0, panel.position.y + 18.0, panel.size.x - 36.0, 54.0)
	canvas.draw_rect(header_bar, header_wash, true)
	canvas.draw_rect(header_bar, Color(reward_accent.r, reward_accent.g, reward_accent.b, 0.8), false, 1.0)
	UiDraw.text(canvas, header_cn, header_bar.position.x + 18.0, header_bar.position.y + 28.0, GameConstants.COLOR_TEXT_HEADING, 24, true)
	UiDraw.text(canvas, header_en, header_bar.position.x + 18.0, header_bar.position.y + 48.0, GameConstants.COLOR_TEXT_BODY, 17)
	UiDraw.text(canvas, "Arrows, 1/2/3, Enter or click", panel.position.x + 26.0, panel.position.y + 92.0, GameConstants.COLOR_TEXT_HINT, 15)

	for i in range(rewards.size()):
		var box: Rect2 = _get_reward_box_rect(i)
		var reward_label: String = "..."
		var reward_desc: String = ""
		if i < rewards.size():
			reward_label = rewards[i].label
			if rewards[i].technique_id != "":
				var tech_data: Dictionary = DataManager.get_technique(rewards[i].technique_id)
				reward_desc = str(tech_data.get("description", ""))
		UiDraw.reward_option(canvas, box, reward_label, reward_desc, selection_idx == i, ctx.cursor_flash, reward_accent)

func _apply_reward_by_index(ctx: Variant, index: int) -> void:
	if index < 0 or index >= rewards.size():
		return
	var selected: RewardOption = rewards[index]
	selected.apply(ctx.player)
	if selected.technique_id != "" and not ctx.run_techniques_acquired.has(selected.technique_id):
		ctx.run_techniques_acquired.append(selected.technique_id)
	ctx.run_state.mark_current_node_cleared()
	rewards.clear()
	selection_idx = 0
	ctx.goto(SceneContext.SCENE_MAP)

func _get_reward_panel_rect() -> Rect2:
	var width: float = minf(1200.0, float(GameConstants.VIEW_WIDTH) - 200.0)
	var height: float = 300.0
	return Rect2((float(GameConstants.VIEW_WIDTH) - width) * 0.5, (float(GameConstants.VIEW_HEIGHT) - height) * 0.5 - 20.0, width, height)

func _get_reward_box_rect(index: int) -> Rect2:
	var panel: Rect2 = _get_reward_panel_rect()
	var count: int = maxi(rewards.size(), 1)
	var gap: float = 20.0
	var box_width: float = (panel.size.x - gap * float(count + 1)) / float(count)
	var box_height: float = 150.0
	var x: float = panel.position.x + gap + float(index) * (box_width + gap)
	var y: float = panel.position.y + 118.0
	return Rect2(x, y, box_width, box_height)

func _get_hovered_reward_index(mouse_pos: Vector2) -> int:
	if mouse_pos == Vector2.INF:
		return -1
	for i in range(rewards.size()):
		if _get_reward_box_rect(i).has_point(mouse_pos):
			return i
	return -1

func _owned_ids(player: Fighter) -> Array[String]:
	if player != null and player.technique_engine != null:
		return player.technique_engine.technique_ids()
	return []
