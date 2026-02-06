class_name SparrowXML
extends RefCounted

var tag_name: String = ""
var attributes: Dictionary = {}
var children: Array = []
var text_content: String = ""

static func parse(xml_string: String):
	var parser := XMLParser.new()
	parser.open_buffer(xml_string.to_utf8_buffer())
	
	var root = null
	var stack: Array = []
	
	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var script = load("res://source/libs/Sparrowdot/src/sparrow/XML.gd")
				var node = script.new()
				node.tag_name = parser.get_node_name()
				
				for i in parser.get_attribute_count():
					node.attributes[parser.get_attribute_name(i)] = parser.get_attribute_value(i)
				
				if stack.size() > 0:
					stack[-1].children.append(node)
				else:
					root = node
				
				if not parser.is_empty():
					stack.append(node)
			
			XMLParser.NODE_ELEMENT_END:
				if stack.size() > 0:
					stack.pop_back()
			
			XMLParser.NODE_TEXT:
				if stack.size() > 0:
					stack[-1].text_content += parser.get_node_data().strip_edges()
	
	return root

static func parse_file(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open XML file: " + path)
		return null
	var content := file.get_as_text()
	file.close()
	return parse(content)

func get_attribute(attr_name: String, default: Variant = "") -> Variant:
	return attributes.get(attr_name, default)

func get_attribute_int(attr_name: String, default: int = 0) -> int:
	return int(attributes.get(attr_name, str(default)))

func get_attribute_float(attr_name: String, default: float = 0.0) -> float:
	return float(attributes.get(attr_name, str(default)))

func get_children_by_tag(tag: String) -> Array:
	var result: Array = []
	for child in children:
		if child.tag_name == tag:
			result.append(child)
	return result

func get_first_child_by_tag(tag: String):
	for child in children:
		if child.tag_name == tag:
			return child
	return null
