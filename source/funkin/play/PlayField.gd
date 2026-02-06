@tool
class_name PlayField
extends Node2D

const SparrowAtlasClass = preload("res://source/libs/Sparrowdot/src/sparrow/SparrowAtlas.gd")
const StrumlineClass = preload("res://source/funkin/play/notes/Strumline.gd")
const NoteClass = preload("res://source/funkin/play/notes/Note.gd")

@export var note_atlas_xml: String = "res://assets/images/NOTE_assets.xml":
	set(value):
		note_atlas_xml = value
		if Engine.is_editor_hint():
			_refresh_editor_preview()

@export var scroll_speed: float = 1.0
@export var safe_zone_offset: float = 166.0

@export_group("Strumline Positions")
@export var opponent_position: Vector2 = Vector2(50, 50):
	set(value):
		opponent_position = value
		if opponent_strumline:
			opponent_strumline.position = value

@export var player_position: Vector2 = Vector2(690, 50):
	set(value):
		player_position = value
		if player_strumline:
			player_strumline.position = value

@export_group("Editor Preview")
@export var show_preview_notes: bool = true:
	set(value):
		show_preview_notes = value
		if Engine.is_editor_hint():
			_refresh_editor_preview()

var _atlas = null
var player_strumline = null
var opponent_strumline = null

var unspawned_notes: Array = []
var active_notes: Array = []

var song_position: float = 0.0

const NOTE_ACTIONS: Array[String] = ["NOTE_LEFT", "NOTE_DOWN", "NOTE_UP", "NOTE_RIGHT"]

var _editor_preview_notes: Array = []

func _ready() -> void:
	_atlas = SparrowAtlasClass.load_from_xml(note_atlas_xml)
	if _atlas == null:
		push_error("Failed to load note atlas")
		return
	
	_setup_strumlines()
	
	if Engine.is_editor_hint():
		_setup_editor_preview()
	else:
		_generate_test_notes()

func _refresh_editor_preview() -> void:
	_clear_children()
	_atlas = SparrowAtlasClass.load_from_xml(note_atlas_xml)
	if _atlas == null:
		return
	_setup_strumlines()
	_setup_editor_preview()

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()
	player_strumline = null
	opponent_strumline = null
	_editor_preview_notes.clear()

func _setup_strumlines() -> void:
	opponent_strumline = StrumlineClass.create(_atlas, 0)
	opponent_strumline.position = opponent_position
	add_child(opponent_strumline)
	
	player_strumline = StrumlineClass.create(_atlas, 1)
	player_strumline.position = player_position
	add_child(player_strumline)

func _setup_editor_preview() -> void:
	if not show_preview_notes:
		return
	
	var preview_data: Array = [
		{"y": 100, "data": 0, "player": true},
		{"y": 200, "data": 1, "player": true},
		{"y": 300, "data": 2, "player": true},
		{"y": 400, "data": 3, "player": true},
		{"y": 100, "data": 0, "player": false},
		{"y": 200, "data": 1, "player": false},
		{"y": 300, "data": 2, "player": false},
		{"y": 400, "data": 3, "player": false},
	]
	
	for info in preview_data:
		var note = NoteClass.create(_atlas, 0, info["data"], null, false)
		note.position.x = info["data"] * NoteClass.swag_width
		note.position.y = info["y"]
		
		var strumline = player_strumline if info["player"] else opponent_strumline
		strumline.add_child(note)
		_editor_preview_notes.append(note)

func _generate_test_notes() -> void:
	var test_pattern: Array = [
		{"time": 1000.0, "data": 0, "must_press": true},
		{"time": 1500.0, "data": 1, "must_press": true},
		{"time": 2000.0, "data": 2, "must_press": true},
		{"time": 2500.0, "data": 3, "must_press": true},
		{"time": 3000.0, "data": 0, "must_press": true},
		{"time": 3000.0, "data": 3, "must_press": true},
		{"time": 3500.0, "data": 1, "must_press": true},
		{"time": 3500.0, "data": 2, "must_press": true},
		{"time": 4000.0, "data": 0, "must_press": false},
		{"time": 4500.0, "data": 1, "must_press": false},
		{"time": 5000.0, "data": 2, "must_press": false},
		{"time": 5500.0, "data": 3, "must_press": false},
	]
	
	var prev_note = null
	for note_info in test_pattern:
		var note = NoteClass.create(
			_atlas,
			note_info["time"],
			note_info["data"],
			prev_note,
			false
		)
		note.must_press = note_info["must_press"]
		unspawned_notes.append(note)
		prev_note = note
	
	unspawned_notes.sort_custom(func(a, b): return a.strum_time < b.strum_time)

func spawn_note(p_strum_time: float, p_note_data: int, p_must_press: bool, p_sustain_length: float = 0.0) -> void:
	var prev_note = null
	if active_notes.size() > 0:
		prev_note = active_notes[-1]
	elif unspawned_notes.size() > 0:
		prev_note = unspawned_notes[-1]
	
	var note = NoteClass.create(_atlas, p_strum_time, p_note_data, prev_note, false)
	note.must_press = p_must_press
	note.sustain_length = p_sustain_length
	
	unspawned_notes.append(note)
	unspawned_notes.sort_custom(func(a, b): return a.strum_time < b.strum_time)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	song_position += delta * 1000.0
	
	_spawn_upcoming_notes()
	_update_notes()
	_handle_input()

func _spawn_upcoming_notes() -> void:
	while unspawned_notes.size() > 0:
		var note = unspawned_notes[0]
		if note.strum_time - song_position < 1500.0:
			unspawned_notes.remove_at(0)
			active_notes.append(note)
			
			var strumline = player_strumline if note.must_press else opponent_strumline
			strumline.add_note(note)
		else:
			break

func _update_notes() -> void:
	var notes_to_remove: Array = []
	
	for note in active_notes:
		var strumline = player_strumline if note.must_press else opponent_strumline
		var strum_y: float = strumline.position.y
		
		var y_offset: float = (song_position - note.strum_time) * (0.45 * scroll_speed)
		note.position.y = -y_offset
		
		if note.must_press:
			_update_player_note(note)
		else:
			_update_opponent_note(note)
		
		if note.position.y < -note.get_rect().size.y - 100:
			notes_to_remove.append(note)
	
	for note in notes_to_remove:
		_remove_note(note)

func _update_player_note(note) -> void:
	var diff: float = note.strum_time - song_position
	
	if diff > -safe_zone_offset and diff < safe_zone_offset * 0.5:
		note.can_be_hit = true
	else:
		note.can_be_hit = false
	
	if diff < -safe_zone_offset:
		note.too_late = true
		if note.modulate.a > 0.3:
			note.modulate.a = 0.3

func _update_opponent_note(note) -> void:
	if note.strum_time <= song_position and not note.was_good_hit:
		note.was_good_hit = true
		var direction: int = note.note_data
		
		opponent_strumline.confirm_strum(direction)
		
		get_tree().create_timer(0.15).timeout.connect(func():
			opponent_strumline.release_strum(direction)
		)
		
		_remove_note(note)

func _remove_note(note) -> void:
	active_notes.erase(note)
	note.queue_free()

func _handle_input() -> void:
	for i in range(4):
		var action: String = NOTE_ACTIONS[i]
		
		if Input.is_action_pressed(action):
			if Input.is_action_just_pressed(action):
				_on_key_pressed(i)
			player_strumline.press_strum(i)
		else:
			player_strumline.release_strum(i)

func _on_key_pressed(direction: int) -> void:
	var hittable_notes: Array = []
	
	for note in active_notes:
		if note.can_be_hit and note.must_press and note.note_data == direction and not note.was_good_hit:
			hittable_notes.append(note)
	
	if hittable_notes.size() > 0:
		hittable_notes.sort_custom(func(a, b): return a.strum_time < b.strum_time)
		var note = hittable_notes[0]
		_good_note_hit(note)

func _good_note_hit(note) -> void:
	if note.was_good_hit:
		return
	
	note.was_good_hit = true
	var direction: int = note.note_data
	var dir_name: String = note.get_direction_name()
	
	player_strumline.confirm_strum(direction)
	
	get_tree().create_timer(0.15).timeout.connect(func():
		player_strumline.release_strum(direction)
	)
	
	_remove_note(note)
	print("Hit! Direction: ", dir_name)
