extends SceneTree

const Game = preload("res://veyrath/engine.gd")
const Civic = preload("res://veyrath/dossier/civic.gd")
var failures := 0
var counts := [0,0]

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var game = Game.new()
	check(game.new_game("Cobertura","scholar","valdor",361),"Campanha de teste")
	var director = game.dossier
	for source in director.scenarios:
		exercise(game,source,0)
	for source in director.sagas:
		for stage in range(director.count_acts(source)):
			exercise(game,source,stage)
	check(counts == [144,100],"Cobertura exata de escolhas")
	var previous: Dictionary = game.state.duplicate(true)
	previous.dossier.erase("civic")
	check(game.valid(previous),"Save 0.12 sem registro cívico")
	for id in director.scenarios:
		var book: Dictionary = director.create(361,1)
		var city: Dictionary = game.expedition_city()
		director.open_story(book,city,id,1)
		director.advance(book,180,{})
		check(not book.stories[city.id+":"+id].outcome.is_empty() and director.valid(book),"Prazo autônomo "+id)
	print("Cobertura: %d opções de situações, %d de sagas, %d falhas." % [counts[0],counts[1],failures])
	quit(1 if failures else 0)

func exercise(game, source: String, stage: int) -> void:
	var director = game.dossier
	var city: Dictionary = game.expedition_city()
	var initial: Dictionary = director.create(361,1)
	if source in ["S04","S05","S06"]:
		director.open_story(initial,city,"N02",1)
		director.relationship_action(initial,initial.stories[city.id+":N02"],"talk",2)
	director.open_story(initial,city,source,1)
	var id: String = city.id+":"+source
	initial.stories[id].stage = stage
	initial.stories[id].due = 40
	var expected: Array = director.act_for(initial.stories[id]).options
	var executable: Dictionary = director.plan_for(initial.stories[id]).actions
	check(expected.size() == executable.size(),"Número de opções em "+id)
	for option in expected:
		var key: String = option.id
		check(executable.has(key),id+" sem "+key)
		if not executable.has(key):
			continue
		counts[0 if source.begins_with("S") else 1] += 1
		var book: Dictionary = initial.duplicate(true)
		var story: Dictionary = book.stories[id]
		var rule: Dictionary = executable[key]
		var domain: Dictionary = book.places[city.id]
		domain.legitimacy = 75
		domain.tension = 65
		domain.supply = 50
		domain.flux = 20
		domain.government = "regência"
		var office: Dictionary = director.civic.office_for(book,city.id)
		office.status = "regência"
		office.incumbent = story.cast[0].id
		office.review = 20
		for need in rule.needs:
			if need=="independent_artisan":
				domain.marks.guild_consorcio = true
			if need.begins_with("proof:"):
				book.known[city.id+":"+need.trim_prefix("proof:")] = {"id":need.trim_prefix("proof:")}
			else:
				domain.marks[need] = true
		domain.marks.diplomatic_channel = true
		if rule.special in ["ratify","truce","offensive","convoy","prisoner_exchange","unilateral"]:
			director.civic.mobilize(book,story,2)
			domain.war = "engaged"
		var relation: Dictionary = director.relationship(book,city.id)
		if source == "N02" and relation.is_empty():
			director.relationship_action(book,story,"talk",2)
			relation = director.relationship(book,city.id)
		if not relation.is_empty():
			relation.state = "convivência" if rule.special != "date" else "interesse"
			relation.accept_a = true
			relation.accept_b = true
		var result: Dictionary = director.perform(book,id,stage,key,city.id,3,99,99,{})
		check(not result.is_empty(),"%s/%d/%s: %s" % [source,stage+1,key,director.check_action(book,story,rule,{},99,99)])
		if result.is_empty():
			continue
		check(story.chosen.has(str(stage)) and book.civic.ledger.size() == 1,"Decisão registra evento "+id+"/"+key)
		check(director.perform(book,id,stage,key,city.id,3,99,99,{}).is_empty(),"Duplicata recusada "+id+"/"+key)
		check(director.valid(book),"Estado válido após "+id+"/"+key)
