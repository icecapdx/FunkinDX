@tool
class_name SustainTrail
extends Node2D

const SparrowAtlasClass = preload("res://source/libs/Sparrowdot/src/sparrow/SparrowAtlas.gd")

const DIRECTION_COLORS: Array[String] = ["purple", "blue", "green", "red"]

var strum_time: float = 0.0
var note_data: int = 0
var sustain_length: float = 0.0
var full_sustain_length: float = 0.0
var must_press: bool = false

var hit_note: bool = false
var missed_note: bool = false

var _atlas = null
var _sprite_frames: SpriteFrames = null
var _animated_sprite: AnimatedSprite2D = null
var _hold_piece_sprite: Sprite2D = null
var _hold_end_sprite: Sprite2D = null

var _current_clip_height: float = 0.0

static func create(atlas, p_strum_time: float, p_note_data: int, p_sustain_length: float):
	var script = load("res://source/funkin/play/notes/SustainTrail.gd")
	var trail = script.new()
	trail._atlas = atlas
	trail.strum_time = p_strum_time
	trail.note_data = clampi(p_note_data, 0, 3)
	trail.sustain_length = p_sustain_length
	trail.full_sustain_length = p_sustain_length
	trail._setup_sprites()
	return trail

func _setup_sprites() -> void:
	var color: String = DIRECTION_COLORS[note_data]
	
	var hold_piece_name: String = color + " hold piece instance 10000"
	var hold_piece_frame = _atlas.get_frame(hold_piece_name)
	if hold_piece_frame != null:
		_hold_piece_sprite = Sprite2D.new()
		add_child(_hold_piece_sprite)
		var hold_piece_tex = _atlas.create_atlas_texture(hold_piece_frame)
		_hold_piece_sprite.texture = hold_piece_tex
		_hold_piece_sprite.centered = false
		_hold_piece_sprite.position.y = 0
		_hold_piece_sprite.position.x = 0
	
	var hold_end_name: String
	if color == "purple":
		hold_end_name = "pruple end hold instance 10000"
	else:
		hold_end_name = color + " hold end instance 10000"
	var hold_end_frame = _atlas.get_frame(hold_end_name)
	if hold_end_frame != null:
		_hold_end_sprite = Sprite2D.new()
		add_child(_hold_end_sprite)
		var hold_end_tex = _atlas.create_atlas_texture(hold_end_frame)
		_hold_end_sprite.texture = hold_end_tex
		_hold_end_sprite.centered = false
		_hold_end_sprite.position.y = 0
		_hold_end_sprite.position.x = 0
	
	modulate.a = 0.6
	scale = Vector2(0.7, 0.7)

func update_clipping(song_time: float, scroll_speed: float) -> void:
	if sustain_length <= 0.0:
		visible = false
		return
	
	var remaining: float = sustain_length
	
	if not hit_note:
		var elapsed: float = song_time - strum_time
		remaining = sustain_length - elapsed
	
	if remaining <= 0.0:
		visible = false
		return
	
	visible = true
	
	var pixels_per_ms: float = 0.45
	var full_height: float = full_sustain_length * pixels_per_ms * scroll_speed
	var clip_height: float = remaining * pixels_per_ms * scroll_speed
	
	_current_clip_height = clip_height
	
	var end_height: float = 0.0
	if _hold_end_sprite and _hold_end_sprite.texture:
		end_height = _hold_end_sprite.texture.get_height() * scale.y
	
	if _hold_piece_sprite and _hold_piece_sprite.texture:
		var piece_height: float = _hold_piece_sprite.texture.get_height() * scale.y
		var piece_scale_y: float = 1.0
		
		if clip_height > end_height:
			var piece_clip_height: float = clip_height - end_height
			piece_scale_y = piece_clip_height / piece_height
			_hold_piece_sprite.visible = true
			_hold_piece_sprite.scale.y = piece_scale_y
			_hold_piece_sprite.position.y = 0
			var piece_width: float = _hold_piece_sprite.texture.get_width() * scale.x
			_hold_piece_sprite.position.x = -piece_width / 2
		else:
			_hold_piece_sprite.visible = false
		
		if _hold_end_sprite:
			if clip_height > end_height:
				_hold_end_sprite.position.y = clip_height - end_height
			else:
				_hold_end_sprite.position.y = 0
			var end_width: float = _hold_end_sprite.texture.get_width() * scale.x
			_hold_end_sprite.position.x = -end_width / 2
			_hold_end_sprite.visible = true

func get_clip_height() -> float:
	return _current_clip_height

func get_color() -> String:
	return DIRECTION_COLORS[note_data]
