@tool
class_name Strumline
extends Node2D

const SparrowAtlasClass = preload("res://source/libs/Sparrowdot/src/sparrow/SparrowAtlas.gd")
const StrumNoteClass = preload("res://source/funkin/play/notes/StrumNote.gd")
const NoteClass = preload("res://source/funkin/play/notes/Note.gd")

var strums: Array = []
var notes: Array = []
var _note_atlas = null
var _strum_atlas = null
var player: int = 0

static func create(note_atlas, strum_atlas, p_player: int = 0):
	var script = load("res://source/funkin/play/notes/Strumline.gd")
	var strumline = script.new()
	strumline._note_atlas = note_atlas
	strumline._strum_atlas = strum_atlas
	strumline.player = p_player
	strumline._setup_strums()
	return strumline

func _setup_strums() -> void:
	for i in range(4):
		var strum = StrumNoteClass.create(_strum_atlas, i, player)
		strum.position.x = i * NoteClass.swag_width
		strums.append(strum)
		add_child(strum)

func add_note(note) -> void:
	notes.append(note)
	add_child(note)
	note.position.x = note.note_data * NoteClass.swag_width

func get_strum(direction: int):
	if direction >= 0 and direction < strums.size():
		return strums[direction]
	return null

func press_strum(direction: int) -> void:
	var strum = get_strum(direction)
	if strum and strum.get_state() != StrumNoteClass.State.CONFIRM:
		strum.play_pressed()

func confirm_strum(direction: int) -> void:
	var strum = get_strum(direction)
	if strum:
		strum.play_confirm()

func release_strum(direction: int) -> void:
	var strum = get_strum(direction)
	if strum:
		strum.play_static()

func get_width() -> float:
	return NoteClass.swag_width * 4
