extends SceneTree

const Game = preload("res://veyrath/engine.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var game = Game.new()
	check(game.new_game("Dossiê","scholar","valdor",361),"Campanha offline")
	var director = game.dossier
	var counts := {}
	for family in director.families:
		counts[family.id] = 0
	for scenario in director.scenarios.values():
		check(counts.has(scenario.family) and not scenario.opening.is_empty() and scenario.options.size() >= 3
			and scenario.days[0] > 0 and scenario.days[1] >= scenario.days[0],"Cenário válido: "+scenario.id)
		counts[scenario.family] += 1
	check(counts.size() == 12 and director.scenarios.size() == 36,"12 famílias e 36 cenários com IDs únicos")
	for id in counts:
		check(counts[id] == 3,"Três cenários em "+id)
	check(director.rules.seeds.size() == 36 and director.sagas.size() == 6,"Escopo jogável catalogado")
	for id in director.sagas:
		check(director.count_acts(id) == (6 if id == "N06" else 5),"Atos importados: "+id)
		var acts: Array = director.rules.sagas[id].acts
		for index in range(acts.size()):
			var options: Array = director.sagas[id].acts[index].options
			for action_id in acts[index].actions:
				check(options.any(func(option): return option.id == action_id),"Regra pertence a escolha autoral")
	var original: Dictionary = JSON.parse_string(JSON.stringify(game.state))
	for version in ["0.10","0.11"]:
		game.state = original.duplicate(true)
		game.state.erase("dossier")
		if version == "0.10":
			game.state.erase("chronicle")
		check(game.save_game(),"Fixture estrutural "+version)
		var loaded = Game.new()
		check(loaded.load_game() and not loaded.state.has("dossier") and loaded.chronicle_wait(7),"Migração "+version)
		check(loaded.state.seed == original.seed and loaded.state.node == original.node and loaded.state.people == original.people
			and loaded.state.get("inventory",{}) == original.get("inventory",{}),"Preserva save "+version)
		check(loaded.state.chronicle.cast.assistant.id == original.chronicle.cast.assistant.id,"Identidade das Crônicas "+version)
		check(not loaded.read_save(loaded.BACKUP).has("dossier"),"Backup anterior à primeira gravação "+version)
		check(loaded.load_game() and loaded.state.dossier.stories.has("valdoria-0:N01"),"Dossiê reabre após migração "+version)
	game.load_game()
	var city := "valdoria-0"
	var romance := city+":N02"
	check(game.dossier_choice(romance,0,"C"),"É possível recusar pressão no jogo")
	check(not game.dossier_choice(romance,0,"A"),"Decisão repetida não reaplica")
	var book: Dictionary = game.dossier_view()
	check(director.relationship(book,city).state == "conhecidos" and director.relationship(book,city).grievance == 12,"Pressão tem consequência e não cria romance")
	var story: Dictionary = book.stories[romance]
	check(not director.validate_player(book,romance,0,"B","namaris-0",8,20,20,{}).is_empty(),"Ação fora do local recusada")
	var a: Dictionary = book.actors[story.cast[0].id]
	var b: Dictionary = book.actors[story.cast[1].id]
	a.openness = 75
	b.openness = 75
	check(director.relationship_action(book,story,"talk",9).contains("dois"),"Adultos podem demonstrar interesse")
	director.relationship_action(book,story,"date",10)
	director.relationship_action(book,story,"cohabit",11)
	check(director.relationship(book,city).state == "convivência" and book.unions.is_empty(),"Convivência independente de casamento")
	b.age = 17
	check(director.relationship_action(book,story,"marriage",12).contains("elegíveis") and book.unions.is_empty(),"Idade bloqueia casamento")
	b.age = 25
	b.openness = 30
	director.relationship_action(book,story,"marriage",12)
	check(book.unions.is_empty(),"Uma recusa basta para não formar união")
	b.openness = 75
	director.relationship_action(book,story,"marriage",13)
	check(book.unions.size() == 1,"União registra dois aceites")
	var domain: Dictionary = book.places[city]
	director.open_story(book,game.expedition_city(),"N06",21)
	var front: Dictionary = book.stories[city+":N06"]
	var order: Dictionary = director.rules.sagas.N06.acts[2].actions.C
	check(not director.check_action(book,front,order,{},20,20).is_empty(),"Guerra sem autorização bloqueada")
	domain.government = "regência"
	director.civic.office_for(book,city).status = "regência"
	domain.tension = 64
	domain.supply = 10
	check(director.check_action(book,front,order,{},20,20).is_empty(),"Mobilização com autoridade e reserva")
	director.result_for(book,front,order,22,false,"C")
	director.resolve_front(book,front,domain,23)
	check(domain.war != "mobilized" and domain.supply == 4 and domain.damage == 2 and domain.deaths > 0,"Confronto consome reserva, registra mortos e dano")
	check(not director.check_action(book,front,director.rules.sagas.N06.acts[4].actions.A,{},20,20).is_empty(),"Tratado exige canal aberto")
	domain.war = "engaged"
	domain.marks.diplomatic_channel = true
	domain.legitimacy = 50
	director.apply_special(book,front,domain,"ratify",24)
	check(not domain.has("treaty"),"Ratificação com só uma parte não gera tratado")
	domain.tension = 42
	director.apply_special(book,front,domain,"ratify",25)
	check(domain.war == "peace" and domain.treaty.party_a and domain.treaty.party_b,"Tratado com dois aceites")
	var mountains: Dictionary = game.expansion.city("tharvok-0",361)
	director.open_story(book,mountains,"N05",25)
	var dragon: Dictionary = book.stories["tharvok-0:N05"]
	var ridge: Dictionary = book.places[mountains.id]
	director.apply_special(book,dragon,ridge,"dragon_consent",26)
	check(not ridge.marks.dragon_accepted and ridge.habitat > 0,"Dragão recusa e conserva habitat")
	book.known[city+":n04_water"] = {"id":"n04_water","city":city}
	check(director.has_mark(book,domain,city,"proof:n04_water",{}) and not director.has_mark(book,ridge,mountains.id,"proof:n04_water",{}),"Prova pertence ao local de origem")
	check(director.has_mark(book,domain,city,"independent_artisan",{"independent_artisan":true}),"Licença de C01 habilita via em N04")
	var other: Dictionary = director.create(361,1)
	director.open_story(other,game.expedition_city(),"N02",3)
	check(other.stories[romance].cast == story.cast and other.unions.is_empty(),"Elenco reproduzível e estado isolado")
	director.advance(other,3651,{})
	var autonomous: Dictionary = other.stories[romance]
	check(not autonomous.outcome.is_empty() and autonomous.history.size() > 2,"NPCs avançam prazos sem jogador")
	var count: int = autonomous.history.size()
	director.advance(other,3651,{})
	check(autonomous.history.size() == count and director.valid(other),"Repetição do relógio não duplica consequências")
	print("Dossiê: 12 famílias, 36 entradas, seis sagas, 36 sementes com regras; %d falhas." % failures)
	quit(1 if failures else 0)
