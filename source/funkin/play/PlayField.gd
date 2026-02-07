@tool
class_name PlayField
extends Node2D

const SparrowAtlasClass = preload("res://source/libs/Sparrowdot/src/sparrow/SparrowAtlas.gd")
const StrumlineClass = preload("res://source/funkin/play/notes/Strumline.gd")
const NoteClass = preload("res://source/funkin/play/notes/Note.gd")
const SustainTrailClass = preload("res://source/funkin/play/notes/SustainTrail.gd")
const ChartParserClass = preload("res://source/funkin/data/song/ChartParser.gd")
const SongDataClass = preload("res://source/funkin/data/song/SongData.gd")
const SongAudioClass = preload("res://source/funkin/audio/SongAudio.gd")
const PathsClass = preload("res://source/funkin/Paths.gd")

@export var note_atlas_xml: String = "res://assets/images/NOTE_assets.xml":
	set(value):
		note_atlas_xml = value
		if Engine.is_editor_hint():
			_refresh_editor_preview()

@export var strum_atlas_xml: String = "res://assets/images/noteStrumline.xml":
	set(value):
		strum_atlas_xml = value
		if Engine.is_editor_hint():
			_refresh_editor_preview()

@export var scroll_speed: float = 1.0
@export var safe_zone_offset: float = 166.0

@export_group("Song")
@export var song_id: String = "":
	set(value):
		song_id = value
@export var difficulty: String = "normal"
@export var variation: String = "default"
@export var songs_path: String = "res://assets/songs/"

@export_group("Audio")
@export var instrumental_volume: float = 1.0:
	set(value):
		instrumental_volume = value
		if _song_audio:
			_song_audio.set_instrumental_volume(value)

@export var player_vocals_volume: float = 1.0:
	set(value):
		player_vocals_volume = value
		if _song_audio:
			_song_audio.set_player_vocals_volume(value)

@export var opponent_vocals_volume: float = 1.0:
	set(value):
		opponent_vocals_volume = value
		if _song_audio:
			_song_audio.set_opponent_vocals_volume(value)

@export var auto_start: bool = true
@export var start_countdown: bool = true
@export var countdown_offset: float = -3000.0

@export_group("Timing")
@export var bpm: float = 100.0

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
var _strum_atlas = null
var player_strumline = null
var opponent_strumline = null

var unspawned_notes: Array = []
var active_notes: Array = []
var active_sustains: Array = []
var unspawned_events: Array = []

const NOTE_ACTIONS: Array[String] = ["NOTE_LEFT", "NOTE_DOWN", "NOTE_UP", "NOTE_RIGHT"]

var _editor_preview_notes: Array = []

var _precise_input = null
var _conductor = null
var _current_song = null
var _song_audio: SongAudioClass = null

var _song_started: bool = false
var _song_paused: bool = false

const RESYNC_THRESHOLD: float = 40.0

func _ready() -> void:
	_atlas = SparrowAtlasClass.load_from_xml(note_atlas_xml)
	if _atlas == null:
		push_error("Failed to load note atlas")
		return
	_strum_atlas = SparrowAtlasClass.load_from_xml(strum_atlas_xml)
	if _strum_atlas == null:
		push_error("Failed to load strum atlas")
		return
	
	_setup_strumlines()
	
	if Engine.is_editor_hint():
		_setup_editor_preview()
	else:
		_setup_gameplay()

func _setup_gameplay() -> void:
	_precise_input = get_node_or_null("/root/PreciseInput")
	_conductor = get_node_or_null("/root/Conductor")
	
	_song_audio = SongAudioClass.new()
	add_child(_song_audio)
	_song_audio.song_finished.connect(_on_song_finished)
	
	if _precise_input:
		_precise_input.initialize_keys()
		_precise_input.input_pressed.connect(_on_precise_input_pressed)
		_precise_input.input_released.connect(_on_precise_input_released)
	
	if has_node("/root/InputAssigner"):
		get_node("/root/InputAssigner").bindings_changed.connect(_on_bindings_changed)
	
	if song_id != "":
		if load_song(song_id, difficulty):
			if auto_start:
				start_song()
	else:
		_setup_conductor_default()
		_generate_test_notes()

func _setup_conductor_default() -> void:
	if _conductor:
		_conductor.reset()
		var tc = _conductor.TimeChange.new(0.0, bpm)
		_conductor.map_time_changes([tc])

func _on_bindings_changed() -> void:
	if _precise_input:
		_precise_input.initialize_keys()

func _on_precise_input_pressed(event) -> void:
	_on_key_pressed_precise(event.direction, event.timestamp)

func _on_precise_input_released(event) -> void:
	_on_key_released_precise(event.direction, event.timestamp)

func _refresh_editor_preview() -> void:
	_clear_children()
	_atlas = SparrowAtlasClass.load_from_xml(note_atlas_xml)
	if _atlas == null:
		return
	_strum_atlas = SparrowAtlasClass.load_from_xml(strum_atlas_xml)
	if _strum_atlas == null:
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
	opponent_strumline = StrumlineClass.create(_atlas, _strum_atlas, 0)
	opponent_strumline.position = opponent_position
	add_child(opponent_strumline)
	
	player_strumline = StrumlineClass.create(_atlas, _strum_atlas, 1)
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

func load_song(p_song_id: String, p_difficulty: String = "normal", p_variation: String = "") -> bool:
	var target_variation := p_variation
	if target_variation.is_empty():
		if p_difficulty in PathsClass.DEFAULT_DIFFICULTY_LIST_ERECT:
			target_variation = "erect"
		else:
			target_variation = "default"
	
	_current_song = ChartParserClass.load_song_with_variations(p_song_id, songs_path)
	
	if _current_song == null:
		_current_song = ChartParserClass.load_song(p_song_id, songs_path, target_variation)
	
	if _current_song == null:
		push_error("Failed to load song: " + p_song_id)
		return false
	
	song_id = p_song_id
	difficulty = p_difficulty
	variation = target_variation
	_current_song.current_variation = target_variation
	
	bpm = _current_song.get_bpm(variation)
	scroll_speed = _current_song.get_scroll_speed(difficulty)
	
	_setup_conductor_from_song()
	_load_notes_from_song()
	_load_events_from_song()
	_load_audio_from_song()
	
	print("Loaded song: %s (%s / %s) - BPM: %.1f, Speed: %.2f, Notes: %d" % [
		_current_song.metadata.song_name,
		difficulty,
		variation,
		bpm,
		scroll_speed,
		unspawned_notes.size()
	])
	
	return true

func _load_audio_from_song() -> void:
	if not _song_audio or not _current_song:
		return
	
	_song_audio.clear()
	
	var meta = _current_song.get_metadata(variation)
	var chars = _current_song.get_characters(variation)
	var offsets = _current_song.get_offsets(variation)
	
	var instrumental_id: String = chars.instrumental if chars else ""
	var inst_path := PathsClass.get_inst_path(song_id, instrumental_id, variation)
	print("[Audio] Trying instrumental: " + inst_path)
	if PathsClass.file_exists(inst_path):
		if _song_audio.load_instrumental(inst_path):
			print("[Audio] Loaded instrumental: " + inst_path)
		else:
			push_error("[Audio] Failed to load instrumental: " + inst_path)
	else:
		push_warning("[Audio] Instrumental not found: " + inst_path)
	
	var characters: Dictionary = {}
	if chars:
		characters = {
			"player": chars.player,
			"opponent": chars.opponent,
			"playerVocals": chars.player_vocals,
			"opponentVocals": chars.opponent_vocals
		}
	
	var voice_list := PathsClass.build_voice_list(song_id, characters, variation)
	print("[Audio] Voice list: player=%s, opponent=%s" % [voice_list["player"], voice_list["opponent"]])
	
	for player_voice_path in voice_list["player"]:
		if _song_audio.add_player_voice(player_voice_path):
			print("[Audio] Loaded player voice: " + player_voice_path)
	
	for opponent_voice_path in voice_list["opponent"]:
		if _song_audio.add_opponent_voice(opponent_voice_path):
			print("[Audio] Loaded opponent voice: " + opponent_voice_path)
	
	_song_audio.set_instrumental_volume(instrumental_volume)
	_song_audio.set_player_vocals_volume(player_vocals_volume)
	_song_audio.set_opponent_vocals_volume(opponent_vocals_volume)
	
	if offsets:
		_song_audio.instrumental_offset = offsets.instrumental

func load_song_from_json(json_string: String, p_difficulty: String = "normal") -> bool:
	_current_song = ChartParserClass.load_from_json(json_string)
	
	if _current_song == null:
		push_error("Failed to parse song JSON")
		return false
	
	difficulty = p_difficulty
	bpm = _current_song.get_bpm()
	scroll_speed = _current_song.get_scroll_speed(difficulty)
	
	_setup_conductor_from_song()
	_load_notes_from_song()
	_load_events_from_song()
	
	return true

func _setup_conductor_from_song() -> void:
	if not _conductor or not _current_song:
		return
	
	_conductor.reset()
	
	var time_changes: Array = []
	for tc in _current_song.get_time_changes(variation):
		var conductor_tc = _conductor.TimeChange.new(tc.time_stamp, tc.bpm, tc.time_sig_num, tc.time_sig_den)
		time_changes.append(conductor_tc)
	
	if time_changes.size() == 0:
		time_changes.append(_conductor.TimeChange.new(0.0, bpm))
	
	_conductor.map_time_changes(time_changes)

func _load_notes_from_song() -> void:
	if not _current_song:
		return
	
	unspawned_notes.clear()
	active_notes.clear()
	
	var chart_notes: Array = _current_song.get_notes(difficulty)
	var prev_note = null
	
	for note_data in chart_notes:
		var direction: int = note_data.get_direction()
		var is_player: bool = note_data.is_player_note()
		var length: float = note_data.length
		
		var note = NoteClass.create(
			_atlas,
			note_data.time,
			direction,
			prev_note,
			false
		)
		note.must_press = is_player
		note.sustain_length = length
		
		if length > 0:
			var sustain_trail = SustainTrailClass.create(
				_atlas,
				note_data.time,
				direction,
				length
			)
			sustain_trail.must_press = is_player
			note.sustain_trail = sustain_trail
		
		unspawned_notes.append(note)
		prev_note = note
	
	unspawned_notes.sort_custom(func(a, b): return a.strum_time < b.strum_time)

func _load_events_from_song() -> void:
	if not _current_song:
		return
	
	unspawned_events.clear()
	
	for event_data in _current_song.get_events():
		unspawned_events.append({
			"time": event_data.time,
			"kind": event_data.event_kind,
			"value": event_data.value,
			"activated": false
		})
	
	unspawned_events.sort_custom(func(a, b): return a["time"] < b["time"])

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
	
	if _song_started and not _song_paused:
		var song_pos: float = _song_audio.get_song_position() if _song_audio else 0.0
		
		if _conductor:
			_conductor.update(song_pos, true)
		
		_check_resync()
	elif _conductor:
		_conductor.update(_conductor.song_position + delta * 1000.0, false)
	
	_process_events()
	_spawn_upcoming_notes()
	_update_notes()
	_handle_strum_visuals()

func _process_events() -> void:
	var pos: float = get_song_position()
	
	for event in unspawned_events:
		if event["activated"]:
			continue
		
		if event["time"] <= pos:
			event["activated"] = true
			_on_event_triggered(event)

func _on_event_triggered(event: Dictionary) -> void:
	var kind: String = event["kind"]
	var value = event["value"]
	
	match kind:
		"FocusCamera":
			pass
		"PlayAnimation":
			pass
		"SetCameraBop":
			pass
		_:
			pass

func get_song_position() -> float:
	if _song_started and _song_audio:
		return _song_audio.get_song_position()
	if _conductor:
		return _conductor.song_position
	return 0.0

func start_song(from_position: float = 0.0) -> void:
	if not _song_audio:
		push_error("[Audio] Cannot start song - no audio manager")
		return
	
	var start_pos: float = from_position
	if start_countdown:
		start_pos = countdown_offset
	
	_song_started = true
	_song_paused = false
	
	print("[Audio] Starting song at position: %.2f ms (countdown: %s)" % [start_pos, start_countdown])
	
	if _conductor:
		_conductor.update(start_pos, false)
	
	if start_pos >= 0:
		_song_audio.play(start_pos)
	else:
		print("[Audio] Waiting %.2f seconds for countdown..." % (absf(start_pos) / 1000.0))
		get_tree().create_timer(absf(start_pos) / 1000.0).timeout.connect(func():
			if _song_started and not _song_paused:
				print("[Audio] Countdown finished, playing audio")
				_song_audio.play(0.0)
		)

func pause_song() -> void:
	if not _song_started:
		return
	
	_song_paused = true
	if _song_audio:
		_song_audio.pause()

func resume_song() -> void:
	if not _song_started:
		return
	
	_song_paused = false
	if _song_audio:
		_song_audio.resume()

func stop_song() -> void:
	_song_started = false
	_song_paused = false
	if _song_audio:
		_song_audio.stop()

func seek_song(time_ms: float) -> void:
	if _song_audio:
		_song_audio.seek(time_ms)
	if _conductor:
		_conductor.update(time_ms, false)

func _check_resync() -> void:
	if not _song_audio or not _song_audio.is_playing():
		return
	
	var inst_time: float = _song_audio.get_song_position()
	var vocal_time: float = inst_time
	if _song_audio.vocals:
		vocal_time = _song_audio.vocals.get_time()
	
	if absf(inst_time - vocal_time) > RESYNC_THRESHOLD:
		_song_audio.resync_vocals()
		print("Resyncing vocals (diff: %.2fms)" % absf(inst_time - vocal_time))

func _on_song_finished() -> void:
	_song_started = false
	print("Song finished!")

func _spawn_upcoming_notes() -> void:
	var pos: float = get_song_position()
	while unspawned_notes.size() > 0:
		var note = unspawned_notes[0]
		if note.strum_time - pos < 1500.0:
			unspawned_notes.remove_at(0)
			active_notes.append(note)
			
			var strumline = player_strumline if note.must_press else opponent_strumline
			strumline.add_note(note)
			
			if note.sustain_trail != null:
				strumline.add_child(note.sustain_trail)
				note.sustain_trail.position = note.position
		else:
			break

func _update_notes() -> void:
	var notes_to_remove: Array = []
	var pos: float = get_song_position()
	
	for note in active_notes:
		var y_offset: float = (pos - note.strum_time) * (0.45 * scroll_speed)
		note.position.y = -y_offset
		
		if note.sustain_trail != null:
			note.sustain_trail.position.x = note.position.x
			note.sustain_trail.position.y = note.position.y
			var note_height: float = 157.0 * note.scale.y
			note.sustain_trail.position.y += note_height / 2
			note.sustain_trail.update_clipping(pos, scroll_speed)
		
		if note.must_press:
			_update_player_note(note, pos)
		else:
			_update_opponent_note(note, pos)
		
		if note.position.y < -note.get_rect().size.y - 100:
			if note not in active_sustains:
				notes_to_remove.append(note)
	
	for sustain_note in active_sustains:
		if not is_instance_valid(sustain_note) or sustain_note.sustain_trail == null:
			continue
		
		var strumline = player_strumline if sustain_note.must_press else opponent_strumline		
		sustain_note.sustain_trail.position.x = sustain_note.note_data * NoteClass.swag_width
		sustain_note.sustain_trail.position.y = 0  # At the strumline
		
		var elapsed: float = pos - sustain_note.strum_time
		var remaining: float = sustain_note.sustain_length - elapsed
		if remaining > 0:
			sustain_note.sustain_trail.sustain_length = remaining
			sustain_note.sustain_trail.update_clipping(pos, scroll_speed)
			sustain_note.sustain_trail.visible = true
	
	for note in notes_to_remove:
		_remove_note(note)	
	_update_sustains(pos)

func _update_player_note(note, pos: float) -> void:
	var diff: float = note.strum_time - pos
	
	if diff > -safe_zone_offset and diff < safe_zone_offset * 0.5:
		note.can_be_hit = true
	else:
		note.can_be_hit = false
	
	if diff < -safe_zone_offset:
		note.too_late = true
		if note.modulate.a > 0.3:
			note.modulate.a = 0.3

func _update_opponent_note(note, pos: float) -> void:
	if note.strum_time <= pos and not note.was_good_hit:
		note.was_good_hit = true
		var direction: int = note.note_data
		
		opponent_strumline.confirm_strum(direction)
		
		if note.sustain_length > 0 and note.sustain_trail != null:
			note.sustain_trail.hit_note = true
			active_sustains.append(note)
			note.visible = false
			var sustain_end_time: float = note.strum_time + note.sustain_length
			var captured_direction: int = direction
			var captured_note = note
			get_tree().create_timer((sustain_end_time - pos) / 1000.0).timeout.connect(func():
				opponent_strumline.release_strum(captured_direction)
				if is_instance_valid(captured_note):
					_remove_note(captured_note)
			)
		else:
			get_tree().create_timer(0.15).timeout.connect(func():
				opponent_strumline.release_strum(direction)
			)
			_remove_note(note)

func _remove_note(note) -> void:
	if not is_instance_valid(note):
		return
	
	active_notes.erase(note)
	active_sustains.erase(note)
	if is_instance_valid(note) and note.sustain_trail != null:
		if is_instance_valid(note.sustain_trail):
			note.sustain_trail.queue_free()
	if is_instance_valid(note):
		note.queue_free()

func _handle_strum_visuals() -> void:
	if not _precise_input:
		return
	
	for i in range(4):
		if _precise_input.is_pressed(i):
			player_strumline.press_strum(i)
		else:
			player_strumline.release_strum(i)

func _on_key_pressed_precise(direction: int, timestamp: int) -> void:
	var input_time: float = _timestamp_to_song_time(timestamp)
	var hittable_notes: Array = []
	
	for note in active_notes:
		if not note.must_press or note.note_data != direction or note.was_good_hit:
			continue
		
		var diff: float = note.strum_time - input_time
		
		if diff > -safe_zone_offset and diff < safe_zone_offset * 0.5:
			hittable_notes.append({"note": note, "diff": absf(diff)})
	
	if hittable_notes.size() > 0:
		hittable_notes.sort_custom(func(a, b): return a["diff"] < b["diff"])
		var note = hittable_notes[0]["note"]
		var timing_diff: float = note.strum_time - input_time
		_good_note_hit(note, timing_diff)

func _timestamp_to_song_time(timestamp: int) -> float:
	if not _precise_input or not _conductor:
		return get_song_position()
	
	var current_timestamp: int = _precise_input.get_current_timestamp()
	var delta_us: int = current_timestamp - timestamp
	var delta_ms: float = float(delta_us) / 1000.0
	return _conductor.song_position - delta_ms

func _good_note_hit(note, timing_diff: float = 0.0) -> void:
	if note.was_good_hit:
		return
	
	note.was_good_hit = true
	var direction: int = note.note_data
	var dir_name: String = note.get_direction_name()
	
	player_strumline.confirm_strum(direction)
	
	if note.sustain_length > 0 and note.sustain_trail != null:
		note.sustain_trail.hit_note = true
		active_sustains.append(note)
		note.visible = false
		var pos: float = get_song_position()
		note.sustain_trail.position.x = note.note_data * NoteClass.swag_width
		note.sustain_trail.position.y = 0
		note.sustain_trail.visible = true
		var elapsed: float = pos - note.strum_time
		var remaining: float = note.sustain_length - elapsed
		if remaining > 0:
			note.sustain_trail.sustain_length = remaining
			note.sustain_trail.update_clipping(pos, scroll_speed)
	else:
		_remove_note(note)
	
	var rating: String = _get_timing_rating(timing_diff)
	print("Hit! Direction: %s, Timing: %.2fms (%s)" % [dir_name, timing_diff, rating])

func _get_timing_rating(diff: float) -> String:
	var abs_diff: float = absf(diff)
	if abs_diff <= 22.0:
		return "Sick"
	elif abs_diff <= 45.0:
		return "Good"
	elif abs_diff <= 90.0:
		return "Bad"
	else:
		return "Shit"

func _on_key_released_precise(direction: int, timestamp: int) -> void:
	var pos: float = get_song_position()
	for sustain_note in active_sustains:
		if not is_instance_valid(sustain_note) or sustain_note == null:
			continue
		if sustain_note.note_data == direction and sustain_note.sustain_trail != null:
			if sustain_note.sustain_trail.hit_note and not sustain_note.sustain_trail.missed_note:
				var elapsed: float = pos - sustain_note.strum_time
				if elapsed < sustain_note.sustain_length:
					sustain_note.sustain_trail.missed_note = true
					player_strumline.release_strum(direction)
					print("Sustain released early! Direction: %s" % NoteClass.DIRECTION_NAMES[direction])

func _update_sustains(pos: float) -> void:
	var sustains_to_remove: Array = []
	
	for sustain_note in active_sustains:
		if not is_instance_valid(sustain_note) or sustain_note == null:
			sustains_to_remove.append(sustain_note)
			continue
		
		if sustain_note.sustain_trail == null:
			sustains_to_remove.append(sustain_note)
			continue
		
		var elapsed: float = pos - sustain_note.strum_time
		
		if elapsed >= sustain_note.sustain_length:
			if sustain_note.sustain_trail.hit_note and not sustain_note.sustain_trail.missed_note:
				player_strumline.release_strum(sustain_note.note_data)
				print("Sustain completed! Direction: %s" % sustain_note.get_direction_name())
			sustains_to_remove.append(sustain_note)
			continue
		
		if sustain_note.must_press and _precise_input:
			var direction: int = sustain_note.note_data
			if _precise_input.is_pressed(direction):
				sustain_note.sustain_trail.hit_note = true
				sustain_note.sustain_trail.missed_note = false
			elif sustain_note.sustain_trail.hit_note and not sustain_note.sustain_trail.missed_note:
				sustain_note.sustain_trail.missed_note = true
				player_strumline.release_strum(direction)
				print("Sustain dropped! Direction: %s" % sustain_note.get_direction_name())
	
	for sustain_note in sustains_to_remove:
		if is_instance_valid(sustain_note):
			_remove_note(sustain_note)
		else:
			active_sustains.erase(sustain_note)