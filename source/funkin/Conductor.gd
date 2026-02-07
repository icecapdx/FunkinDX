extends Node

signal beat_hit(beat: int)
signal step_hit(step: int)
signal measure_hit(measure: int)

const SECS_PER_MIN: float = 60.0
const MS_PER_SEC: float = 1000.0
const STEPS_PER_BEAT: int = 4
const DEFAULT_BPM: float = 100.0
const DEFAULT_TIME_SIG_NUM: int = 4
const DEFAULT_TIME_SIG_DEN: int = 4

class TimeChange:
	var time_stamp: float = 0.0
	var beat_time: float = 0.0
	var bpm: float = DEFAULT_BPM
	var time_sig_num: int = DEFAULT_TIME_SIG_NUM
	var time_sig_den: int = DEFAULT_TIME_SIG_DEN
	
	func _init(p_timestamp: float = 0.0, p_bpm: float = DEFAULT_BPM, p_num: int = DEFAULT_TIME_SIG_NUM, p_den: int = DEFAULT_TIME_SIG_DEN):
		time_stamp = p_timestamp
		bpm = p_bpm
		time_sig_num = p_num
		time_sig_den = p_den

var time_changes: Array[TimeChange] = []
var current_time_change: TimeChange = null

var song_position: float = 0.0
var _song_position_delta: float = 0.0
var _prev_time: float = 0.0
var _prev_timestamp: int = 0

var _bpm_override: float = -1.0

var instrumental_offset: float = 0.0
var format_offset: float = 0.0
var _global_offset: int = 0

var current_measure: int = 0
var current_beat: int = 0
var current_step: int = 0

var current_measure_time: float = 0.0
var current_beat_time: float = 0.0
var current_step_time: float = 0.0

var bpm: float:
	get:
		if _bpm_override > 0:
			return _bpm_override
		if current_time_change == null:
			return DEFAULT_BPM
		return current_time_change.bpm

var starting_bpm: float:
	get:
		if _bpm_override > 0:
			return _bpm_override
		if time_changes.size() == 0:
			return DEFAULT_BPM
		return time_changes[0].bpm

var beat_length_ms: float:
	get:
		var denom: int = DEFAULT_TIME_SIG_DEN
		if current_time_change != null:
			denom = current_time_change.time_sig_den
		return ((SECS_PER_MIN / bpm) * MS_PER_SEC) * (4.0 / denom)

var step_length_ms: float:
	get:
		return beat_length_ms / STEPS_PER_BEAT

var measure_length_ms: float:
	get:
		return beat_length_ms * time_signature_numerator

var time_signature_numerator: int:
	get:
		if current_time_change == null:
			return DEFAULT_TIME_SIG_NUM
		return current_time_change.time_sig_num

var time_signature_denominator: int:
	get:
		if current_time_change == null:
			return DEFAULT_TIME_SIG_DEN
		return current_time_change.time_sig_den

var beats_per_measure: float:
	get:
		return float(time_signature_numerator)

var steps_per_measure: int:
	get:
		return time_signature_numerator * STEPS_PER_BEAT

var combined_offset: float:
	get:
		return instrumental_offset + format_offset + _global_offset

var global_offset: int:
	get:
		return _global_offset
	set(value):
		_global_offset = value

func _ready() -> void:
	reset()

func reset() -> void:
	time_changes.clear()
	current_time_change = null
	song_position = 0.0
	_song_position_delta = 0.0
	_prev_time = 0.0
	_prev_timestamp = 0
	_bpm_override = -1.0
	current_measure = 0
	current_beat = 0
	current_step = 0
	current_measure_time = 0.0
	current_beat_time = 0.0
	current_step_time = 0.0

func force_bpm(p_bpm: float = -1.0) -> void:
	_bpm_override = p_bpm

func update(song_pos: float = NAN, apply_offsets: bool = true) -> void:
	if is_nan(song_pos):
		song_pos = song_position
	
	if apply_offsets:
		song_pos += combined_offset
	
	var old_measure: int = current_measure
	var old_beat: int = current_beat
	var old_step: int = current_step
	
	song_position = song_pos
	_song_position_delta += get_process_delta_time() * MS_PER_SEC
	
	if time_changes.size() > 0:
		current_time_change = time_changes[0]
		if song_position > 0.0:
			for tc in time_changes:
				if song_position >= tc.time_stamp:
					current_time_change = tc
				else:
					break
	
	if current_time_change != null and song_position > 0.0:
		current_step_time = (current_time_change.beat_time * STEPS_PER_BEAT) + (song_position - current_time_change.time_stamp) / step_length_ms
		current_beat_time = current_step_time / STEPS_PER_BEAT
		current_measure_time = get_time_in_measures(song_position)
		current_step = int(floor(current_step_time))
		current_beat = int(floor(current_beat_time))
		current_measure = int(floor(current_measure_time))
	else:
		current_step_time = song_position / step_length_ms
		current_beat_time = current_step_time / STEPS_PER_BEAT
		current_measure_time = current_step_time / steps_per_measure
		current_step = int(floor(current_step_time))
		current_beat = int(floor(current_beat_time))
		current_measure = int(floor(current_measure_time))
	
	if current_step != old_step:
		step_hit.emit(current_step)
	
	if current_beat != old_beat:
		beat_hit.emit(current_beat)
	
	if current_measure != old_measure:
		measure_hit.emit(current_measure)
	
	if _prev_time != song_position:
		_song_position_delta = 0.0
		_prev_time = song_position
		_prev_timestamp = Time.get_ticks_msec()

func get_time_with_delta() -> float:
	return song_position + _song_position_delta

func map_time_changes(song_time_changes: Array) -> void:
	time_changes.clear()
	
	song_time_changes.sort_custom(func(a, b): return a.time_stamp < b.time_stamp)
	
	for stc in song_time_changes:
		var tc: TimeChange
		if stc is TimeChange:
			tc = stc
		else:
			tc = TimeChange.new(stc.get("time_stamp", 0.0), stc.get("bpm", DEFAULT_BPM))
		
		if tc.time_stamp < 0.0:
			tc.time_stamp = 0.0
		
		if tc.time_stamp <= 0.0:
			tc.beat_time = 0.0
		else:
			tc.beat_time = 0.0
			if tc.time_stamp > 0.0 and time_changes.size() > 0:
				var prev_tc: TimeChange = time_changes[-1]
				tc.beat_time = prev_tc.beat_time + ((tc.time_stamp - prev_tc.time_stamp) * prev_tc.bpm / SECS_PER_MIN / MS_PER_SEC * (prev_tc.time_sig_den / 4.0))
		
		time_changes.append(tc)
	
	update(song_position, false)

func get_time_in_measures(ms: float) -> float:
	if time_changes.size() == 0:
		return ms / step_length_ms / steps_per_measure
	
	var result_measure_time: float = 0.0
	ms = max(ms, 0.0)
	
	var last_tc: TimeChange = time_changes[0]
	var i: int = -1
	for tc in time_changes:
		i += 1
		if ms >= tc.time_stamp:
			if ms < tc.time_stamp or i == time_changes.size() - 1:
				last_tc = tc
				break
			var current_step_len: float = (((SECS_PER_MIN / last_tc.bpm) * MS_PER_SEC) * (4.0 / last_tc.time_sig_den)) / STEPS_PER_BEAT
			var current_steps_per_measure: int = last_tc.time_sig_num * STEPS_PER_BEAT
			result_measure_time += (tc.time_stamp - last_tc.time_stamp) / current_step_len / current_steps_per_measure
			last_tc = tc
	
	var remaining_step_len: float = (((SECS_PER_MIN / last_tc.bpm) * MS_PER_SEC) * (4.0 / last_tc.time_sig_den)) / STEPS_PER_BEAT
	var remaining_steps_per_measure: int = last_tc.time_sig_num * STEPS_PER_BEAT
	var remaining_fractional_measure: float = (ms - last_tc.time_stamp) / remaining_step_len / remaining_steps_per_measure
	result_measure_time += remaining_fractional_measure
	
	return result_measure_time

func get_time_in_steps(ms: float) -> float:
	if time_changes.size() == 0:
		return floor(ms / step_length_ms)
	
	var result_step: float = 0.0
	ms = max(ms, 0.0)
	
	var last_tc: TimeChange = time_changes[0]
	var i: int = -1
	for tc in time_changes:
		i += 1
		if ms >= tc.time_stamp:
			if ms < tc.time_stamp or i == time_changes.size() - 1:
				last_tc = tc
				break
			result_step += (tc.beat_time - last_tc.beat_time) * STEPS_PER_BEAT
			last_tc = tc
	
	var last_step_len: float = (((SECS_PER_MIN / last_tc.bpm) * MS_PER_SEC) * (4.0 / last_tc.time_sig_den)) / STEPS_PER_BEAT
	var result_fractional_step: float = (ms - last_tc.time_stamp) / last_step_len
	result_step += result_fractional_step
	
	return result_step

func get_step_time_in_ms(step_time: float) -> float:
	if time_changes.size() == 0:
		return step_time * step_length_ms
	
	var result_ms: float = 0.0
	step_time = max(step_time, 0.0)
	
	var last_tc: TimeChange = time_changes[0]
	var i: int = -1
	for tc in time_changes:
		i += 1
		if step_time >= tc.beat_time * STEPS_PER_BEAT:
			if step_time < (tc.beat_time * STEPS_PER_BEAT) or i == time_changes.size() - 1:
				last_tc = tc
				break
			result_ms += tc.time_stamp - last_tc.time_stamp
			last_tc = tc
	
	var last_step_len: float = (((SECS_PER_MIN / last_tc.bpm) * MS_PER_SEC) * (4.0 / last_tc.time_sig_den)) / STEPS_PER_BEAT
	result_ms += (step_time - last_tc.beat_time * STEPS_PER_BEAT) * last_step_len
	
	return result_ms

func get_beat_time_in_ms(beat_time: float) -> float:
	if time_changes.size() == 0:
		return beat_time * step_length_ms * STEPS_PER_BEAT
	
	var result_ms: float = 0.0
	
	var last_tc: TimeChange = time_changes[0]
	for tc in time_changes:
		if beat_time >= tc.beat_time:
			last_tc = tc
			result_ms = last_tc.time_stamp
		else:
			break
	
	var last_step_len: float = (((SECS_PER_MIN / last_tc.bpm) * MS_PER_SEC) * (4.0 / last_tc.time_sig_den)) / STEPS_PER_BEAT
	result_ms += (beat_time - last_tc.beat_time) * last_step_len * STEPS_PER_BEAT
	
	return result_ms
