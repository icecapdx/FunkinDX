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
const StageClass = preload("res://source/funkin/play/stage/Stage.gd")
const CharacterClass = preload("res://source/funkin/play/character/Character.gd")

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
@export var stage_id: String = ""

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
var _stage: StageClass = null

var cam_game: Camera2D
var cam_hud: CanvasLayer
var _hud_container: Node2D

var _camera_follow_point: Vector2 = Vector2(640, 360)
var _camera_follow_tween: Tween
var _camera_zoom_tween: Tween

var current_camera_zoom: float = 1.05
var default_camera_zoom: float = 1.05
var default_hud_zoom: float = 1.0
var camera_bop_multiplier: float = 1.0
var camera_bop_intensity: float = 1.015
var hud_camera_zoom_intensity: float = 0.03
var camera_zoom_rate: int = 4
var camera_zoom_rate_offset: int = 0
var zoom_camera_enabled: bool = true
var _hud_bop_zoom: float = 0.0

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

	if not Engine.is_editor_hint():
		_setup_cameras()

	_setup_strumlines()

	if Engine.is_editor_hint():
		_setup_editor_preview()
	else:
		_setup_gameplay()

func _setup_cameras() -> void:
	cam_game = Camera2D.new()
	cam_game.name = "CamGame"
	cam_game.zoom = Vector2(current_camera_zoom, current_camera_zoom)
	cam_game.position_smoothing_enabled = false
	cam_game.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	add_child(cam_game)

	cam_hud = CanvasLayer.new()
	cam_hud.name = "CamHUD"
	cam_hud.layer = 1
	cam_hud.follow_viewport_enabled = false
	add_child(cam_hud)

	_hud_container = Node2D.new()
	_hud_container.name = "HUDContainer"
	cam_hud.add_child(_hud_container)

	_sync_hud_offset()

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
		if load_song(song_id, difficulty, variation):
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

	player_strumline = StrumlineClass.create(_atlas, _strum_atlas, 1)
	player_strumline.position = player_position

	if _hud_container:
		_hud_container.add_child(opponent_strumline)
		_hud_container.add_child(player_strumline)
	else:
		add_child(opponent_strumline)
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
	if scroll_speed == 1.0:
		scroll_speed = _current_song.get_scroll_speed(difficulty)

	_setup_conductor_from_song()
	_load_notes_from_song()
	_load_events_from_song()
	_load_audio_from_song()
	_load_stage_from_song()

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

func _load_stage_from_song() -> void:
	if not _current_song:
		return

	var target_stage_id := stage_id
	if target_stage_id.is_empty():
		var play_data = _current_song.get_metadata(variation).play_data if _current_song.get_metadata(variation) else null
		if play_data:
			target_stage_id = play_data.stage

	if target_stage_id.is_empty():
		target_stage_id = "mainStage"

	if _stage:
		_stage.cleanup()
		_stage.queue_free()
		_stage = null

	_stage = StageClass.load_stage(target_stage_id)
	if _stage == null:
		push_warning("[Stage] Could not load stage: " + target_stage_id)
		return

	add_child(_stage)
	move_child(_stage, 0)
	_stage.build()

	var chars: SongDataClass.SongCharacterData = _current_song.get_characters(variation)
	var bf_id: String = chars.player if chars else "bf"
	var dad_id: String = chars.opponent if chars else "dad"
	var gf_id: String = chars.girlfriend if chars else "gf"
	_stage.add_characters(bf_id, dad_id, gf_id)

	default_camera_zoom = _stage.camera_zoom
	current_camera_zoom = default_camera_zoom
	if cam_game:
		cam_game.zoom = Vector2(current_camera_zoom, current_camera_zoom)

	if _stage.dad:
		_camera_follow_point = _stage.dad.camera_focus_point
	elif _stage.bf:
		_camera_follow_point = _stage.bf.camera_focus_point
	if cam_game:
		cam_game.position = _camera_follow_point

	if _conductor:
		if not _conductor.beat_hit.is_connected(_on_beat_hit_stage):
			_conductor.beat_hit.connect(_on_beat_hit_stage)
		if not _conductor.step_hit.is_connected(_on_step_hit_stage):
			_conductor.step_hit.connect(_on_step_hit_stage)

	print("[Stage] Loaded stage: %s (%s) - zoom: %.2f, characters: %s/%s/%s" % [
		_stage.get_stage_name(), target_stage_id, _stage.camera_zoom,
		bf_id, dad_id, gf_id
	])

func _on_beat_hit_stage(beat: int) -> void:
	if _stage:
		_stage.on_beat_hit(beat)

	if zoom_camera_enabled and cam_game and cam_game.zoom.x < 1.35 and camera_zoom_rate > 0:
		if (beat + camera_zoom_rate_offset) % camera_zoom_rate == 0:
			camera_bop_multiplier = camera_bop_intensity
			_hud_bop_zoom += hud_camera_zoom_intensity * default_hud_zoom

func _on_step_hit_stage(step: int) -> void:
	if _stage:
		_stage.on_step_hit(step)

func get_stage() -> StageClass:
	return _stage

func load_song_from_json(json_string: String, p_difficulty: String = "normal") -> bool:
	_current_song = ChartParserClass.load_from_json(json_string)

	if _current_song == null:
		push_error("Failed to parse song JSON")
		return false

	difficulty = p_difficulty
	bpm = _current_song.get_bpm()
	if scroll_speed == 1.0:
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
		if _song_audio and _song_audio.is_playing():
			var song_pos: float = _song_audio.get_song_position()
			if _conductor:
				_conductor.update(song_pos, true)
			_check_resync()
		elif _conductor:
			_conductor.update(_conductor.song_position + delta * 1000.0, false)
	elif _conductor:
		_conductor.update(_conductor.song_position + delta * 1000.0, false)

	_update_cameras(delta)
	_process_events()
	_spawn_upcoming_notes()
	_update_notes()
	_handle_strum_visuals()

func _sync_hud_offset() -> void:
	if cam_hud and not Engine.is_editor_hint():
		var gp := global_position
		cam_hud.offset = Vector2(gp.x, gp.y)

func _update_cameras(delta: float) -> void:
	if not cam_game:
		return

	var decay_rate: float = 0.95
	var dt: float = delta * 60.0

	if camera_zoom_rate > 0.0:
		camera_bop_multiplier = lerpf(1.0, camera_bop_multiplier, pow(decay_rate, dt))
		var zoom_plus_bop: float = current_camera_zoom * camera_bop_multiplier
		cam_game.zoom = Vector2(zoom_plus_bop, zoom_plus_bop)

		_hud_bop_zoom = lerpf(0.0, _hud_bop_zoom, pow(decay_rate, dt))
		var hud_zoom: float = default_hud_zoom + _hud_bop_zoom
		if _hud_container:
			var viewport_size := get_viewport_rect().size
			var center := viewport_size / 2.0
			_hud_container.scale = Vector2(hud_zoom, hud_zoom)
			_hud_container.position = center * (1.0 - hud_zoom)

	if _camera_follow_tween != null and _camera_follow_tween.is_running():
		cam_game.position = _camera_follow_point
	else:
		cam_game.position = cam_game.position.lerp(_camera_follow_point, 1.0 - pow(0.05, delta))

func move_camera_to_character(char_type: int, offset: Vector2 = Vector2.ZERO) -> void:
	if _stage == null:
		return

	var target: Vector2
	match char_type:
		0:
			if _stage.bf:
				target = _stage.bf.camera_focus_point
			else:
				target = _stage.get_bf_position()
		1:
			if _stage.dad:
				target = _stage.dad.camera_focus_point
			else:
				target = _stage.get_dad_position()
		2:
			if _stage.gf:
				target = _stage.gf.camera_focus_point
			else:
				target = _stage.get_gf_position()
		_:
			return

	_camera_follow_point = target + offset

func tween_camera_to_position(target_x: float, target_y: float, duration: float = 0.0, ease_type: Tween.EaseType = Tween.EASE_OUT, trans_type: Tween.TransitionType = Tween.TRANS_SINE) -> void:
	cancel_camera_follow_tween()

	if duration <= 0:
		_camera_follow_point = Vector2(target_x, target_y)
		if cam_game:
			cam_game.position = _camera_follow_point
		return

	_camera_follow_tween = create_tween()
	_camera_follow_tween.tween_property(self, "_camera_follow_point", Vector2(target_x, target_y), duration).set_ease(ease_type).set_trans(trans_type)

func tween_camera_zoom(target_zoom: float, duration: float = 0.0, ease_type: Tween.EaseType = Tween.EASE_OUT, trans_type: Tween.TransitionType = Tween.TRANS_SINE) -> void:
	if _camera_zoom_tween and _camera_zoom_tween.is_running():
		_camera_zoom_tween.kill()

	if duration <= 0:
		current_camera_zoom = target_zoom
		return

	_camera_zoom_tween = create_tween()
	_camera_zoom_tween.tween_property(self, "current_camera_zoom", target_zoom, duration).set_ease(ease_type).set_trans(trans_type)

func cancel_camera_follow_tween() -> void:
	if _camera_follow_tween and _camera_follow_tween.is_running():
		_camera_follow_tween.kill()

func reset_camera() -> void:
	cancel_camera_follow_tween()
	current_camera_zoom = default_camera_zoom
	camera_bop_multiplier = 1.0
	if cam_game:
		cam_game.zoom = Vector2(current_camera_zoom, current_camera_zoom)

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
			_handle_focus_camera(value)
		"PlayAnimation":
			pass
		"SetCameraBop":
			_handle_set_camera_bop(value)
		_:
			pass

func _handle_focus_camera(value) -> void:
	if value == null or _stage == null:
		return

	var char_id: int = 0
	var offset_x: float = 0.0
	var offset_y: float = 0.0
	var duration: float = 4.0
	var ease_str: String = "CLASSIC"

	if value is Dictionary:
		char_id = value.get("char", 0)
		offset_x = value.get("x", 0.0)
		offset_y = value.get("y", 0.0)
		duration = value.get("duration", 4.0)
		ease_str = value.get("ease", "CLASSIC")
	elif value is int or value is float:
		char_id = int(value)

	var target_x: float = offset_x
	var target_y: float = offset_y

	match char_id:
		-1:
			pass
		0:
			if _stage.bf:
				target_x += _stage.bf.camera_focus_point.x
				target_y += _stage.bf.camera_focus_point.y
			else:
				var bf_pos := _stage.get_bf_position()
				var bf_cam := _stage.get_bf_camera_offsets()
				target_x += bf_pos.x + bf_cam.x
				target_y += bf_pos.y + bf_cam.y
		1:
			if _stage.dad:
				target_x += _stage.dad.camera_focus_point.x
				target_y += _stage.dad.camera_focus_point.y
			else:
				var dad_pos := _stage.get_dad_position()
				var dad_cam := _stage.get_dad_camera_offsets()
				target_x += dad_pos.x + dad_cam.x
				target_y += dad_pos.y + dad_cam.y
		2:
			if _stage.gf:
				target_x += _stage.gf.camera_focus_point.x
				target_y += _stage.gf.camera_focus_point.y
			else:
				var gf_pos := _stage.get_gf_position()
				var gf_cam := _stage.get_gf_camera_offsets()
				target_x += gf_pos.x + gf_cam.x
				target_y += gf_pos.y + gf_cam.y

	match ease_str:
		"CLASSIC":
			cancel_camera_follow_tween()
			_camera_follow_point = Vector2(target_x, target_y)
		"INSTANT":
			tween_camera_to_position(target_x, target_y, 0)
		_:
			var step_length_ms: float = 60000.0 / bpm / 4.0
			var dur_seconds: float = step_length_ms * duration / 1000.0
			tween_camera_to_position(target_x, target_y, dur_seconds)

func _handle_set_camera_bop(value) -> void:
	if value is Dictionary:
		var rate = value.get("rate", null)
		if rate == null:
			rate = 4
		var offset = value.get("offset", null)
		if offset == null:
			offset = 0
		var intensity = value.get("intensity", null)
		if intensity == null:
			intensity = 1.0

		const DEFAULT_BOP_INTENSITY: float = 1.015
		camera_bop_intensity = (DEFAULT_BOP_INTENSITY - 1.0) * float(intensity) + 1.0
		hud_camera_zoom_intensity = (DEFAULT_BOP_INTENSITY - 1.0) * float(intensity) * 2.0
		camera_zoom_rate = int(rate)
		camera_zoom_rate_offset = int(offset)

func get_song_position() -> float:
	if _conductor:
		return _conductor.song_position
	if _song_started and _song_audio:
		return _song_audio.get_song_position()
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
		sustain_note.sustain_trail.position.y = 0

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
	if note.was_good_hit:
		return
	var diff: float = note.strum_time - pos

	if diff > -safe_zone_offset and diff < safe_zone_offset * 0.5:
		note.can_be_hit = true
	else:
		note.can_be_hit = false

	if diff < -safe_zone_offset:
		if not note.too_late:
			note.too_late = true
			if _stage and _stage.bf:
				_stage.bf.play_sing_animation(note.note_data, true)
		if note.modulate.a > 0.3:
			note.modulate.a = 0.3

func _update_opponent_note(note, pos: float) -> void:
	if note.strum_time <= pos and not note.was_good_hit:
		note.was_good_hit = true
		var direction: int = note.note_data

		opponent_strumline.confirm_strum(direction)

		if _stage and _stage.dad:
			_stage.dad.play_sing_animation(direction, false)

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

	if _stage and _stage.bf:
		_stage.bf.play_sing_animation(direction, false)

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
