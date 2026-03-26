class_name AssetCatalog
extends RefCounted

var _texture_cache: Dictionary = {}
var _missing_texture: Texture2D

func get_texture(path: String) -> Texture2D:
	if path.is_empty():
		return _get_missing_texture()

	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D

	if not ResourceLoader.exists(path):
		_texture_cache[path] = _get_missing_texture()
		return _texture_cache[path] as Texture2D

	var loaded: Resource = load(path)
	var texture: Texture2D = loaded as Texture2D
	if texture == null:
		texture = _get_missing_texture()

	_texture_cache[path] = texture
	return texture

func _get_missing_texture() -> Texture2D:
	if _missing_texture != null:
		return _missing_texture

	var image: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var checker: bool = ((x / 4) + (y / 4)) % 2 == 0
			image.set_pixel(x, y, Color8(230, 70, 220) if checker else Color8(40, 10, 40))

	_missing_texture = ImageTexture.create_from_image(image)
	return _missing_texture

func clear() -> void:
	_texture_cache.clear()
