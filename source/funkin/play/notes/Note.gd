@tool
class_name Note
extends Sprite2D

const SparrowAtlasClass = preload("res://source/libs/Sparrowdot/src/sparrow/SparrowAtlas.gd")

enum NoteDirection { LEFT = 0, DOWN = 1, UP = 2, RIGHT = 3 }

const DIRECTION_COLORS: Array[String] = ["purple", "blue", "green", "red"]
const DIRECTION_NAMES: Array[String] = ["LEFT", "DOWN", "UP", "RIGHT"]

static var swag_width: float = 160 * 0.7

var strum_time: float = 0.0
var note_data: int = 0
var must_press: bool = false
var can_be_hit: bool = false
var too_late: bool = false
var was_good_hit: bool = false

var sustain_length: float = 0.0
var is_sustain_note: bool = false
var prev_note = null
var sustain_trail = null

var note_score: float = 1.0

var _atlas = null
var _sprite_frames: SpriteFrames = null
var _animated_sprite: AnimatedSprite2D = null
var _current_anim: String = ""

static func create(atlas, p_strum_time: float, p_note_data: int, p_prev_note = null, is_sustain: bool = false):
	var script = load("res://source/funkin/play/notes/Note.gd")
	var note = script.new()
	note._atlas = atlas
	note.strum_time = p_strum_time
	note.note_data = clampi(p_note_data, 0, 3)
	note.is_sustain_note = is_sustain
	note.prev_note = p_prev_note if p_prev_note != null else note
	note._setup_sprite()
	return note

func _setup_sprite() -> void:
	_animated_sprite = AnimatedSprite2D.new()
	add_child(_animated_sprite)
	
	_sprite_frames = SpriteFrames.new()
	if _sprite_frames.has_animation("default"):
		_sprite_frames.remove_animation("default")
	
	var color: String = DIRECTION_COLORS[note_data]
	
	var head_name: String = color + " instance 10000"
	var head_frame = _atlas.get_frame(head_name)
	if head_frame != null:
		var head_tex = _atlas.create_atlas_texture(head_frame)
		_sprite_frames.add_animation("scroll")
		_sprite_frames.set_animation_speed("scroll", 0.0)
		_sprite_frames.set_animation_loop("scroll", false)
		_sprite_frames.add_frame("scroll", head_tex)
	
	var hold_end_name: String
	if color == "purple":
		hold_end_name = "pruple end hold instance 10000"
	else:
		hold_end_name = color + " hold end instance 10000"
	var hold_end_frame = _atlas.get_frame(hold_end_name)
	if hold_end_frame != null:
		var hold_end_tex = _atlas.create_atlas_texture(hold_end_frame)
		_sprite_frames.add_animation("hold_end")
		_sprite_frames.set_animation_speed("hold_end", 0.0)
		_sprite_frames.set_animation_loop("hold_end", false)
		_sprite_frames.add_frame("hold_end", hold_end_tex)
	
	var hold_piece_name: String = color + " hold piece instance 10000"
	var hold_piece_frame = _atlas.get_frame(hold_piece_name)
	if hold_piece_frame != null:
		var hold_piece_tex = _atlas.create_atlas_texture(hold_piece_frame)
		_sprite_frames.add_animation("hold_piece")
		_sprite_frames.set_animation_speed("hold_piece", 0.0)
		_sprite_frames.set_animation_loop("hold_piece", true)
		_sprite_frames.add_frame("hold_piece", hold_piece_tex)
	
	_animated_sprite.sprite_frames = _sprite_frames
	_animated_sprite.centered = true
	
	if is_sustain_note:
		note_score *= 0.2
		modulate.a = 0.6
		play_anim("hold_end")
	else:
		play_anim("scroll")
	
	scale = Vector2(0.7, 0.7)

func play_anim(anim_name: String) -> void:
	if _animated_sprite == null:
		return
	if _sprite_frames.has_animation(anim_name):
		_current_anim = anim_name
		_animated_sprite.play(anim_name)

func get_direction_name() -> String:
	return DIRECTION_NAMES[note_data]

func get_color() -> String:
	return DIRECTION_COLORS[note_data]
