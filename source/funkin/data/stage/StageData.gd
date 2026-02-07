class_name StageData
extends RefCounted

var version: String = "1.0.0"
var name: String = "Unknown"
var directory: String = "shared"
var camera_zoom: float = 1.0
var props: Array[PropData] = []
var characters: CharacterPositions = CharacterPositions.new()

class PropData:
	extends RefCounted
	var name: String = ""
	var asset_path: String = ""
	var position: Vector2 = Vector2.ZERO
	var scale: Vector2 = Vector2.ONE
	var z_index: int = 0
	var is_pixel: bool = false
	var flip_x: bool = false
	var flip_y: bool = false
	var alpha: float = 1.0
	var angle: float = 0.0
	var scroll: Vector2 = Vector2.ONE
	var dance_every: float = 0.0
	var anim_type: String = "sparrow"
	var blend: String = ""
	var color: String = "#FFFFFF"
	var starting_animation: String = ""
	var animations: Array[AnimData] = []

class AnimData:
	extends RefCounted
	var name: String = ""
	var prefix: String = ""
	var frame_rate: int = 24
	var looped: bool = false
	var flip_x: bool = false
	var flip_y: bool = false
	var offsets: Vector2 = Vector2.ZERO
	var frame_indices: Array[int] = []

class CharacterPositions:
	extends RefCounted
	var bf: StageCharData = StageCharData.new()
	var dad: StageCharData = StageCharData.new()
	var gf: StageCharData = StageCharData.new()

class StageCharData:
	extends RefCounted
	var position: Vector2 = Vector2.ZERO
	var z_index: int = 0
	var camera_offsets: Vector2 = Vector2.ZERO
	var scale: float = 1.0
	var scroll: Vector2 = Vector2.ONE
	var alpha: float = 1.0
	var angle: float = 0.0

static func from_json(json_path: String) -> StageData:
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open stage data: " + json_path)
		return null

	var text := file.get_as_text()
	file.close()

	var data = JSON.parse_string(text)
	if data == null:
		push_error("Failed to parse stage JSON: " + json_path)
		return null

	return _parse(data)

static func _parse(data: Dictionary) -> StageData:
	var stage := StageData.new()
	stage.version = data.get("version", "1.0.0")
	stage.name = data.get("name", "Unknown")
	stage.directory = data.get("directory", "shared")
	stage.camera_zoom = data.get("cameraZoom", 1.0)

	var props_array: Array = data.get("props", [])
	for prop_dict: Dictionary in props_array:
		var prop := PropData.new()
		prop.name = prop_dict.get("name", "")
		prop.asset_path = prop_dict.get("assetPath", "")

		var pos: Array = prop_dict.get("position", [0, 0])
		prop.position = Vector2(pos[0], pos[1])

		var sc = prop_dict.get("scale", [1, 1])
		if sc is Array:
			prop.scale = Vector2(sc[0], sc[1])
		elif sc is float or sc is int:
			prop.scale = Vector2(sc, sc)

		prop.z_index = prop_dict.get("zIndex", 0)
		prop.is_pixel = prop_dict.get("isPixel", false)
		prop.flip_x = prop_dict.get("flipX", false)
		prop.flip_y = prop_dict.get("flipY", false)
		prop.alpha = prop_dict.get("alpha", 1.0)
		prop.angle = prop_dict.get("angle", 0.0)

		var scroll_arr: Array = prop_dict.get("scroll", [1, 1])
		prop.scroll = Vector2(scroll_arr[0], scroll_arr[1])

		prop.dance_every = prop_dict.get("danceEvery", 0.0)
		prop.anim_type = prop_dict.get("animType", "sparrow")
		prop.blend = prop_dict.get("blend", "")
		prop.color = prop_dict.get("color", "#FFFFFF")
		prop.starting_animation = prop_dict.get("startingAnimation", "")

		var anims_array: Array = prop_dict.get("animations", [])
		for anim_dict: Dictionary in anims_array:
			var anim := AnimData.new()
			anim.name = anim_dict.get("name", "")
			anim.prefix = anim_dict.get("prefix", "")
			anim.frame_rate = anim_dict.get("frameRate", 24)
			anim.looped = anim_dict.get("looped", false)
			anim.flip_x = anim_dict.get("flipX", false)
			anim.flip_y = anim_dict.get("flipY", false)

			var off: Array = anim_dict.get("offsets", [0, 0])
			anim.offsets = Vector2(off[0], off[1])

			var indices_raw: Array = anim_dict.get("frameIndices", [])
			for idx in indices_raw:
				anim.frame_indices.append(int(idx))

			prop.animations.append(anim)

		stage.props.append(prop)

	var chars_dict: Dictionary = data.get("characters", {})
	if chars_dict.has("bf"):
		stage.characters.bf = _parse_char_data(chars_dict["bf"])
	if chars_dict.has("dad"):
		stage.characters.dad = _parse_char_data(chars_dict["dad"])
	if chars_dict.has("gf"):
		stage.characters.gf = _parse_char_data(chars_dict["gf"])

	return stage

static func _parse_char_data(data: Dictionary) -> StageCharData:
	var cd := StageCharData.new()
	var pos: Array = data.get("position", [0, 0])
	cd.position = Vector2(pos[0], pos[1])
	cd.z_index = data.get("zIndex", 0)

	var cam_off: Array = data.get("cameraOffsets", [0, 0])
	cd.camera_offsets = Vector2(cam_off[0], cam_off[1])

	cd.scale = data.get("scale", 1.0)

	var scroll_arr: Array = data.get("scroll", [1, 1])
	cd.scroll = Vector2(scroll_arr[0], scroll_arr[1])

	cd.alpha = data.get("alpha", 1.0)
	cd.angle = data.get("angle", 0.0)
	return cd