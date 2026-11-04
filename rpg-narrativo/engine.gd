extends RefCounted

const SAVE := "user://campanha.json"
const BACKUP := "user://campanha.backup.json"
const VERSION := 1
var story: Dictionary
var state: Dictionary = {}

func _init() -> void:
	var file := FileAccess.open("res://story.json", FileAccess.READ)
	if file:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			story = parsed

func new_game(character_name: String, character_class: String) -> bool:
	if character_name.strip_edges().is_empty():
		return false
	state = {"version": VERSION, "name": character_name.strip_edges(), "class": character_class, "node": "start", "trust": 0, "credits": 5, "stability": 5, "insight": 0, "history": []}
	return save_game()

func valid_save(candidate) -> bool:
	if not candidate is Dictionary:
		return false
	for key in ["version", "name", "class", "node", "trust", "credits", "stability", "insight", "history"]:
		if not candidate.has(key):
			return false
	if candidate.version != VERSION or not candidate.name is String or not candidate["class"] is String or not candidate.node is String or not candidate.history is Array or not story.has(candidate.node):
		return false
	for key in ["trust", "credits", "stability", "insight"]:
		if typeof(candidate[key]) not in [TYPE_INT, TYPE_FLOAT]:
			return false
	return true

func _read(path: String):
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	return JSON.parse_string(file.get_as_text())

func save_game() -> bool:
	if not valid_save(state):
		return false
	var old = _read(SAVE)
	if valid_save(old):
		var backup := FileAccess.open(BACKUP, FileAccess.WRITE)
		if not backup:
			return false
		backup.store_string(JSON.stringify(old))
		backup.close()
	var tmp := SAVE + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(state))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(SAVE)) == OK

func load_game() -> bool:
	var saved = _read(SAVE)
	if not valid_save(saved):
		saved = _read(BACKUP)
	if not valid_save(saved):
		return false
	state = saved
	return true

func choose(index: int) -> bool:
	if not valid_save(state):
		return false
	var choices: Array = story[state.node].choices
	if index < 0 or index >= choices.size():
		return false
	var choice: Dictionary = choices[index]
	if not story.has(choice.next):
		return false
	var previous := state.duplicate(true)
	for key in choice.effects:
		state[key] += choice.effects[key]
	state.history.append(choice.memory)
	state.node = choice.next
	if not save_game():
		state = previous
		return false
	return true
