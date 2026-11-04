extends RefCounted
## Rules and clocks are local. Text is an output of transitions, never an instruction.
const VERSION := 1
const CAST := {
	"maker": ["workshop",0], "assistant": ["workshop",3], "witness": ["fort",1],
	"boat": ["river",1], "clerk": ["rail",2], "registrar": ["archive",0],
	"delegate": ["council",0], "guild": ["market",0], "scholar": ["lab",0],
	"warden": ["quarry",0], "scout": ["quarry",3], "assessor": ["archive",2],
	"custodian": ["temple",1], "inspector": ["fort",0], "carrier": ["rail",1], "keeper": ["lab",2],
}
var catalog: Dictionary
var expansion
var definitions := {}

func _init(world) -> void:
	expansion = world
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://veyrath/chronicles/catalog.json"))
	for definition in catalog.arcs:
		definitions[definition.id] = definition

func create(seed_value: int, city_id: String, day: int) -> Dictionary:
	var city: Dictionary = expansion.city(city_id,seed_value)
	var sites: Array = expansion.places(city,seed_value)
	var people := {}
	var used := {}
	for role in CAST:
		var preferred: Array = CAST[role]
		var person: Dictionary = {}
		for site in sites:
			if site.kind == preferred[0]:
				person = expansion.person(site,int(preferred[1]),seed_value)
				if used.has(person.id):
					person = {}
				break
		if person.is_empty():
			var start: int = expansion.number(seed_value,"cast:"+role,sites.size())
			for offset in range(sites.size()*4):
				var site: Dictionary = sites[(start+offset/4)%sites.size()]
				var candidate: Dictionary = expansion.person(site,(int(preferred[1])+offset)%4,seed_value)
				if not used.has(candidate.id):
					person = candidate
					break
		used[person.id] = true
		people[role] = person
	var lineage: int = expansion.number(seed_value,"chronicle-lineage",23)
	var surname: String = expansion.catalog.regions[city.region].suffix[lineage%6]
	for item in [["elder",80,0,"guardiã da casa de leitura"],["caretaker",51,7,"responsável pelos reparos"],["heir",26,14,"herdeiro e leitor"]]:
		var name: String = expansion.GIVEN[(lineage+int(item[2]))%expansion.GIVEN.size()]
		people[item[0]] = {"id":city_id+"/lineage/"+item[0],"name":name+" "+surname,"job":item[3],
			"people":"Humano","age":int(item[1]),"pin":lineage+int(item[2])}
	people.dragon = {"id":city_id+"/orunide","name":["Saar do Limiar","Iriam da Pedra","Teren do Estuário"][lineage%3],
		"job":"dragão sapiente Orúnide","people":"Orúnide","pin":lineage}
	people.elder.parents = []
	people.caretaker.parents = [people.elder.id]
	people.heir.parents = [people.caretaker.id]
	for role in catalog.profiles:
		var profile: Array = catalog.profiles[role]
		people[role].dramatic = {"desire":profile[0],"fear":profile[1],"stance":profile[2]}
	var states := {}
	for arc in catalog.arcs:
		states[arc.id] = {"phase":-1,"due":day+int(arc.start)-1,"outcome":"","tracked":false}
	var journal := {"version":VERSION,"city":city_id,"origin_day":day,"arcs":states,"cast":people,
		"flags":{"cause_diverted":expansion.number(seed_value,"ledger-cause",2) == 1},"known":{},"events":[],"actions":{}}
	advance(journal,day)
	return journal

func valid(journal) -> bool:
	if not journal is Dictionary or not journal.has_all(["version","city","origin_day","arcs","cast","flags","known","events","actions"]):
		return false
	if journal.version != VERSION or not journal.city is String or not journal.arcs is Dictionary or not journal.cast is Dictionary:
		return false
	if not journal.flags is Dictionary or not journal.known is Dictionary or not journal.actions is Dictionary or not journal.events is Array:
		return false
	for arc in catalog.arcs:
		var entry = journal.arcs.get(arc.id)
		if not entry is Dictionary or not entry.has_all(["phase","due","outcome","tracked"]):
			return false
		if typeof(entry.phase) not in [TYPE_INT,TYPE_FLOAT] or typeof(entry.due) not in [TYPE_INT,TYPE_FLOAT] or not entry.outcome is String:
			return false
		if entry.phase < -1 or entry.phase >= arc.stages.size() or entry.due < 1:
			return false
		for role in arc.cast:
			var person = journal.cast.get(role)
			if not person is Dictionary or not person.has_all(["id","name","job","people","pin"]):
				return false
	for entry in journal.events:
		if not entry is Dictionary or not entry.has_all(["id","arc","day","text"]):
			return false
	return true

func render(journal: Dictionary, prose: String) -> String:
	var names := {}
	for role in journal.cast:
		names[role] = journal.cast[role].name
	return prose.format(names)

func append_event(journal: Dictionary, arc_id: String, id: String, day: int, prose: String) -> void:
	journal.events.append({"id":arc_id+":"+id,"arc":arc_id,"day":day,"text":render(journal,prose)})

func matches(flags: Dictionary, conditions: Dictionary) -> bool:
	for key in conditions:
		if flags.get(key) != conditions[key]:
			return false
	return true

func advance(journal: Dictionary, day: int) -> void:
	# A long caravan journey processes cross-arc effects by actual due date.
	while true:
		var next_arc := ""
		var due := day+1
		for definition in catalog.arcs:
			var entry: Dictionary = journal.arcs[definition.id]
			if entry.outcome.is_empty() and int(entry.due) < due:
				next_arc = definition.id
				due = int(entry.due)
		if next_arc.is_empty():
			return
		var arc: Dictionary = definitions[next_arc]
		var current: Dictionary = journal.arcs[next_arc]
		if current.phase < 0:
			current.phase = 0
			current.due = due + int(arc.stages[0].days)
			append_event(journal,next_arc,"abertura",due,arc.cause)
			continue
		var phase := int(current.phase)
		var stage: Dictionary = arc.stages[phase]
		for rule in stage.routes:
			if not matches(journal.flags,rule.when):
				continue
			journal.flags.merge(rule.sets,true)
			if rule.sets.get("elder_dead",false):
				journal.cast.elder.died_day = due
			append_event(journal,next_arc,"fase-%d" % phase,due,rule.text)
			if rule.outcome == "próxima":
				current.phase = phase + 1
				current.due = due + int(arc.stages[phase+1].days)
			else:
				current.outcome = rule.outcome
			break

func visible(journal: Dictionary, arc_id: String) -> Dictionary:
	if not definitions.has(arc_id):
		return {}
	var entry: Dictionary = journal.arcs[arc_id]
	if entry.phase < 0:
		return {}
	return definitions[arc_id]

func block_reason(journal: Dictionary, arc_id: String, action: Dictionary, credits: int, flow: int, city_id: String) -> String:
	if city_id != journal.city:
		return "Requer presença no assentamento."
	if journal.actions.has(arc_id+":"+action.id):
		return "Decisão registrada."
	if not action.need.is_empty() and not journal.known.has(action.need):
		return "Investigue a fonte anterior primeiro."
	if action.participant == "elder" and journal.flags.get("elder_dead",false):
		return "A interlocutora morreu."
	if credits < action.cost:
		return "Créditos insuficientes."
	if flow < action.flow:
		return "Fluxo insuficiente."
	return ""

func perform(journal: Dictionary, arc_id: String, phase: int, action_id: String, day: int, credits: int, flow: int, city_id: String) -> Dictionary:
	var definition := visible(journal,arc_id)
	if definition.is_empty():
		return {}
	var current: Dictionary = journal.arcs[arc_id]
	if current.phase != phase or not current.outcome.is_empty() or int(current.due) <= day:
		return {}
	for action in definition.stages[phase].actions:
		if action.id != action_id or not block_reason(journal,arc_id,action,credits,flow,city_id).is_empty():
			continue
		journal.actions[arc_id+":"+action.id] = day
		journal.flags.merge(action.sets,true)
		if not action.clue.is_empty():
			journal.known[action.clue] = {"day":day,"source":action.participant,"arc":arc_id}
		append_event(journal,arc_id,"decisao-"+action.id,day,action.text)
		return action
	return {}

func clue_text(journal: Dictionary, id: String) -> String:
	if not journal.known.has(id) or not catalog.clues.has(id):
		return ""
	var clue: Dictionary = catalog.clues[id]
	var prose: String = clue.get("alternate",clue.text) if journal.flags.cause_diverted else clue.text
	return "%s  ·  %s\n%s" % [clue.label,clue.kind,prose]

func goal_for(journal: Dictionary, person: Dictionary) -> String:
	if journal.cast.assistant.id == person.id:
		if journal.flags.get("independent_artisan",false):
			return "Manter o ateliê independente e cumprir a encomenda do laboratório."
		if not journal.arcs.apprentice.outcome.is_empty():
			return "Manter a autoria nos contratos da oficina."
	if journal.cast.boat.id == person.id and journal.flags.get("supply_suspended",false):
		return "Recorrer da suspensão do contrato de travessia."
	for role in journal.cast:
		if journal.cast[role].id == person.id:
			return str(journal.cast[role].get("dramatic",{}).get("desire",person.get("goal","")))
	return str(person.get("goal",""))
