class_name GDAnimateData
extends RefCounted

enum SymbolType { GRAPHIC, MOVIE_CLIP, BUTTON }
enum LoopType { LOOP, PLAY_ONCE, SINGLE_FRAME }

class ColorEffectData:
	var mode: String = ""
	var tint_color: Color = Color.WHITE
	var tint_multiplier: float = 0.0
	var alpha_multiplier: float = 1.0
	var alpha_offset: int = 0
	var red_multiplier: float = 1.0
	var red_offset: int = 0
	var green_multiplier: float = 1.0
	var green_offset: int = 0
	var blue_multiplier: float = 1.0
	var blue_offset: int = 0
	var brightness: float = 0.0

class SymbolParamsData:
	var name: String = ""
	var instance_name: String = ""
	var symbol_type: int = SymbolType.GRAPHIC
	var loop_type: int = LoopType.LOOP
	var first_frame: int = 0
	var reverse: bool = false
	var transformation_point: Vector2 = Vector2.ZERO
	var color_effect: ColorEffectData = null

class ElementData:
	var bitmap_name: String = ""
	var symbol_params: SymbolParamsData = null
	var transform: Transform2D = Transform2D.IDENTITY

	func is_bitmap() -> bool:
		return bitmap_name != ""

	func is_symbol() -> bool:
		return symbol_params != null

class KeyFrameData:
	var index: int = 0
	var duration: int = 1
	var label: String = ""
	var elements: Array = []
	var color_effect: ColorEffectData = null

	func contains_frame(frame: int) -> bool:
		return frame >= index and frame < index + duration

	func get_frame_indices() -> Array[int]:
		var result: Array[int] = []
		for i in range(index, index + duration):
			result.append(i)
		return result

class LayerData:
	var name: String = ""
	var layer_type: String = "Normal"
	var clipped_by: String = ""
	var keyframes: Array = []
	var labels: Dictionary = {}
	var visible: bool = true

	func get_length() -> int:
		if keyframes.is_empty():
			return 0
		var last: KeyFrameData = keyframes[keyframes.size() - 1]
		return last.index + last.duration

	func get_keyframe_at(frame: int) -> KeyFrameData:
		for kf in keyframes:
			if kf.index + kf.duration > frame:
				return kf
		return null

	func get_label(label_name: String) -> KeyFrameData:
		return labels.get(label_name)

class TimelineData:
	var layers: Array = []

	func get_total_frames() -> int:
		var max_frames := 0
		for layer in layers:
			var l: int = layer.get_length()
			if l > max_frames:
				max_frames = l
		return max_frames

class SymbolData:
	var name: String = ""
	var timeline: TimelineData = null

	func get_length() -> int:
		if timeline == null:
			return 0
		return timeline.get_total_frames()

class AtlasData:
	var name: String = ""
	var framerate: float = 24.0
	var main_symbol_name: String = ""
	var stage_instance: ElementData = null
	var symbols: Dictionary = {}

static func parse_animation(json_path: String) -> AtlasData:
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open Animation.json: " + json_path)
		return null

	var text := file.get_as_text()
	file.close()

	text = text.strip_edges()
	if text.begins_with("\ufeff"):
		text = text.substr(1)

	var json = JSON.parse_string(text)
	if json == null:
		push_error("Failed to parse Animation.json: " + json_path)
		return null

	var result := AtlasData.new()

	var an: Dictionary = _get_field(json, ["AN", "ANIMATION"], {})
	var sd = _get_field(json, ["SD", "SYMBOL_DICTIONARY"], null)
	var md: Dictionary = _get_field(json, ["MD", "metadata"], {})

	result.name = _get_field(an, ["N", "name"], "")
	result.framerate = _get_field(md, ["FRT", "framerate"], 24.0)
	result.main_symbol_name = _get_field(an, ["SN", "SYMBOL_name"], "")

	var main_tl = _get_field(an, ["TL", "TIMELINE"], null)
	if main_tl != null:
		var main_symbol := SymbolData.new()
		main_symbol.name = result.main_symbol_name
		main_symbol.timeline = _parse_timeline(main_tl)
		result.symbols[main_symbol.name] = main_symbol

	var sti = _get_field(an, ["STI", "StageInstance"], null)
	if sti != null:
		result.stage_instance = _parse_element_from_sti(sti)
	else:
		result.stage_instance = ElementData.new()
		result.stage_instance.symbol_params = SymbolParamsData.new()
		result.stage_instance.symbol_params.name = result.main_symbol_name

	if sd != null:
		var symbols_arr: Array = _get_field(sd, ["S", "Symbols"], [])
		for sym_json in symbols_arr:
			var sym := SymbolData.new()
			sym.name = _get_field(sym_json, ["SN", "SYMBOL_name"], "")
			var tl = _get_field(sym_json, ["TL", "TIMELINE"], null)
			if tl != null:
				sym.timeline = _parse_timeline(tl)
			result.symbols[sym.name] = sym

	return result

static func _parse_timeline(tl_json: Dictionary) -> TimelineData:
	var timeline := TimelineData.new()
	var layers_json: Array = _get_field(tl_json, ["L", "LAYERS"], [])
	for layer_json in layers_json:
		timeline.layers.append(_parse_layer(layer_json))
	return timeline

static func _parse_layer(layer_json: Dictionary) -> LayerData:
	var layer := LayerData.new()
	layer.name = _get_field(layer_json, ["LN", "Layer_name"], "")

	var lt = _get_field(layer_json, ["LT", "Layer_type"], null)
	var clpb = _get_field(layer_json, ["Clpb", "Clipped_by"], null)

	if lt != null:
		layer.layer_type = "Clipper"
	elif clpb != null:
		layer.layer_type = "Clipped"
		layer.clipped_by = str(clpb)

	var frames_json: Array = _get_field(layer_json, ["FR", "Frames"], [])
	for frame_json in frames_json:
		var kf := _parse_keyframe(frame_json)
		layer.keyframes.append(kf)
		if kf.label != "":
			layer.labels[kf.label] = kf

	return layer

static func _parse_keyframe(frame_json: Dictionary) -> KeyFrameData:
	var kf := KeyFrameData.new()
	kf.index = int(_get_field(frame_json, ["I", "index"], 0))
	kf.duration = int(_get_field(frame_json, ["DU", "duration"], 1))
	kf.label = _get_field(frame_json, ["N", "name"], "")

	var c = _get_field(frame_json, ["C", "color"], null)
	if c != null:
		kf.color_effect = _parse_color_effect(c)

	var elements_json: Array = _get_field(frame_json, ["E", "elements"], [])
	for elem_json in elements_json:
		kf.elements.append(_parse_element(elem_json))

	return kf

static func _parse_element(elem_json: Dictionary) -> ElementData:
	var element := ElementData.new()

	var si = _get_field(elem_json, ["SI", "SYMBOL_Instance"], null)
	var asi = _get_field(elem_json, ["ASI", "ATLAS_SPRITE_instance"], null)

	if si != null:
		element.symbol_params = _parse_symbol_params(si)
		element.transform = _parse_element_matrix(si)
		var bm = _get_field(si, ["BM", "bitmap"], null)
		if bm != null:
			element.bitmap_name = _get_field(bm, ["N", "name"], "")
			var bm_pos = _get_field(bm, ["POS", "Position"], null)
			if bm_pos != null and bm_pos is Dictionary:
				element.transform.origin.x += float(bm_pos.get("x", 0.0))
				element.transform.origin.y += float(bm_pos.get("y", 0.0))
	elif asi != null:
		element.bitmap_name = _get_field(asi, ["N", "name"], "")
		element.transform = _parse_element_matrix(asi)
		var asi_pos = _get_field(asi, ["POS", "Position"], null)
		if asi_pos != null and asi_pos is Dictionary:
			element.transform.origin.x += float(asi_pos.get("x", 0.0))
			element.transform.origin.y += float(asi_pos.get("y", 0.0))

	return element

static func _parse_element_from_sti(sti_json: Dictionary) -> ElementData:
	var si = _get_field(sti_json, ["SI", "SYMBOL_Instance"], null)
	if si != null:
		var elem := ElementData.new()
		elem.symbol_params = _parse_symbol_params(si)
		elem.transform = _parse_element_matrix(si)
		return elem
	return null

static func _parse_symbol_params(si_json: Dictionary) -> SymbolParamsData:
	var params := SymbolParamsData.new()
	params.name = _get_field(si_json, ["SN", "SYMBOL_name"], "")
	params.instance_name = _get_field(si_json, ["IN", "Instance_Name"], "")

	var st: String = str(_get_field(si_json, ["ST", "symbolType"], "G"))
	match st:
		"MC", "movieclip":
			params.symbol_type = SymbolType.MOVIE_CLIP
		"B", "button":
			params.symbol_type = SymbolType.BUTTON
		_:
			params.symbol_type = SymbolType.GRAPHIC

	var lp_raw = _get_field(si_json, ["LP", "loop"], "LP")
	if lp_raw == null:
		lp_raw = "LP"
	var lp: String = str(lp_raw)
	params.reverse = lp.contains("R")
	lp = lp.replace("R", "")
	match lp:
		"PO", "playonce":
			params.loop_type = LoopType.PLAY_ONCE
		"SF", "singleframe":
			params.loop_type = LoopType.SINGLE_FRAME
		_:
			params.loop_type = LoopType.LOOP

	var ff_val = _get_field(si_json, ["FF", "firstFrame"], 0)
	params.first_frame = int(ff_val) if ff_val != null else 0

	var trp = _get_field(si_json, ["TRP", "transformationPoint"], null)
	if trp != null and trp is Dictionary:
		params.transformation_point = Vector2(float(trp.get("x", 0.0)), float(trp.get("y", 0.0)))

	var c = _get_field(si_json, ["C", "color"], null)
	if c != null:
		params.color_effect = _parse_color_effect(c)

	return params

static func _parse_color_effect(c_json: Dictionary) -> ColorEffectData:
	var ce := ColorEffectData.new()
	ce.mode = str(_get_field(c_json, ["M", "mode"], ""))

	var tc: String = str(_get_field(c_json, ["TC", "tintColor"], ""))
	if tc != "" and tc.begins_with("#"):
		ce.tint_color = Color.html(tc)

	ce.tint_multiplier = float(_get_field(c_json, ["TM", "tintMultiplier"], 0.0))
	ce.alpha_multiplier = float(_get_field(c_json, ["AM", "alphaMultiplier"], 1.0))
	ce.alpha_offset = int(_get_field(c_json, ["AO", "AlphaOffset"], 0))
	ce.red_multiplier = float(_get_field(c_json, ["RM", "RedMultiplier"], 1.0))
	ce.red_offset = int(_get_field(c_json, ["RO", "redOffset"], 0))
	ce.green_multiplier = float(_get_field(c_json, ["GM", "greenMultiplier"], 1.0))
	ce.green_offset = int(_get_field(c_json, ["GO", "greenOffset"], 0))
	ce.blue_multiplier = float(_get_field(c_json, ["BM", "blueMultiplier"], 1.0))
	ce.blue_offset = int(_get_field(c_json, ["BO", "blueOffset"], 0))
	ce.brightness = float(_get_field(c_json, ["BRT", "Brightness"], 0.0))
	return ce

static func _parse_element_matrix(json_obj: Dictionary) -> Transform2D:
	var mx = _get_field(json_obj, ["MX"], null)
	if mx != null and mx is Array:
		return _parse_matrix_2d(mx)
	var m3d = _get_field(json_obj, ["M3D", "Matrix3D"], null)
	return _parse_matrix_3d(m3d)

static func _parse_matrix_2d(mx_arr) -> Transform2D:
	if mx_arr == null or not (mx_arr is Array):
		return Transform2D.IDENTITY

	var m: Array = mx_arr
	while m.size() < 6:
		m.append(0.0)

	return Transform2D(
		Vector2(float(m[0]), float(m[1])),
		Vector2(float(m[2]), float(m[3])),
		Vector2(float(m[4]), float(m[5]))
	)

static func _parse_matrix_3d(m3d_val) -> Transform2D:
	if m3d_val == null:
		return Transform2D.IDENTITY

	var m: Array = []
	if m3d_val is Array:
		m = m3d_val
	elif m3d_val is Dictionary:
		var keys := ["m00", "m01", "m02", "m03", "m10", "m11", "m12", "m13",
					 "m20", "m21", "m22", "m23", "m30", "m31", "m32", "m33"]
		for k in keys:
			m.append(float(m3d_val.get(k, 0.0)))
	else:
		return Transform2D.IDENTITY

	while m.size() < 16:
		m.append(0.0)

	return Transform2D(
		Vector2(float(m[0]), float(m[1])),
		Vector2(float(m[4]), float(m[5])),
		Vector2(float(m[12]), float(m[13]))
	)

static func _get_field(dict, keys: Array, default_value: Variant) -> Variant:
	if dict == null or not (dict is Dictionary):
		return default_value
	for key in keys:
		if dict.has(key) and dict[key] != null:
			return dict[key]
	return default_value