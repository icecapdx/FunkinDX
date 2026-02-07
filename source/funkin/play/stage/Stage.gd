class_name Stage
extends Node2D

const StageDataClass = preload("res://source/funkin/data/stage/StageData.gd")
const StagePropClass = preload("res://source/funkin/play/stage/StageProp.gd")
const BopperClass = preload("res://source/funkin/play/stage/Bopper.gd")
const GDAnimateClass = preload("res://source/libs/GDAnimate/src/gdanimate/GDAnimate.gd")
const CharacterClass = preload("res://source/funkin/play/character/Character.gd")

const STAGES_PATH := "res://assets/data/stages"
const IMAGES_PATH := "res://assets/images"

var id: String = ""
var _data: StageDataClass
var named_props: Dictionary = {}
var boppers: Array = []
var camera_zoom: float = 1.0

var bf = null
var dad = null
var gf = null
var _characters: Array = []

signal stage_built

static func load_stage(stage_id: String) -> Stage:
	var json_path := "%s/%s.json" % [STAGES_PATH, stage_id]
	if not FileAccess.file_exists(json_path) and not ResourceLoader.exists(json_path):
		push_error("Stage: Could not find stage file: " + json_path)
		return null

	var data := StageDataClass.from_json(json_path)
	if data == null:
		push_error("Stage: Failed to parse stage data: " + json_path)
		return null

	var stage := Stage.new()
	stage.id = stage_id
	stage._data = data
	stage.camera_zoom = data.camera_zoom
	return stage

func get_data() -> StageDataClass:
	return _data

func get_stage_name() -> String:
	if _data:
		return _data.name
	return "Unknown"

func get_camera_zoom() -> float:
	return camera_zoom

func get_bf_position() -> Vector2:
	if _data:
		return _data.characters.bf.position
	return Vector2.ZERO

func get_dad_position() -> Vector2:
	if _data:
		return _data.characters.dad.position
	return Vector2.ZERO

func get_gf_position() -> Vector2:
	if _data:
		return _data.characters.gf.position
	return Vector2.ZERO

func get_bf_camera_offsets() -> Vector2:
	var stage_off := Vector2.ZERO
	if _data:
		stage_off = _data.characters.bf.camera_offsets
	var char_off := Vector2.ZERO
	if bf:
		char_off = bf.data_camera_offsets
	return stage_off + char_off

func get_dad_camera_offsets() -> Vector2:
	var stage_off := Vector2.ZERO
	if _data:
		stage_off = _data.characters.dad.camera_offsets
	var char_off := Vector2.ZERO
	if dad:
		char_off = dad.data_camera_offsets
	return stage_off + char_off

func get_gf_camera_offsets() -> Vector2:
	var stage_off := Vector2.ZERO
	if _data:
		stage_off = _data.characters.gf.camera_offsets
	var char_off := Vector2.ZERO
	if gf:
		char_off = gf.data_camera_offsets
	return stage_off + char_off

func get_character_data(char_type: String) -> StageDataClass.StageCharData:
	if _data == null:
		return null
	match char_type:
		"bf":
			return _data.characters.bf
		"dad":
			return _data.characters.dad
		"gf":
			return _data.characters.gf
	return null

func build() -> void:
	if _data == null:
		push_error("Stage: No data loaded")
		return

	for prop_data: StageDataClass.PropData in _data.props:
		var is_solid_color := prop_data.asset_path.begins_with("#")
		var is_animated := prop_data.animations.size() > 0

		var prop: StagePropClass
		if prop_data.dance_every != 0 or is_animated:
			var bopper := BopperClass.new(prop_data.dance_every)
			prop = bopper
		else:
			prop = StagePropClass.new()

		if is_animated:
			match prop_data.anim_type:
				"animateatlas":
					var atlas_path := _resolve_asset_path(prop_data.asset_path)
					var gd_anim := GDAnimateClass.new()
					gd_anim.load_atlas(atlas_path)
					prop.add_child(gd_anim)
					prop._is_animated = true
				_:
					var xml_path := _resolve_atlas_path(prop_data.asset_path)
					if not xml_path.is_empty():
						prop.load_sparrow(xml_path)
						prop.setup_animations(prop_data.animations, prop_data.anim_type)
					else:
						push_error("Stage: Could not find atlas for prop: " + prop_data.asset_path)
						continue
		elif is_solid_color:
			var col := Color.from_string(prop_data.asset_path, Color.BLACK)
			prop.make_solid_color(int(prop_data.scale.x), int(prop_data.scale.y), col)
		else:
			var tex_path := _resolve_image_path(prop_data.asset_path)
			if not tex_path.is_empty():
				prop.load_texture(tex_path)
			else:
				push_error("Stage: Could not find image for prop: " + prop_data.asset_path)
				continue

		if not prop.is_valid():
			push_error("Stage: Prop has no valid texture: " + prop_data.name + " (" + prop_data.asset_path + ")")
			prop.queue_free()
			continue

		if not is_solid_color:
			prop.scale = prop_data.scale

		prop.position = prop_data.position
		prop.modulate.a = prop_data.alpha
		prop.z_index = prop_data.z_index
		prop.scroll_factor = prop_data.scroll

		if prop_data.angle != 0.0:
			prop.rotation_degrees = prop_data.angle

		if prop_data.flip_x:
			prop.scale.x *= -1
		if prop_data.flip_y:
			prop.scale.y *= -1

		if prop_data.color != "#FFFFFF" and prop_data.color != "" and not is_solid_color:
			prop.modulate = prop.modulate * Color.from_string(prop_data.color, Color.WHITE)

		if prop is BopperClass:
			for anim_data: StageDataClass.AnimData in prop_data.animations:
				prop.set_animation_offsets(anim_data.name, anim_data.offsets.x, anim_data.offsets.y)
			prop.original_position = prop_data.position

		if not prop_data.starting_animation.is_empty() and prop.has_animation(prop_data.starting_animation):
			prop.play_animation(prop_data.starting_animation)

		prop.prop_name = prop_data.name

		if not prop_data.name.is_empty():
			named_props[prop_data.name] = prop

		if prop is BopperClass:
			boppers.append(prop)

		add_child(prop)

	_sort_children_by_z_index()
	stage_built.emit()

func _sort_children_by_z_index() -> void:
	var children: Array[Node] = []
	for child in get_children():
		children.append(child)

	children.sort_custom(func(a: Node, b: Node) -> bool:
		return a.z_index < b.z_index
	)

	for i in range(children.size()):
		move_child(children[i], i)

func _resolve_image_path(asset_path: String) -> String:
	var directory := _data.directory if _data else "shared"

	var dir_path := "res://assets/%s/images/%s.png" % [directory, asset_path]
	if FileAccess.file_exists(dir_path) or ResourceLoader.exists(dir_path):
		return dir_path

	var images_path := "%s/%s.png" % [IMAGES_PATH, asset_path]
	if FileAccess.file_exists(images_path) or ResourceLoader.exists(images_path):
		return images_path

	var shared_path := "res://assets/shared/images/%s.png" % asset_path
	if FileAccess.file_exists(shared_path) or ResourceLoader.exists(shared_path):
		return shared_path

	return ""

func _resolve_atlas_path(asset_path: String) -> String:
	var directory := _data.directory if _data else "shared"

	var dir_xml := "res://assets/%s/images/%s.xml" % [directory, asset_path]
	if FileAccess.file_exists(dir_xml) or ResourceLoader.exists(dir_xml):
		return dir_xml

	var images_xml := "%s/%s.xml" % [IMAGES_PATH, asset_path]
	if FileAccess.file_exists(images_xml) or ResourceLoader.exists(images_xml):
		return images_xml

	var shared_xml := "res://assets/shared/images/%s.xml" % asset_path
	if FileAccess.file_exists(shared_xml) or ResourceLoader.exists(shared_xml):
		return shared_xml

	return ""

func _resolve_asset_path(asset_path: String) -> String:
	var directory := _data.directory if _data else "shared"

	var dir_path := "res://assets/%s/images/%s" % [directory, asset_path]
	if DirAccess.dir_exists_absolute(dir_path):
		return dir_path

	var images_path := "%s/%s" % [IMAGES_PATH, asset_path]
	if DirAccess.dir_exists_absolute(images_path):
		return images_path

	return ""

func get_named_prop(prop_name: String) -> StagePropClass:
	return named_props.get(prop_name)

func add_characters(bf_id: String = "bf", dad_id: String = "dad", gf_id: String = "gf") -> void:
	if not gf_id.is_empty():
		gf = CharacterClass.create_character(gf_id)
		if gf:
			gf.character_type = CharacterClass.CharacterType.GF
			_apply_character_stage_data(gf, "gf")
			add_child(gf)
			_characters.append(gf)
			boppers.append(gf)
			print("[Stage] Added GF: %s at %s" % [gf_id, str(gf.position)])

	if not dad_id.is_empty():
		dad = CharacterClass.create_character(dad_id)
		if dad:
			dad.character_type = CharacterClass.CharacterType.DAD
			_apply_character_stage_data(dad, "dad")
			add_child(dad)
			_characters.append(dad)
			boppers.append(dad)
			print("[Stage] Added Dad: %s at %s" % [dad_id, str(dad.position)])

	if not bf_id.is_empty():
		bf = CharacterClass.create_character(bf_id)
		if bf:
			bf.character_type = CharacterClass.CharacterType.BF
			_apply_character_stage_data(bf, "bf")
			add_child(bf)
			_characters.append(bf)
			boppers.append(bf)
			print("[Stage] Added BF: %s at %s" % [bf_id, str(bf.position)])

	_sort_children_by_z_index()

func _apply_character_stage_data(character, char_type: String) -> void:
	var char_stage_data: StageDataClass.StageCharData = get_character_data(char_type)
	if char_stage_data == null:
		return

	var should_flip: bool
	if char_type == "bf":
		should_flip = not character.data_flip_x
	else:
		should_flip = character.data_flip_x

	var combined_scale: float = char_stage_data.scale * character.get_scale_value()
	if character._use_gd_animate and character._gd_animate:
		character._gd_animate.scale = Vector2(combined_scale, combined_scale)
		if should_flip:
			character._gd_animate.scale.x *= -1
	else:
		character.scale = Vector2(combined_scale, combined_scale)
		if should_flip:
			character.scale.x *= -1

	character.dance(true)
	var char_origin: Vector2 = character.get_character_origin()
	character.position = char_stage_data.position - char_origin + character.global_offsets
	character.original_position = character.position
	character.z_index = char_stage_data.z_index
	character.scroll_factor = char_stage_data.scroll
	character.modulate.a = char_stage_data.alpha

	if char_stage_data.angle != 0.0:
		character.rotation_degrees = char_stage_data.angle

	character.reset_camera_focus_point()
	character.camera_focus_point += char_stage_data.camera_offsets

func get_bf():
	return bf

func get_dad():
	return dad

func get_gf():
	return gf

func on_beat_hit(beat: int) -> void:
	for bopper in boppers:
		if bopper is BopperClass or bopper is CharacterClass:
			bopper.on_beat_hit(beat)

func on_step_hit(step: int) -> void:
	for bopper in boppers:
		if bopper is BopperClass or bopper is CharacterClass:
			bopper.on_step_hit(step)

func reset_stage() -> void:
	for prop_data: StageDataClass.PropData in _data.props:
		var prop := get_named_prop(prop_data.name)
		if prop != null:
			prop.position = prop_data.position
			prop.z_index = prop_data.z_index

	for character in _characters:
		character.reset_position()
		character.dance(true)

func cleanup() -> void:
	for child in get_children():
		child.queue_free()
	named_props.clear()
	boppers.clear()
	_characters.clear()
	bf = null
	dad = null
	gf = null
