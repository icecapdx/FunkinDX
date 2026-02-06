class_name SongAudio
extends Node

const VoicesGroupClass = preload("res://source/funkin/audio/VoicesGroup.gd")

var instrumental: AudioStreamPlayer = null
var vocals: VoicesGroup = null

var instrumental_offset: float = 0.0
var _playing: bool = false
var _song_position: float = 0.0
var _start_time: float = 0.0

signal song_finished

func _init() -> void:
	vocals = VoicesGroupClass.new()

func _ready() -> void:
	add_child(vocals)

func load_instrumental(path: String) -> bool:
	if instrumental != null:
		instrumental.stop()
		instrumental.queue_free()
	
	var stream = load(path)
	if stream == null:
		push_error("Failed to load instrumental: " + path)
		return false
	
	instrumental = AudioStreamPlayer.new()
	instrumental.stream = stream
	instrumental.finished.connect(_on_instrumental_finished)
	add_child(instrumental)
	return true

func add_player_voice(path: String) -> bool:
	var stream = load(path)
	if stream == null:
		push_error("Failed to load player voice: " + path)
		return false
	vocals.add_player_voice(stream)
	return true

func add_opponent_voice(path: String) -> bool:
	var stream = load(path)
	if stream == null:
		push_error("Failed to load opponent voice: " + path)
		return false
	vocals.add_opponent_voice(stream)
	return true

func play(from_position_ms: float = 0.0) -> void:
	_playing = true
	_song_position = from_position_ms
	_start_time = Time.get_ticks_msec() - from_position_ms
	
	if instrumental:
		var inst_pos: float = maxf(0.0, from_position_ms - instrumental_offset)
		instrumental.play(inst_pos / 1000.0)
	
	vocals.play(from_position_ms)

func pause() -> void:
	_playing = false
	if instrumental:
		instrumental.stream_paused = true
	vocals.pause()

func resume() -> void:
	_playing = true
	_start_time = Time.get_ticks_msec() - _song_position
	if instrumental:
		instrumental.stream_paused = false
	vocals.resume()

func stop() -> void:
	_playing = false
	if instrumental:
		instrumental.stop()
	vocals.stop()

func seek(time_ms: float) -> void:
	_song_position = time_ms
	_start_time = Time.get_ticks_msec() - time_ms
	
	if instrumental:
		var inst_pos: float = maxf(0.0, time_ms - instrumental_offset)
		instrumental.seek(inst_pos / 1000.0)
	
	vocals.set_time(time_ms)

func get_song_position() -> float:
	if not _playing:
		return _song_position
	
	if instrumental and instrumental.playing:
		return (instrumental.get_playback_position() * 1000.0) + instrumental_offset
	
	return Time.get_ticks_msec() - _start_time

func set_instrumental_volume(volume: float) -> void:
	if instrumental:
		instrumental.volume_db = linear_to_db(clampf(volume, 0.0, 1.0))

func set_player_vocals_volume(volume: float) -> void:
	vocals.player_volume = volume

func set_opponent_vocals_volume(volume: float) -> void:
	vocals.opponent_volume = volume

func set_vocals_volume(volume: float) -> void:
	vocals.set_volume(volume)

func get_song_length() -> float:
	if instrumental and instrumental.stream:
		return instrumental.stream.get_length() * 1000.0
	return 0.0

func is_playing() -> bool:
	return _playing

func resync_vocals() -> void:
	if not instrumental or not instrumental.playing:
		return
	
	var inst_time: float = instrumental.get_playback_position() * 1000.0
	vocals.set_time(inst_time + instrumental_offset)

func _on_instrumental_finished() -> void:
	_playing = false
	song_finished.emit()

func clear() -> void:
	stop()
	if instrumental:
		instrumental.queue_free()
		instrumental = null
	vocals.clear()
