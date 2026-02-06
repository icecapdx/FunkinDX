class_name Paths
extends RefCounted

const SONGS_PATH := "res://assets/songs"
const SONGS_DATA_PATH := "res://assets/data/songs"
const MUSIC_PATH := "res://assets/music"
const SOUNDS_PATH := "res://assets/sounds"
const IMAGES_PATH := "res://assets/images"
const DATA_PATH := "res://assets/data"

const EXT_SOUND := "ogg"
const EXT_IMAGE := "png"

static func inst(song: String, suffix: String = "") -> String:
	return "%s/%s/Inst%s.%s" % [SONGS_PATH, song.to_lower(), suffix, EXT_SOUND]

static func voices(song: String, suffix: String = "") -> String:
	return "%s/%s/Voices%s.%s" % [SONGS_PATH, song.to_lower(), suffix, EXT_SOUND]

static func music(key: String) -> String:
	return "%s/%s.%s" % [MUSIC_PATH, key, EXT_SOUND]

static func sound(key: String) -> String:
	return "%s/%s.%s" % [SOUNDS_PATH, key, EXT_SOUND]

static func image(key: String) -> String:
	return "%s/%s.%s" % [IMAGES_PATH, key, EXT_IMAGE]

static func xml(key: String) -> String:
	return "%s/%s.xml" % [DATA_PATH, key]

static func json(key: String) -> String:
	return "%s/%s.json" % [DATA_PATH, key]

static func chart(song: String, difficulty: String = "") -> String:
	if difficulty.is_empty():
		return "%s/%s/%s.json" % [SONGS_PATH, song.to_lower(), song.to_lower()]
	return "%s/%s/%s-%s.json" % [SONGS_PATH, song.to_lower(), song.to_lower(), difficulty]

static func metadata(song: String, variation: String = "") -> String:
	var song_lower := song.to_lower()
	if variation.is_empty() or variation == "default":
		var data_format := "%s/%s/%s-metadata.json" % [SONGS_DATA_PATH, song_lower, song_lower]
		if file_exists(data_format):
			return data_format
		var new_format := "%s/%s/metadata.json" % [SONGS_PATH, song_lower]
		if file_exists(new_format):
			return new_format
		return "%s/%s/%s-metadata.json" % [SONGS_PATH, song_lower, song_lower]
	var data_format := "%s/%s/%s-metadata-%s.json" % [SONGS_DATA_PATH, song_lower, song_lower, variation]
	if file_exists(data_format):
		return data_format
	var new_format := "%s/%s/metadata-%s.json" % [SONGS_PATH, song_lower, variation]
	if file_exists(new_format):
		return new_format
	return "%s/%s/%s-metadata-%s.json" % [SONGS_PATH, song_lower, song_lower, variation]

static func chart_data(song: String, variation: String = "") -> String:
	var song_lower := song.to_lower()
	if variation.is_empty() or variation == "default":
		var data_format := "%s/%s/%s-chart.json" % [SONGS_DATA_PATH, song_lower, song_lower]
		if file_exists(data_format):
			return data_format
		var new_format := "%s/%s/chart.json" % [SONGS_PATH, song_lower]
		if file_exists(new_format):
			return new_format
		return "%s/%s/%s-chart.json" % [SONGS_PATH, song_lower, song_lower]
	var data_format := "%s/%s/%s-chart-%s.json" % [SONGS_DATA_PATH, song_lower, song_lower, variation]
	if file_exists(data_format):
		return data_format
	var new_format := "%s/%s/chart-%s.json" % [SONGS_PATH, song_lower, variation]
	if file_exists(new_format):
		return new_format
	return "%s/%s/%s-chart-%s.json" % [SONGS_PATH, song_lower, song_lower, variation]

const DEFAULT_VARIATION := "default"
const DEFAULT_VARIATION_LIST: Array[String] = ["default", "erect", "pico", "bf"]
const DEFAULT_DIFFICULTY_LIST: Array[String] = ["easy", "normal", "hard"]
const DEFAULT_DIFFICULTY_LIST_ERECT: Array[String] = ["erect", "nightmare"]
const DEFAULT_DIFFICULTY_LIST_FULL: Array[String] = ["easy", "normal", "hard", "erect", "nightmare"]

static func get_variation_suffix(variation: String) -> String:
	if variation.is_empty() or variation == "default":
		return ""
	return "-%s" % variation

static func is_erect_difficulty(difficulty: String) -> bool:
	return difficulty in DEFAULT_DIFFICULTY_LIST_ERECT

static func file_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or ResourceLoader.exists(path)

static func build_voice_list(song: String, characters: Dictionary, variation: String = "") -> Dictionary:
	var result := {"player": [], "opponent": []}
	var suffix := "" if (variation.is_empty() or variation == "default") else "-%s" % variation
	
	var player_vocals: Array = characters.get("playerVocals", [])
	if player_vocals.is_empty() and characters.has("player"):
		player_vocals = [characters["player"]]
	
	for player_id in player_vocals:
		var tried_paths: Array[String] = []
		var voice_path := voices(song, "-%s%s" % [player_id, suffix])
		tried_paths.append(voice_path)
		if file_exists(voice_path):
			result["player"].append(voice_path)
			continue		
		voice_path = voices(song, "-%s" % player_id)
		tried_paths.append(voice_path)
		if file_exists(voice_path):
			result["player"].append(voice_path)
			continue		
		if "-" in player_id:
			var base_id: String = player_id.split("-")[0]
			
			voice_path = voices(song, "-%s%s" % [base_id, suffix])
			tried_paths.append(voice_path)
			if file_exists(voice_path):
				result["player"].append(voice_path)
				continue
			
			voice_path = voices(song, "-%s" % base_id)
			tried_paths.append(voice_path)
			if file_exists(voice_path):
				result["player"].append(voice_path)
				continue
	
	var opponent_vocals: Array = characters.get("opponentVocals", [])
	if opponent_vocals.is_empty() and characters.has("opponent"):
		opponent_vocals = [characters["opponent"]]
	
	for opponent_id in opponent_vocals:
		var tried_paths: Array[String] = []
		var voice_path := voices(song, "-%s%s" % [opponent_id, suffix])
		tried_paths.append(voice_path)
		if file_exists(voice_path):
			result["opponent"].append(voice_path)
			continue		
		voice_path = voices(song, "-%s" % opponent_id)
		tried_paths.append(voice_path)
		if file_exists(voice_path):
			result["opponent"].append(voice_path)
			continue		
		if "-" in opponent_id:
			var base_id: String = opponent_id.split("-")[0]
			
			voice_path = voices(song, "-%s%s" % [base_id, suffix])
			tried_paths.append(voice_path)
			if file_exists(voice_path):
				result["opponent"].append(voice_path)
				continue
			
			voice_path = voices(song, "-%s" % base_id)
			tried_paths.append(voice_path)
			if file_exists(voice_path):
				result["opponent"].append(voice_path)
				continue
	
	if result["player"].is_empty() and result["opponent"].is_empty():
		var fallback_path := voices(song, suffix)
		if file_exists(fallback_path):
			result["player"].append(fallback_path)
		else:
			fallback_path = voices(song)
			if file_exists(fallback_path):
				result["player"].append(fallback_path)
	
	return result

static func get_inst_path(song: String, instrumental_id: String = "", variation: String = "") -> String:
	var suffix := ""
	if not instrumental_id.is_empty():
		suffix = "-%s" % instrumental_id
	elif not variation.is_empty() and variation != "default":
		suffix = "-%s" % variation
	
	var path := inst(song, suffix)
	if file_exists(path):
		return path
	
	return inst(song)
