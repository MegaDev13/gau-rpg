extends Control

const VeyrathEngine = preload("res://veyrath/engine.gd")
const Art = preload("res://veyrath/art.gd")
const DefenseUI = preload("res://veyrath/defense_ui.gd")
const MultiplayerUI = preload("res://veyrath/multiplayer_ui.gd")
const UpdatesUI = preload("res://veyrath/updates/updates_ui.gd")
const GOLD := Color("d6b47d")
const TEXT := Color("f1e6d3")
const MUTED := Color("bcb3a3")
const INK := Color("141615")
const PANEL := Color("222522")
const RULE := Color("625340")
const EDITION := "res://veyrath/assets/edition/"
const ILLUSTRATIONS := {
	"city": "veyra.webp", "council": "conselho.webp", "workshop": "oficina.webp",
	"river": "margem.webp", "quarry": "pedreira.webp", "archive": "arquivo.webp",
}
var reading_font: Font
var illustrations: Dictionary = {}
var game = VeyrathEngine.new()
var column: VBoxContainer
var scroll: ScrollContainer
var name_input: LineEdit
var origin_input: OptionButton
var city_input: OptionButton
var notice := ""
var music_player: AudioStreamPlayer
var music_enabled := true
var large_text := false
var action_input: LineEdit
var action_status: Label
var action_confirm: Button
var proposed_action: Dictionary = {}

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = INK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["margin_left","margin_right"]:
		margin.add_theme_constant_override(side,26)
	for side in ["margin_top","margin_bottom"]:
		margin.add_theme_constant_override(side,30)
	scroll.add_child(margin)
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",16)
	margin.add_child(column)
	var font_path := EDITION + "romano.otf"
	if ResourceLoader.exists(font_path):
		reading_font = load(font_path)
	elif FileAccess.file_exists(font_path):
		var local_font := FontFile.new()
		local_font.data = FileAccess.get_file_as_bytes(font_path)
		reading_font = local_font
	setup_music()
	menu()

func style(bg: Color, border: Color, padding: int = 14) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.set_content_margin_all(padding)
	return box

func clear() -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	scroll.scroll_vertical = 0

func label(value: String, font_size: int = 25, color: Color = TEXT, literary: bool = false, centered: bool = false) -> void:
	var item := Label.new()
	item.text = value
	if literary and reading_font != null:
		item.add_theme_font_override("font",reading_font)
	if centered:
		item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",color)
	column.add_child(item)

func button(value: String, action: Callable, disabled: bool = false) -> Button:
	var item := Button.new()
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.custom_minimum_size.y = 74
	item.add_theme_font_size_override("font_size",21)
	item.add_theme_color_override("font_color",TEXT)
	item.add_theme_color_override("font_disabled_color",Color("7b8382"))
	item.add_theme_stylebox_override("normal",style(PANEL,RULE,17))
	item.add_theme_stylebox_override("hover",style(Color("38372e"),GOLD,17))
	item.add_theme_stylebox_override("pressed",style(Color("44402e"),GOLD,17))
	item.add_theme_stylebox_override("disabled",style(Color("1a1c1a"),Color("42423a"),17))
	item.disabled = disabled
	item.pressed.connect(action)
	column.add_child(item)
	return item

func card(value: String, font_size: int = 25, literary: bool = false) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",style(PANEL,RULE,24))
	var content := Label.new()
	content.text = value
	if literary and reading_font != null:
		content.add_theme_font_override("font",reading_font)
		content.add_theme_constant_override("line_spacing",6)
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_theme_font_size_override("font_size",font_size)
	content.add_theme_color_override("font_color",TEXT)
	panel.add_child(content)
	column.add_child(panel)

func divider() -> void:
	var line := HSeparator.new()
	var rule := StyleBoxLine.new()
	rule.color = RULE
	rule.thickness = 1
	line.add_theme_stylebox_override("separator",rule)
	column.add_child(line)

func illustration(which: String) -> Texture2D:
	if illustrations.has(which):
		return illustrations[which]
	if ILLUSTRATIONS.has(which):
		var path: String = EDITION + ILLUSTRATIONS[which]
		if ResourceLoader.exists(path):
			illustrations[which] = load(path)
			return illustrations[which]
		if FileAccess.file_exists(path):
			var decoded := Image.new()
			if decoded.load_webp_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
				illustrations[which] = ImageTexture.create_from_image(decoded)
				return illustrations[which]
	if which in ["city","river"]:
		return load("res://veyrath/assets/val_doria.jpg")
	return null

func scene_art(which: String, height: int = 225) -> void:
	var texture := illustration(which)
	if texture != null:
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel",style(INK,RULE,3))
		var visual := TextureRect.new()
		visual.texture = texture
		visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		visual.custom_minimum_size.y = height
		frame.add_child(visual)
		column.add_child(frame)
		return
	var visual = Art.new()
	visual.kind = "scene"
	visual.scene_id = "workshop" if which == "archive" else which
	visual.custom_minimum_size.y = height
	column.add_child(visual)

func portrait(role: String, mood: String = "neutral") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	column.add_child(row)
	var person: Dictionary = game.state.people[role]
	var portraits := {"artisan_v1":"res://veyrath/assets/artifice_v1.jpg", "researcher_v1":"res://veyrath/assets/pesquisadora_v1.jpg", "leader_v1":"res://veyrath/assets/lider_v1.jpg", "merchant_v1":"res://veyrath/assets/comerciante_v1.jpg", "resident_v1":"res://veyrath/assets/morador_v1.jpg", "community_v1":"res://veyrath/assets/comunidade_v1.jpg"}
	var portrait_path: String = portraits.get(person.get("portrait_asset", ""), "")
	if not portrait_path.is_empty():
		var image := TextureRect.new()
		image.texture = load(portrait_path)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.custom_minimum_size = Vector2(150,150)
		row.add_child(image)
	else:
		var visual = Art.new()
		visual.kind = "portrait"
		visual.variant = game.portrait_variant(role)
		visual.expression = mood
		visual.custom_minimum_size = Vector2(150,110)
		row.add_child(visual)
	var info := Label.new()
	info.text = person.name.to_upper() + "\n" + person.job
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("font_size",20)
	info.add_theme_color_override("font_color",GOLD)
	row.add_child(info)

func menu() -> void:
	clear()
	label("C R Ô N I C A S   D O   C É U   P A R T I D O",16,GOLD,false,true)
	label("Veyrath",78,TEXT,true,true)
	label("O CÉU SOB FERRO",21,GOLD,false,true)
	scene_art("city",330)
	label("Toda cidade tem uma dívida.\nAlgumas são escritas na água.",30,TEXT,true,true)
	divider()
	if not notice.is_empty():
		card(notice,20)
		notice = ""
	button("Continuar a crônica",continue_game,not game.valid(game.read_save(game.SAVE)) and not game.valid(game.read_save(game.BACKUP)))
	button("Escrever uma nova história",creation)
	button("Mundo compartilhado",multiplayer_screen)
	button("Configurações",settings)
	button("Sobre Veyrath",about)
	button("Cinzas de Éter · campanha anterior",legacy)
	label("VEYRATH   /   CRÔNICA SOLO OFFLINE",15,MUTED,false,true)

func creation() -> void:
	clear()
	label("✦ SUA HISTÓRIA",36,GOLD)
	label("Cada origem oferece oportunidades diferentes. Você decide o que fazer com elas.",21,MUTED)
	label("Nome",22,GOLD)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Nome do personagem adulto"
	name_input.max_length = 40
	name_input.custom_minimum_size.y = 70
	name_input.add_theme_font_size_override("font_size",24)
	name_input.add_theme_stylebox_override("normal",style(Color("202f3a"),Color("7b6c58"),15))
	column.add_child(name_input)
	label("Origem",22,GOLD)
	origin_input = OptionButton.new()
	origin_input.custom_minimum_size.y = 70
	origin_input.add_theme_font_size_override("font_size",21)
	for origin in game.world.origins:
		origin_input.add_item(origin.name)
	column.add_child(origin_input)
	label("Cidade inicial",22,GOLD)
	city_input = OptionButton.new()
	city_input.custom_minimum_size.y = 70
	city_input.add_theme_font_size_override("font_size",21)
	for city in game.world.cities:
		city_input.add_item(city.name + " · " + city.region)
	column.add_child(city_input)
	for origin in game.world.origins:
		label("◆ " + origin.name + ": " + origin.detail,18,MUTED)
	label("Uma nova campanha substitui o progresso anterior de Veyrath. Cinzas de Éter permanece separado.",18,MUTED)
	button("✦  COMEÇAR",start_game)
	button("‹  VOLTAR",menu)

func start_game() -> void:
	if name_input.text.strip_edges().is_empty():
		name_input.placeholder_text = "Digite um nome"
		return
	if game.new_game(name_input.text,game.world.origins[origin_input.selected].id,game.world.cities[city_input.selected].id):
		show_scene()
	else:
		notice = "Não foi possível salvar."
		menu()

func continue_game() -> void:
	if game.load_game():
		show_scene()
	else:
		notice = "Nenhuma campanha de Veyrath encontrada."
		menu()

func legacy() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func scene_place(node: String) -> String:
	if node == "dragon":
		return "quarry"
	if node == "river" or node.begins_with("measures"):
		return "river"
	if node in ["council","peace","industry","environment","aftermath_wait"]:
		return "council"
	if node.begins_with("archive"):
		return "archive"
	if node in ["workshop","investigation","evidence"]:
		return "workshop"
	return "city"

func chapter_label(node: String) -> String:
	if node.begins_with("measures"):
		return "III   /   O QUE A ÁGUA LEVA"
	if node.begins_with("archive"):
		return "II   /   O QUE O PAPEL GUARDA"
	return "I   /   O QUE O FERRO COBRA"

func scene_person(node: String) -> String:
	match node:
		"workshop": return "artisan"
		"investigation", "evidence", "dragon", "archive": return "researcher"
		"river", "environment", "peace", "measures", "measures_public", "measures_departure": return "community"
		"council", "aftermath_wait": return "leader"
		"industry": return "artisan"
		_: return ""

func show_scene() -> void:
	clear()
	var scene: Dictionary = game.story[game.state.node]
	var node: String = game.state.node
	label(chapter_label(node),17,GOLD)
	label("%s   ·   DIA %s   ·   312 P.R." % [game.render("{city}"),game.state.day],18,MUTED)
	scene_art(scene_place(node),270)
	label(scene.title,48,TEXT,true)
	divider()
	card(game.scene_text(),38 if large_text else 32,true)
	var role := scene_person(node)
	if not role.is_empty():
		portrait(role, "warm" if int(game.state.people[role].trust) > 1 else "neutral")
	if node == "start":
		label("SUA ORIGEM  /  " + game.render("{origin}"),19,GOLD)
		label(game.find_entry(game.world.origins,game.state.origin).detail,20,MUTED)
	if scene.choices.is_empty():
		divider()
		label("DESFECHO DA CRÔNICA",18,GOLD)
		card(game.reaction(),25,true)
		label("As decisões desta crônica ficam registradas no diário.",20,MUTED)
	else:
		divider()
		label("SUA DECISÃO",18,GOLD)
	for i in range(scene.choices.size()):
		var choice: Dictionary = scene.choices[i]
		var reason: String = game.choice_block_reason(choice)
		var suffix := "" if reason.is_empty() else "\n" + reason
		button("%02d   %s%s" % [i+1,choice.label,suffix],select_choice.bind(i),not reason.is_empty())
	if not scene.choices.is_empty():
		label("ESCREVA UMA AÇÃO",18,GOLD)
		action_input = LineEdit.new()
		action_input.placeholder_text = "Ex.: escolha 1, descansar, falar com Aren"
		action_input.custom_minimum_size.y = 70
		action_input.add_theme_font_size_override("font_size",21)
		column.add_child(action_input)
		button("⌕  INTERPRETAR",interpret_input)
		action_status = Label.new()
		action_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		action_status.add_theme_font_size_override("font_size",20)
		action_status.add_theme_color_override("font_color",GOLD)
		action_status.text = "Comandos simples: escolha 1, descansar, usar curativo, investigar a área ou falar com [nome]."
		column.add_child(action_status)
		action_confirm = button("CONFIRMAR AÇÃO",confirm_input,true)
		proposed_action = {}
	divider()
	button("Abrir registros da campanha",campaign_records)
	button("‹  Menu principal",menu)

func campaign_records() -> void:
	clear()
	label("REGISTROS DA CAMPANHA",19,GOLD)
	label("O mundo lembra",49,TEXT,true)
	divider()
	button("◈  FICHA E ATRIBUTOS",character_sheet)
	button("◉  INVENTÁRIO",inventory)
	button("◆  BESTIÁRIO",bestiary)
	button("✧  MUNDO E AÇÕES",world_panel)
	button("▤  DIÁRIO",journal)
	button("♧  PESSOAS E RELAÇÕES",people)
	button("▤  JORNAL LOCAL",news)
	button("⚔  DEFESA DO POSTO",defense)
	button("Configurações",settings)
	button("‹  Voltar à leitura",show_scene)

func select_choice(index: int) -> void:
	if game.choose(index):
		show_scene()
	else:
		clear()
		card("Não foi possível salvar a decisão. Tente novamente.")
		button("‹  VOLTAR",show_scene)

func journal() -> void:
	clear()
	label("◈  PERSONAGEM",34,GOLD)
	var origin := game.find_entry(game.world.origins,game.state.origin)
	card("%s\n%s  ·  %s\n\n◉ CRÉDITOS  %s      ✦ FLUXO  %s\n◈ FADIGA  %s      ⚠ RISCO LOCAL  %s" % [game.state.name,origin.name,game.render("{city}"),game.state.credits,game.state.flow,game.state.fatigue,game.state.risk],22)
	label("DIÁRIO DE VIAGEM",24,GOLD)
	if game.state.history.is_empty():
		label("A primeira página da sua história ainda está em branco.",21,MUTED)
	for event in game.state.history:
		card("DIA %s  ·  %s\n%s." % [event.day,game.render("{city}"),event.description.capitalize()],20)
	button("‹  VOLTAR",show_scene)

func people() -> void:
	clear()
	label("♧  PESSOAS E RELAÇÕES",32,GOLD)
	label("Cada pessoa tem seus próprios objetivos e memórias.",21,MUTED)
	for role in game.world.roles:
		var person: Dictionary = game.state.people[role.id]
		portrait(role.id,"warm" if int(person.trust) > 1 else "neutral")
		var content: String = "Objetivo: %s\nConfiança: %s" % [person.goal,person.trust]
		if not person.memories.is_empty():
			var memory: Dictionary = person.memories[-1]
			content += "\nLembra que você %s (dia %s)." % [memory.summary,memory.day]
		card(content,20)
		if game.can_converse(role.id):
			button("✧  CONVERSAR COM " + person.name.to_upper() + " · 1 dia",converse.bind(role.id))
	button("‹  VOLTAR",show_scene)

func converse(role: String) -> void:
	if game.converse(role):
		people()
	else:
		clear()
		card("A conversa não pôde ser registrada.")
		button("‹  VOLTAR",people)

func news() -> void:
	clear()
	label("▤  A GAZETA LOCAL",36,GOLD)
	label("%s  ·  312 P.R." % game.render("{city}"),19,MUTED)
	if game.state.news.is_empty():
		card("Ainda não há notícias desta campanha.")
	for item in game.state.news:
		card("DIA %s  /  %s\n\n%s" % [item.day,item.source,item.text],22)
	button("‹  VOLTAR",show_scene)

func about() -> void:
	clear()
	label("✦  VEYRATH",36,GOLD)
	scene_art("city",200)
	card("A Trama é descrita pelos princípios Forma, Fluxo e Eco. Toda transformação arcana exige Compensação. A Grande Ruptura ocorreu no ano zero e a Fenda Celeste permanece visível; suas causas ainda são disputadas.")
	card("Dragões sapientes têm autonomia; dragões ferais são animais de ecologias diversas. Povos e culturas não determinam moralidade.",22)
	divider()
	label("CRÉDITOS DA EDIÇÃO",18,GOLD)
	label("Ilustrações originais criadas para Veyrath. Tipografia Latin Modern Roman, de Bogusław Jackowski e Janusz M. Nowacki, sob GUST Font License.",19,MUTED)
	button("‹  VOLTAR",menu)

func defense() -> void:
	clear()
	var screen = DefenseUI.new()
	screen.configure(game,show_scene)
	column.add_child(screen)

func multiplayer_screen() -> void:
	clear()
	var screen = MultiplayerUI.new()
	screen.configure(menu)
	column.add_child(screen)

func setup_music() -> void:
	var config := ConfigFile.new()
	if config.load("user://veyrath_config.cfg") == OK:
		music_enabled = bool(config.get_value("audio", "music", true))
		large_text = bool(config.get_value("reading", "large_text", false))
	music_player = AudioStreamPlayer.new()
	var track: AudioStreamOggVorbis = load("res://veyrath/assets/tema_cidade.ogg")
	track.loop = true
	music_player.stream = track
	music_player.volume_db = -13.0
	add_child(music_player)
	if music_enabled:
		music_player.play()

func settings() -> void:
	clear()
	label("♫  CONFIGURAÇÕES",34,GOLD)
	card("Trilha original instrumental: " + ("ativada" if music_enabled else "desativada"),22)
	button("DESATIVAR MÚSICA" if music_enabled else "ATIVAR MÚSICA",toggle_music)
	button("TEXTO DA CRÔNICA  ·  " + ("GRANDE" if large_text else "PADRÃO"),toggle_reading_size)
	button("ATUALIZAÇÕES E CONTEÚDO",updates_screen)
	button("‹  MENU PRINCIPAL",menu)

func toggle_music() -> void:
	music_enabled = not music_enabled
	if music_enabled:
		music_player.play()
	else:
		music_player.stop()
	save_preferences()
	settings()

func toggle_reading_size() -> void:
	large_text = not large_text
	save_preferences()
	settings()

func save_preferences() -> void:
	var config := ConfigFile.new()
	config.load("user://veyrath_config.cfg")
	config.set_value("audio","music",music_enabled)
	config.set_value("reading","large_text",large_text)
	if config.save("user://veyrath_config.cfg") != OK:
		notice = "Não foi possível salvar as preferências."

func character_sheet() -> void:
	clear()
	var p: Dictionary = game.profile()
	var origin: Dictionary = game.find_entry(game.world.origins,game.state.origin)
	label("◈  FICHA DE PERSONAGEM",34,GOLD)
	card("%s  ·  %s\nVIDA  %s / %s    •    FLUXO  %s    •    FADIGA  %s\nAtaque físico básico: %+d  ·  modificador de Força" % [game.state.name,origin.name,p.hp,p.max_hp,game.state.flow,game.state.fatigue,game.modifier(int(p.attributes.forca))],22)
	label("ATRIBUTOS",23,GOLD)
	var names := {"forca":"Força","agilidade":"Agilidade","vigor":"Vigor","intelecto":"Intelecto","percepcao":"Percepção","vontade":"Vontade","presenca":"Presença","tecnica":"Técnica","sintonia":"Sintonia arcana"}
	for key in names:
		label("%s   %s   (%+d)" % [names[key],p.attributes[key],game.modifier(int(p.attributes[key]))],21)
	label("O ataque é uma referência do atributo; combate de personagem e equipamentos ainda estão em desenvolvimento.",18,MUTED)
	button("‹  VOLTAR À HISTÓRIA",show_scene)

func inventory() -> void:
	clear()
	var p: Dictionary = game.profile()
	label("◉  INVENTÁRIO",34,GOLD)
	card("CURATIVO  × %s\nRecupera até 3 pontos de vida." % p.bandages,22)
	button("USAR CURATIVO",perform_basic.bind("bandage"),int(p.bandages)<=0 or int(p.hp)>=int(p.max_hp))
	label("Itens e equipamentos adicionais serão integrados à campanha conforme forem implementados.",18,MUTED)
	button("‹  VOLTAR À HISTÓRIA",show_scene)

func bestiary() -> void:
	clear()
	label("◆  BESTIÁRIO",34,GOLD)
	if game.discovered_dragon():
		card("VÉU-NOTURNO\nDragão feral pequeno e crepuscular, conhecido por imitar sons. O indivíduo observado na pedreira não demonstrou hostilidade.\n\nClassificação: feral. O motivo de sua presença precisa de investigação.",22)
	else:
		card("Nenhuma criatura foi registrada ainda. Investigações e encontros podem acrescentar informações a este livro.",22)
	button("‹  VOLTAR À HISTÓRIA",show_scene)

func world_panel() -> void:
	clear()
	label("✧  MUNDO E AÇÕES",34,GOLD)
	var local: Dictionary = game.state.get("local_world", {"supplies":5,"pressure":0})
	card("%s · dia %s, 312 P.R.\nSuprimentos locais: %s\nPressão arcana acumulada: %s" % [game.render("{city}"),game.state.day,local.supplies,local.pressure],22)
	label("A cada três dias de ações, a cidade reage às condições locais. O jogo não avança sozinho enquanto estiver fechado.",19,MUTED)
	button("DESCANSAR · 1 DIA",perform_basic.bind("rest"))
	button("INSPECIONAR A ÁREA · 1 DIA",perform_basic.bind("scout"))
	label("Inspeção: teste de Percepção em 1d20, dificuldade 12. Um sucesso encontra um curativo; uma falha causa ferimento. Intervalo mínimo de três dias.",19,MUTED)
	button("‹  VOLTAR À HISTÓRIA",show_scene)

func perform_basic(kind: String) -> void:
	var ok := false
	match kind:
		"rest": ok = game.rest()
		"bandage": ok = game.use_bandage()
		"scout": ok = game.scout()
	clear()
	if ok:
		if kind == "scout":
			var events: Array = game.state.history.duplicate()
			events.reverse()
			for event in events:
				if event.action == "scout":
					card("%s\nDado: %s + %s · dificuldade %s" % [event.description.capitalize(),event.effects.d20,event.effects.bonus,event.effects.difficulty],22)
					break
		else:
			card("Ação registrada no diário.",22)
	else:
		card("Esta ação não está disponível agora: confira os recursos, a vida ou o intervalo necessário.",22)
	button("‹  VOLTAR À HISTÓRIA",show_scene)

func interpret_input() -> void:
	proposed_action = game.interpret_action(action_input.text)
	if proposed_action.is_empty():
		action_status.text = "Não reconheci essa ação. Use um dos exemplos ou uma das escolhas numeradas."
		action_confirm.disabled = true
	else:
		action_status.text = "Entendi: " + str(proposed_action.description) + " Confirma?"
		action_confirm.disabled = false

func confirm_input() -> void:
	if proposed_action.is_empty():
		return
	match proposed_action.kind:
		"choice": select_choice(int(proposed_action.index))
		"talk":
			if game.converse(proposed_action.role):
				show_scene()
			else:
				action_status.text = "Essa conversa já aconteceu ou não está disponível."
				action_confirm.disabled = true
		"rest", "bandage", "scout": perform_basic(proposed_action.kind)

func _exit_tree() -> void:
	if is_instance_valid(music_player):
		music_player.stop()
		music_player.stream = null

func updates_screen() -> void:
	clear()
	var screen = UpdatesUI.new()
	screen.configure(game,settings,music_player)
	column.add_child(screen)
