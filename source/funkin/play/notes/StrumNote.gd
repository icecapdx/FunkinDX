@tool
class_name StrumNote
extends Sprite2D

const SparrowAtlasClass = preload("res://source/libs/Sparrowdot/src/sparrow/SparrowAtlas.gd")

enum State { STATIC, PRESSED, CONFIRM }

const DIRECTION_ARROWS: Array[String] = ["arrowLEFT", "arrowDOWN", "arrowUP", "arrowRIGHT"]
const DIRECTION_NAMES: Array[String] = ["left", "down", "up", "right"]

var note_data: int = 0
var player: int = 0
var _state: int = State.STATIC

var _atlas = null
var _sprite_frames: SpriteFrames = null
var _animated_sprite: AnimatedSprite2D = null

var confirm_offset: Vector2 = Vector2(-13, -13)

static func create(atlas, p_note_data: int, p_player: int = 0):
	var script = load("res://source/funkin/play/notes/StrumNote.gd")
	var strum = script.new()
	strum._atlas = atlas
	strum.note_data = clampi(p_note_data, 0, 3)
	strum.player = p_player
	strum._setup_sprite()
	return strum

func _setup_sprite() -> void:
	_animated_sprite = AnimatedSprite2D.new()
	add_child(_animated_sprite)
	
	_sprite_frames = SpriteFrames.new()
	_sprite_frames.remove_animation("default")
	
	var arrow: String = DIRECTION_ARROWS[note_data]
	var dir: String = DIRECTION_NAMES[note_data]
	
	_atlas.add_animation_to_sprite_frames(_sprite_frames, "static", arrow, 24.0, false)
	_atlas.add_animation_to_sprite_frames(_sprite_frames, "pressed", dir + " press", 24.0, false)
	_atlas.add_animation_to_sprite_frames(_sprite_frames, "confirm", dir + " confirm", 24.0, false)
	
	_animated_sprite.sprite_frames = _sprite_frames
	_animated_sprite.centered = true
	
	scale = Vector2(0.7, 0.7)
	play_static()

func play_static() -> void:
	if _state == State.STATIC:
		return
	_state = State.STATIC
	_animated_sprite.play("static")
	_animated_sprite.offset = Vector2.ZERO

func play_pressed() -> void:
	if _state == State.PRESSED:
		return
	_state = State.PRESSED
	_animated_sprite.play("pressed")
	_animated_sprite.offset = Vector2.ZERO

func play_confirm() -> void:
	if _state == State.CONFIRM:
		return
	_state = State.CONFIRM
	_animated_sprite.play("confirm")
	_animated_sprite.offset = confirm_offset

func get_state() -> int:
	return _state
