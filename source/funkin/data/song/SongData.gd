extends RefCounted

class SongTimeChange:
	var time_stamp: float = 0.0
	var beat_time: float = 0.0
	var bpm: float = 100.0
	var time_sig_num: int = 4
	var time_sig_den: int = 4
	
	func _init(p_time: float = 0.0, p_bpm: float = 100.0, p_num: int = 4, p_den: int = 4):
		time_stamp = p_time
		bpm = p_bpm
		time_sig_num = p_num
		time_sig_den = p_den

class SongNoteData:
	var time: float = 0.0
	var data: int = 0
	var length: float = 0.0
	var kind: String = ""
	
	func _init(p_time: float = 0.0, p_data: int = 0, p_length: float = 0.0, p_kind: String = ""):
		time = p_time
		data = p_data
		length = p_length
		kind = p_kind
	
	func get_direction(strumline_size: int = 4) -> int:
		return data % strumline_size
	
	func get_strumline_index(strumline_size: int = 4) -> int:
		return int(floor(float(data) / strumline_size))
	
	func is_player_note(strumline_size: int = 4) -> bool:
		return get_strumline_index(strumline_size) == 0
	
	func is_hold_note() -> bool:
		return length > 0

class SongEventData:
	var time: float = 0.0
	var event_kind: String = ""
	var value: Variant = null
	var activated: bool = false
	
	func _init(p_time: float = 0.0, p_kind: String = "", p_value: Variant = null):
		time = p_time
		event_kind = p_kind
		value = p_value
	
	func get_string(key: String, default_value: String = "") -> String:
		if value == null:
			return default_value
		if value is Dictionary:
			return value.get(key, default_value)
		return default_value
	
	func get_int(key: String, default_value: int = 0) -> int:
		if value == null:
			return default_value
		if value is Dictionary:
			return int(value.get(key, default_value))
		return default_value
	
	func get_float(key: String, default_value: float = 0.0) -> float:
		if value == null:
			return default_value
		if value is Dictionary:
			return float(value.get(key, default_value))
		return default_value
	
	func get_bool(key: String, default_value: bool = false) -> bool:
		if value == null:
			return default_value
		if value is Dictionary:
			return bool(value.get(key, default_value))
		return default_value

class SongCharacterData:
	var player: String = "bf"
	var girlfriend: String = "gf"
	var opponent: String = "dad"
	var instrumental: String = ""
	var alt_instrumentals: Array[String] = []
	var player_vocals: Array[String] = []
	var opponent_vocals: Array[String] = []
	
	func _init(p_player: String = "bf", p_gf: String = "gf", p_opponent: String = "dad"):
		player = p_player
		girlfriend = p_gf
		opponent = p_opponent
		player_vocals = [p_player]
		opponent_vocals = [p_opponent]

class SongOffsets:
	var instrumental: float = 0.0
	var vocals: Dictionary = {}
	
	func get_vocal_offset(char_id: String) -> float:
		return vocals.get(char_id, 0.0)

class SongPlayData:
	var song_variations: Array[String] = []
	var difficulties: Array[String] = []
	var characters: SongCharacterData = null
	var stage: String = "mainStage"
	var note_style: String = "funkin"
	var ratings: Dictionary = {}
	
	func _init():
		characters = SongCharacterData.new()

class SongMetadata:
	var version: String = "2.0.0"
	var song_name: String = "Unknown"
	var artist: String = "Unknown"
	var charter: String = ""
	var divisions: int = 96
	var looped: bool = false
	var offsets: SongOffsets = null
	var play_data: SongPlayData = null
	var time_format: String = "ms"
	var time_changes: Array = []
	var variation: String = "default"
	
	func _init(p_name: String = "Unknown", p_artist: String = "Unknown"):
		song_name = p_name
		artist = p_artist
		offsets = SongOffsets.new()
		play_data = SongPlayData.new()
		time_changes = [SongTimeChange.new(0.0, 100.0)]

class SongChartData:
	var version: String = "2.0.0"
	var scroll_speed: Dictionary = {}
	var events: Array = []
	var notes: Dictionary = {}
	var variation: String = "default"
	
	func get_scroll_speed(difficulty: String = "normal") -> float:
		var speed: float = scroll_speed.get(difficulty, 0.0)
		if speed == 0.0 and difficulty != "normal":
			speed = scroll_speed.get("normal", 1.0)
		return speed if speed > 0.0 else 1.0
	
	func get_notes(difficulty: String = "normal") -> Array:
		var note_data: Array = notes.get(difficulty, [])
		if note_data.size() == 0 and difficulty != "normal":
			note_data = notes.get("normal", [])
		return note_data

class Song:
	var id: String = ""
	var metadata: SongMetadata = null
	var chart_data: SongChartData = null
	var variations: Dictionary = {}
	var current_variation: String = "default"
	
	func _init(p_id: String = ""):
		id = p_id
		metadata = SongMetadata.new()
		chart_data = SongChartData.new()
	
	func get_bpm(variation: String = "") -> float:
		var meta := get_metadata(variation)
		if meta and meta.time_changes.size() > 0:
			return meta.time_changes[0].bpm
		return 100.0
	
	func get_scroll_speed(difficulty: String = "normal") -> float:
		return chart_data.get_scroll_speed(difficulty)
	
	func get_notes(difficulty: String = "normal") -> Array:
		return chart_data.get_notes(difficulty)
	
	func get_events() -> Array:
		return chart_data.events
	
	func get_time_changes(variation: String = "") -> Array:
		var meta := get_metadata(variation)
		return meta.time_changes if meta else []
	
	func get_metadata(variation: String = "") -> SongMetadata:
		var var_key := variation if not variation.is_empty() else current_variation
		if variations.has(var_key):
			return variations[var_key]
		return metadata
	
	func get_characters(variation: String = "") -> SongCharacterData:
		var meta := get_metadata(variation)
		return meta.play_data.characters if meta and meta.play_data else null
	
	func get_offsets(variation: String = "") -> SongOffsets:
		var meta := get_metadata(variation)
		return meta.offsets if meta else null
	
	func list_variations() -> Array[String]:
		var result: Array[String] = []
		for key in variations.keys():
			result.append(key)
		return result
	
	func list_difficulties(variation: String = "") -> Array[String]:
		var meta := get_metadata(variation)
		if meta and meta.play_data:
			return meta.play_data.difficulties
		return ["normal"]
	
	func has_variation(variation: String) -> bool:
		return variations.has(variation)
	
	func has_difficulty(difficulty: String, variation: String = "") -> bool:
		return difficulty in list_difficulties(variation)
	
	func get_variation_for_difficulty(difficulty: String) -> String:
		if difficulty in ["erect", "nightmare"]:
			if has_variation("erect"):
				return "erect"
		return "default"
