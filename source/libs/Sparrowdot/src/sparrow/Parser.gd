class_name SparrowParser
extends RefCounted

const XML = preload("res://source/libs/Sparrowdot/src/sparrow/XML.gd")

class FrameData:
	var name: String
	var x: int
	var y: int
	var width: int
	var height: int
	var frame_x: int
	var frame_y: int
	var frame_width: int
	var frame_height: int
	var is_trimmed: bool
	var rotated: bool = false
	
	func get_region() -> Rect2i:
		return Rect2i(x, y, width, height)
	
	func get_logical_size() -> Vector2i:
		if rotated:
			return Vector2i(height, width)
		return Vector2i(width, height)
	
	func get_margin() -> Rect2i:
		if not is_trimmed:
			return Rect2i(0, 0, 0, 0)
		var ls := get_logical_size()
		var left := -frame_x
		var top := -frame_y
		var right := frame_width - ls.x - left
		var bottom := frame_height - ls.y - top
		return Rect2i(left, top, right, bottom)
	
	func get_original_size() -> Vector2i:
		if is_trimmed:
			return Vector2i(frame_width, frame_height)
		if rotated:
			return Vector2i(height, width)
		return Vector2i(width, height)

class ParseResult:
	var image_path: String
	var frames: Array
	var frames_by_name: Dictionary

static func parse(xml_path: String):
	var xml = XML.parse_file(xml_path)
	if xml == null:
		return null
	
	return parse_xml(xml)

static func parse_xml(xml):
	if xml.tag_name != "TextureAtlas":
		push_error("Invalid Sparrow atlas: root element must be TextureAtlas")
		return null
	
	var result := ParseResult.new()
	result.image_path = xml.get_attribute("imagePath", "")
	result.frames = []
	result.frames_by_name = {}
	
	for subtexture in xml.get_children_by_tag("SubTexture"):
		var frame := FrameData.new()
		frame.name = subtexture.get_attribute("name", "")
		frame.x = subtexture.get_attribute_int("x")
		frame.y = subtexture.get_attribute_int("y")
		frame.width = subtexture.get_attribute_int("width")
		frame.height = subtexture.get_attribute_int("height")
		frame.rotated = subtexture.get_attribute("rotated", "false") == "true"
		
		if subtexture.attributes.has("frameX"):
			frame.is_trimmed = true
			frame.frame_x = subtexture.get_attribute_int("frameX")
			frame.frame_y = subtexture.get_attribute_int("frameY")
			frame.frame_width = subtexture.get_attribute_int("frameWidth")
			frame.frame_height = subtexture.get_attribute_int("frameHeight")
		else:
			frame.is_trimmed = false
			frame.frame_x = 0
			frame.frame_y = 0
			var ls := frame.get_logical_size()
			frame.frame_width = ls.x
			frame.frame_height = ls.y
		
		result.frames.append(frame)
		result.frames_by_name[frame.name] = frame
	
	return result

static func extract_animation_name(frame_name: String) -> String:
	var regex := RegEx.new()
	regex.compile("^(.+?)\\d{4}$")
	var result := regex.search(frame_name)
	if result:
		return result.get_string(1)
	return frame_name

static func group_frames_by_animation(frames: Array) -> Dictionary:
	var animations: Dictionary = {}
	
	for frame in frames:
		var anim_name := extract_animation_name(frame.name)
		if not animations.has(anim_name):
			animations[anim_name] = []
		animations[anim_name].append(frame)
	
	return animations
