extends SceneTree

const Game = preload("res://veyrath/engine.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func jump(game, day: int) -> void:
	var old := int(game.state.day)
	game.state.day = day
	game.advance_world(old)

func _initialize() -> void:
	var game = Game.new()
	check(game.new_game("Crônicas","scholar","valdor",361),"Campanha")
	var old_save: Dictionary = game.state.duplicate(true)
	old_save.erase("chronicle")
	check(game.valid(old_save),"Save 0.10 continua válido")
	check(game.state.chronicle.arcs.apprentice.phase == 0,"NPC abriu crônica no início")
	check(not game.state.chronicle.events.is_empty(),"Abertura tem memória")
	var cast_ids := {}
	for role in game.state.chronicle.cast:
		var actor: Dictionary = game.state.chronicle.cast[role]
		check(not cast_ids.has(actor.id) and not actor.dramatic.desire.is_empty(),"Elenco tem identidade e desejo")
		cast_ids[actor.id] = true
	check(cast_ids.size() == 20,"Elenco de vinte participantes")
	check(game.chronicle_choice("apprentice",0,"witness"),"Testemunha pode ser convocada")
	check(not game.chronicle_choice("apprentice",0,"witness"),"Decisão idempotente")
	check(game.chronicle_choice("inheritance",0,"copy"),"Pode consultar cessão")
	jump(game,4)
	check(game.director.clue_text(game.state.chronicle,"receipt").is_empty(),"Verdade não aparece antes de investigação")
	check(game.chronicle_choice("ledger",0,"register"),"Indício registrado")
	jump(game,6)
	check(game.chronicle_choice("council",0,"clause"),"Cláusula política")
	jump(game,8)
	var flow: int = game.state.flow
	check(game.chronicle_choice("flux",0,"seal") and game.state.flow == flow-1,"Contenção tem custo")
	jump(game,12)
	check(game.chronicle_choice("dragon",0,"boundary"),"Rota preserva habitat")
	jump(game,13)
	check(game.state.chronicle.cast.elder.died_day == 13,"Morte e cronologia")
	check(game.state.chronicle.cast.heir.parents == [game.state.chronicle.cast.caretaker.id],"Terceira geração registrada")
	check(game.chronicle_choice("inheritance",1,"file"),"Cessão persistente habilita petição")
	check(game.chronicle_choice("ledger",1,"receipt"),"Prova depende do indício")
	check(not game.director.clue_text(game.state.chronicle,"receipt").is_empty(),"Prova revelada")
	check(game.chronicle_choice("ledger",1,"report"),"Entrega do laudo")
	jump(game,26)
	check(game.chronicle_choice("council",1,"charter"),"Contraproposta custa créditos")
	jump(game,33)
	check(game.chronicle_choice("dragon",1,"privacy"),"Sigilo protege autonomia")
	jump(game,106)
	var journal: Dictionary = game.state.chronicle
	check(journal.flags.independent_artisan and journal.flags.calibrated_lens and journal.flags.arcane_map,"Licença muda pesquisa")
	check(journal.flags.draconic_pact,"Pesquisa, habitat e privacidade permitem pacto")
	check(journal.flags.public_house and journal.flags.route_modifier == -1,"Legado familiar e emenda mudam voto")
	check(game.director.goal_for(journal,journal.cast.assistant).contains("ateliê independente"),"Objetivo mudou")
	var unique := {}
	var last_day := 0
	for event in journal.events:
		check(not unique.has(event.id) and int(event.day) >= last_day,"Cronologia sem duplicatas")
		unique[event.id] = true
		last_day = int(event.day)
	var previous_count: int = journal.events.size()
	game.director.advance(journal,106)
	check(journal.events.size() == previous_count,"Reavaliação não duplica transições")
	check(game.save_game(),"Grava legado")
	var loaded = Game.new()
	check(loaded.load_game() and loaded.state.chronicle.flags.draconic_pact,"Legado persiste após reabrir")
	var ignored: Dictionary = game.director.create(361,game.expansion.home_id("valdor"),1)
	game.director.advance(ignored,106)
	check(ignored.arcs.council.outcome != journal.arcs.council.outcome,"Omissão produz caminho diferente")
	check(ignored.arcs.dragon.outcome != journal.arcs.dragon.outcome,"Dragão pode recusar o contato")
	var other: Dictionary = game.director.create(947,game.expansion.home_id("tharvok"),1)
	check(other.cast.assistant.id != journal.cast.assistant.id,"Campanhas usam elencos coerentes com seu assentamento")
	print("Crônicas: 6 arcos, 5 escalas, %d registros no percurso testado, %d falhas." % [previous_count,failures])
	quit(1 if failures else 0)
