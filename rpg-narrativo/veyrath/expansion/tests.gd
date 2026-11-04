extends SceneTree

const EngineScript = preload("res://veyrath/engine.gd")
var failures := 0

func check(condition: bool, reason: String) -> void:
	if not condition:
		failures += 1
		push_error(reason)

func _initialize() -> void:
	var game = EngineScript.new()
	var world = game.expansion
	var seed_value := 3814
	var cities := {}
	var venues := {}
	var people := {}
	var art := {}
	var important := 0
	for region in world.catalog.regions:
		for slot in range(6):
			var city: Dictionary = world.city("%s-%d" % [region.id,slot],seed_value)
			check(not city.is_empty() and not cities.has(city.id),"Cidade repetida ou ausente")
			cities[city.id] = city
			art[city.art] = true
			for site in world.places(city,seed_value):
				check(not venues.has(site.id),"Local repetido")
				venues[site.id] = site
				art[site.art] = true
				for staff in range(4):
					var npc: Dictionary = world.person(site,staff,seed_value)
					check(not people.has(npc.id) and npc.site == site.id and npc.home == city.id,"Identidade NPC inválida")
					check(not npc.job.is_empty() and not npc.goal.is_empty(),"NPC sem função ou objetivo")
					check(world.present(npc,int(npc.off_shift)+4) == false,"Folga não respeitada")
					people[npc.id] = npc
					important += int(npc.important)
	for npc in people.values():
		check(people.has(npc.coworker) and npc.coworker != npc.id,"Colega inválido")
		check(cities.has(npc.birthplace),"Origem inexistente")
		if not npc.household.is_empty():
			check(people.has(npc.household) and people[npc.household].household == npc.id,"Domicílio inconsistente")
	check(cities.size() == 36 and venues.size() == 288 and people.size() == 1152 and important == 108,"Escala divergente")
	check(art.size() >= 18,"Biblioteca visual insuficiente para os modelos")
	check(game.new_game("Expedição","merchant","valdor",seed_value),"Campanha")
	check(not game.state.has("expedition") and game.valid(game.state),"Save anterior deve continuar válido")
	check(game.expedition().city == "valdoria-0","Cidade inicial")
	var credits: int = game.state.credits
	var day: int = game.state.day
	var destination: Dictionary = cities["valdoria-1"]
	var route: Dictionary = world.route(cities["valdoria-0"],destination,true)
	check(game.travel_to(destination.id,true),"Viagem")
	check(game.state.credits == credits-route.credits and game.state.day == day+route.days,"Custo e tempo de viagem")
	check(not game.enter_place("elarion-0/market"),"Entrada remota proibida")
	check(not game.choose(0),"A crônica local não avança durante viagem")
	check(game.enter_place("valdoria-1/market"),"Entrada no mercado")
	var place: Dictionary = venues[game.expedition().place]
	var before: int = game.profile().bandages
	check(game.expedition_service("bandage") and game.profile().bandages == before+1,"Comércio usa o inventário real")
	check(not game.expedition_service("lodging"),"Serviço não disponível")
	var actor: Dictionary = {}
	for i in range(4):
		actor = world.person(place,i,seed_value)
		if world.present(actor,int(game.state.day)):
			check(game.meet_resident(i),"Encontro válido")
			check(not game.meet_resident(i),"Encontro duplicado")
			break
	var reopened = EngineScript.new()
	check(reopened.load_game() and reopened.expedition().place == place.id,"Local persiste")
	check(reopened.expedition().known.has(actor.id),"Memória do encontro persiste")
	check(reopened.expansion.place(place.id,seed_value) == place,"Local não muda ao reabrir")
	check(reopened.travel_to("elarion-0",false) and reopened.travel_to("valdoria-1",false),"Viagem de ida e volta")
	check(reopened.expansion.place(place.id,seed_value) == place,"Identidade preservada no retorno")
	var unfunded: Dictionary = {}
	for c in cities.values():
		var p: Dictionary = world.project(c,seed_value,1,{})
		if not p.self_funded:
			unfunded = p
			destination = c
			break
	check(not unfunded.is_empty(),"Projeto com falta de recursos deve existir")
	if not unfunded.is_empty():
		var ignored: Dictionary = world.condition(destination,seed_value,int(unfunded.deadline),{})
		var backed: Dictionary = world.condition(destination,seed_value,int(unfunded.deadline),{unfunded.id:{}})
		check(ignored.project.phase == "adiado" and backed.project.phase == "realizado","Iniciativa continua sem jogador e responde ao apoio")
		check(backed.supply > ignored.supply,"Decisão tem consequência econômica")
		check(world.condition(destination,seed_value,15,{}).previous_project.id == unfunded.id,"Ciclo anterior consultável")
	check(world.condition(destination,seed_value,3651,{}).project.date > 3600,"Calendário calculável após 10 anos")
	var funding_seed := seed_value
	var home_project: Dictionary = world.project(cities["valdoria-0"],funding_seed,1,{})
	while home_project.self_funded and funding_seed < seed_value+100:
		funding_seed += 1
		home_project = world.project(cities["valdoria-0"],funding_seed,1,{})
	check(not home_project.self_funded and game.new_game("Patrono","merchant","valdor",funding_seed),"Campanha para apoio")
	game.state.credits = 30
	check(game.enter_place(home_project.site),"Entrou no local da iniciativa")
	check(game.back_initiative(home_project.id) and game.state.credits == 30-home_project.cost,"Apoio realmente debita créditos")
	check(not game.back_initiative(home_project.id),"Apoio não duplica")
	var saved_support = EngineScript.new()
	check(saved_support.load_game() and saved_support.expedition().backing.has(home_project.id),"Apoio persiste após recarregar")
	var second: Dictionary = world.person(place,0,seed_value+1)
	check(second != world.person(place,0,seed_value),"Seeds independentes")
	print("Expansão: %d assentamentos, %d locais, %d NPCs, %d responsáveis; %d falhas." % [cities.size(),venues.size(),people.size(),important,failures])
	quit(1 if failures else 0)
