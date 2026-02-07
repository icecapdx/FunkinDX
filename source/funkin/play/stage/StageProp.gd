class_name StageProp
extends Node2D

const SparrowAtlasClass = preload("res://source/libs/Sparrowdot/src/sparrow/SparrowAtlas.gd")

var prop_name: String = ""
var _sprite: Sprite2D
var _animated_sprite: AnimatedSprite2D
var _atlas: SparrowAtlasClass
var _is_animated: bool = false
var _is_solid_color: bool = false

var scroll_factor: Vector2 = Vector2.ONE

func _init():
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.visible = false
	add_child(_sprite)

	_animated_sprite = AnimatedSprite2D.new()
	_animated_sprite.centered = false
	_animated_sprite.visible = false
	add_child(_animated_sprite)

func load_texture(asset_path: String) -> void:
	var tex := load(asset_path) as Texture2D
	if tex == null:
		push_error("StageProp: Failed to load texture: " + asset_path)
		return
	_sprite.texture = tex
	_sprite.visible = true
	_animated_sprite.visible = false
	_is_animated = false

func load_sparrow(xml_path: String) -> void:
	_atlas = SparrowAtlasClass.load_from_xml(xml_path)
	if _atlas == null:
		push_error("StageProp: Failed to load sparrow atlas: " + xml_path)
		return
	_is_animated = true
	_sprite.visible = false
	_animated_sprite.visible = true

func make_solid_color(width: int, height: int, color: Color) -> void:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex := ImageTexture.create_from_image(img)
	_sprite.texture = tex
	_sprite.visible = true
	_sprite.centered = false
	_animated_sprite.visible = false
	_is_animated = false
	_is_solid_color = true

func setup_animations(animations: Array, anim_type: String = "sparrow") -> void:
	if _atlas == null:
		return
	if animations.is_empty():
		var sprite_frames := _atlas.create_sprite_frames(24.0, false)
		_animated_sprite.sprite_frames = sprite_frames
		return

	var sprite_frames := SpriteFrames.new()
	if sprite_frames.has_animation("default"):
		sprite_frames.remove_animation("default")

	for anim in animations:
		var anim_name: String = anim.name
		var prefix: String = anim.prefix
		var fps: int = anim.frame_rate
		var looped: bool = anim.looped
		var indices: Array[int] = anim.frame_indices

		_atlas.add_animation_to_sprite_frames(sprite_frames, anim_name, prefix, float(fps), looped, indices)

	_animated_sprite.sprite_frames = sprite_frames

func play_animation(anim_name: String, force_restart: bool = false) -> void:
	if not _is_animated:
		return
	if _animated_sprite.sprite_frames == null:
		return
	if not _animated_sprite.sprite_frames.has_animation(anim_name):
		return
	if not force_restart and _animated_sprite.animation == anim_name and _animated_sprite.is_playing():
		return
	_animated_sprite.play(anim_name)

func get_current_animation() -> String:
	if _is_animated:
		return _animated_sprite.animation
	return ""

func has_animation(anim_name: String) -> bool:
	if not _is_animated or _animated_sprite.sprite_frames == null:
		return false
	return _animated_sprite.sprite_frames.has_animation(anim_name)

func is_valid() -> bool:
	if _is_solid_color:
		return _sprite.texture != null
	if _is_animated:
		return _animated_sprite.sprite_frames != null and _animated_sprite.sprite_frames.get_animation_names().size() > 0
	return _sprite.texture != null

func get_display_size() -> Vector2:
	if _is_animated and _animated_sprite.sprite_frames != null:
		var anim_names := _animated_sprite.sprite_frames.get_animation_names()
		if anim_names.size() > 0:
			var first_anim: String = anim_names[0]
			if _animated_sprite.sprite_frames.get_frame_count(first_anim) > 0:
				var tex := _animated_sprite.sprite_frames.get_frame_texture(first_anim, 0)
				if tex:
					return tex.get_size()
	if _sprite.texture:
		return _sprite.texture.get_size()
	return Vector2.ZERO