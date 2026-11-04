extends SceneTree
const Updater = preload("res://veyrath/updates/content_updater.gd")
const Game = preload("res://veyrath/engine.gd")
var failures := 0
func check(ok: bool, msg: String) -> void:
	if not ok:
		push_error(msg)
		failures += 1
func envelope(private_key: CryptoKey, version: int, min_native: int = 7, rollout: int = 100) -> String:
	var pack := {"schema":1,"stories":[{"id":"test_story","title":"Uma história","text":"Uma notícia.","choices":[{"id":"listen","label":"Ouvir","result":"Você ouviu."}]}]}
	var bytes := JSON.stringify(pack).to_utf8_buffer()
	var helper = Updater.new()
	var manifest := {"format":1,"version":version,"min_native":min_native,"max_native":min_native,"channel":"beta","rollout_percent":rollout,"size":bytes.size(),"sha256":helper.sha256(bytes).hex_encode()}
	var raw := JSON.stringify(manifest).to_utf8_buffer()
	var sig := Crypto.new().sign(HashingContext.HASH_SHA256,helper.sha256(raw),private_key)
	return JSON.stringify({"manifest":Marshalls.raw_to_base64(raw),"signature":Marshalls.raw_to_base64(sig),"bundle":Marshalls.raw_to_base64(bytes)})
func _initialize() -> void:
	var crypto := Crypto.new()
	var key := crypto.generate_rsa(2048)
	var updater = Updater.new(key.save_to_string(true),"user://update_test")
	for f in ["active.json","previous.json","highest.txt"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(updater.path(f)))
	var v1 := envelope(key,1)
	var v2 := envelope(key,2)
	check(updater.validate(v1,"beta","abc",true).ok,"Assinatura válida")
	check(not updater.validate(v1,"stable","abc",true).ok,"Canal incompatível")
	check(not updater.validate(envelope(key,1,8),"beta","abc",true).ok,"Versão nativa incompatível")
	check(not updater.validate(envelope(key,1,7,0),"beta","abc",true).ok,"Lançamento gradual respeitado")
	var tampered: Dictionary = JSON.parse_string(v1)
	tampered.bundle = Marshalls.raw_to_base64("{}".to_utf8_buffer())
	check(not updater.validate(JSON.stringify(tampered)).ok,"Conteúdo adulterado recusado")
	var forged: Dictionary = JSON.parse_string(v1)
	forged.signature = Marshalls.raw_to_base64(Crypto.new().generate_random_bytes(256))
	check(not updater.validate(JSON.stringify(forged)).ok,"Assinatura adulterada recusada")
	var game = Game.new()
	check(game.new_game("Salvo", "scholar", "valdor", 123), "Campanha para testar atualização")
	var save_before := FileAccess.get_file_as_bytes(game.SAVE)
	check(updater.install(v1,"beta","abc").ok,"Primeira instalação")
	check(FileAccess.get_file_as_bytes(game.SAVE) == save_before, "Instalação não altera save")
	check(not updater.install(v1,"beta","abc").ok,"Versão antiga recusada")
	check(updater.install(v2,"beta","abc").ok,"Segunda instalação")
	check(updater.current().manifest.version == 2,"Conteúdo atual")
	check(updater.rollback() and updater.current().manifest.version == 1,"Rollback preserva versão anterior")
	check(FileAccess.get_file_as_bytes(game.SAVE) == save_before, "Rollback não altera save")
	check(not updater.install(v1,"beta","abc").ok,"Rollback não elimina proteção contra versões antigas")
	check(updater.atomic_write("active.json","corrompido"),"Preparar corrupção")
	check(not updater.current().is_empty() and updater.current().manifest.version == 1,"Fallback para backup válido")
	var production = Updater.new()
	var sample := FileAccess.get_file_as_string("res://remote/beta.json")
	check(production.validate(sample,"beta","teste",true).ok,"Pacote de demonstração assinado e mídia válidos")
	print("Atualizações: testes concluídos. Falhas: ",failures)
	quit(1 if failures else 0)
