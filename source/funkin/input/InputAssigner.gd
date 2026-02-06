extends Node

signal bindings_changed

const SAVE_PATH := "assets/data/keybinds.cfg"

const DEFAULT_NOTE_BINDINGS := {
	"NOTE_LEFT": [KEY_Z, KEY_LEFT],
	"NOTE_DOWN": [KEY_X, KEY_DOWN],
	"NOTE_UP": [KEY_N, KEY_UP],
	"NOTE_RIGHT": [KEY_M, KEY_RIGHT],
}

const DEFAULT_UI_BINDINGS := {
	"UI_LEFT": [KEY_LEFT, KEY_A],
	"UI_DOWN": [KEY_DOWN, KEY_S],
	"UI_UP": [KEY_UP, KEY_W],
	"UI_RIGHT": [KEY_RIGHT, KEY_D],
	"ACCEPT": [KEY_ENTER, KEY_SPACE],
	"BACK": [KEY_ESCAPE, KEY_BACKSPACE],
	"PAUSE": [KEY_ESCAPE, KEY_ENTER],
	"RESET": [KEY_R],
}

var note_bindings: Dictionary = {}
var ui_bindings: Dictionary = {}

func _ready() -> void:
	_load_or_create_defaults()
	_apply_all_bindings()
	bindings_changed.emit()

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
		bindings_changed.emit()

func set_ui_binding(action: String, keys: Array) -> void:
	if ui_bindings.has(action):
		ui_bindings[action] = keys
		_apply_binding(action, keys)
		bindings_changed.emit()

func get_note_binding(action: String) -> Array:
	return note_bindings.get(action, [])

func get_ui_binding(action: String) -> Array:
	return ui_bindings.get(action, [])

func get_all_bindings() -> Dictionary:
	var result := {}
	result.merge(note_bindings)
	result.merge(ui_bindings)
	return result

func get_keys_for_direction(direction: int) -> Array:
	var actions: Array[String] = ["NOTE_LEFT", "NOTE_DOWN", "NOTE_UP", "NOTE_RIGHT"]
	if direction < 0 or direction > 3:
		return []
	return note_bindings.get(actions[direction], [])

func get_key_name(keycode: int) -> String:
	return OS.get_keycode_string(keycode)

func reset_to_defaults() -> void:
	note_bindings = DEFAULT_NOTE_BINDINGS.duplicate(true)
	ui_bindings = DEFAULT_UI_BINDINGS.duplicate(true)
	_apply_all_bindings()
	save_bindings()
	bindings_changed.emit()

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
