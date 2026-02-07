class_name CharacterData
extends RefCounted

const CHARACTERS_PATH := "res://assets/data/characters"
const DEFAULT_SING_TIME: float = 8.0
const DEFAULT_DANCE_EVERY: float = 1.0
const DEFAULT_SCALE: float = 1.0
const DEFAULT_FRAMERATE: int = 24
const DEFAULT_STARTING_ANIM: String = "idle"
const DEFAULT_ANIM_TYPE: String = "framelabel"

var version: String = "1.0.0"
var name: String = "Untitled Character"
var render_type: String = "sparrow"
var asset_path: String = ""
var flip_x: bool = false
var offsets: Vector2 = Vector2.ZERO
var camera_offsets: Vector2 = Vector2.ZERO
var scale_value: float = 1.0
var sing_time: float = 8.0
var dance_every: float = 1.0
var starting_animation: String = "idle"
var is_pixel: bool = false
var animations: Array = []

class AnimData:
	extends RefCounted
	var name: String = ""
	var prefix: String = ""
	var asset_path: String = ""
	var frame_rate: int = 24
	var looped: bool = false
	var flip_x: bool = false
	var flip_y: bool = false
	var offsets: Vector2 = Vector2.ZERO
	var frame_indices: Array[int] = []
	var anim_type: String = "framelabel"

static func load_character_data(char_id: String) -> CharacterData:
	var json_path := "%s/%s.json" % [CHARACTERS_PATH, char_id]
	if not FileAccess.file_exists(json_path) and not ResourceLoader.exists(json_path):
		push_error("CharacterData: Could not find character file: " + json_path)
		return null
	return from_json(json_path)

static func from_json(json_path: String) -> CharacterData:
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("CharacterData: Failed to open: " + json_path)
		return null

	var text := file.get_as_text()
	file.close()

	var data = JSON.parse_string(text)
	if data == null or not (data is Dictionary):
		push_error("CharacterData: Failed to parse JSON: " + json_path)
		return null

	return _parse(data)

static func _parse(data: Dictionary) -> CharacterData:
	var cd := CharacterData.new()
	cd.version = data.get("version", "1.0.0")
	cd.name = data.get("name", "Untitled Character")
	cd.render_type = data.get("renderType", "sparrow")
	cd.asset_path = data.get("assetPath", "")
	cd.flip_x = data.get("flipX", false)
	cd.scale_value = data.get("scale", DEFAULT_SCALE)
	cd.sing_time = data.get("singTime", DEFAULT_SING_TIME)
	cd.dance_every = data.get("danceEvery", DEFAULT_DANCE_EVERY)
	cd.starting_animation = data.get("startingAnimation", DEFAULT_STARTING_ANIM)
	cd.is_pixel = data.get("isPixel", false)

	var off: Array = data.get("offsets", [0, 0])
	if off.size() >= 2:
		cd.offsets = Vector2(off[0], off[1])

	var cam_off: Array = data.get("cameraOffsets", [0, 0])
	if cam_off.size() >= 2:
		cd.camera_offsets = Vector2(cam_off[0], cam_off[1])

	var anims_array: Array = data.get("animations", [])
	for anim_dict: Dictionary in anims_array:
		var anim := AnimData.new()
		anim.name = anim_dict.get("name", "")
		anim.prefix = anim_dict.get("prefix", "")
		anim.asset_path = anim_dict.get("assetPath", anim_dict.get("asset", ""))
		anim.frame_rate = anim_dict.get("frameRate", DEFAULT_FRAMERATE)
		anim.looped = anim_dict.get("looped", false)
		anim.flip_x = anim_dict.get("flipX", false)
		anim.flip_y = anim_dict.get("flipY", false)
		anim.anim_type = anim_dict.get("animType", DEFAULT_ANIM_TYPE)

		var anim_off: Array = anim_dict.get("offsets", [0, 0])
		if anim_off.size() >= 2:
			anim.offsets = Vector2(anim_off[0], anim_off[1])

		var indices_raw: Array = anim_dict.get("frameIndices", [])
		for idx in indices_raw:
			anim.frame_indices.append(int(idx))

		cd.animations.append(anim)

	return cd

static func resolve_asset_path(raw_path: String) -> String:
	if ":" in raw_path:
		var parts := raw_path.split(":", true, 1)
		var library: String = parts[0]
		var sub_path: String = parts[1]
		var dir_path := "res://assets/%s/images/%s" % [library, sub_path]
		if DirAccess.dir_exists_absolute(dir_path):
			return dir_path
		dir_path = "res://assets/images/%s" % sub_path
		if DirAccess.dir_exists_absolute(dir_path):
			return dir_path
		return "res://assets/%s/images/%s" % [library, sub_path]
	var dir_path := "res://assets/shared/images/%s" % raw_path
	if DirAccess.dir_exists_absolute(dir_path):
		return dir_path
	dir_path = "res://assets/images/%s" % raw_path
	if DirAccess.dir_exists_absolute(dir_path):
		return dir_path
	return "res://assets/shared/images/%s" % raw_path

static func resolve_sparrow_path(raw_path: String) -> String:
	if ":" in raw_path:
		var parts := raw_path.split(":", true, 1)
		var library: String = parts[0]
		var sub_path: String = parts[1]
		for base in ["res://assets/%s/images/%s" % [library, sub_path], "res://assets/images/%s" % sub_path]:
			if FileAccess.file_exists(base + ".xml") or ResourceLoader.exists(base + ".xml"):
				return base
		return "res://assets/%s/images/%s" % [library, sub_path]
	for base in ["res://assets/shared/images/%s" % raw_path, "res://assets/images/%s" % raw_path]:
		if FileAccess.file_exists(base + ".xml") or ResourceLoader.exists(base + ".xml"):
			return base
	return "res://assets/images/%s" % raw_path