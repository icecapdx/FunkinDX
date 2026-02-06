class_name SparrowAtlas
extends RefCounted

const Parser = preload("res://source/libs/Sparrowdot/src/sparrow/Parser.gd")

var texture: Texture2D
var parse_result
var _atlas_textures: Dictionary = {}

static func load_from_xml(xml_path: String, texture_path: String = ""):
	var script = load("res://source/libs/Sparrowdot/src/sparrow/SparrowAtlas.gd")
	var atlas = script.new()
	
	atlas.parse_result = Parser.parse(xml_path)
	if atlas.parse_result == null:
		return null
	
	var tex_path := texture_path
	if tex_path.is_empty():
		var base_dir := xml_path.get_base_dir()
		tex_path = base_dir.path_join(atlas.parse_result.image_path)
	
	atlas.texture = load(tex_path)
	if atlas.texture == null:
		push_error("Failed to load texture: " + tex_path)
		return null
	
	return atlas

func get_frame(frame_name: String):
	return parse_result.frames_by_name.get(frame_name)

func get_all_frames() -> Array:
	return parse_result.frames

func get_animation_names() -> Array[String]:
	var animations := Parser.group_frames_by_animation(parse_result.frames)
	var names: Array[String] = []
	for key in animations.keys():
		names.append(key)
	return names

func get_animation_frames(animation_name: String) -> Array:
	var animations := Parser.group_frames_by_animation(parse_result.frames)
	if animations.has(animation_name):
		var frames: Array = []
		for f in animations[animation_name]:
			frames.append(f)
		return frames
	return []

func get_frames_by_prefix(prefix: String) -> Array:
	var result: Array = []
	for frame in parse_result.frames:
		if frame.name.begins_with(prefix):
			result.append(frame)
	return result

func get_frames_by_indices(prefix: String, indices: Array[int]) -> Array:
	var result: Array = []
	for idx in indices:
		var frame_name := prefix + str(idx).pad_zeros(4)
		if parse_result.frames_by_name.has(frame_name):
			result.append(parse_result.frames_by_name[frame_name])
	return result

func create_atlas_texture(frame) -> AtlasTexture:
	if _atlas_textures.has(frame.name):
		return _atlas_textures[frame.name]
	
	var atlas_tex := AtlasTexture.new()
	atlas_tex.atlas = texture
	atlas_tex.region = frame.get_region()
	
	if frame.is_trimmed:
		atlas_tex.margin = frame.get_margin()
	
	_atlas_textures[frame.name] = atlas_tex
	return atlas_tex

func create_sprite_frames(fps: float = 24.0, loop: bool = true) -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation("default")
	
	var animations := Parser.group_frames_by_animation(parse_result.frames)
	
	for anim_name in animations.keys():
		sprite_frames.add_animation(anim_name)
		sprite_frames.set_animation_speed(anim_name, fps)
		sprite_frames.set_animation_loop(anim_name, loop)
		
		for frame in animations[anim_name]:
			var atlas_tex := create_atlas_texture(frame)
			sprite_frames.add_frame(anim_name, atlas_tex)
	
	return sprite_frames

func create_sprite_frames_for_animations(animation_config: Dictionary, fps: float = 24.0) -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation("default")
	
	for anim_name in animation_config.keys():
		var config = animation_config[anim_name]
		sprite_frames.add_animation(anim_name)
		
		var anim_fps: float = config.get("fps", fps)
		var anim_loop: bool = config.get("loop", true)
		var prefix: String = config.get("prefix", anim_name)
		var indices: Array = config.get("indices", [])
		
		sprite_frames.set_animation_speed(anim_name, anim_fps)
		sprite_frames.set_animation_loop(anim_name, anim_loop)
		
		var frames: Array
		if indices.size() > 0:
			var typed_indices: Array[int] = []
			for i in indices:
				typed_indices.append(i)
			frames = get_frames_by_indices(prefix, typed_indices)
		else:
			frames = get_frames_by_prefix(prefix)
		
		for frame in frames:
			var atlas_tex := create_atlas_texture(frame)
			sprite_frames.add_frame(anim_name, atlas_tex)
	
	return sprite_frames

func add_animation_to_sprite_frames(sprite_frames: SpriteFrames, anim_name: String, prefix: String, fps: float = 24.0, loop: bool = true, indices: Array[int] = []) -> void:
	if not sprite_frames.has_animation(anim_name):
		sprite_frames.add_animation(anim_name)
	
	sprite_frames.set_animation_speed(anim_name, fps)
	sprite_frames.set_animation_loop(anim_name, loop)
	
	var frames: Array
	if indices.size() > 0:
		frames = get_frames_by_indices(prefix, indices)
	else:
		frames = get_frames_by_prefix(prefix)
	
	for frame in frames:
		var atlas_tex := create_atlas_texture(frame)
		sprite_frames.add_frame(anim_name, atlas_tex)

func create_animated_sprite_2d(fps: float = 24.0, loop: bool = true) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = create_sprite_frames(fps, loop)
	return sprite
