extends SceneTree
const EngineScript = preload("res://engine.gd")
var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1
func _initialize() -> void:
	var game = EngineScript.new()
	check(game.story.size() == 7, "História não foi carregada")
	check(game.new_game("Teste", "Tecnomago"), "Falha ao criar e salvar")
	check(game.choose(0), "Falha na escolha inicial")
	check(game.state.node == "workers" and game.state.trust == 2, "Consequência incorreta")
	var loaded = EngineScript.new()
	check(loaded.load_game(), "Falha ao carregar")
	check(loaded.state.node == "workers" and loaded.state.history.size() == 1, "Decisão não persistiu")
	check(loaded.choose(1), "Falha na segunda escolha")
	check(loaded.state.node == "corporation" and loaded.state.trust == -1 and loaded.state.credits == 9, "Consequências não acumuladas")
	check(not loaded.choose(99), "Índice inválido aceito")
	var broken := FileAccess.open("user://campanha.json", FileAccess.WRITE)
	broken.store_string("corrompido")
	broken.close()
	var recovered = EngineScript.new()
	check(recovered.load_game() and recovered.state.node == "workers", "Backup não foi recuperado")
	print("Testes concluídos. Falhas: ", failures)
	quit(1 if failures else 0)
