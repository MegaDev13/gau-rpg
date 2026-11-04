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
	# Existing saves lack portrait_asset and retain their original generated faces.
	people.artisan["portrait_asset"] = "artisan_v1"
	people.researcher["portrait_asset"] = "researcher_v1"
	people.leader["portrait_asset"] = "leader_v1"
	people.merchant["portrait_asset"] = "merchant_v1"
	people.resident["portrait_asset"] = "resident_v1"
	people.community["portrait_asset"] = "community_v1"
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
	if candidate.has("profile"):
		if not candidate.profile is Dictionary or not candidate.profile.has_all(["attributes", "hp", "max_hp", "bandages", "last_scout_day"]):
			return false
		var p: Dictionary = candidate.profile
		if not p.attributes is Dictionary or not p.attributes.has_all(["forca", "agilidade", "vigor", "intelecto", "percepcao", "vontade", "presenca", "tecnica", "sintonia"]):
			return false
		for key in ["hp", "max_hp", "bandages", "last_scout_day"]:
			if typeof(p[key]) not in [TYPE_INT, TYPE_FLOAT]:
				return false
		for key in p.attributes:
			if typeof(p.attributes[key]) not in [TYPE_INT, TYPE_FLOAT]:
				return false
		if p.hp < 0 or p.hp > p.max_hp or p.max_hp < 1 or p.bandages < 0:
			return false
	if candidate.has("local_world"):
		if not candidate.local_world is Dictionary or not candidate.local_world.has_all(["supplies", "pressure"]):
			return false
		for key in ["supplies", "pressure"]:
			if typeof(candidate.local_world[key]) not in [TYPE_INT, TYPE_FLOAT] or candidate.local_world[key] < 0:
				return false
	if candidate.has("fort"):
		if not candidate.fort is Dictionary or not candidate.fort.has_all(["layout", "supplies", "hp", "wave", "results"]):
			return false
		var fort: Dictionary = candidate.fort
		if not fort.layout is Array or fort.layout.size() != 16 or not fort.results is Array:
			return false
		for tile in fort.layout:
			if tile not in ["", "arcana", "steam"]:
				return false
		for key in ["supplies", "hp", "wave"]:
			if typeof(fort[key]) not in [TYPE_INT, TYPE_FLOAT]:
				return false
		if fort.supplies < 0 or fort.hp < 0 or fort.hp > 10 or fort.wave < 1:
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
	advance_world(int(previous.day))
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

## One optional conversation per character; NPCs keep agency and do not grant romance.
func converse(role: String) -> bool:
	if not valid(state) or not state.people.has(role):
		return false
	var person: Dictionary = state.people[role]
	for memory in person.memories:
		if memory.get("kind", "") == "conversation":
			return false
	var previous := state.duplicate(true)
	state.day += 1
	person.trust += 1
	var event_id := "evt_%s" % (state.history.size() + 1)
	var description: String = "conversou com %s sobre seus objetivos" % person.name
	person.memories.append({"event_id":event_id,"day":state.day,"type":"testemunhado","kind":"conversation","summary":description})
	state.history.append({"id":event_id,"day":state.day,"city":state.city,"action":"conversation","description":description,"effects":{"time":1,"trust":1}})
	advance_world(int(previous.day))
	if not save_game():
		state = previous
		return false
	return true

func can_converse(role: String) -> bool:
	if not valid(state) or not state.people.has(role):
		return false
	for memory in state.people[role].memories:
		if memory.get("kind", "") == "conversation":
			return false
	return true

func portrait_variant(role: String) -> int:
	return absi(hash("veyrath-portrait-v1:%s:%s" % [int(state.seed), role]))

## Fortification values are lazily introduced, preserving pre-defense saves.
func fort_state() -> Dictionary:
	if state.has("fort") and state.fort is Dictionary:
		return state.fort.duplicate(true)
	var slots: Array = []
	slots.resize(16)
	slots.fill("")
	return {"layout":slots,"supplies":8,"hp":10,"wave":1,"results":[]}

func fort_build(index: int, kind: String) -> bool:
	if not valid(state) or index < 0 or index >= 16 or kind not in ["arcana", "steam"]:
		return false
	var fort := fort_state()
	var cost := 2 if kind == "arcana" else 3
	if fort.layout.size() != 16 or fort.layout[index] != "" or fort.supplies < cost:
		return false
	var previous := state.duplicate(true)
	fort.layout[index] = kind
	fort.supplies -= cost
	state.fort = fort
	if not save_game():
		state = previous
		return false
	return true

func fort_repair() -> bool:
	if not valid(state):
		return false
	var fort := fort_state()
	if fort.hp >= 10 or fort.supplies < 1:
		return false
	var previous := state.duplicate(true)
	fort.hp = mini(10, int(fort.hp) + 3)
	fort.supplies -= 1
	state.fort = fort
	if not save_game():
		state = previous
		return false
	return true

func fort_finish(expected_wave: int, won: bool, remaining_hp: int, escaped: int) -> bool:
	if not valid(state):
		return false
	var fort := fort_state()
	if fort.wave != expected_wave or remaining_hp < 0 or remaining_hp > fort.hp or escaped < 0 or (won and remaining_hp == 0) or (not won and remaining_hp > 0):
		return false
	var previous := state.duplicate(true)
	fort.hp = remaining_hp
	fort.supplies += 3 if won else 2
	fort.wave += 1
	state.day += 1
	var description := "defendeu o posto contra a onda %s" % expected_wave if won else "o posto caiu durante a onda %s" % expected_wave
	var event_id := "evt_%s" % (state.history.size() + 1)
	fort.results.append({"wave":expected_wave,"won":won,"hp":remaining_hp,"escaped":escaped,"event_id":event_id})
	state.fort = fort
	state.history.append({"id":event_id,"day":state.day,"city":state.city,"action":"fort_defense","description":description,"effects":{"supplies":3 if won else 2,"base_hp":remaining_hp}})
	state.news.append({"event_id":event_id,"day":state.day,"text":"A defesa local resistiu à investida." if won else "A defesa local foi rompida; reparos foram iniciados.","source":"Gazeta local"})
	advance_world(int(previous.day))
	if not save_game():
		state = previous
		return false
	return true

## The profile is lazily initialized to preserve the pre-existing version-1 saves.
func profile() -> Dictionary:
	if state.has("profile") and state.profile is Dictionary:
		return state.profile.duplicate(true)
	var attributes := {"forca":10,"agilidade":10,"vigor":10,"intelecto":10,"percepcao":10,"vontade":10,"presenca":10,"tecnica":10,"sintonia":10}
	match state.origin:
		"apprentice": attributes.tecnica = 14
		"scholar":
			attributes.intelecto = 14
			attributes.sintonia = 12
		"community":
			attributes.vigor = 12
			attributes.percepcao = 14
		"merchant": attributes.presenca = 14
	return {"attributes":attributes,"hp":10,"max_hp":10,"bandages":2,"last_scout_day":-99}

func modifier(score: int) -> int:
	return floori((score - 10) / 2.0)

func advance_world(previous_day: int) -> void:
	var old_tick := floori(previous_day / 3.0)
	var new_tick := floori(int(state.day) / 3.0)
	for tick in range(old_tick + 1,new_tick + 1):
		var sim: Dictionary = state.get("local_world", {"supplies":5,"pressure":0}).duplicate(true)
		var description: String
		if int(state.risk) >= 4:
			sim.pressure += 1
			sim.supplies = maxi(0,int(sim.supplies)-1)
			description = "O risco arcano pressiona as reservas locais; a cidade consome suprimentos de contenção."
		else:
			sim.supplies += 1
			description = "A oficina e os moradores recuperam parte dos suprimentos da cidade."
		state.local_world = sim
		var event_id := "evt_%s" % (state.history.size() + 1)
		state.history.append({"id":event_id,"day":state.day,"city":state.city,"action":"world_tick","description":description,"effects":{"supplies":sim.supplies,"pressure":sim.pressure,"tick":tick}})
		state.news.append({"event_id":event_id,"day":state.day,"text":description,"source":"Gazeta local"})

func rest() -> bool:
	if not valid(state):
		return false
	var p := profile()
	var max_flow := 3 if state.origin == "scholar" else 2
	if p.hp >= p.max_hp and state.flow >= max_flow and state.fatigue <= 0:
		return false
	var previous := state.duplicate(true)
	p.hp = mini(int(p.max_hp),int(p.hp)+2)
	state.flow = mini(max_flow,int(state.flow)+1)
	state.fatigue = maxi(0,int(state.fatigue)-1)
	state.day += 1
	state.profile = p
	var id := "evt_%s" % (state.history.size()+1)
	state.history.append({"id":id,"day":state.day,"city":state.city,"action":"rest","description":"descansou e recuperou forças","effects":{"hp":p.hp,"flow":state.flow}})
	advance_world(int(previous.day))
	if not save_game():
		state = previous
		return false
	return true

func use_bandage() -> bool:
	if not valid(state):
		return false
	var p := profile()
	if p.bandages <= 0 or p.hp >= p.max_hp:
		return false
	var previous := state.duplicate(true)
	p.bandages -= 1
	p.hp = mini(int(p.max_hp),int(p.hp)+3)
	state.profile = p
	var id := "evt_%s" % (state.history.size()+1)
	state.history.append({"id":id,"day":state.day,"city":state.city,"action":"bandage","description":"usou um curativo","effects":{"hp":p.hp,"bandages":-1}})
	if not save_game():
		state = previous
		return false
	return true

func scout() -> bool:
	if not valid(state):
		return false
	var p := profile()
	if p.hp <= 0 or int(state.day) - int(p.last_scout_day) < 3:
		return false
	var previous := state.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("veyrath-scout-v1:%s:%s:%s" % [int(state.seed),int(state.day),state.history.size()])
	var roll := rng.randi_range(1,20)
	var bonus := modifier(int(p.attributes.percepcao))
	var success := roll + bonus >= 12
	state.day += 1
	p.last_scout_day = state.day
	if success:
		p.bandages += 1
	else:
		p.hp = maxi(0,int(p.hp)-2)
	state.profile = p
	var id := "evt_%s" % (state.history.size()+1)
	var desc := "encontrou um curativo em uma inspeção local" if success else "feriu-se ao inspecionar a área"
	state.history.append({"id":id,"day":state.day,"city":state.city,"action":"scout","description":desc,"effects":{"d20":roll,"bonus":bonus,"difficulty":12,"success":success}})
	advance_world(int(previous.day))
	if not save_game():
		state = previous
		return false
	return true

func discovered_dragon() -> bool:
	if state.node == "dragon":
		return true
	for event in state.history:
		if event.get("action", "") in ["quarry", "quarry_work", "quarry_river", "evidence_quarry"]:
			return true
	return false

func normalized(value: String) -> String:
	var t := value.strip_edges().to_lower()
	for pair in [["á","a"],["à","a"],["â","a"],["ã","a"],["é","e"],["ê","e"],["í","i"],["ó","o"],["ô","o"],["õ","o"],["ú","u"],["ç","c"]]:
		t = t.replace(pair[0],pair[1])
	return t

func interpret_action(sentence: String) -> Dictionary:
	if not valid(state):
		return {}
	var text := normalized(sentence)
	if text in ["descansar", "repousar", "quero descansar"]:
		return {"kind":"rest","description":"Descansar um dia para recuperar forças e Fluxo."}
	if text in ["usar curativo", "aplicar curativo"]:
		return {"kind":"bandage","description":"Usar um curativo para recuperar vida."}
	if text in ["investigar a area", "explorar a area", "reconhecer a area"]:
		return {"kind":"scout","description":"Inspecionar a área: teste de Percepção, dificuldade 12; risco de ferimento."}
	for role in world.roles:
		var person_name: String = normalized(state.people[role.id].name)
		if text == "conversar com " + person_name or text == "falar com " + person_name:
			return {"kind":"talk","role":role.id,"description":"Conversar com " + state.people[role.id].name + "."}
	var options: Array = story[state.node].choices
	for i in range(options.size()):
		if text == "escolha %s" % (i+1) or text == "opcao %s" % (i+1):
			if available(options[i]):
				return {"kind":"choice","index":i,"description":options[i].label}
	return {}
