extends SceneTree
const Updater = preload("res://veyrath/updates/content_updater.gd")
const Game = preload("res://veyrath/engine.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func _initialize() -> void:
	var game = Game.new()
	check(game.new_game("História", "scholar", "valdor", 456),"Criar campanha")
	var before: Dictionary = game.state.duplicate(true)
	var updater = Updater.new()
	var sample := FileAccess.get_file_as_string("res://remote/beta.json")
	check(updater.install(sample,"beta","test_device").ok,"Instalar pacote assinado")
	check(game.state == before,"A instalação não muda o mundo")
	check(game.record_content_choice("ecos_da_ponte","ouvir"),"Registrar escolha do pacote")
	check(not game.record_content_choice("ecos_da_ponte","ouvir"),"Não repetir história")
	check(game.state.credits == before.credits and game.state.people == before.people,"A escolha não modifica recursos ou NPCs")
	var reload = Game.new()
	check(reload.load_game() and reload.state.remote_progress.has("1:ecos_da_ponte"),"Escolha persiste após reabrir")
	print("História remota: testes concluídos. Falhas: ",failures)
	quit(1 if failures else 0)
