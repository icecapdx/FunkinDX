extends Node

signal input_pressed(event: PreciseInputEvent)
signal input_released(event: PreciseInputEvent)

class PreciseInputEvent:
	var direction: int = -1
	var timestamp: int = 0
	var key_code: int = 0
	
	func _init(p_dir: int, p_timestamp: int, p_key: int):
		direction = p_dir
		timestamp = p_timestamp
		key_code = p_key

enum NoteDirection { LEFT = 0, DOWN = 1, UP = 2, RIGHT = 3 }

const DIRECTION_ACTIONS: Array[String] = ["NOTE_LEFT", "NOTE_DOWN", "NOTE_UP", "NOTE_RIGHT"]
const NS_PER_MS: int = 1000000
const US_PER_MS: int = 1000

var _key_to_direction: Dictionary = {}
var _dir_press_timestamps: Dictionary = {}
var _dir_release_timestamps: Dictionary = {}
var _dir_pressed: Dictionary = {}
var _dir_just_pressed: Dictionary = {}
var _dir_just_released: Dictionary = {}

var _pending_just_pressed: Array[int] = []
var _pending_just_released: Array[int] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initialize_timestamps()

func _initialize_timestamps() -> void:
	for i in range(4):
		_dir_press_timestamps[i] = 0
		_dir_release_timestamps[i] = 0
		_dir_pressed[i] = false
		_dir_just_pressed[i] = false
		_dir_just_released[i] = false

func initialize_keys() -> void:
	_key_to_direction.clear()
	
	for dir in range(4):
		var action: String = DIRECTION_ACTIONS[dir]
		if InputMap.has_action(action):
			var events := InputMap.action_get_events(action)
			for event in events:
				if event is InputEventKey:
					_key_to_direction[event.keycode] = dir

func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	
	var key_event := event as InputEventKey
	var key_code: int = key_event.keycode
	
	if not _key_to_direction.has(key_code):
		return
	
	var direction: int = _key_to_direction[key_code]
	var timestamp: int = get_current_timestamp()
	
	if key_event.pressed and not key_event.echo:
		_handle_key_down(direction, timestamp, key_code)
	elif not key_event.pressed:
		_handle_key_up(direction, timestamp, key_code)

func _handle_key_down(direction: int, timestamp: int, key_code: int) -> void:
	if _dir_pressed[direction]:
		return
	
	_dir_pressed[direction] = true
	_dir_just_pressed[direction] = true
	_dir_press_timestamps[direction] = timestamp
	_pending_just_pressed.append(direction)
	
	var ev := PreciseInputEvent.new(direction, timestamp, key_code)
	input_pressed.emit(ev)

func _handle_key_up(direction: int, timestamp: int, key_code: int) -> void:
	if not _dir_pressed[direction]:
		return
	
	_dir_pressed[direction] = false
	_dir_just_released[direction] = true
	_dir_release_timestamps[direction] = timestamp
	_pending_just_released.append(direction)
	
	var ev := PreciseInputEvent.new(direction, timestamp, key_code)
	input_released.emit(ev)

func _process(_delta: float) -> void:
	for dir in _pending_just_pressed:
		_dir_just_pressed[dir] = false
	_pending_just_pressed.clear()
	
	for dir in _pending_just_released:
		_dir_just_released[dir] = false
	_pending_just_released.clear()

func get_current_timestamp() -> int:
	return Time.get_ticks_usec()

func get_time_since_pressed(direction: int) -> int:
	return get_current_timestamp() - _dir_press_timestamps.get(direction, 0)

func get_time_since_released(direction: int) -> int:
	return get_current_timestamp() - _dir_release_timestamps.get(direction, 0)

func get_press_timestamp(direction: int) -> int:
	return _dir_press_timestamps.get(direction, 0)

func get_release_timestamp(direction: int) -> int:
	return _dir_release_timestamps.get(direction, 0)

func is_pressed(direction: int) -> bool:
	return _dir_pressed.get(direction, false)

func is_just_pressed(direction: int) -> bool:
	return _dir_just_pressed.get(direction, false)

func is_just_released(direction: int) -> bool:
	return _dir_just_released.get(direction, false)

func get_pressed_directions() -> Array[int]:
	var result: Array[int] = []
	for dir in range(4):
		if _dir_pressed[dir]:
			result.append(dir)
	return result

func get_just_pressed_directions() -> Array[int]:
	var result: Array[int] = []
	for dir in range(4):
		if _dir_just_pressed[dir]:
			result.append(dir)
	return result

func get_just_released_directions() -> Array[int]:
	var result: Array[int] = []
	for dir in range(4):
		if _dir_just_released[dir]:
			result.append(dir)
	return result

func timestamp_to_song_time(timestamp: int, current_timestamp: int, song_position: float) -> float:
	var delta_us: int = current_timestamp - timestamp
	var delta_ms: float = float(delta_us) / US_PER_MS
	return song_position - delta_ms
