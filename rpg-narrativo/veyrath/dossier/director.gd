extends RefCounted
## The imported prose is display data. Only the typed rules below can alter a campaign.
const VERSION := 1
const Civic = preload("res://veyrath/dossier/civic.gd")
const FOLDER := "res://veyrath/dossier/"
const METERS := {"supply":[0,100],"health":[0,100],"river":[0,100],"habitat":[0,100],
	"legitimacy":[0,100],"tension":[0,100],"route":[-4,9],"damage":[0,10]}
const SPECIALS := ["","regency","constitutional_vote","recognize_title","talk","pause","date","cohabit",
	"friends","pressure","apart","separate","marriage","union","citizenship_vote","civil_rights",
	"dragon_consent","dragon_refusal","war_order","ratify","truce"]
var expansion
var civic: Civic
var families: Array
var scenarios := {}
var sagas := {}
var rules: Dictionary

func _init(world) -> void:
	expansion = world
	civic = Civic.new(world)
	families = read_json("families")
	for row in read_json("scenarios"):
		scenarios[row.id] = row
	for row in read_json("sagas"):
		sagas[row.id] = row
	rules = read_json("rules")

func read_json(name: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(FOLDER+name+".json"))

func create(seed_value: int, day: int) -> Dictionary:
	return {"version":VERSION,"seed":seed_value,"origin_day":day,"stories":{},"places":{},"actors":{},
		"known":{},"relationships":{},"unions":{},"observed":{},"legacy_flags":{}}

func valid(book) -> bool:
	if not book is Dictionary or not book.has_all(["version","seed","origin_day","stories","places","actors","known","relationships","unions","observed"]):
		return false
	if book.version != VERSION or not is_integer(book.seed) or not is_integer(book.origin_day):
		return false
	if book.has("civic") and not civic.valid(book.civic):
		return false
	for key in ["stories","places","actors","known","relationships","unions","observed"]:
		if not book[key] is Dictionary:
			return false
	for id in book.places:
		var place = book.places[id]
		if not place is Dictionary or not place.has_all(["marks","government","war","flux","duty","civil","deaths","origin_supply"]):
			return false
		if not place.marks is Dictionary or not place.war in ["calm","mobilized","engaged","truce","peace"]:
			return false
		for key in ["flux","duty","civil","deaths","origin_supply"]:
			if not is_integer(place.get(key)) or place[key] < 0:
				return false
		if place.civil > 2 or place.origin_supply > 100:
			return false
		for key in METERS:
			if not is_integer(place.get(key)) or place[key] < METERS[key][0] or place[key] > METERS[key][1]:
				return false
	for id in book.stories:
		var story = book.stories[id]
		if not story is Dictionary or not story.has_all(["id","source","city","stage","due","opened","history","chosen","outcome","cast"]):
			return false
		if story.id != id or not book.places.has(story.city) or not is_integer(story.stage) or not is_integer(story.due) or not is_integer(story.opened):
			return false
		if not story.history is Array or not story.cast is Array or not story.chosen is Dictionary or not story.outcome is String:
			return false
		if not rules.sagas.has(story.source) and not rules.seeds.has(story.source):
			return false
		if story.stage < 0 or story.stage >= count_acts(story.source) or story.due < story.opened:
			return false
		for actor in story.cast:
			if not actor is Dictionary or not actor.has_all(["id","role"]) or not book.actors.has(actor.id):
				return false
	return true

func is_integer(value) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and int(value) == value

func setup_place(book: Dictionary, city: Dictionary) -> Dictionary:
	if not book.places.has(city.id):
		book.places[city.id] = {
			"supply":int(city.supply),"origin_supply":int(city.supply),"health":50,"river":55,"habitat":55,"legitimacy":45,
			"tension":32,"route":0,"damage":0,"marks":{},"government":"inicial",
			"war":"calm","flux":4,"civil":0,"deaths":0,"duty":0,
		}
	return book.places[city.id]

func source(source_id: String) -> Dictionary:
	return sagas.get(source_id,scenarios.get(source_id,{}))

func count_acts(source_id: String) -> int:
	return sagas[source_id].acts.size() if sagas.has(source_id) else 1

func act_for(story: Dictionary) -> Dictionary:
	if sagas.has(story.source):
		return sagas[story.source].acts[int(story.stage)]
	var row: Dictionary = scenarios[story.source]
	return {"title":row.title,"scene":row.opening,"options":row.options}

func plan_for(story: Dictionary) -> Dictionary:
	if rules.sagas.has(story.source):
		return rules.sagas[story.source].acts[int(story.stage)]
	return rules.seeds[story.source]

func open_story(book: Dictionary, city: Dictionary, source_id: String, day: int) -> void:
	var id: String = city.id+":"+source_id
	if book.stories.has(id):
		return
	setup_place(book,city)
	var story := {"id":id,"source":source_id,"city":city.id,"stage":0,"opened":day,"due":day,
		"history":[],"chosen":{},"outcome":"","cast":[]}
	if rules.sagas.has(source_id):
		story.due += int(rules.sagas[source_id].acts[0].days)
		story.cast = make_cast(book,city,source_id,rules.sagas[source_id].roles)
	else:
		var row: Dictionary = scenarios[source_id]
		story.due += int(row.days[0])+expansion.number(int(book.seed),id,int(row.days[1])-int(row.days[0])+1)
		if source_id in ["S04","S05","S06"] and book.stories.has(city.id+":N02"):
			story.cast = book.stories[city.id+":N02"].cast.duplicate(true)
		else:
			story.cast = make_cast(book,city,source_id,row.roles)
	book.stories[id] = story
	civic.open_case(book,story,day)
	log_event(story,"open",day,"O prazo começou. O andamento continua mesmo se você deixar o assentamento.")

func make_cast(book: Dictionary, city: Dictionary, source_id: String, roles: Array) -> Array:
	var cast := []
	var sites: Array = expansion.places(city,int(book.seed))
	var used := {}
	var names := {}
	for i in range(roles.size()):
		var role: String = roles[i]
		var start: int = expansion.number(int(book.seed),city.id+source_id+role,sites.size()*4)
		var actor: Dictionary = {}
		for n in range(sites.size()*4):
			var slot: int = (start+n)%(sites.size()*4)
			var person: Dictionary = expansion.person(sites[slot/4],slot%4,int(book.seed))
			if used.has(person.id) or names.has(person.name) or not book.actors.get(person.id,{}).get("alive",true) or book.actors.get(person.id,{}).get("home",city.id) != city.id:
				continue
			if source_id == "N02" and i == 1 and person.site == book.actors[cast[0].id].get("site",""):
				continue
			if (role.contains("Eidrino") and person.people != "Eidrino") or (role.contains("Nymari") and person.people != "Nymari"):
				continue
			actor = person
			break
		if actor.is_empty():
			# A named visiting participant, with deterministic origin and identity.
			var people_type := "Eidrino" if role.contains("Eidrino") else ("Nymari" if role.contains("Nymari") else "Humano")
			actor = {"id":city.id+"/"+source_id+"/visitor/"+str(i),"name":expansion.GIVEN[start%expansion.GIVEN.size()]+" "+expansion.SUFFIXES[i%expansion.SUFFIXES.size()],
				"people":people_type,"age":24+start,"pin":start,"job":role,"home":city.id,"birthplace":city.id,"reserve":2}
		used[actor.id] = true
		names[actor.name] = true
		if not book.actors.has(actor.id):
			actor.alive = true
			actor.openness = expansion.number(int(book.seed),actor.id+"openness",45)+30
			actor.caution = expansion.number(int(book.seed),actor.id+"caution",75)+15
			actor.knowledge = {}
			book.actors[actor.id] = actor
		cast.append({"id":actor.id,"role":role})
	return cast

func observe(book: Dictionary, city: Dictionary, day: int, old: Dictionary) -> void:
	advance(book,day,book.get("legacy_flags",{}))
	book.legacy_flags = old.duplicate(true)
	var domain := setup_place(book,city)
	var region: String = city.id.get_slice("-",0)
	if not book.observed.has(city.id):
		book.observed[city.id] = day
	var elapsed := day-int(book.observed[city.id])+1
	for id in rules.sagas:
		var spec: Dictionary = rules.sagas[id]
		if elapsed < int(spec.start) or (spec.region != "*" and spec.region != region):
			continue
		if id == "N01" and city.id != "valdoria-0":
			continue
		if id == "N03" and city.id != "nexaria-0":
			continue
		if id == "N05" and city.id != "tharvok-0":
			continue
		if spec.gate == "medical" and region != "namaris" and not old.has("arcane_map") and domain.river >= 50:
			continue
		if spec.gate == "shortage" and not old.get("supply_suspended",false) and int(old.get("route_modifier",0)) <= 0 and domain.supply > 13:
			continue
		open_story(book,city,id,day)
	var active_families := {}
	for entry in book.stories.values():
		if entry.city == city.id and scenarios.has(entry.source) and entry.outcome.is_empty():
			active_families[scenarios[entry.source].family] = true
	if active_families.size() >= 3:
		return
	var candidates: Array[String] = []
	for id in rules.seeds:
		if book.stories.has(city.id+":"+id) or active_families.has(scenarios[id].family):
			continue
		if eligible(book,city,domain,rules.seeds[id].when,day,old):
			candidates.append(id)
	if not candidates.is_empty():
		var selected: String = candidates[expansion.number(int(book.seed),city.id+":selection:"+str(day),candidates.size())]
		open_story(book,city,selected,day)

func eligible(book: Dictionary, city: Dictionary, domain: Dictionary, reason: String, day: int, old: Dictionary) -> bool:
	var pair := relationship(book,city.id)
	match reason:
		"public_house": return old.get("public_house",false)
		"relationship": return pair.get("state") == "interesse"
		"cohabitation": return pair.get("state") == "convivência"
		"commitment": return pair.get("state") in ["compromisso","convivência"]
		"scarcity": return domain.supply <= 13 and (domain.route > 0 or old.get("route_modifier",0) > 0 or domain.war == "engaged")
		"independent_artisan": return old.get("independent_artisan",false)
		"medical": return book.stories.has(city.id+":N04") and domain.health < 64
		"flux_record": return old.has("arcane_map") and book.stories.has(city.id+":N04")
		"nest": return book.stories.has(city.id+":N05") and domain.habitat > 40
		"dragon_contact": return old.get("dragon_contact",false) and book.stories.has(city.id+":N05")
		"damaged_river": return domain.river < 45
		"ledger_report": return old.get("verified_report",false) or old.get("public_suspicion",false)
		"sensor": return city.id == "nexaria-0" and book.stories.has(city.id+":N03") and book.stories[city.id+":N03"].stage >= 1
		"festival": return day%30 in [5,6,7] and domain.tension < 60
		"storm": return domain.damage > 0
		"estate": return day%28 in [9,10,11] and int(domain.supply) > 8
		"adoption": return old.get("public_house",false) or book.stories.has(city.id+":S01")
		"vacancy": return city.id=="valdoria-0" and day>=6 and domain.government=="inicial"
		"concession": return int(domain.route)>0 or old.get("public_suspicion",false)
		"wages": return int(domain.tension)>=45 and int(domain.supply)<17
		"rail": return int(city.region) in [0,1,2] and day%19 in [10,11,12]
		"absence": return day%23 in [9,10,11] and int(domain.tension)>=32
		"observatory": return int(city.region) in [1,3] and day%21 in [12,13,14]
		"religious": return day%29 in [9,10,11] and int(domain.legitimacy)>=40
		"implants": return int(city.region)==1 and book.stories.has(city.id+":N03")
		"relic": return int(city.region) in [2,3] and day%27 in [15,16,17]
		"border": return int(city.region) in [2,3] and int(domain.tension)>=48
		"blockade": return domain.war=="engaged" or int(domain.supply)<9
		"diplomacy": return domain.war in ["mobilized","engaged","truce"]
		"eidrino": return int(city.region)==1 and int(domain.civil)<2 and day>=5
		"suffrage": return int(city.region)==1 and (int(domain.civil)>0 or domain.marks.has("contract_capacity"))
		"archive": return old.get("public_house",false) or book.stories.has(city.id+":S24")
		"exploration": return int(city.region) in [2,3] and day%20 in [9,10,11]
		"rupture": return old.has("arcane_map") or (int(city.region)==5 and day>=10)
		"school": return int(domain.damage)>0 or int(domain.supply)<12
	return false

func relationship(book: Dictionary, city_id: String) -> Dictionary:
	var saga_id := city_id+":N02"
	if not book.stories.has(saga_id):
		return {}
	var cast: Array = book.stories[saga_id].cast
	return book.relationships.get(cast[0].id+"|"+cast[1].id,{})

func log_event(story: Dictionary, key: String, day: int, message: String) -> void:
	story.history.append({"id":story.id+":"+key,"day":day,"text":message})

func has_mark(book: Dictionary, domain: Dictionary, city_id: String, requirement: String, old: Dictionary) -> bool:
	if requirement.begins_with("proof:"):
		return book.known.has(city_id+":"+requirement.trim_prefix("proof:"))
	if requirement == "independent_artisan":
		return old.get("independent_artisan",false) or domain.marks.get("guild_consorcio",false)
	return domain.marks.get(requirement,false) or old.get(requirement,false)

func check_action(book: Dictionary, story: Dictionary, action: Dictionary, old: Dictionary, credits: int, flux: int, npc: bool = false) -> String:
	var domain: Dictionary = book.places[story.city]
	if not action.special in SPECIALS and not action.special in Civic.OPS:
		return "Regra indisponível."
	if int(action.cost) > (int(domain.supply) if npc else credits) or int(action.flux) > (int(domain.flux) if npc else flux):
		return "Recursos insuficientes."
	for mark in action.needs:
		# The NPC decision does not gain access to the player's private notebook.
		if npc and str(mark).begins_with("proof:"):
			return "A comissão ainda não recebeu a prova."
		if not has_mark(book,domain,story.city,mark,old):
			return "Requer " + str(mark).trim_prefix("proof:").replace("_"," ") + "."
	for meter in action.delta:
		if not METERS.has(meter):
			return "Efeito indisponível."
		if meter == "supply" and int(domain.supply)+int(action.delta[meter])-(int(action.cost) if npc else 0)<0:
			return "A reserva não cobre a medida."
	if npc and int(domain.supply)-int(action.cost) < 0:
		return "A reserva não cobre a medida."
	var pair := relationship(book,story.city)
	match action.special:
		"date":
			if pair.get("state") not in ["interesse","cortejo"]:
				return "Os dois ainda não declararam interesse."
		"cohabit","union":
			if pair.get("state") not in ["cortejo","compromisso","convivência"]:
				return "Exige um vínculo já aceito pelos dois."
		"marriage":
			if pair.get("state") not in ["compromisso","convivência"] or not pair.get("accept_a",false) or not pair.get("accept_b",false):
				return "Exige compromisso e manifestação prévia de ambos."
		"constitutional_vote","citizenship_vote":
			if domain.legitimacy < 52:
				return "A proposta ainda não tem apoio para votação."
		"war_order":
			var office: Dictionary = civic.ensure(book).offices.get(story.city,{})
			if (not office.is_empty() and office.status == "vacância") or domain.government not in ["regência","constitucional","título reconhecido"] or domain.tension < 55 or domain.supply < 8 or domain.war != "calm":
				return "Requer autoridade formal, tensão de fronteira e reservas."
		"ratify","truce":
			if not (domain.marks.get("diplomatic_channel",false) or "diplomatic_channel" in action.marks) or domain.war not in ["mobilized","engaged","truce"]:
				return "As partes precisam de canal diplomático e conflito ativo."
	return civic.check(book,story,action)

func result_for(book: Dictionary, story: Dictionary, action: Dictionary, day: int, npc: bool, action_id: String) -> void:
	var domain: Dictionary = book.places[story.city]
	if npc:
		domain.supply -= int(action.cost)
		domain.flux -= int(action.flux)
	for key in action.delta:
		var limit: Array = METERS[key]
		domain[key] = clampi(int(domain[key])+int(action.delta[key]),int(limit[0]),int(limit[1]))
	for mark in action.marks:
		domain.marks[mark] = true
	if not action.fact.is_empty():
		var discovery := {"id":action.fact,"city":story.city,"source":story.id,"day":day,"type":"evidência"}
		if npc:
			var participant: Dictionary = story.cast[0]
			book.actors[participant.id].knowledge[action.fact] = discovery
		else:
			book.known[story.city+":"+action.fact] = discovery
	var response := apply_special(book,story,domain,action.special,day)
	if action.special in Civic.OPS:
		response = civic.dispatch(book,story,action.special,day,action_id,action)
	if int(action.flux) > 0:
		var registry := civic.ensure(book)
		registry.contracts[story.id+":fluxo:"+str(int(story.stage))] = {"kind":"Compensação","city":story.city,
			"source":"reserva local" if npc else "reserva do viajante","amount":int(action.flux),"sink":"contenção local","date":day}
	var result: String = action.result + (" "+response if not response.is_empty() else "")
	log_event(story,"act-"+str(int(story.stage)+1),day,("Iniciativa local. " if npc else "")+result)
	story.chosen[str(int(story.stage))] = {"option":action_id,"day":day,"npc":npc}
	var ledger: Array = civic.ensure(book).ledger
	ledger.append({"seq":ledger.size()+1,"story":story.id,"city":story.city,"day":day,"option":action_id,
		"stage":int(story.stage),"type":"decision","effect":str(action.special),"delta":action.delta.duplicate()})

func apply_special(book: Dictionary, story: Dictionary, domain: Dictionary, special: String, day: int) -> String:
	match special:
		"regency":
			domain.government = "regência"
			var office := civic.office_for(book,story.city)
			office.incumbent = civic.actor_id(story,0)
			office.status = "regência"
			office.review = day+38
		"constitutional_vote":
			domain.government = "constitucional"
			var office := civic.office_for(book,story.city)
			office.incumbent = civic.actor_id(story,0)
			office.status = "constitucional"
			office.method = "conselho"
			office.review = day+180
		"recognize_title":
			var office := civic.office_for(book,story.city)
			var claimant := civic.actor_id(story,1)
			if book.actors[claimant].alive and int(domain.legitimacy) >= 49:
				domain.government = "título reconhecido"
				office.incumbent = claimant
				office.status = "titular"
			else:
				office.claimant = claimant
				office.opposition += 1
				return "O reconhecimento foi impugnado no conselho."
		"citizenship_vote": domain.civil = 2
		"civil_rights": domain.civil = maxi(1,int(domain.civil))
		"dragon_refusal":
			domain.marks.dragon_accepted = false
			return "A recusa foi registrada e o dragão conserva seu território."
		"dragon_consent":
			var accepts: bool = domain.marks.get("memorial_respect",false) and domain.habitat >= 58 and domain.tension < 52
			domain.marks.dragon_accepted = accepts
			return "O Orúnide aceitou a passagem sazonal, revogável." if accepts else "O Orúnide recusou. A proposta não se tornou pacto."
		"war_order":
			domain.war = "mobilized"
			domain.duty = 6
			civic.mobilize(book,story,day)
		"ratify","truce":
			var domestic: bool = domain.legitimacy >= 45
			var other: bool = domain.tension <= 54
			if not domestic or not other:
				return "Pelo menos uma delegação recusou ratificar. O conflito permanece aberto."
			domain.war = "peace" if special == "ratify" else "truce"
			domain.treaty = {"id":story.id+":tratado:"+str(day),"day":day,"party_a":true,"party_b":true,
				"ratified":true,"scope":domain.war}
			var front := civic.front_for(book,story.city)
			if not front.is_empty():
				front.status = "paz" if special=="ratify" else "trégua"
				front.treaty = domain.treaty.duplicate(true)
				front.treaty.territory = story.city
				front.treaty.review = day+30
				front.treaty.humanitarian_access = true
			return "O registro recebeu os dois aceites."
		"talk","pause","date","cohabit","friends","pressure","apart","separate","marriage","union":
			return relationship_action(book,story,special,day)
	return ""

func relationship_action(book: Dictionary, story: Dictionary, action: String, day: int) -> String:
	var id: String = story.city+":N02"
	if not book.stories.has(id):
		return ""
	var cast: Array = book.stories[id].cast
	var a: Dictionary = book.actors[cast[0].id]
	var b: Dictionary = book.actors[cast[1].id]
	if a.age < 18 or b.age < 18 or not a.alive or not b.alive:
		return "A proposta não reúne participantes elegíveis."
	var key: String = a.id+"|"+b.id
	var relation: Dictionary = book.relationships.get(key,{"state":"conhecidos","trust":0,"respect":10,
		"affinity":5,"familiarity":0,"grievance":0,"responses":[],"accept_a":false,"accept_b":false})
	book.relationships[key] = relation
	match action:
		"pause": return "O vínculo anterior foi preservado."
		"pressure":
			relation.trust = maxi(-100,int(relation.trust)-12)
			relation.grievance = mini(100,int(relation.grievance)+12)
			relation.responses.append({"day":day,"action":action,"a":false,"b":false})
			return "A pressão foi recusada; não avançou o vínculo."
		"friends","separate":
			if relation.state == "casamento":
				return "O registro civil requer procedimento próprio de dissolução."
			relation.state = "amizade" if action == "friends" else "separação"
			relation.accept_a = false
			relation.accept_b = false
			return "As obrigações individuais foram preservadas."
		"apart":
			if relation.state == "convivência":
				relation.state = "compromisso"
			return "Continuaram com residências independentes."
	var place: Dictionary = book.places[story.city]
	var flexibility := 8 if place.marks.get("flexible_work",false) else 0
	var barrier := 35 if action == "talk" else (48 if action == "date" else 59)
	var accept_a: bool = int(a.openness)+int(relation.trust)+flexibility-int(relation.grievance) >= barrier
	var accept_b: bool = int(b.openness)+int(relation.respect)+flexibility-int(relation.grievance) >= barrier+3
	if action in ["marriage","union"] and place.war == "engaged":
		accept_b = false
	relation.responses.append({"day":day,"action":action,"a":accept_a,"b":accept_b})
	relation.accept_a = accept_a
	relation.accept_b = accept_b
	if not accept_a or not accept_b:
		return "Respostas — %s: %s. %s: %s. O vínculo não avançou." % [
			a.name,"aceita" if accept_a else "recusa",b.name,"aceita" if accept_b else "recusa"]
	relation.trust = mini(100,int(relation.trust)+5)
	relation.respect = mini(100,int(relation.respect)+5)
	relation.affinity = mini(100,int(relation.affinity)+4)
	relation.familiarity = mini(100,int(relation.familiarity)+6)
	match action:
		"talk":
			if relation.state in ["conhecidos","amizade"]:
				relation.state = "interesse"
		"date": relation.state = "cortejo"
		"cohabit","union": relation.state = "convivência"
		"marriage":
			if not book.unions.has(key):
				relation.state = "casamento"
				book.unions[key] = {"id":key,"partners":[a.id,b.id],"city":story.city,"day":day,
					"property":"separado","consent":[accept_a,accept_b],"witness":cast[2].id}
	return "Os dois aceitaram. Situação: %s." % relation.state

func validate_player(book: Dictionary, story_id: String, stage: int, option: String, city_id: String, day: int,
	credits: int, flux: int, old: Dictionary) -> String:
	if not book.stories.has(story_id):
		return "Trama indisponível."
	var story: Dictionary = book.stories[story_id]
	if story.city != city_id:
		return "Viaje ao assentamento da cena."
	if story.stage != stage or day >= story.due or not story.outcome.is_empty() or story.chosen.has(str(stage)):
		return "A decisão deste ato já foi encerrada."
	var actions: Dictionary = plan_for(story).actions
	if not actions.has(option):
		return "Depende de regra ainda não implementada."
	return check_action(book,story,actions[option],old,credits,flux)

func perform(book: Dictionary, story_id: String, stage: int, option: String, city_id: String, day: int,
	credits: int, flux: int, old: Dictionary) -> Dictionary:
	if not validate_player(book,story_id,stage,option,city_id,day,credits,flux,old).is_empty():
		return {}
	var story: Dictionary = book.stories[story_id]
	var action: Dictionary = plan_for(story).actions[option]
	if story.source=="S03":
		civic.open_case(book,story,day)
	result_for(book,story,action,day,false,option)
	return action

func automatic(book: Dictionary, story: Dictionary, day: int, old: Dictionary) -> void:
	var plan := plan_for(story)
	var action: Dictionary = {}
	var selected := "prazo"
	if story.source=="S03":
		civic.open_case(book,story,day)
	if rules.seeds.has(story.source):
		action = plan.auto
		if not check_action(book,story,action,old,0,0,true).is_empty():
			action = {}
	else:
		var best := -10000
		var person: Dictionary = book.actors[story.cast[0].id]
		for id in plan.actions:
			var candidate: Dictionary = plan.actions[id]
			if not check_action(book,story,candidate,old,0,0,true).is_empty():
				continue
			var gain: Dictionary = candidate.delta
			var score := 3*int(gain.get("health",0))+2*int(gain.get("legitimacy",0))+int(gain.get("river",0)) + int(gain.get("habitat",0))
			score -= int(gain.get("tension",0))*int(person.caution)/20+int(candidate.cost)*2
			score += expansion.number(int(book.seed),story.id+str(day)+id,17)
			if score > best:
				best = score
				action = candidate
				selected = id
	if not action.is_empty():
		result_for(book,story,action,day,true,selected)
	elif not plan.actions.is_empty():
		log_event(story,"act-"+str(int(story.stage)+1),day,"O prazo venceu sem meios para executar uma das opções.")

func advance(book: Dictionary, day: int, old: Dictionary) -> void:
	while true:
		var next_story: Dictionary = {}
		for entry in book.stories.values():
			if entry.outcome.is_empty() and entry.due <= day and (next_story.is_empty() or entry.due < next_story.due or (entry.due == next_story.due and entry.id < next_story.id)):
				next_story = entry
		if next_story.is_empty():
			civic.advance(book,day)
			return
		civic.advance(book,int(next_story.due))
		var stage := int(next_story.stage)
		var deadline := int(next_story.due)
		if not next_story.chosen.has(str(stage)):
			automatic(book,next_story,deadline,old)
		var domain: Dictionary = book.places[next_story.city]
		if (next_story.source == "N06" and stage == 2 or next_story.source == "S25") and domain.war == "mobilized":
			resolve_front(book,next_story,domain,deadline)
		if stage+1 == count_acts(next_story.source):
			next_story.outcome = conclude(book,next_story,domain)
			log_event(next_story,"legacy",deadline,next_story.outcome)
			var ledger: Array = civic.ensure(book).ledger
			ledger.append({"seq":ledger.size()+1,"story":next_story.id,"city":next_story.city,"day":deadline,
				"type":"closure","text":next_story.outcome})
		else:
			next_story.stage = stage+1
			next_story.due = deadline+int(plan_for(next_story).days)

func resolve_front(book: Dictionary, story: Dictionary, domain: Dictionary, day: int) -> void:
	if not civic.front_for(book,story.city).is_empty():
		log_event(story,"front",day,civic.battle(book,story,day))
		return
	if domain.supply < 2 or domain.duty < 2:
		domain.war = "calm"
		log_event(story,"front",day,"O comandante retirou a ordem por falta de meios.")
		return
	var terrain: int = expansion.number(int(book.seed),story.id+":terrain",4)
	var loss := clampi(4-terrain,1,int(domain.duty))
	domain.supply -= 2
	domain.duty -= loss
	domain.deaths += loss
	domain.damage = mini(10,int(domain.damage)+2)
	domain.health = maxi(0,int(domain.health)-4)
	domain.war = "engaged"
	log_event(story,"front",day,"Houve confronto na passagem. Baixas registradas: %d. A rota consumiu duas reservas e sofreu danos." % loss)

func conclude(book: Dictionary, story: Dictionary, domain: Dictionary) -> String:
	match story.source:
		"N01":
			var office := civic.office_for(book,story.city)
			if office.status == "vacância":
				return "A coroa segue vaga; o conselho convocou revisão."
			if office.status == "contestada":
				return "O poder foi fragmentado e o título continua sob contestação."
			return "Legado institucional — " + str(office.status)
		"N02": return "Vínculo ao longo dos anos — " + relationship(book,story.city).get("state","vidas independentes")
		"N03":
			if domain.marks.get("reform_rejected",false) and domain.civil == 0:
				return "A reforma foi rejeitada; recursos seguem no conselho."
			return ["Reforma pendente","Estatuto civil parcial","Cidadania reconhecida"][int(domain.civil)]
		"N04":
			if domain.marks.get("plant_transferred",false):
				return "O reator saiu da cidade sob acordo ambiental inter-regional."
			return "Tratamento sustentado e margem recuperada." if domain.river >= 60 and domain.health >= 60 else ("Crise ecológica com tratamento ainda ativo." if domain.river < 40 else "Revisão do protocolo e atendimento limitado.")
		"N05":
			if domain.marks.get("coercion_refused",false):
				return "O Orúnide recusou a licença e a negociação foi interrompida."
			return "Corredor pactuado." if domain.marks.get("corridor",false) and domain.marks.get("dragon_accepted",false) else ("Rota desviada para preservar o ninho." if domain.marks.get("detour",false) else "Coexistência sem tratado permanente.")
		"N06":
			var front := civic.front_for(book,story.city)
			if front.get("status") == "ocupação":
				return "A passagem segue ocupada sob administração militar."
			if front.get("status") == "retirada":
				return "A frente recuou por desgaste e falta de suprimentos."
			return {"peace":"Acordo ratificado e início da reconstrução.","truce":"Armistício temporário.","engaged":"Conflito prolongado.","calm":"A crise comercial seguiu sem declaração."}.get(domain.war,"Tropas em mobilização.")
	var registry := civic.ensure(book)
	if registry.estates.has(story.id):
		var estate: Dictionary = registry.estates[story.id]
		return "Espólio: %s. Dívida remanescente: %d." % [estate.state,int(estate.debts)]
	if registry.cases.has(story.id):
		var case_record: Dictionary = registry.cases[story.id]
		return "Instrução concluída com %d diligência(s): %s." % [int(case_record.progress),case_record.status]
	return "Prazo encerrado. As decisões e seus efeitos foram registrados no histórico."
