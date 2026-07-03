class_name BackgroundRenderer
extends RefCounted

const UiDraw = preload("res://scripts/ui/ui_draw.gd")

var current_arena_id: String = ""
var _texture: Texture2D = null
var _fallback_color: Color = GameConstants.COLOR_INK_BLACK

const ARENA_PATHS: Dictionary = {
	"chapter1_bamboo_dusk": "res://assets/backgrounds/chapter1_bamboo_dusk.png",
	"chapter1_boss_clearing": "res://assets/backgrounds/chapter1_boss_clearing.png",
}

func set_arena(arena_id: String) -> void:
	current_arena_id = arena_id
	_texture = null
	var path: String = str(ARENA_PATHS.get(arena_id, ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		_texture = load(path) as Texture2D

func draw(canvas: CanvasItem, camera_offset: Vector2, _battle_state: Dictionary, ctx: Dictionary = {}) -> void:
	var bleed: float = 40.0
	if _texture != null:
		var rect: Rect2 = Rect2(
			camera_offset.x - bleed,
			camera_offset.y - bleed,
			float(_texture.get_width()) + bleed * 2.0,
			float(_texture.get_height()) + bleed * 2.0
		)
		canvas.draw_texture_rect(_texture, rect, false)
	else:
		canvas.draw_rect(
			Rect2(
				camera_offset.x - bleed,
				camera_offset.y - bleed,
				float(GameConstants.VIEW_WIDTH) + bleed * 2.0,
				float(GameConstants.VIEW_HEIGHT) + bleed * 2.0
			),
			_fallback_color
		)
	UiDraw.depth_wash(canvas, str(ctx.get("band", "foothill")))
