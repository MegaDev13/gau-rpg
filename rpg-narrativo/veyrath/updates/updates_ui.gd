extends VBoxContainer
const Updater = preload("res://veyrath/updates/content_updater.gd")
var updater = Updater.new()
var game
var back: Callable
var background: AudioStreamPlayer
var was_playing := false
var audio_preview: AudioStreamPlayer
var request: HTTPRequest
var content: VBoxContainer
var status := ""
var config := ConfigFile.new()
var channel := "stable"
var install_id := ""
var downloading := false

func configure(game_engine, callback: Callable, soundtrack: AudioStreamPlayer) -> void:
	game = game_engine
	back = callback
	background = soundtrack

func _ready() -> void:
	config.load("user://veyrath_updates.cfg")
	channel = str(config.get_value("updates","channel","stable"))
	if channel not in ["beta","stable"]:
		channel = "stable"
	install_id = str(config.get_value("updates","installation_id",""))
	if install_id.is_empty():
		install_id = Crypto.new().generate_random_bytes(16).hex_encode()
		config.set_value("updates","installation_id",install_id)
		if config.save("user://veyrath_updates.cfg") != OK:
			install_id = ""
	request = HTTPRequest.new()
	request.timeout = 25
	request.max_redirects = 0
	request.body_size_limit = Updater.MAX_ENVELOPE
	request.request_completed.connect(on_download)
	add_child(request)
	audio_preview = AudioStreamPlayer.new()
	audio_preview.volume_db = -13
	add_child(audio_preview)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation",14)
	add_child(content)
	render()

func text_label(value: String, font_size: int = 21) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("e7e0d2"))
	content.add_child(label)

func add_button(value: String, action: Callable, disabled: bool = false) -> void:
	var b := Button.new()
	b.text = value
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.y = 65
	b.add_theme_font_size_override("font_size",20)
	b.disabled = disabled
	b.pressed.connect(action)
	content.add_child(b)

func render() -> void:
	for node in content.get_children():
		content.remove_child(node)
		node.queue_free()
	text_label("CONTEÚDO E ATUALIZAÇÕES",30)
	text_label("Canal: " + ("teste beta" if channel == "beta" else "estável"),22)
	text_label("Atualizações são verificadas antes de instalar. Sua campanha e seus saves continuam neste aparelho.",19)
	if not status.is_empty():
		text_label(status,20)
	add_button("BUSCAR ATUALIZAÇÃO",check_online,downloading or install_id.is_empty())
	add_button("MUDAR PARA " + ("ESTÁVEL" if channel == "beta" else "BETA"),toggle_channel,downloading)
	add_button("RESTAURAR VERSÃO ANTERIOR",rollback,downloading)
	var current: Dictionary = updater.current()
	if current.is_empty():
		text_label("Nenhum conteúdo adicional instalado. O jogo original continua disponível offline.")
	else:
		text_label("CONTEÚDO INSTALADO • VERSÃO %s" % current.manifest.version,22)
		if current.pack.has("image_jpg"):
			var img := Image.new()
			if img.load_jpg_from_buffer(Marshalls.base64_to_raw(current.pack.image_jpg)) == OK:
				var image := TextureRect.new()
				image.texture = ImageTexture.create_from_image(img)
				image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				image.custom_minimum_size.y = 190
				content.add_child(image)
		if current.pack.has("audio_ogg"):
			add_button("OUVIR TRILHA DO PACOTE",play_audio,downloading)
		for story in current.pack.stories:
			text_label(story.title.to_upper(),26)
			text_label(story.text,22)
			var progress: Dictionary = game.state.get("remote_progress",{}) if game.valid(game.state) else {}
			var progress_key := "%s:%s" % [int(current.manifest.version),story.id]
			if progress.has(progress_key):
				text_label("Esta história já foi registrada no diário.",19)
			elif game.valid(game.state):
				for choice in story.choices:
					add_button(choice.label,choose.bind(story.id,choice.id),downloading)
			else:
				text_label("Abra ou crie uma campanha solo para participar.",19)
	add_button("VOLTAR",exit_screen,downloading)

func check_online() -> void:
	if downloading or install_id.is_empty():
		return
	downloading = true
	status = "Verificando assinatura e compatibilidade…"
	render()
	var result := request.request(Updater.ROOT_URL + channel + ".json")
	if result != OK:
		downloading = false
		status = "Não foi possível iniciar a conexão."
		render()

func on_download(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	downloading = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		status = "Não foi possível obter uma atualização neste canal. O conteúdo local permanece disponível."
	else:
		var outcome: Dictionary = updater.install(body.get_string_from_utf8(),channel,install_id)
		status = "Atualização instalada: versão %s." % outcome.version if outcome.get("ok",false) else str(outcome.get("error","Atualização recusada."))
	render()

func toggle_channel() -> void:
	channel = "stable" if channel == "beta" else "beta"
	config.set_value("updates","channel",channel)
	status = "Canal alterado." if config.save("user://veyrath_updates.cfg") == OK else "Não foi possível salvar o canal."
	render()

func rollback() -> void:
	status = "Versão anterior restaurada." if updater.rollback() else "Nenhuma versão anterior válida encontrada."
	render()

func choose(story_id: String, choice_id: String) -> void:
	status = "Escolha registrada no diário." if game.record_content_choice(story_id,choice_id) else "Escolha já registrada ou indisponível."
	render()

func play_audio() -> void:
	var current: Dictionary = updater.current()
	if current.is_empty() or not current.pack.has("audio_ogg"):
		return
	if audio_preview.playing:
		audio_preview.stop()
		status = "Trilha de demonstração pausada."
	else:
		was_playing = was_playing or background.playing
		background.stop()
		audio_preview.stream = AudioStreamOggVorbis.load_from_buffer(Marshalls.base64_to_raw(current.pack.audio_ogg))
		audio_preview.play()
		status = "Reproduzindo a trilha do pacote."
	render()

func exit_screen() -> void:
	audio_preview.stop()
	if was_playing:
		background.play()
	back.call()
