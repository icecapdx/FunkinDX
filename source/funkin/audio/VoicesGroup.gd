class_name VoicesGroup
extends Node

var player_voices: Array[AudioStreamPlayer] = []
var opponent_voices: Array[AudioStreamPlayer] = []

var player_volume: float = 1.0:
	set(value):
		player_volume = clampf(value, 0.0, 1.0)
		for voice in player_voices:
			voice.volume_db = linear_to_db(player_volume * _master_volume)

var opponent_volume: float = 1.0:
	set(value):
		opponent_volume = clampf(value, 0.0, 1.0)
		for voice in opponent_voices:
			voice.volume_db = linear_to_db(opponent_volume * _master_volume)

var player_voices_offset: float = 0.0
var opponent_voices_offset: float = 0.0

var _master_volume: float = 1.0
var _playing: bool = false
var _time: float = 0.0

signal playback_finished

func _init() -> void:
	pass

func add_player_voice(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(player_volume * _master_volume)
	add_child(player)
	player_voices.append(player)
	player.finished.connect(_on_voice_finished)
	return player

func add_opponent_voice(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(opponent_volume * _master_volume)
	add_child(player)
	opponent_voices.append(player)
	player.finished.connect(_on_voice_finished)
	return player

func play(from_position: float = 0.0) -> void:
	_playing = true
	_time = from_position
	
	for voice in player_voices:
		var pos: float = maxf(0.0, from_position - player_voices_offset)
		voice.play(pos / 1000.0)
	
	for voice in opponent_voices:
		var pos: float = maxf(0.0, from_position - opponent_voices_offset)
		voice.play(pos / 1000.0)

func pause() -> void:
	_playing = false
	for voice in player_voices:
		voice.stream_paused = true
	for voice in opponent_voices:
		voice.stream_paused = true

func resume() -> void:
	_playing = true
	for voice in player_voices:
		voice.stream_paused = false
	for voice in opponent_voices:
		voice.stream_paused = false

func stop() -> void:
	_playing = false
	for voice in player_voices:
		voice.stop()
	for voice in opponent_voices:
		voice.stop()

func set_time(time_ms: float) -> void:
	_time = time_ms
	for voice in player_voices:
		var pos: float = maxf(0.0, time_ms - player_voices_offset)
		voice.seek(pos / 1000.0)
	for voice in opponent_voices:
		var pos: float = maxf(0.0, time_ms - opponent_voices_offset)
		voice.seek(pos / 1000.0)

func get_time() -> float:
	if player_voices.size() > 0 and player_voices[0].playing:
		return (player_voices[0].get_playback_position() * 1000.0) + player_voices_offset
	elif opponent_voices.size() > 0 and opponent_voices[0].playing:
		return (opponent_voices[0].get_playback_position() * 1000.0) + opponent_voices_offset
	return _time

func set_volume(volume: float) -> void:
	_master_volume = clampf(volume, 0.0, 1.0)
	player_volume = player_volume
	opponent_volume = opponent_volume

func get_player_voice(index: int = 0) -> AudioStreamPlayer:
	if index >= 0 and index < player_voices.size():
		return player_voices[index]
	return null

func get_opponent_voice(index: int = 0) -> AudioStreamPlayer:
	if index >= 0 and index < opponent_voices.size():
		return opponent_voices[index]
	return null

func get_player_voice_length() -> float:
	if player_voices.size() > 0 and player_voices[0].stream:
		return player_voices[0].stream.get_length() * 1000.0
	return 0.0

func get_opponent_voice_length() -> float:
	if opponent_voices.size() > 0 and opponent_voices[0].stream:
		return opponent_voices[0].stream.get_length() * 1000.0
	return 0.0

func is_playing() -> bool:
	for voice in player_voices:
		if voice.playing:
			return true
	for voice in opponent_voices:
		if voice.playing:
			return true
	return false

func clear() -> void:
	for voice in player_voices:
		voice.stop()
		voice.queue_free()
	for voice in opponent_voices:
		voice.stop()
		voice.queue_free()
	player_voices.clear()
	opponent_voices.clear()

func _on_voice_finished() -> void:
	if not is_playing():
		_playing = false
		playback_finished.emit()
