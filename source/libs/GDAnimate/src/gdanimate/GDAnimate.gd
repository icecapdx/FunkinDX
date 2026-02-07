class_name GDAnimate
extends Node2D

const SpriteMapClass = preload("res://source/libs/GDAnimate/src/gdanimate/SpriteMap.gd")
const AnimDataClass = preload("res://source/libs/GDAnimate/src/gdanimate/AnimationData.gd")

var anim: AnimController
var pivot: Vector2 = Vector2.ZERO

var _sprite_maps: Array = []
var _anim_data: AnimDataClass.AtlasData

signal animation_finished

func _init():
	anim = AnimController.new(self)

static func create(path: String, x_pos: float = 0, y_pos: float = 0) -> GDAnimate:
	var instance := GDAnimate.new()
	instance.position = Vector2(x_pos, y_pos)
	instance.load_atlas(path)
	return instance

func load_atlas(path: String) -> bool:
	_sprite_maps.clear()

	var i := 0
	while true:
		var json_name: String
		if i == 0:
			json_name = "spritemap.json"
		else:
			json_name = "spritemap" + str(i) + ".json"

		var json_path := path.path_join(json_name)
		if not FileAccess.file_exists(json_path):
			if i == 0:
				i = 1
				continue
			break

		var smap = SpriteMapClass.from_json(json_path)
		if smap != null:
			_sprite_maps.append(smap)

		if i == 0:
			i = 1
			continue
		i += 1

	if _sprite_maps.is_empty():
		push_error("No spritemaps found in: " + path)
		return false

	var anim_path := path.path_join("Animation.json")
	_anim_data = AnimDataClass.parse_animation(anim_path)
	if _anim_data == null:
		push_error("Failed to load Animation.json from: " + path)
		return false

	anim._init_from_data(_anim_data)

	if anim.cur_instance != null and anim.cur_instance.symbol_params != null:
		pivot = anim.cur_instance.symbol_params.transformation_point

	return true

func _process(delta: float) -> void:
	anim.update(delta)
	queue_redraw()

func _draw() -> void:
	if _anim_data == null or anim.cur_instance == null:
		return
	if not anim.cur_instance.is_symbol():
		return

	var base_xform := anim.cur_instance.transform
	if pivot != Vector2.ZERO:
		base_xform = base_xform * Transform2D.IDENTITY.translated(-pivot)

	var base_color := _apply_element_color(Color.WHITE, anim.cur_instance)
	_render_symbol_layers(anim.cur_instance.symbol_params.name, anim.cur_frame, base_xform, base_color)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _render_symbol_layers(sym_name: String, sym_frame: int, xform: Transform2D, color: Color) -> void:
	var symbol: AnimDataClass.SymbolData = _anim_data.symbols.get(sym_name)
	if symbol == null or symbol.timeline == null:
		return

	var layers := symbol.timeline.layers
	for i in range(layers.size() - 1, -1, -1):
		var layer: AnimDataClass.LayerData = layers[i]
		if not layer.visible or layer.layer_type == "Clipper":
			continue

		var kf: AnimDataClass.KeyFrameData = layer.get_keyframe_at(sym_frame)
		if kf == null:
			continue

		var kf_color := _apply_keyframe_color(color, kf)
		var relative_frame: int = sym_frame - kf.index

		for child in kf.elements:
			_render_element(child, xform, kf_color, relative_frame)

func _render_element(element: AnimDataClass.ElementData, parent_xform: Transform2D, parent_color: Color, context_frame: int) -> void:
	var xform := parent_xform * element.transform
	var color := _apply_element_color(parent_color, element)

	if element.is_bitmap():
		_draw_bitmap(element.bitmap_name, xform, color)
	elif element.is_symbol():
		var sym_name: String = element.symbol_params.name
		var symbol: AnimDataClass.SymbolData = _anim_data.symbols.get(sym_name)
		if symbol == null:
			return

		var sym_length: int = symbol.get_length()
		if sym_length <= 0:
			return

		var sym_frame: int = context_frame + element.symbol_params.first_frame
		match element.symbol_params.loop_type:
			AnimDataClass.LoopType.LOOP:
				if sym_length > 0:
					sym_frame = sym_frame % sym_length
					if sym_frame < 0:
						sym_frame += sym_length
			AnimDataClass.LoopType.PLAY_ONCE:
				sym_frame = clampi(sym_frame, 0, sym_length - 1)
			AnimDataClass.LoopType.SINGLE_FRAME:
				sym_frame = clampi(element.symbol_params.first_frame, 0, sym_length - 1)

		if element.symbol_params.symbol_type == AnimDataClass.SymbolType.MOVIE_CLIP:
			sym_frame = 0

		_render_symbol_layers(sym_name, sym_frame, xform, color)

func _draw_bitmap(bitmap_name: String, xform: Transform2D, color: Color) -> void:
	for smap in _sprite_maps:
		var sprite_data: SpriteMapClass.SpriteData = smap.get_sprite(bitmap_name)
		if sprite_data == null:
			continue

		var src_rect := Rect2(sprite_data.x, sprite_data.y, sprite_data.w, sprite_data.h)
		var draw_xform := xform
		var dest_size: Vector2

		if sprite_data.rotated:
			dest_size = Vector2(sprite_data.w, sprite_data.h)
			var rot_correction := Transform2D(
				Vector2(0, -1),
				Vector2(1, 0),
				Vector2(0, float(sprite_data.w))
			)
			draw_xform = draw_xform * rot_correction
		else:
			dest_size = Vector2(sprite_data.w, sprite_data.h)

		draw_set_transform_matrix(draw_xform)
		draw_texture_rect_region(smap.texture, Rect2(Vector2.ZERO, dest_size), src_rect, color)
		return

func compute_frame_bounds() -> Rect2:
	if _anim_data == null or anim.cur_instance == null:
		return Rect2()
	if not anim.cur_instance.is_symbol():
		return Rect2()

	var base_xform := anim.cur_instance.transform
	if pivot != Vector2.ZERO:
		base_xform = base_xform * Transform2D.IDENTITY.translated(-pivot)

	var all_rects: Array[Rect2] = []
	_collect_symbol_bounds(anim.cur_instance.symbol_params.name, anim.cur_frame, base_xform, all_rects)

	if all_rects.is_empty():
		return Rect2()

	var result := all_rects[0]
	for i in range(1, all_rects.size()):
		result = result.merge(all_rects[i])
	return result

func _collect_symbol_bounds(sym_name: String, sym_frame: int, xform: Transform2D, out_rects: Array[Rect2]) -> void:
	var symbol: AnimDataClass.SymbolData = _anim_data.symbols.get(sym_name)
	if symbol == null or symbol.timeline == null:
		return

	var layers := symbol.timeline.layers
	for i in range(layers.size() - 1, -1, -1):
		var layer: AnimDataClass.LayerData = layers[i]
		if not layer.visible or layer.layer_type == "Clipper":
			continue
		var kf: AnimDataClass.KeyFrameData = layer.get_keyframe_at(sym_frame)
		if kf == null:
			continue
		var relative_frame: int = sym_frame - kf.index
		for child in kf.elements:
			_collect_element_bounds(child, xform, relative_frame, out_rects)

func _collect_element_bounds(element: AnimDataClass.ElementData, parent_xform: Transform2D, context_frame: int, out_rects: Array[Rect2]) -> void:
	var xform := parent_xform * element.transform

	if element.is_bitmap():
		var bounds := _get_bitmap_bounds(element.bitmap_name, xform)
		if bounds.size != Vector2.ZERO:
			out_rects.append(bounds)
	elif element.is_symbol():
		var sym_name: String = element.symbol_params.name
		var symbol: AnimDataClass.SymbolData = _anim_data.symbols.get(sym_name)
		if symbol == null:
			return
		var sym_length: int = symbol.get_length()
		if sym_length <= 0:
			return

		var sym_frame: int = context_frame + element.symbol_params.first_frame
		match element.symbol_params.loop_type:
			AnimDataClass.LoopType.LOOP:
				if sym_length > 0:
					sym_frame = sym_frame % sym_length
					if sym_frame < 0:
						sym_frame += sym_length
			AnimDataClass.LoopType.PLAY_ONCE:
				sym_frame = clampi(sym_frame, 0, sym_length - 1)
			AnimDataClass.LoopType.SINGLE_FRAME:
				sym_frame = clampi(element.symbol_params.first_frame, 0, sym_length - 1)

		if element.symbol_params.symbol_type == AnimDataClass.SymbolType.MOVIE_CLIP:
			sym_frame = 0

		_collect_symbol_bounds(sym_name, sym_frame, xform, out_rects)

func _get_bitmap_bounds(bitmap_name: String, xform: Transform2D) -> Rect2:
	for smap in _sprite_maps:
		var sprite_data: SpriteMapClass.SpriteData = smap.get_sprite(bitmap_name)
		if sprite_data == null:
			continue

		var draw_xform := xform
		var dest_size: Vector2

		if sprite_data.rotated:
			dest_size = Vector2(sprite_data.w, sprite_data.h)
			var rot_correction := Transform2D(
				Vector2(0, -1), Vector2(1, 0), Vector2(0, float(sprite_data.w))
			)
			draw_xform = draw_xform * rot_correction
		else:
			dest_size = Vector2(sprite_data.w, sprite_data.h)

		return _transform_rect_to_aabb(draw_xform, Rect2(Vector2.ZERO, dest_size))
	return Rect2()

func _transform_rect_to_aabb(xform: Transform2D, rect: Rect2) -> Rect2:
	var p0 := xform * rect.position
	var p1 := xform * Vector2(rect.position.x + rect.size.x, rect.position.y)
	var p2 := xform * Vector2(rect.position.x, rect.position.y + rect.size.y)
	var p3 := xform * (rect.position + rect.size)

	var min_x := minf(minf(p0.x, p1.x), minf(p2.x, p3.x))
	var max_x := maxf(maxf(p0.x, p1.x), maxf(p2.x, p3.x))
	var min_y := minf(minf(p0.y, p1.y), minf(p2.y, p3.y))
	var max_y := maxf(maxf(p0.y, p1.y), maxf(p2.y, p3.y))

	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

func _apply_element_color(parent_color: Color, element: AnimDataClass.ElementData) -> Color:
	if element.is_symbol() and element.symbol_params.color_effect != null:
		return _compute_color(parent_color, element.symbol_params.color_effect)
	return parent_color

func _apply_keyframe_color(parent_color: Color, kf: AnimDataClass.KeyFrameData) -> Color:
	if kf.color_effect == null:
		return parent_color
	return _compute_color(parent_color, kf.color_effect)

func _compute_color(base: Color, ce: AnimDataClass.ColorEffectData) -> Color:
	match ce.mode:
		"CA", "Alpha":
			return Color(base.r, base.g, base.b, base.a * ce.alpha_multiplier)
		"T", "Tint":
			var t := ce.tint_multiplier
			return Color(
				lerpf(base.r, ce.tint_color.r, t),
				lerpf(base.g, ce.tint_color.g, t),
				lerpf(base.b, ce.tint_color.b, t),
				base.a
			)
		"CBRT", "Brightness":
			var b := ce.brightness
			if b > 0:
				return Color(
					lerpf(base.r, 1.0, b),
					lerpf(base.g, 1.0, b),
					lerpf(base.b, 1.0, b),
					base.a
				)
			else:
				return Color(
					lerpf(base.r, 0.0, -b),
					lerpf(base.g, 0.0, -b),
					lerpf(base.b, 0.0, -b),
					base.a
				)
		"AD", "Advanced":
			return Color(
				clampf(base.r * ce.red_multiplier + ce.red_offset / 255.0, 0.0, 1.0),
				clampf(base.g * ce.green_multiplier + ce.green_offset / 255.0, 0.0, 1.0),
				clampf(base.b * ce.blue_multiplier + ce.blue_offset / 255.0, 0.0, 1.0),
				clampf(base.a * ce.alpha_multiplier + ce.alpha_offset / 255.0, 0.0, 1.0)
			)
	return base


class AnimController:
	var is_playing: bool = false
	var framerate: float = 24.0
	var reversed: bool = false
	var time_scale: float = 1.0

	var cur_instance: AnimDataClass.ElementData
	var stage_instance: AnimDataClass.ElementData

	var _cur_frame: int = 0
	var _tick: float = 0.0
	var _frame_delay: float = 1.0 / 24.0
	var _atlas_data: AnimDataClass.AtlasData
	var _anims: Dictionary = {}
	var _parent: GDAnimate

	func _init(parent: GDAnimate):
		_parent = parent

	func _init_from_data(data: AnimDataClass.AtlasData) -> void:
		_atlas_data = data
		stage_instance = data.stage_instance
		cur_instance = stage_instance
		framerate = data.framerate
		_frame_delay = 1.0 / framerate if framerate > 0 else 0.0
		_cur_frame = 0
		if cur_instance != null and cur_instance.symbol_params != null:
			_cur_frame = cur_instance.symbol_params.first_frame

	var cur_frame: int:
		get:
			return _cur_frame
		set(value):
			_set_cur_frame(value)

	var length: int:
		get:
			return _get_length()

	var finished: bool:
		get:
			return _is_finished()

	func _get_length() -> int:
		if cur_instance == null or cur_instance.symbol_params == null:
			return 0
		if _atlas_data == null:
			return 0
		var sym: AnimDataClass.SymbolData = _atlas_data.symbols.get(cur_instance.symbol_params.name)
		if sym == null:
			return 0
		return sym.get_length()

	func _is_finished() -> bool:
		if cur_instance == null or cur_instance.symbol_params == null:
			return true
		if cur_instance.symbol_params.loop_type != AnimDataClass.LoopType.PLAY_ONCE:
			return false
		if reversed:
			return _cur_frame <= 0
		return _cur_frame >= length - 1

	func _set_cur_frame(value: int) -> void:
		var l := length
		if l <= 0:
			_cur_frame = 0
			return
		var lt := AnimDataClass.LoopType.LOOP
		if cur_instance != null and cur_instance.symbol_params != null:
			lt = cur_instance.symbol_params.loop_type
		match lt:
			AnimDataClass.LoopType.LOOP:
				if value < 0:
					_cur_frame = l - 1
				else:
					_cur_frame = value % l
			AnimDataClass.LoopType.PLAY_ONCE:
				_cur_frame = clampi(value, 0, l - 1)
			_:
				_cur_frame = value

	func play(anim_name: String = "", force: bool = false, reverse: bool = false, frame: int = 0) -> void:
		pause()
		force = force or finished

		if anim_name != "":
			if _anims.has(anim_name):
				var entry: Dictionary = _anims[anim_name]
				var fr: float = entry.get("framerate", 0.0)
				if fr > 0:
					framerate = fr
				else:
					framerate = _atlas_data.framerate
				_frame_delay = 1.0 / framerate if framerate > 0 else 0.0
				force = force or (cur_instance != entry["instance"])
				cur_instance = entry["instance"]
			elif _atlas_data != null and _atlas_data.symbols.has(anim_name):
				if cur_instance != null and cur_instance.symbol_params != null:
					cur_instance.symbol_params.name = anim_name
			else:
				push_error("No animation called: " + anim_name)
				resume()
				return

		if force:
			_tick = 0.0
			reversed = reverse
			if reverse:
				cur_frame = frame - length
			else:
				cur_frame = frame

		reversed = reverse
		resume()

	func pause() -> void:
		is_playing = false

	func resume() -> void:
		is_playing = true

	func stop() -> void:
		pause()
		cur_frame = 0

	func finish() -> void:
		stop()
		if not reversed:
			cur_frame = length - 1

	func update(delta: float) -> void:
		if _frame_delay <= 0 or not is_playing or finished:
			return

		_tick += delta * time_scale

		while _tick > _frame_delay:
			if reversed:
				cur_frame = _cur_frame - 1
			else:
				cur_frame = _cur_frame + 1
			_tick -= _frame_delay

		var lt := AnimDataClass.LoopType.LOOP
		if cur_instance != null and cur_instance.symbol_params != null:
			lt = cur_instance.symbol_params.loop_type

		if lt != AnimDataClass.LoopType.SINGLE_FRAME:
			var at_end: bool = _cur_frame == (0 if reversed else length - 1)
			if at_end:
				if lt == AnimDataClass.LoopType.PLAY_ONCE:
					pause()
				_parent.animation_finished.emit()

	func add_by_symbol(anim_name: String, symbol_name: String, frame_rate: float = 0, looped: bool = true, x_pos: float = 0, y_pos: float = 0) -> void:
		if _atlas_data == null:
			return

		var found_name := ""
		if _atlas_data.symbols.has(symbol_name):
			found_name = symbol_name
		else:
			for sname in _atlas_data.symbols.keys():
				if _starts_with_check(sname, symbol_name):
					found_name = sname
					break

		if found_name == "":
			push_error("No symbol found with name: " + symbol_name)
			return

		var element := AnimDataClass.ElementData.new()
		element.symbol_params = AnimDataClass.SymbolParamsData.new()
		element.symbol_params.name = found_name
		element.symbol_params.loop_type = AnimDataClass.LoopType.LOOP if looped else AnimDataClass.LoopType.PLAY_ONCE
		element.transform = Transform2D(Vector2(1, 0), Vector2(0, 1), Vector2(x_pos, y_pos))

		_anims[anim_name] = {
			"instance": element,
			"framerate": frame_rate
		}

	func add_by_frame_label(anim_name: String, frame_label: String, frame_rate: float = 0, looped: bool = true, x_pos: float = 0, y_pos: float = 0) -> void:
		var label_kf := get_frame_label(frame_label)
		if label_kf == null:
			push_error("No frame label found: " + frame_label)
			return

		var indices: Array[int] = label_kf.get_frame_indices()
		add_by_symbol_indices(anim_name, _atlas_data.main_symbol_name, indices, frame_rate, looped, x_pos, y_pos)

	func add_by_frame_label_indices(anim_name: String, frame_label: String, indices: Array[int], frame_rate: float = 0, looped: bool = true, x_pos: float = 0, y_pos: float = 0) -> void:
		var label_kf := get_frame_label(frame_label)
		if label_kf == null:
			push_error("No frame label found: " + frame_label)
			return

		var sub_info: Variant = _find_sub_symbol_at_frame(label_kf.index)
		if sub_info != null and _atlas_data.symbols.has(sub_info["name"]):
			add_by_symbol_indices(anim_name, sub_info["name"], indices, frame_rate, looped, x_pos, y_pos)
			if _anims.has(anim_name):
				var inst: AnimDataClass.ElementData = _anims[anim_name]["instance"]
				inst.transform = sub_info["transform"] * inst.transform
		else:
			var base: int = label_kf.index
			var offset_indices: Array[int] = []
			for idx in indices:
				offset_indices.append(idx + base)
			add_by_symbol_indices(anim_name, _atlas_data.main_symbol_name, offset_indices, frame_rate, looped, x_pos, y_pos)

	func _find_sub_symbol_at_frame(frame_idx: int):
		if _atlas_data == null:
			return null
		var main_sym: AnimDataClass.SymbolData = _atlas_data.symbols.get(_atlas_data.main_symbol_name)
		if main_sym == null or main_sym.timeline == null:
			return null
		for layer in main_sym.timeline.layers:
			var kf: AnimDataClass.KeyFrameData = layer.get_keyframe_at(frame_idx)
			if kf != null:
				for elem in kf.elements:
					if elem.is_symbol() and elem.symbol_params != null:
						return {"name": elem.symbol_params.name, "transform": elem.transform}
		return null

	func add_by_symbol_indices(anim_name: String, symbol_name: String, indices: Array[int], frame_rate: float = 0, looped: bool = true, x_pos: float = 0, y_pos: float = 0) -> void:
		if _atlas_data == null or not _atlas_data.symbols.has(symbol_name):
			push_error(symbol_name + " does not exist as a symbol")
			return

		var new_timeline := AnimDataClass.TimelineData.new()
		var new_layer := AnimDataClass.LayerData.new()
		new_layer.name = "Layer 1"

		for idx_i in range(indices.size()):
			var kf := AnimDataClass.KeyFrameData.new()
			kf.index = idx_i
			kf.duration = 1

			var elem := AnimDataClass.ElementData.new()
			elem.symbol_params = AnimDataClass.SymbolParamsData.new()
			elem.symbol_params.name = symbol_name
			elem.symbol_params.loop_type = AnimDataClass.LoopType.LOOP if looped else AnimDataClass.LoopType.PLAY_ONCE
			elem.symbol_params.first_frame = indices[idx_i]
			kf.elements.append(elem)
			new_layer.keyframes.append(kf)

		new_timeline.layers.append(new_layer)

		var new_symbol := AnimDataClass.SymbolData.new()
		new_symbol.name = anim_name
		new_symbol.timeline = new_timeline
		_atlas_data.symbols[anim_name] = new_symbol

		var element := AnimDataClass.ElementData.new()
		element.symbol_params = AnimDataClass.SymbolParamsData.new()
		element.symbol_params.name = anim_name
		element.symbol_params.loop_type = AnimDataClass.LoopType.LOOP if looped else AnimDataClass.LoopType.PLAY_ONCE
		element.transform = Transform2D(Vector2(1, 0), Vector2(0, 1), Vector2(x_pos, y_pos))

		_anims[anim_name] = {
			"instance": element,
			"framerate": frame_rate
		}

	func add_by_indices(anim_name: String, indices: Array[int], frame_rate: float = 0, looped: bool = true) -> void:
		if _atlas_data == null:
			return
		add_by_symbol_indices(anim_name, stage_instance.symbol_params.name, indices, frame_rate, looped)

	func get_frame_label(label_name: String) -> AnimDataClass.KeyFrameData:
		if _atlas_data == null:
			return null
		var main_sym: AnimDataClass.SymbolData = _atlas_data.symbols.get(_atlas_data.main_symbol_name)
		if main_sym == null or main_sym.timeline == null:
			return null
		for layer in main_sym.timeline.layers:
			var kf = layer.get_label(label_name)
			if kf != null:
				return kf
		return null

	func get_frame_labels() -> Array:
		var result: Array = []
		if _atlas_data == null:
			return result
		var main_sym: AnimDataClass.SymbolData = _atlas_data.symbols.get(_atlas_data.main_symbol_name)
		if main_sym == null or main_sym.timeline == null:
			return result
		for layer in main_sym.timeline.layers:
			for lbl_name in layer.labels.keys():
				result.append(layer.labels[lbl_name])
		result.sort_custom(func(a, b): return a.index < b.index)
		return result

	func go_to_frame_label(label_name: String) -> void:
		pause()
		var kf := get_frame_label(label_name)
		if kf != null:
			cur_frame = kf.index
		resume()

	func has_animation(anim_name: String) -> bool:
		return _anims.has(anim_name)

	func _starts_with_check(reference: String, query: String) -> bool:
		if query.ends_with("\\"):
			return reference == query.substr(0, query.length() - 1)
		return reference.begins_with(query)