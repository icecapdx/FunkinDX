class_name Bopper
extends StageProp

var dance_every: float = 0.0
var should_alternate: int = -1
var has_danced: bool = false
var idle_suffix: String = ""
var can_play_other_anims: bool = true
var should_bop: bool = true
var original_position: Vector2 = Vector2.ZERO
var animation_offsets: Dictionary = {}
var _anim_offsets: Vector2 = Vector2.ZERO

func _init(p_dance_every: float = 0.0):
	super()
	dance_every = p_dance_every

func on_step_hit(step: int) -> void:
	if dance_every > 0 and int(step) % int(dance_every * Conductor.STEPS_PER_BEAT) == 0:
		dance(should_bop)

func on_beat_hit(_beat: int) -> void:
	pass

func dance(force_restart: bool = false) -> void:
	if should_alternate == -1:
		should_alternate = 1 if has_animation("danceLeft") else 0

	if should_alternate == 1:
		if has_danced:
			_play_anim("danceRight" + idle_suffix, force_restart)
		else:
			_play_anim("danceLeft" + idle_suffix, force_restart)
		has_danced = !has_danced
	else:
		_play_anim("idle" + idle_suffix, force_restart)

func _play_anim(anim_name: String, force_restart: bool = false, ignore_other: bool = false) -> void:
	if not can_play_other_anims and not ignore_other:
		return

	var corrected := _correct_animation_name(anim_name)
	if corrected.is_empty():
		return

	play_animation(corrected, force_restart)
	_apply_animation_offsets(corrected)

	if ignore_other:
		can_play_other_anims = false

func _correct_animation_name(anim_name: String) -> String:
	if has_animation(anim_name):
		return anim_name

	var dash_pos := anim_name.rfind("-")
	if dash_pos != -1:
		var stripped := anim_name.substr(0, dash_pos)
		return _correct_animation_name(stripped)

	if has_animation("idle"):
		return "idle"

	return ""

func set_animation_offsets(anim_name: String, x_offset: float, y_offset: float) -> void:
	animation_offsets[anim_name] = Vector2(x_offset, y_offset)

func _apply_animation_offsets(anim_name: String) -> void:
	if animation_offsets.has(anim_name):
		_anim_offsets = animation_offsets[anim_name]
	else:
		_anim_offsets = Vector2.ZERO

func reset_position() -> void:
	position = original_position