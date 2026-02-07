class_name Character
extends Bopper

const CharacterDataClass = preload("res://source/funkin/data/character/CharacterData.gd")
const GDAnimateClass = preload("res://source/libs/GDAnimate/src/gdanimate/GDAnimate.gd")

enum CharacterType { BF, DAD, GF, OTHER }

const DIRECTION_NAMES: Array[String] = ["LEFT", "DOWN", "UP", "RIGHT"]

var character_id: String = ""
var character_name: String = ""
var character_type: int = CharacterType.OTHER

var _char_data: CharacterDataClass
var _gd_animate: GDAnimateClass
var _use_gd_animate: bool = false

var hold_timer: float = 0.0
var sing_time_steps: float = 8.0

var camera_focus_point: Vector2 = Vector2.ZERO
var global_offsets: Vector2 = Vector2.ZERO
var data_camera_offsets: Vector2 = Vector2.ZERO
var data_flip_x: bool = false

var _conductor_ref = null
var _current_anim: String = ""

static func create_character(char_id: String) -> Character:
	var data := CharacterDataClass.load_character_data(char_id)
	if data == null:
		push_error("Character: Failed to load character data for: " + char_id)
		return null

	var script: GDScript = load("res://source/funkin/play/character/Character.gd")
	var character = script.new(data.dance_every)
	character.character_id = char_id
	character._char_data = data
	character.character_name = data.name
	character.sing_time_steps = data.sing_time
	character.global_offsets = data.offsets
	character.data_camera_offsets = data.camera_offsets
	character.data_flip_x = data.flip_x
	character.dance_every = data.dance_every
	character.should_bop = false

	if not character._load_assets():
		push_error("Character: Failed to load assets for: " + char_id)
		character.queue_free()
		return null

	character._register_animations()
	return character

var _sub_atlases: Dictionary = {}

func _load_assets() -> bool:
	match _char_data.render_type:
		"animateatlas", "multianimateatlas":
			return _load_gdanimate_atlas()
		"sparrow":
			return _load_sparrow_atlas()
		"multisparrow":
			return _load_multisparrow_atlas()
		_:
			push_warning("Character: Unsupported render type: " + _char_data.render_type)
			return _load_gdanimate_atlas()

func _load_gdanimate_atlas() -> bool:
	var base_path := CharacterDataClass.resolve_asset_path(_char_data.asset_path)
	_gd_animate = GDAnimateClass.new()
	if not _gd_animate.load_atlas(base_path):
		push_error("Character: Failed to load GDAnimate atlas from: " + base_path)
		return false

	if _char_data.render_type == "multianimateatlas":
		for anim_data: CharacterDataClass.AnimData in _char_data.animations:
			if anim_data.asset_path.is_empty():
				continue
			var sub_path := CharacterDataClass.resolve_asset_path(anim_data.asset_path)
			if not DirAccess.dir_exists_absolute(sub_path):
				continue
			var sub_gd := GDAnimateClass.new()
			if sub_gd.load_atlas(sub_path):
				for smap in sub_gd._sprite_maps:
					_gd_animate._sprite_maps.append(smap)
				if sub_gd._anim_data != null:
					for sym_name in sub_gd._anim_data.symbols.keys():
						_gd_animate._anim_data.symbols[sym_name] = sub_gd._anim_data.symbols[sym_name]
			sub_gd.free()

	add_child(_gd_animate)
	_use_gd_animate = true
	_is_animated = true

	if _char_data.scale_value != 1.0:
		_gd_animate.scale = Vector2(_char_data.scale_value, _char_data.scale_value)

	if _char_data.is_pixel:
		_gd_animate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	return true

func _load_sparrow_atlas() -> bool:
	var base_path := CharacterDataClass.resolve_sparrow_path(_char_data.asset_path)
	var xml_path := base_path + ".xml"
	if not FileAccess.file_exists(xml_path) and not ResourceLoader.exists(xml_path):
		push_error("Character: Could not find sparrow atlas: " + xml_path)
		return false

	load_sparrow(xml_path)

	if _char_data.scale_value != 1.0:
		scale = Vector2(_char_data.scale_value, _char_data.scale_value)

	if _char_data.is_pixel:
		_animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	return _atlas != null

func _load_multisparrow_atlas() -> bool:
	var base_path := CharacterDataClass.resolve_sparrow_path(_char_data.asset_path)
	var xml_path := base_path + ".xml"
	if not FileAccess.file_exists(xml_path) and not ResourceLoader.exists(xml_path):
		push_error("Character: Could not find primary sparrow atlas: " + xml_path)
		return false

	load_sparrow(xml_path)
	if _atlas == null:
		return false

	var loaded_paths: Array[String] = []
	for anim_data: CharacterDataClass.AnimData in _char_data.animations:
		if anim_data.asset_path.is_empty() or anim_data.asset_path == _char_data.asset_path:
			continue
		if anim_data.asset_path in loaded_paths:
			continue

		var sub_base := CharacterDataClass.resolve_sparrow_path(anim_data.asset_path)
		var sub_xml := sub_base + ".xml"
		if not FileAccess.file_exists(sub_xml) and not ResourceLoader.exists(sub_xml):
			push_warning("Character: Could not find sub-atlas: " + sub_xml)
			continue

		var sub_atlas = SparrowAtlasClass.load_from_xml(sub_xml)
		if sub_atlas != null:
			_sub_atlases[anim_data.asset_path] = sub_atlas
			loaded_paths.append(anim_data.asset_path)

	if _char_data.scale_value != 1.0:
		scale = Vector2(_char_data.scale_value, _char_data.scale_value)

	if _char_data.is_pixel:
		_animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	return true

func _register_animations() -> void:
	if _use_gd_animate and _gd_animate:
		_register_gdanimate_animations()
	elif _atlas:
		_register_sparrow_animations()

	for anim_data: CharacterDataClass.AnimData in _char_data.animations:
		set_animation_offsets(anim_data.name, anim_data.offsets.x, anim_data.offsets.y)

func _register_gdanimate_animations() -> void:
	for anim_data: CharacterDataClass.AnimData in _char_data.animations:
		if not anim_data.asset_path.is_empty():
			var sub_path := CharacterDataClass.resolve_asset_path(anim_data.asset_path)
			if not DirAccess.dir_exists_absolute(sub_path):
				continue

		var fps: float = float(anim_data.frame_rate)
		var looped: bool = anim_data.looped
		var has_indices: bool = anim_data.frame_indices.size() > 0

		match anim_data.anim_type:
			"symbol":
				if has_indices:
					_gd_animate.anim.add_by_symbol_indices(
						anim_data.name, anim_data.prefix,
						anim_data.frame_indices, fps, looped
					)
				else:
					_gd_animate.anim.add_by_symbol(
						anim_data.name, anim_data.prefix, fps, looped
					)
			_:
				if has_indices:
					_gd_animate.anim.add_by_frame_label_indices(
						anim_data.name, anim_data.prefix,
						anim_data.frame_indices, fps, looped
					)
				else:
					_gd_animate.anim.add_by_frame_label(
						anim_data.name, anim_data.prefix, fps, looped
					)

func _register_sparrow_animations() -> void:
	var sprite_frames := SpriteFrames.new()
	if sprite_frames.has_animation("default"):
		sprite_frames.remove_animation("default")

	for anim_data: CharacterDataClass.AnimData in _char_data.animations:
		var target_atlas = _atlas
		if not anim_data.asset_path.is_empty() and anim_data.asset_path != _char_data.asset_path:
			if _sub_atlases.has(anim_data.asset_path):
				target_atlas = _sub_atlases[anim_data.asset_path]
			else:
				continue

		if target_atlas == null:
			continue

		target_atlas.add_animation_to_sprite_frames(
			sprite_frames, anim_data.name, anim_data.prefix,
			float(anim_data.frame_rate), anim_data.looped, anim_data.frame_indices
		)

	_animated_sprite.sprite_frames = sprite_frames

func _ready() -> void:
	_conductor_ref = get_node_or_null("/root/Conductor")

	if _use_gd_animate and _gd_animate:
		_gd_animate.animation_finished.connect(_on_gd_anim_finished)

func _on_gd_anim_finished() -> void:
	var cur_anim := get_current_animation()
	if cur_anim.is_empty():
		return
	_on_animation_finished(cur_anim)

func _process(delta: float) -> void:
	_update_character(delta)

func _update_character(delta: float) -> void:
	if _is_singing():
		hold_timer += delta
		var step_ms: float = 150.0
		if _conductor_ref:
			step_ms = _conductor_ref.step_length_ms
		var sing_time_sec: float = sing_time_steps * (step_ms / 1000.0)
		var cur_anim := get_current_animation()
		if cur_anim.ends_with("miss"):
			sing_time_sec *= 2.0

		var should_stop: bool = true
		if character_type == CharacterType.BF:
			should_stop = not _is_holding_note()

		if hold_timer > sing_time_sec and should_stop:
			hold_timer = 0.0
			var end_anim := cur_anim.replace("-hold", "") + "-end"
			if has_animation(end_anim):
				_play_anim(end_anim, true)
			else:
				dance(true)
	else:
		hold_timer = 0.0

func _on_animation_finished(anim_name: String) -> void:
	if not anim_name.ends_with("-hold") and has_animation(anim_name + "-hold"):
		_play_anim(anim_name + "-hold", true)
		return

	if (anim_name.ends_with("-end") and not anim_name.begins_with("idle") and not anim_name.begins_with("dance")) \
		or anim_name.begins_with("combo") or anim_name.begins_with("drop"):
		dance(true)

func _apply_animation_offsets(anim_name: String) -> void:
	super._apply_animation_offsets(anim_name)
	var offset := _anim_offsets - global_offsets
	if _use_gd_animate and _gd_animate:
		_gd_animate.position = Vector2(-offset.x, -offset.y)
	elif _animated_sprite:
		_animated_sprite.position = Vector2(-offset.x, -offset.y)

func play_animation(anim_name: String, force_restart: bool = false) -> void:
	if _use_gd_animate and _gd_animate:
		if _gd_animate.anim.has_animation(anim_name):
			_gd_animate.anim.play(anim_name, force_restart)
			_current_anim = anim_name
			return
	super.play_animation(anim_name, force_restart)
	_current_anim = anim_name

func has_animation(anim_name: String) -> bool:
	if _use_gd_animate and _gd_animate:
		return _gd_animate.anim.has_animation(anim_name)
	return super.has_animation(anim_name)

func get_current_animation() -> String:
	return _current_anim

func is_animation_finished() -> bool:
	if _use_gd_animate and _gd_animate:
		return _gd_animate.anim.finished
	if _animated_sprite and _animated_sprite.sprite_frames:
		return not _animated_sprite.is_playing()
	return true

func dance(force: bool = false) -> void:
	if not force:
		if _is_singing():
			return
		var cur_anim := get_current_animation()
		if not cur_anim.begins_with("dance") and not cur_anim.begins_with("idle") and not is_animation_finished():
			return
	super.dance(force)

func play_sing_animation(direction: int, miss: bool = false, suffix: String = "") -> void:
	if direction < 0 or direction >= DIRECTION_NAMES.size():
		return
	var anim_str: String = "sing" + DIRECTION_NAMES[direction]
	if miss:
		anim_str += "miss"
	if not suffix.is_empty():
		anim_str += "-" + suffix
	_play_anim(anim_str, true)
	hold_timer = 0.0

func _is_singing() -> bool:
	var cur_anim := get_current_animation()
	return cur_anim.begins_with("sing") and not cur_anim.ends_with("-end")

func _is_holding_note() -> bool:
	var pi = get_node_or_null("/root/PreciseInput")
	if pi == null:
		return false
	for i in range(4):
		if pi.is_pressed(i):
			return true
	return false

func get_character_origin() -> Vector2:
	if _use_gd_animate and _gd_animate:
		var local_bounds := _gd_animate.compute_frame_bounds()
		if local_bounds.size == Vector2.ZERO:
			return Vector2.ZERO
		var local_origin := Vector2(
			local_bounds.position.x + local_bounds.size.x / 2.0,
			local_bounds.position.y + local_bounds.size.y
		)
		return Vector2(
			local_origin.x * _gd_animate.scale.x,
			local_origin.y * _gd_animate.scale.y
		)
	elif _animated_sprite and _animated_sprite.sprite_frames:
		var size := get_display_size()
		return Vector2(size.x / 2.0, size.y)
	return Vector2.ZERO

func get_visual_center() -> Vector2:
	if _use_gd_animate and _gd_animate:
		var local_bounds := _gd_animate.compute_frame_bounds()
		if local_bounds.size == Vector2.ZERO:
			return Vector2.ZERO
		var local_center := local_bounds.position + local_bounds.size / 2.0
		return Vector2(
			local_center.x * _gd_animate.scale.x,
			local_center.y * _gd_animate.scale.y
		)
	elif _animated_sprite and _animated_sprite.sprite_frames:
		var size := get_display_size()
		return Vector2(size.x / 2.0, size.y / 2.0)
	return Vector2.ZERO

func get_visual_size() -> Vector2:
	if _use_gd_animate and _gd_animate:
		var local_bounds := _gd_animate.compute_frame_bounds()
		return Vector2(
			local_bounds.size.x * absf(_gd_animate.scale.x),
			local_bounds.size.y * absf(_gd_animate.scale.y)
		)
	return get_display_size()

func reset_camera_focus_point() -> void:
	var visual_center := get_visual_center()
	camera_focus_point = original_position + visual_center + data_camera_offsets

func get_data_flip_x() -> bool:
	return data_flip_x

func get_scale_value() -> float:
	return _char_data.scale_value if _char_data else 1.0