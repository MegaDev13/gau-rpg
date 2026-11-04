extends RefCounted

const SAVE := "user://veyrath-campanha-v1.json"
const BACKUP := "user://veyrath-campanha-v1.backup.json"
const VERSION := 1
var world: Dictionary = {}
var story: Dictionary = {}
var state: Dictionary = {}

func _init() -> void:
	world = read_resource("res://veyrath/world.json")
	story = read_resource("res://veyrath/story.json")

func read_resource(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var parser := JSON.new()
	if parser.parse(f.get_as_text()) != OK or not parser.data is Dictionary:
		return {}
	return parser.data

func find_entry(entries: Array, id: String) -> Dictionary:
	for entry in entries:
		if entry.id == id:
			return entry
	return {}

func new_game(player_name: String, origin_id: String, city_id: String, seed_value: int = -1) -> bool:
	var origin := find_entry(world.origins, origin_id)
	var city := find_entry(world.cities, city_id)
	if player_name.strip_edges().is_empty() or origin.is_empty() or city.is_empty():
		return false
	var rng := RandomNumberGenerator.new()
	if seed_value < 0:
		rng.randomize()
		seed_value = int(rng.randi())
	rng.seed = seed_value
	var names: Array = world.names.duplicate()
	var people := {}
	for role in world.roles:
		var pos := rng.randi_range(0, names.size() - 1)
		var person_name: String = names.pop_at(pos)
		people[role.id] = {"id":role.id, "name":person_name, "job":role.job, "goal":role.goal, "age":"adulto", "home":city.id, "trust":1 if origin_id == "community" and role.id == "community" else 0, "memories":[]}
	state = {"version":VERSION,"seed":seed_value,"name":player_name.strip_edges(),"origin":origin.id,"city":city.id,"node":"start","day":1,"credits":origin.credits,"flow":origin.flow,"fatigue":0,"risk":3,"evidence":0,"habitat":0,"people":people,"history":[],"news":[]}
	return save_game()

func valid(candidate) -> bool:
	if not candidate is Dictionary:
		return false
	for key in ["version","seed","name","origin","city","node","day","credits","flow","fatigue","risk","evidence","habitat","people","history","news"]:
		if not candidate.has(key):
			return false
	if candidate.version != VERSION or not candidate.name is String or not candidate.origin is String or not candidate.city is String or not candidate.node is String:
		return false
	if not story.has(candidate.node) or find_entry(world.origins,candidate.origin).is_empty() or find_entry(world.cities,candidate.city).is_empty():
		return false
	if not candidate.people is Dictionary or not candidate.history is Array or not candidate.news is Array:
		return false
	for key in ["seed","day","credits","flow","fatigue","risk","evidence","habitat"]:
		if typeof(candidate[key]) not in [TYPE_INT, TYPE_FLOAT]:
			return false
	for role in world.roles:
		if not candidate.people.has(role.id) or not candidate.people[role.id] is Dictionary:
			return false
		var person: Dictionary = candidate.people[role.id]
		if not person.has_all(["name","job","goal","trust","memories"]) or not person.memories is Array:
			return false
	return true

func read_save(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return null
	var parser := JSON.new()
	if parser.parse(f.get_as_text()) != OK:
		return null
	return parser.data

func save_game() -> bool:
	if not valid(state):
		return false
	var old = read_save(SAVE)
	if valid(old):
		var backup := FileAccess.open(BACKUP, FileAccess.WRITE)
		if not backup:
			return false
		backup.store_string(JSON.stringify(old))
		backup.flush()
		if backup.get_error() != OK:
			return false
		backup.close()
	var tmp := SAVE + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if not f:
		return false
	f.store_string(JSON.stringify(state))
	f.flush()
	var error := f.get_error()
	f.close()
	if error != OK:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp),ProjectSettings.globalize_path(SAVE)) == OK

func load_game() -> bool:
	var saved = read_save(SAVE)
	if not valid(saved):
		saved = read_save(BACKUP)
	if not valid(saved):
		return false
	state = saved
	return true

func available(choice: Dictionary) -> bool:
	var req: Dictionary = choice.get("requirements", {})
	if req.has("origin") and state.origin != req.origin:
		return false
	for key in ["flow", "credits"]:
		if req.has(key) and state[key] < req[key]:
			return false
	if req.has("credits_or_origin") and state.origin != "apprentice" and state.credits < req.credits_or_origin:
		return false
	if req.has("community_or_evidence") and state.people.community.trust < req.community_or_evidence and state.evidence < req.community_or_evidence:
		return false
	return true

func choose(index: int) -> bool:
	if not valid(state):
		return false
	var choices: Array = story[state.node].choices
	if index < 0 or index >= choices.size():
		return false
	var choice: Dictionary = choices[index]
	if not available(choice) or not story.has(choice.next):
		return false
	var previous := state.duplicate(true)
	for key in choice.effects:
		if key == "time":
			state.day += choice.effects[key]
		elif key == "credits_or_origin":
			if state.origin != "apprentice":
				state.credits += choice.effects[key]
		else:
			state[key] += choice.effects[key]
	var role: String = choice.npc
	state.people[role].trust += choice.trust
	var event_id := "evt_%s" % (state.history.size() + 1)
	var event := {"id":event_id,"day":state.day,"city":state.city,"action":choice.id,"description":choice.memory,"effects":choice.effects.duplicate(true)}
	state.history.append(event)
	state.people[role].memories.append({"event_id":event_id,"day":state.day,"type":"testemunhado","summary":choice.memory})
	state.news.append({"event_id":event_id,"day":state.day,"text":choice.news,"source":"Gazeta local"})
	state.node = choice.next
	if not save_game():
		state = previous
		return false
	return true

func render(value: String) -> String:
	var city := find_entry(world.cities,state.city)
	var origin := find_entry(world.origins,state.origin)
	var values := {"city":city.name,"industry":city.industry,"water":city.water,"origin":origin.name}
	for role in world.roles:
		values[role.id] = state.people[role.id].name
	return value.format(values)

func reaction() -> String:
	var artisan: Dictionary = state.people.artisan
	var community: Dictionary = state.people.community
	var a := "%s recorda sua ajuda à oficina." % artisan.name if artisan.trust > 0 else "%s ainda não tem motivos pessoais para confiar em você." % artisan.name
	var b := "%s recebeu bem sua atenção às famílias." % community.name if community.trust > 0 else "%s mantém distância enquanto avalia suas decisões." % community.name
	return a + "\n\n" + b
