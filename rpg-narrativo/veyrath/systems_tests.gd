extends SceneTree
const Game = preload("res://veyrath/engine.gd")
var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1
func _initialize() -> void:
	var game = Game.new()
	check(game.new_game("Teste", "community", "valdor", 17), "Novo jogo")
	check(game.profile().attributes.percepcao == 14 and game.modifier(14) == 2, "Atributos e modificador")
	check(not game.state.has("profile") and game.valid(game.state), "Save antigo sem ficha continua válido")
	check(game.interpret_action("escolha 1").kind == "choice", "Escolha por texto")
	check(game.interpret_action("ATACAR O REI").is_empty(), "Frase desconhecida não executa")
	check(game.interpret_action("investigar a área").kind == "scout", "Ação acentuada reconhecida")
	check(not game.discovered_dragon(), "Bestiário sem descobertas")
	check(game.scout(), "Inspeção executa teste")
	check(not game.scout(), "Intervalo de inspeção impede repetição")
	var profile: Dictionary = game.profile()
	profile.hp = 5
	game.state.profile = profile
	game.state.risk = 5
	check(game.use_bandage(), "Usar curativo")
	check(game.profile().hp == 8, "Curativo recupera vida")
	check(game.rest(), "Descanso disponível")
	check(game.state.day == 3 and game.state.local_world.pressure == 1, "Cidade reage ao risco com avanço do tempo")
	var saved = Game.new()
	check(saved.load_game() and saved.profile().hp == 10 and saved.state.local_world.pressure == 1, "Ficha e mundo persistem")
	check(saved.state.news[-1].event_id == saved.state.history[-1].id, "Jornal referencia evento")
	check(saved.choose(2) and saved.choose(1), "Caminho da pedreira")
	check(saved.discovered_dragon(), "Registro de criatura ao observá-la")
	var reload = Game.new()
	check(reload.load_game() and reload.discovered_dragon(), "Bestiário persiste")
	print("Sistemas narrativos: testes concluídos. Falhas: ",failures)
	quit(1 if failures else 0)
