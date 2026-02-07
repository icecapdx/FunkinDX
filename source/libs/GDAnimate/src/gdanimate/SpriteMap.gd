class_name GDAnimateSpriteMap
extends RefCounted

const SCRIPT_PATH = "res://source/libs/GDAnimate/src/gdanimate/SpriteMap.gd"

class SpriteData:
	var name: String
	var x: float
	var y: float
	var w: int
	var h: int
	var rotated: bool

var sprites: Dictionary = {}
var texture: Texture2D
var image_name: String

static func from_json(json_path: String, texture_path: String = ""):
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open spritemap: " + json_path)
		return null

	var text := file.get_as_text()
	file.close()

	text = text.strip_edges()
	if text.begins_with("\ufeff"):
		text = text.substr(1)

	var json = JSON.parse_string(text)
	if json == null:
		push_error("Failed to parse spritemap JSON: " + json_path)
		return null

	var script = load(SCRIPT_PATH)
	var smap = script.new()

	var atlas_data = json.get("ATLAS", {})
	var sprites_arr = atlas_data.get("SPRITES", [])

	for entry in sprites_arr:
		var sprite_raw = entry.get("SPRITE", {})
		var sd = SpriteData.new()
		sd.name = sprite_raw.get("name", "")
		sd.x = sprite_raw.get("x", 0)
		sd.y = sprite_raw.get("y", 0)
		sd.w = int(sprite_raw.get("w", 0))
		sd.h = int(sprite_raw.get("h", 0))
		sd.rotated = sprite_raw.get("rotated", false)
		smap.sprites[sd.name] = sd

	var meta = json.get("meta", {})
	smap.image_name = meta.get("image", "")

	var tex_path := texture_path
	if tex_path.is_empty():
		tex_path = json_path.get_base_dir().path_join(smap.image_name)

	smap.texture = load(tex_path)
	if smap.texture == null:
		push_error("Failed to load spritemap texture: " + tex_path)
		return null

	return smap

func get_sprite(sprite_name: String) -> SpriteData:
	return sprites.get(sprite_name)

func get_sprite_region(sprite_name: String) -> Rect2:
	var sd: SpriteData = sprites.get(sprite_name)
	if sd == null:
		return Rect2()
	return Rect2(sd.x, sd.y, sd.w, sd.h)

func get_unrotated_size(sprite_name: String) -> Vector2:
	var sd: SpriteData = sprites.get(sprite_name)
	if sd == null:
		return Vector2.ZERO
	if sd.rotated:
		return Vector2(sd.h, sd.w)
	return Vector2(sd.w, sd.h)