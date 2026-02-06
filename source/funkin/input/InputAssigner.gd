extends Node

const SAVE_PATH := "user://keybinds.cfg"

const DEFAULT_NOTE_BINDINGS := {
	"NOTE_LEFT": [KEY_A, KEY_LEFT],
	"NOTE_DOWN": [KEY_S, KEY_DOWN],
	"NOTE_UP": [KEY_W, KEY_UP],
	"NOTE_RIGHT": [KEY_D, KEY_RIGHT],
}

const DEFAULT_UI_BINDINGS := {
	"UI_LEFT": [KEY_LEFT, KEY_A],
	"UI_DOWN": [KEY_DOWN, KEY_S],
	"UI_UP": [KEY_UP, KEY_W],
	"UI_RIGHT": [KEY_RIGHT, KEY_D],
	"ACCEPT": [KEY_ENTER, KEY_SPACE],
	"BACK": [KEY_ESCAPE, KEY_BACKSPACE],
	"CHEAT": [KEY_7],
}

var note_bindings: Dictionary = {}
var ui_bindings: Dictionary = {}

func _ready() -> void:
	_load_or_create_defaults()
	_apply_all_bindings()

func _load_or_create_defaults() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		_load_bindings()
	else:
		note_bindings = DEFAULT_NOTE_BINDINGS.duplicate(true)
		ui_bindings = DEFAULT_UI_BINDINGS.duplicate(true)
		save_bindings()

func _apply_all_bindings() -> void:
	for action in note_bindings:
		_apply_binding(action, note_bindings[action])
	for action in ui_bindings:
		_apply_binding(action, ui_bindings[action])

func _apply_binding(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	
	InputMap.action_erase_events(action)
	
	for key in keys:
		var event := InputEventKey.new()
		event.keycode = key
		InputMap.action_add_event(action, event)

func set_note_binding(action: String, keys: Array) -> void:
	if note_bindings.has(action):
		note_bindings[action] = keys
		_apply_binding(action, keys)

func set_ui_binding(action: String, keys: Array) -> void:
	if ui_bindings.has(action):
		ui_bindings[action] = keys
		_apply_binding(action, keys)

func get_note_binding(action: String) -> Array:
	return note_bindings.get(action, [])

func get_ui_binding(action: String) -> Array:
	return ui_bindings.get(action, [])

func get_key_name(keycode: int) -> String:
	return OS.get_keycode_string(keycode)

func reset_to_defaults() -> void:
	note_bindings = DEFAULT_NOTE_BINDINGS.duplicate(true)
	ui_bindings = DEFAULT_UI_BINDINGS.duplicate(true)
	_apply_all_bindings()
	save_bindings()

func save_bindings() -> void:
	var config := ConfigFile.new()
	
	for action in note_bindings:
		config.set_value("note", action, note_bindings[action])
	
	for action in ui_bindings:
		config.set_value("ui", action, ui_bindings[action])
	
	config.save(SAVE_PATH)

func _load_bindings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	
	if err != OK:
		note_bindings = DEFAULT_NOTE_BINDINGS.duplicate(true)
		ui_bindings = DEFAULT_UI_BINDINGS.duplicate(true)
		return
	
	note_bindings.clear()
	ui_bindings.clear()
	
	for action in DEFAULT_NOTE_BINDINGS:
		var keys = config.get_value("note", action, DEFAULT_NOTE_BINDINGS[action])
		note_bindings[action] = keys
	
	for action in DEFAULT_UI_BINDINGS:
		var keys = config.get_value("ui", action, DEFAULT_UI_BINDINGS[action])
		ui_bindings[action] = keys

func is_note_action_pressed(action: String) -> bool:
	return Input.is_action_pressed(action)

func is_note_action_just_pressed(action: String) -> bool:
	return Input.is_action_just_pressed(action)

func is_note_action_just_released(action: String) -> bool:
	return Input.is_action_just_released(action)

func get_pressed_note_directions() -> Array[int]:
	var pressed: Array[int] = []
	if Input.is_action_pressed("NOTE_LEFT"):
		pressed.append(0)
	if Input.is_action_pressed("NOTE_DOWN"):
		pressed.append(1)
	if Input.is_action_pressed("NOTE_UP"):
		pressed.append(2)
	if Input.is_action_pressed("NOTE_RIGHT"):
		pressed.append(3)
	return pressed

func get_just_pressed_note_directions() -> Array[int]:
	var pressed: Array[int] = []
	if Input.is_action_just_pressed("NOTE_LEFT"):
		pressed.append(0)
	if Input.is_action_just_pressed("NOTE_DOWN"):
		pressed.append(1)
	if Input.is_action_just_pressed("NOTE_UP"):
		pressed.append(2)
	if Input.is_action_just_pressed("NOTE_RIGHT"):
		pressed.append(3)
	return pressed

func get_just_released_note_directions() -> Array[int]:
	var released: Array[int] = []
	if Input.is_action_just_released("NOTE_LEFT"):
		released.append(0)
	if Input.is_action_just_released("NOTE_DOWN"):
		released.append(1)
	if Input.is_action_just_released("NOTE_UP"):
		released.append(2)
	if Input.is_action_just_released("NOTE_RIGHT"):
		released.append(3)
	return released
