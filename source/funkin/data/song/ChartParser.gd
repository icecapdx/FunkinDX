extends RefCounted

const SongDataScript = preload("res://source/funkin/data/song/SongData.gd")
const PathsScript = preload("res://source/funkin/Paths.gd")

enum ChartFormat { UNKNOWN, V2, LEGACY }

static func load_song(song_id: String, base_path: String = "res://assets/songs/", variation: String = "default") -> Variant:
	var metadata_path := PathsScript.metadata(song_id, variation)
	var chart_path := PathsScript.chart_data(song_id, variation)
	
	if FileAccess.file_exists(metadata_path) and FileAccess.file_exists(chart_path):
		return load_v2_song(song_id, metadata_path, chart_path, variation)
	
	if variation == "default":
		var legacy_path := base_path.path_join(song_id).path_join(song_id + ".json")
		if FileAccess.file_exists(legacy_path):
			return load_legacy_song(song_id, legacy_path)
	
	push_error("Could not find chart files for song: %s (variation: %s)\n  Tried: %s\n  Tried: %s" % [song_id, variation, metadata_path, chart_path])
	return null

static func load_song_with_variations(song_id: String, base_path: String = "res://assets/songs/") -> Variant:
	var song = load_song(song_id, base_path, "default")
	if song == null:
		return null
	
	for vari in PathsScript.DEFAULT_VARIATION_LIST:
		if vari == "default":
			continue
		
		var var_metadata_path: String = PathsScript.metadata(song_id, vari)
		var var_chart_path: String = PathsScript.chart_data(song_id, vari)
		
		if FileAccess.file_exists(var_metadata_path) and FileAccess.file_exists(var_chart_path):
			_load_variation_into_song(song, song_id, var_metadata_path, var_chart_path, vari)
	
	return song

static func _load_variation_into_song(song: SongDataScript.Song, song_id: String, metadata_path: String, chart_path: String, p_variation: String) -> void:
	var metadata_json = _load_json(metadata_path)
	var chart_json = _load_json(chart_path)
	
	if metadata_json == null or chart_json == null:
		return
	
	var var_metadata: SongDataScript.SongMetadata = SongDataScript.SongMetadata.new()
	var_metadata.variation = p_variation
	_parse_v2_metadata(var_metadata, metadata_json)
	song.variations[p_variation] = var_metadata
	
	_parse_v2_chart_into_song(song.chart_data, chart_json, p_variation)

static func load_v2_song(song_id: String, metadata_path: String, chart_path: String, p_variation: String = "default") -> Variant:
	var metadata_json = _load_json(metadata_path)
	var chart_json = _load_json(chart_path)
	
	if metadata_json == null or chart_json == null:
		return null
	
	var song: SongDataScript.Song = SongDataScript.Song.new(song_id)
	song.metadata.variation = p_variation
	_parse_v2_metadata(song.metadata, metadata_json)
	_parse_v2_chart(song.chart_data, chart_json)
	song.variations[p_variation] = song.metadata
	
	return song

static func load_legacy_song(song_id: String, json_path: String) -> Variant:
	var json_data = _load_json(json_path)
	if json_data == null:
		return null
	
	var song: SongDataScript.Song = SongDataScript.Song.new(song_id)
	_parse_legacy_chart(song, json_data)
	
	return song

static func load_from_json(json_string: String, song_id: String = "") -> Variant:
	var json := JSON.new()
	var err := json.parse(json_string)
	if err != OK:
		push_error("Failed to parse JSON: " + json.get_error_message())
		return null
	
	var data: Dictionary = json.data
	var format := detect_format(data)
	
	var song := SongDataScript.Song.new(song_id)
	
	match format:
		ChartFormat.V2:
			if data.has("notes") and data.has("scrollSpeed"):
				_parse_v2_chart(song.chart_data, data)
			else:
				_parse_v2_metadata(song.metadata, data)
		ChartFormat.LEGACY:
			_parse_legacy_chart(song, data)
		_:
			push_error("Unknown chart format")
			return null
	
	return song

static func detect_format(data: Dictionary) -> ChartFormat:
	if data.has("song") and data["song"] is Dictionary:
		var song_data: Dictionary = data["song"]
		if song_data.has("notes") and song_data["notes"] is Array:
			return ChartFormat.LEGACY
	
	if data.has("version"):
		return ChartFormat.V2
	
	if data.has("notes") and data["notes"] is Dictionary:
		return ChartFormat.V2
	
	if data.has("timeChanges"):
		return ChartFormat.V2
	
	return ChartFormat.UNKNOWN

static func _load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open file: " + path)
		return null
	
	var content := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var err := json.parse(content)
	if err != OK:
		push_error("Failed to parse JSON in " + path + ": " + json.get_error_message())
		return null
	
	return json.data

static func _parse_v2_metadata(metadata: SongDataScript.SongMetadata, data: Dictionary) -> void:
	metadata.version = data.get("version", "2.0.0")
	metadata.song_name = data.get("songName", "Unknown")
	metadata.artist = data.get("artist", "Unknown")
	metadata.charter = data.get("charter", "")
	metadata.divisions = data.get("divisions", 96)
	metadata.looped = data.get("looped", false)
	metadata.time_format = data.get("timeFormat", "ms")
	
	if data.has("offsets"):
		var offsets_data: Dictionary = data["offsets"]
		metadata.offsets.instrumental = offsets_data.get("instrumental", 0.0)
		if offsets_data.has("vocals"):
			metadata.offsets.vocals = offsets_data["vocals"]
	
	if data.has("playData"):
		var play_data: Dictionary = data["playData"]
		metadata.play_data.difficulties.clear()
		for diff in play_data.get("difficulties", []):
			metadata.play_data.difficulties.append(diff)
		metadata.play_data.stage = play_data.get("stage", "mainStage")
		metadata.play_data.note_style = play_data.get("noteStyle", "funkin")
		
		if play_data.has("characters"):
			var chars: Dictionary = play_data["characters"]
			metadata.play_data.characters.player = chars.get("player", "bf")
			metadata.play_data.characters.girlfriend = chars.get("girlfriend", "gf")
			metadata.play_data.characters.opponent = chars.get("opponent", "dad")
			metadata.play_data.characters.instrumental = chars.get("instrumental", "")
			
			var alt_inst = chars.get("altInstrumentals", [])
			metadata.play_data.characters.alt_instrumentals.clear()
			for inst_id in alt_inst:
				metadata.play_data.characters.alt_instrumentals.append(inst_id)
			
			var player_vocals = chars.get("playerVocals", [])
			metadata.play_data.characters.player_vocals.clear()
			for voice_id in player_vocals:
				metadata.play_data.characters.player_vocals.append(voice_id)
			if metadata.play_data.characters.player_vocals.is_empty():
				metadata.play_data.characters.player_vocals.append(metadata.play_data.characters.player)
			
			var opponent_vocals = chars.get("opponentVocals", [])
			metadata.play_data.characters.opponent_vocals.clear()
			for voice_id in opponent_vocals:
				metadata.play_data.characters.opponent_vocals.append(voice_id)
			if metadata.play_data.characters.opponent_vocals.is_empty():
				metadata.play_data.characters.opponent_vocals.append(metadata.play_data.characters.opponent)
	
	if data.has("timeChanges"):
		metadata.time_changes.clear()
		for tc_data in data["timeChanges"]:
			var tc := SongDataScript.SongTimeChange.new()
			tc.time_stamp = tc_data.get("t", tc_data.get("timeStamp", 0.0))
			tc.bpm = tc_data.get("bpm", 100.0)
			tc.beat_time = tc_data.get("b", tc_data.get("beatTime", 0.0))
			tc.time_sig_num = tc_data.get("n", tc_data.get("timeSignatureNum", 4))
			tc.time_sig_den = tc_data.get("d", tc_data.get("timeSignatureDen", 4))
			metadata.time_changes.append(tc)

static func _parse_v2_chart(chart: SongDataScript.SongChartData, data: Dictionary) -> void:
	chart.version = data.get("version", "2.0.0")
	
	if data.has("scrollSpeed"):
		for key in data["scrollSpeed"].keys():
			chart.scroll_speed[key] = data["scrollSpeed"][key]
	
	if data.has("events"):
		for ev_data in data["events"]:
			var ev := SongDataScript.SongEventData.new()
			ev.time = ev_data.get("t", ev_data.get("time", 0.0))
			ev.event_kind = ev_data.get("e", ev_data.get("eventKind", ""))
			ev.value = ev_data.get("v", ev_data.get("value", null))
			chart.events.append(ev)
	
	if data.has("notes"):
		var notes_data: Dictionary = data["notes"]
		for difficulty in notes_data.keys():
			var notes_array: Array = []
			for note_data in notes_data[difficulty]:
				var note := SongDataScript.SongNoteData.new()
				note.time = note_data.get("t", note_data.get("time", 0.0))
				note.data = note_data.get("d", note_data.get("data", 0))
				note.length = note_data.get("l", note_data.get("length", 0.0))
				note.kind = note_data.get("k", note_data.get("kind", ""))
				notes_array.append(note)
			
			notes_array.sort_custom(func(a, b): return a.time < b.time)
			chart.notes[difficulty] = notes_array

static func _parse_v2_chart_into_song(chart: SongDataScript.SongChartData, data: Dictionary, variation: String) -> void:
	if data.has("scrollSpeed"):
		for key in data["scrollSpeed"].keys():
			chart.scroll_speed[key] = data["scrollSpeed"][key]
	
	if data.has("events"):
		for ev_data in data["events"]:
			var ev := SongDataScript.SongEventData.new()
			ev.time = ev_data.get("t", ev_data.get("time", 0.0))
			ev.event_kind = ev_data.get("e", ev_data.get("eventKind", ""))
			ev.value = ev_data.get("v", ev_data.get("value", null))
			chart.events.append(ev)
	
	if data.has("notes"):
		var notes_data: Dictionary = data["notes"]
		for difficulty in notes_data.keys():
			var notes_array: Array = []
			for note_data in notes_data[difficulty]:
				var note := SongDataScript.SongNoteData.new()
				note.time = note_data.get("t", note_data.get("time", 0.0))
				note.data = note_data.get("d", note_data.get("data", 0))
				note.length = note_data.get("l", note_data.get("length", 0.0))
				note.kind = note_data.get("k", note_data.get("kind", ""))
				notes_array.append(note)
			
			notes_array.sort_custom(func(a, b): return a.time < b.time)
			chart.notes[difficulty] = notes_array

static func _parse_legacy_chart(song: SongDataScript.Song, data: Dictionary) -> void:
	if not data.has("song"):
		push_error("Legacy chart missing 'song' key")
		return
	
	var song_data: Dictionary = data["song"]
	
	song.metadata.song_name = song_data.get("song", "Unknown")
	
	var bpm: float = song_data.get("bpm", 100.0)
	song.metadata.time_changes.clear()
	song.metadata.time_changes.append(SongDataScript.SongTimeChange.new(0.0, bpm))
	
	if song_data.has("player1"):
		song.metadata.play_data.characters.player = song_data["player1"]
	if song_data.has("player2"):
		song.metadata.play_data.characters.opponent = song_data["player2"]
	if song_data.has("gfVersion"):
		song.metadata.play_data.characters.girlfriend = song_data["gfVersion"]
	if song_data.has("stage"):
		song.metadata.play_data.stage = song_data["stage"]
	
	var speed = song_data.get("speed", 1.0)
	if speed is Dictionary:
		song.chart_data.scroll_speed = speed
	else:
		song.chart_data.scroll_speed["normal"] = float(speed)
	
	if not song_data.has("notes"):
		return
	
	var notes_source = song_data["notes"]
	
	if notes_source is Array:
		var notes := _parse_legacy_sections(notes_source, song.metadata.time_changes)
		song.chart_data.notes["normal"] = notes
		song.metadata.play_data.difficulties = ["normal"]
	elif notes_source is Dictionary:
		for difficulty in notes_source.keys():
			if notes_source[difficulty] != null:
				var notes := _parse_legacy_sections(notes_source[difficulty], song.metadata.time_changes)
				song.chart_data.notes[difficulty] = notes
				song.metadata.play_data.difficulties.append(difficulty)

static func _parse_legacy_sections(sections: Array, time_changes: Array) -> Array:
	var notes: Array = []
	var current_bpm: float = 100.0
	if time_changes.size() > 0:
		current_bpm = time_changes[0].bpm
	
	for section in sections:
		if section.get("changeBPM", false):
			var new_bpm: float = section.get("bpm", current_bpm)
			if new_bpm != current_bpm:
				current_bpm = new_bpm
		
		var must_hit: bool = section.get("mustHitSection", true)
		var section_notes: Array = section.get("sectionNotes", [])
		
		for note_arr in section_notes:
			if note_arr.size() < 2:
				continue
			
			var time: float = note_arr[0]
			var raw_data: int = int(note_arr[1])
			var length: float = note_arr[2] if note_arr.size() > 2 else 0.0
			var kind: String = ""
			
			if note_arr.size() > 3:
				var kind_val = note_arr[3]
				if kind_val is bool and kind_val:
					kind = "alt"
				elif kind_val is String:
					kind = kind_val
			
			var direction: int = raw_data % 4
			var is_opponent_note: bool = raw_data >= 4
			
			var final_data: int
			if must_hit:
				if is_opponent_note:
					final_data = direction + 4
				else:
					final_data = direction
			else:
				if is_opponent_note:
					final_data = direction
				else:
					final_data = direction + 4
			
			var note := SongDataScript.SongNoteData.new(time, final_data, length, kind)
			notes.append(note)
	
	notes.sort_custom(func(a, b): return a.time < b.time)
	return notes

static func convert_notes_to_play_format(notes: Array, for_player: bool = true) -> Array:
	var result: Array = []
	
	for note in notes:
		var is_player: bool = note.is_player_note()
		if is_player == for_player:
			result.append({
				"time": note.time,
				"data": note.get_direction(),
				"length": note.length,
				"kind": note.kind,
				"must_press": for_player
			})
	
	return result
