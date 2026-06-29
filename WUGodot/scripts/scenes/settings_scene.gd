class_name SettingsScene
extends RefCounted

const SceneContext = preload("res://scripts/scene_context.gd")
const UiDraw = preload("res://scripts/ui/ui_draw.gd")
const SettingsViewScript = preload("res://scripts/scenes/settings_view.gd")

var view: Variant = SettingsViewScript.new()

func enter(_ctx: Variant, _payload: Dictionary = {}) -> void:
	view.enter()

func update(ctx: Variant, input: Variant, delta: float) -> void:
	var result: Dictionary = view.update(input, delta)
	view.consume_changed()
	if bool(result.get("exit", false)):
		ctx.goto(SceneContext.SCENE_MAIN_MENU)

func draw(ctx: Variant, canvas: CanvasItem) -> void:
	UiDraw.background(canvas)
	view.draw(canvas, SettingsViewScript.default_rect(), ctx.cursor_flash)

func is_capturing() -> bool:
	return view.is_capturing()

func feed_key_event(event: InputEventKey) -> void:
	view.feed_key_event(event)

func consume_changed() -> bool:
	return view.consume_changed()
