extends SceneTree
const Game = preload("res://veyrath/engine.gd")
const Simulation = preload("res://veyrath/defense_sim.gd")
var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1
func _initialize() -> void:
	var game = Game.new()
	check(game.new_game("Defesa", "scholar", "valdor", 33), "Criar campanha")
	check(not game.state.has("fort") and game.fort_state().supplies == 8, "Inicialização compatível com save antigo")
	check(game.fort_build(0,"arcana"), "Construir torre")
	check(not game.fort_build(0,"steam"), "Proibir construção sobre torre")
	check(not game.fort_build(-1,"steam") and not game.fort_build(1,"unknown"), "Validar posição e tipo")
	check(game.fort_build(1,"arcana") and game.fort_build(2,"arcana") and game.fort_build(3,"arcana"), "Construir defesa")
	check(not game.fort_build(4,"arcana") and game.fort_state().supplies == 0, "Respeitar saldo")
	var loaded = Game.new()
	check(loaded.load_game() and loaded.fort_state().layout[0] == "arcana", "Construção persistida")
	var fort: Dictionary = loaded.fort_state()
	var sim = Simulation.new()
	sim.setup(fort.layout, fort.wave, fort.hp)
	for i in range(2000):
		if sim.done:
			break
		sim.step()
	check(sim.done and sim.won, "Defesa deve vencer com torres suficientes")
	check(loaded.fort_finish(sim.wave,sim.won,sim.base_hp,sim.escaped), "Registrar vitória")
	check(not loaded.fort_finish(sim.wave,sim.won,sim.base_hp,sim.escaped), "Não duplicar recompensa")
	var next = Game.new()
	check(next.load_game() and next.fort_state().wave == 2 and next.fort_state().supplies == 3, "Onda e recompensa persistem")
	check(next.state.news[-1].event_id == next.state.history[-1].id, "Notícia ligada ao resultado real")
	var empty: Array = []
	empty.resize(16)
	empty.fill("")
	var loss = Simulation.new()
	loss.setup(empty, 1, 1)
	for i in range(2000):
		if loss.done:
			break
		loss.step()
	check(loss.done and not loss.won and loss.base_hp == 0, "Defesa desprotegida pode perder")
	check(next.fort_finish(2, false, 0, 1), "Registrar derrota")
	check(next.fort_repair() and next.fort_state().hp == 3, "Reparar fortificação")
	print("Defesa: testes concluídos. Falhas: ", failures)
	quit(1 if failures else 0)
