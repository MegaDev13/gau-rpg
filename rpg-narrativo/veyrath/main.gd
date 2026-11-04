extends Control

const VeyrathEngine = preload("res://veyrath/engine.gd")
const Stage = preload("res://veyrath/pixel_stage.gd")
const Icons = preload("res://veyrath/pixel_icons.gd")
const DefenseUI = preload("res://veyrath/defense_ui.gd")
const MultiplayerUI = preload("res://veyrath/multiplayer_ui.gd")
const UpdatesUI = preload("res://veyrath/updates/updates_ui.gd")
const GOLD := Color("d6b47d")
const TEXT := Color("f1e6d3")
const MUTED := Color("bcb3a3")
const INK := Color("0d121b")
const PANEL := Color("192331")
const RULE := Color("82613f")
const EDITION := "res://veyrath/assets/edition/"
const ILLUSTRATIONS := {
	"cover": "capa.png", "city": "valdoria.png", "council": "conselho.png",
	"workshop": "oficina.png", "river": "margem.png", "quarry": "pedreira.png",
	"archive": "arquivo.png", "highlands": "tharvok.png", "fort": "posto.png",
	"elarion":"elarion.png","khar":"khar.png","namaris":"namaris.png","nexaria":"nexaria.png",
	"inn":"inn.png","market":"market.png","lab":"lab.png","temple":"temple.png",
	"fields":"fields.png","forest":"forest.png","rail":"rail.png","mine":"mine.png",
}
const ART_MOODS := {
	"cover": "mist", "city": "mist", "highlands": "mist", "river": "rain",
	"workshop": "embers", "quarry": "embers", "council": "rain",
	"archive": "mist", "fort": "embers",
}
var motion_enabled := true
var reading_node := ""
var reading_page := 0
var actions_expanded := false
var portraits: Dictionary = {}
var icons: Dictionary = {}
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
	var theme_game := Theme.new()
	theme_game.set_color("font_color","Label",TEXT)
	theme_game.set_color("font_color","Button",TEXT)
	theme_game.set_stylebox("normal","Button",style(PANEL,RULE,12))
	theme_game.set_stylebox("hover","Button",style(Color("263746"),GOLD,12))
	theme_game.set_stylebox("pressed","Button",style(Color("314345"),GOLD,12))
	theme_game.set_stylebox("disabled","Button",style(Color("141b25"),Color("434657"),12))
	theme_game.set_stylebox("normal","LineEdit",style(INK,RULE,12))
	theme_game.set_stylebox("normal","OptionButton",style(PANEL,RULE,12))
	theme = theme_game
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
	box.set_border_width_all(2)
	box.set_border_width(SIDE_BOTTOM,4)
	box.set_border_width(SIDE_LEFT,4)
	box.set_shadow_color(Color("060912a0"))
	box.set_shadow_size(4)
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

func button(value: String, action: Callable, disabled: bool = false, parent: Control = column) -> Button:
	var item := Button.new()
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.custom_minimum_size.y = 74
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_font_size_override("font_size",21)
	item.add_theme_color_override("font_color",TEXT)
	item.add_theme_color_override("font_disabled_color",Color("7b8382"))
	item.add_theme_stylebox_override("normal",style(PANEL,RULE,17))
	item.add_theme_stylebox_override("hover",style(Color("263746"),GOLD,17))
	item.add_theme_stylebox_override("pressed",style(Color("314345"),GOLD,17))
	item.add_theme_stylebox_override("disabled",style(Color("141b25"),Color("434657"),17))
	item.disabled = disabled
	item.pressed.connect(action)
	parent.add_child(item)
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
	if not illustrations.has(which) and ILLUSTRATIONS.has(which):
		var texture := Stage.load_pixel(ILLUSTRATIONS[which])
		if texture:
			illustrations[which] = texture
	return illustrations.get(which)

func icon(key: String, tint: Color) -> Texture2D:
	var id := key + tint.to_html()
	if not icons.has(id):
		icons[id] = Icons.icon(key,tint,4)
	return icons[id]

func portrait_texture(role: String) -> Texture2D:
	if not portraits.has(role):
		var texture := Stage.load_pixel("npc_%s.png" % role)
		if texture:
			portraits[role] = texture
	return portraits.get(role)

func stage_for(which: String, height: int, role: String = "") -> Control:
	var view = Stage.new()
	view.art = illustration(which)
	view.atmosphere = ART_MOODS.get(which,"mist")
	view.motion = motion_enabled
	view.custom_minimum_size.y = height
	if which == "cover":
		view.vertical_focus = 0.23
	if not game.state.is_empty() and which != "cover":
		view.spark_seed = int(game.state.day)
		var pressure := int(game.state.get("local_world",{}).get("pressure",0))
		view.intensity = clampf(0.25 + float(pressure) * 0.15,0.25,1.0)
		if pressure > 1 and which in ["city","highlands","workshop","river"]:
			view.atmosphere = "embers"
			view.light = Color("61bea5")
		if int(game.state.day) % 3 == 0 and pressure < 2:
			view.light = Color("6c86a8")
	if not role.is_empty():
		view.face = portrait_texture(role)
		view.subject_pin = game.portrait_variant(role)
		if int(game.state.people[role].trust) > 1:
			view.reaction_light = GOLD
	return view

func scene_art(which: String, height: int = 225, role: String = "") -> void:
	column.add_child(stage_for(which,height,role))

func portrait(role: String, mood: String = "neutral") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	column.add_child(row)
	var person: Dictionary = game.state.people[role]
	var visual = Stage.new()
	visual.art = portrait_texture(role)
	visual.light = Color("c6a16b") if mood == "warm" else Color("657b9c")
	visual.intensity = 0.8 if mood == "warm" else 0.35
	visual.motion = false
	visual.subject_pin = game.portrait_variant(role)
	visual.custom_minimum_size = Vector2(144,144)
	row.add_child(visual)
	var info := Label.new()
	info.text = person.name.to_upper() + "\n" + person.job
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("font_size",22)
	info.add_theme_color_override("font_color",GOLD)
	row.add_child(info)

func menu() -> void:
	clear()
	var opening := stage_for("cover",610)
	column.add_child(opening)
	var emblem := Label.new()
	emblem.text = "V E Y R A T H"
	emblem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emblem.add_theme_font_size_override("font_size",68)
	emblem.add_theme_color_override("font_color",TEXT)
	emblem.add_theme_color_override("font_shadow_color",INK)
	emblem.add_theme_constant_override("shadow_offset_x",3)
	emblem.add_theme_constant_override("shadow_offset_y",4)
	emblem.add_theme_constant_override("outline_size",5)
	emblem.add_theme_color_override("font_outline_color",INK)
	if reading_font:
		emblem.add_theme_font_override("font",reading_font)
	emblem.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	emblem.offset_top = 46
	opening.add_child(emblem)
	var subtitle := Label.new()
	subtitle.text = "◆   O CÉU SOB FERRO   ◆"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size",24)
	subtitle.add_theme_color_override("font_color",GOLD)
	subtitle.add_theme_constant_override("outline_size",5)
	subtitle.add_theme_color_override("font_outline_color",INK)
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top = 127
	opening.add_child(subtitle)
	if not notice.is_empty():
		card(notice,20)
		notice = ""
	var controls := GridContainer.new()
	controls.columns = 2
	controls.add_theme_constant_override("h_separation",12)
	controls.add_theme_constant_override("v_separation",12)
	column.add_child(controls)
	var has_save: bool = game.valid(game.read_save(game.SAVE)) or game.valid(game.read_save(game.BACKUP))
	button("Continuar",continue_game,not has_save,controls).icon = icon("book",GOLD)
	button("Nova história",creation,false,controls).icon = icon("flow",GOLD)
	button("Multiplayer",multiplayer_screen,false,controls).icon = icon("shield",GOLD)
	button("Configurações",settings,false,controls)
	button("Sobre e créditos",about,false,controls)
	button("Cinzas de Éter",legacy,false,controls)
	label("CRÔNICAS DO CÉU PARTIDO   /   312 P.R.",16,GOLD,false,true)

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
	reading_node = ""
	if game.new_game(name_input.text,game.world.origins[origin_input.selected].id,game.world.cities[city_input.selected].id):
		show_scene()
	else:
		notice = "Não foi possível salvar."
		menu()

func continue_game() -> void:
	reading_node = ""
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
	if game.expedition().city != game.expansion.home_id(game.state.city):
		if game.expedition().place.is_empty():
			settlement_screen()
		else:
			place_screen()
		return
	clear()
	var node: String = game.state.node
	var scene: Dictionary = game.story[node]
	if reading_node != node:
		reading_node = node
		reading_page = 0
		actions_expanded = false
	var place := scene_place(node)
	if place == "city" and game.state.city == "tharvok":
		place = "highlands"
	var role := scene_person(node)
	label(chapter_label(node),17,GOLD)
	scene_art(place,322,role)
	label("%s  ·  DIA %s  ·  312 P.R." % [game.render("{city}"),game.state.day],17,MUTED)
	label(scene.title,44,TEXT,true)
	if not role.is_empty():
		label("%s  /  %s" % [game.state.people[role].name.to_upper(),game.state.people[role].job],17,GOLD)
	var pages: PackedStringArray = game.scene_text().split("\n\n",false)
	reading_page = clampi(reading_page,0,pages.size()-1)
	card(pages[reading_page],38 if large_text else 32,true)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation",10)
	column.add_child(navigation)
	button("‹  Anterior",turn_page.bind(-1),reading_page == 0,navigation)
	button("%d / %d   Próxima ›" % [reading_page+1,pages.size()],turn_page.bind(1),reading_page+1 == pages.size(),navigation)
	if reading_page + 1 == pages.size():
		if node == "start":
			label("ORIGEM  /  " + game.render("{origin}"),18,GOLD)
			label(game.find_entry(game.world.origins,game.state.origin).detail,20,MUTED)
		if scene.choices.is_empty():
			label("DESFECHO DA CRÔNICA",18,GOLD)
			card(game.reaction(),25,true)
		else:
			label("SUA DECISÃO",18,GOLD)
			for i in range(scene.choices.size()):
				var choice: Dictionary = scene.choices[i]
				var reason: String = game.choice_block_reason(choice)
				var detail := reason if not reason.is_empty() else known_cost(choice)
				button("%02d  %s\n%s" % [i+1,choice.label,detail],select_choice.bind(i),not reason.is_empty())
			button("Fechar comando escrito" if actions_expanded else "Escrever uma ação",toggle_actions)
			if actions_expanded:
				written_actions()
	divider()
	button("Registros da campanha",campaign_records).icon = icon("book",GOLD)
	button("‹  Menu principal",menu)

func known_cost(choice: Dictionary) -> String:
	var effects: Dictionary = choice.get("effects",{})
	var parts := PackedStringArray()
	if int(effects.get("time",0)) > 0:
		parts.append("%d dia(s)" % int(effects.time))
	var credits := int(effects.get("credits",0))
	if game.state.origin != "apprentice":
		credits += int(effects.get("credits_or_origin",0))
	if credits < 0:
		parts.append("%d crédito(s)" % -credits)
	var flow := int(effects.get("flow",0))
	if flow < 0:
		parts.append("%d Fluxo" % -flow)
	return "  ·  ".join(parts)

func turn_page(delta: int) -> void:
	reading_page += delta
	show_scene()

func toggle_actions() -> void:
	actions_expanded = not actions_expanded
	show_scene()
	if actions_expanded:
		action_input.grab_focus()

func written_actions() -> void:
	action_input = LineEdit.new()
	action_input.placeholder_text = "Ex.: escolha 1, descansar, falar com Aren"
	action_input.custom_minimum_size.y = 70
	action_input.add_theme_font_size_override("font_size",21)
	column.add_child(action_input)
	button("Interpretar ação",interpret_input)
	action_status = Label.new()
	action_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_status.add_theme_font_size_override("font_size",20)
	action_status.add_theme_color_override("font_color",GOLD)
	action_status.text = "Comandos simples: escolha 1, descansar, usar curativo, investigar a área ou falar com [nome]."
	column.add_child(action_status)
	action_confirm = button("Confirmar ação",confirm_input,true)
	proposed_action = {}

func campaign_records() -> void:
	clear()
	label("REGISTROS DA CAMPANHA",19,GOLD)
	label("O mundo lembra",49,TEXT,true)
	divider()
	var at_home: bool = game.expedition().city == game.expansion.home_id(game.state.city)
	button("◈  FICHA E ATRIBUTOS",character_sheet)
	button("◉  INVENTÁRIO",inventory)
	button("◆  BESTIÁRIO",bestiary)
	if at_home:
		button("Grimório",grimoire).icon = icon("book",GOLD)
	button("Atlas regional",atlas)
	if at_home:
		button("✧  MUNDO E AÇÕES",world_panel)
	button("▤  DIÁRIO",journal)
	if at_home:
		button("♧  PESSOAS E RELAÇÕES",people)
	button("▤  JORNAL LOCAL",news)
	if at_home:
		button("⚔  DEFESA DO POSTO",defense)
	button("Configurações",settings)
	button("‹  Voltar à leitura" if at_home else "‹  Voltar à expedição",show_scene)

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
		var location: Dictionary = game.expansion.city(str(event.get("city","")),int(game.state.seed))
		var city_name: String = location.get("name",game.render("{city}"))
		card("DIA %s  ·  %s\n%s" % [event.day,city_name,event.description.capitalize()],20)
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
	scene_art("fort",238)
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
		motion_enabled = bool(config.get_value("visual", "motion", true))
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
	button("AMBIENTAÇÃO EM MOVIMENTO  ·  " + ("SIM" if motion_enabled else "NÃO"),toggle_motion)
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

func toggle_motion() -> void:
	motion_enabled = not motion_enabled
	save_preferences()
	settings()

func save_preferences() -> void:
	var config := ConfigFile.new()
	config.load("user://veyrath_config.cfg")
	config.set_value("audio","music",music_enabled)
	config.set_value("reading","large_text",large_text)
	config.set_value("visual","motion",motion_enabled)
	if config.save("user://veyrath_config.cfg") != OK:
		notice = "Não foi possível salvar as preferências."

func character_sheet() -> void:
	clear()
	var p: Dictionary = game.profile()
	var origin: Dictionary = game.find_entry(game.world.origins,game.state.origin)
	label("◈  FICHA DE PERSONAGEM",34,GOLD)
	scene_art("highlands" if game.state.city == "tharvok" else "city",175)
	label(game.state.name,43,TEXT,true)
	label(origin.name + "  ·  " + game.render("{city}"),20,GOLD)
	meter("Vida",int(p.hp),int(p.max_hp),Color("b95964"))
	label("Fluxo disponível  %d   ·   Fadiga  %d" % [game.state.flow,game.state.fatigue],21,GOLD)
	label("Ataque físico  %+d" % game.modifier(int(p.attributes.forca)),21,MUTED)
	label("ATRIBUTOS",23,GOLD)
	var names := {"forca":"Força","agilidade":"Agilidade","vigor":"Vigor","intelecto":"Intelecto","percepcao":"Percepção","vontade":"Vontade","presenca":"Presença","tecnica":"Técnica","sintonia":"Sintonia arcana"}
	for key in names:
		label("%s   %s   (%+d)" % [names[key],p.attributes[key],game.modifier(int(p.attributes[key]))],21)
	label("O ataque é uma referência do atributo; combate de personagem e equipamentos ainda estão em desenvolvimento.",18,MUTED)
	button("‹  VOLTAR À HISTÓRIA",show_scene)

func meter(title: String, value: int, maximum: int, tint: Color) -> void:
	label("%s   %d / %d" % [title,value,maximum],21,GOLD)
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 22
	bar.max_value = maximum
	bar.value = value
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background",style(INK,RULE,0))
	bar.add_theme_stylebox_override("fill",style(tint,tint,0))
	column.add_child(bar)

func grimoire() -> void:
	clear()
	scene_art("workshop",230)
	label("Grimório",48,TEXT,true)
	label("TRAMA   /   FORMA · FLUXO · ECO",17,GOLD)
	card("Eco permite buscar resíduos arcanos no núcleo. A prática exige formação de bolsista. Cada tentativa consome 1 Fluxo e causa 1 ponto de fadiga.",24,true)
	for i in range(game.story[game.state.node].choices.size()):
		var choice: Dictionary = game.story[game.state.node].choices[i]
		if choice.id == "echo":
			var reason: String = game.choice_block_reason(choice)
			button("Executar leitura de Eco" if reason.is_empty() else reason,select_choice.bind(i),not reason.is_empty()).icon = icon("flow",Color("81cbb1"))
			break
	button("‹  Registros",campaign_records)

func atlas() -> void:
	clear()
	label("Atlas de Veyrath",48,TEXT,true)
	var current: Dictionary = game.expedition_city()
	label("POSIÇÃO  /  " + current.name.to_upper(),17,GOLD)
	button("Explorar " + current.name,settlement_screen).icon = icon("shield",GOLD)
	for index in range(game.expansion.catalog.regions.size()):
		var region: Dictionary = game.expansion.catalog.regions[index]
		button("%s   ·   %s" % [region.name,region.economy],region_screen.bind(index))
	button("‹  Registros",campaign_records)

func region_screen(index: int) -> void:
	clear()
	var region: Dictionary = game.expansion.catalog.regions[index]
	var seed_value := int(game.state.seed)
	scene_art(expansion_art(region.art),272)
	label(region.name,48,TEXT,true)
	card(region.economy + "\n" + region.government,21)
	for slot in range(region.cities.size()):
		var city_id := "%s-%d" % [region.id,slot]
		var entry: Dictionary = game.expansion.city(city_id,seed_value)
		button("%s   ·   %s" % [entry.name,entry.size],travel_screen.bind(city_id))
	button("‹  Atlas",atlas)

func expansion_art(key: String) -> String:
	return {"valdoria":"city","tharvok":"highlands","conselho":"council","oficina":"workshop",
		"margem":"river","pedreira":"quarry","arquivo":"archive","posto":"fort"}.get(key,key)

func expedition_stage(key: String, conditions: Dictionary, site: Dictionary = {}) -> void:
	var view := stage_for(expansion_art(key),272)
	view.atmosphere = conditions.weather
	if conditions.daylight == 0:
		view.light = Color("717db1")
		view.intensity = 0.95
	elif conditions.daylight == 3:
		view.light = Color("ce9270")
		view.intensity = 0.70
	if not site.is_empty():
		view.site_trim = site.trim
		view.site_kind = site.kind
		view.shortage = int(conditions.supply) < 10
	column.add_child(view)

func travel_screen(destination_id: String) -> void:
	var current: Dictionary = game.expedition_city()
	if destination_id == current.id:
		settlement_screen()
		return
	clear()
	var destination: Dictionary = game.expansion.city(destination_id,int(game.state.seed))
	scene_art(expansion_art(destination.art),242)
	label(destination.name,47,TEXT,true)
	label(destination.region_name.to_upper() + "   /   " + destination.size,18,GOLD)
	card("Partida de %s. Você tem %d créditos." % [current.name,game.state.credits],23)
	for fast in [false,true]:
		var plan: Dictionary = game.expansion.route(current,destination,fast)
		button("%s   ·   %d dia(s)   ·   %d créditos" % [plan.method,plan.days,plan.credits],
			travel.bind(destination_id,fast),int(game.state.credits) < int(plan.credits))
	button("‹  Região",region_screen.bind(int(destination.region)))

func travel(destination_id: String, fast: bool) -> void:
	if game.travel_to(destination_id,fast):
		settlement_screen()
	else:
		travel_screen(destination_id)
		label("A viagem não pôde ser registrada.",20,GOLD)

func settlement_screen() -> void:
	clear()
	var city: Dictionary = game.expedition_city()
	var conditions: Dictionary = game.expansion.condition(city,int(game.state.seed),int(game.state.day),game.expedition().backing)
	label("%s   /   DIA %s" % [city.region_name.to_upper(),game.state.day],17,GOLD)
	expedition_stage(city.art,conditions)
	label(city.name,47,TEXT,true)
	card("%s · cerca de %s habitantes\nReservas %s   ·   Vigilância %s/10\n%s\n%s" % [city.size,conditions.population,conditions.supply,conditions.security,city.economy,city.government],22)
	var project: Dictionary = conditions.project
	card(initiative_text(project),21,true)
	if not conditions.previous_project.is_empty():
		label("O CICLO ANTERIOR",17,GOLD)
		card(initiative_text(conditions.previous_project),20,true)
	label("DISTRITOS E ESTABELECIMENTOS",17,GOLD)
	for site in game.expansion.places(city,int(game.state.seed)):
		button("%s   ·   %s" % [site.name,site.district],open_place.bind(site.id))
	button("Explorar outras regiões",atlas)
	button("Registros da campanha",campaign_records).icon = icon("book",GOLD)
	var home: String = game.expansion.home_id(game.state.city)
	button("Voltar à crônica" if city.id == home else "Rota de volta à crônica",show_scene if city.id == home else travel_screen.bind(home))
	button("‹  Menu principal",menu)

func initiative_text(project: Dictionary) -> String:
	var text := "%s quer %s em %s. %s ajuda a organizar." % [project.lead.name,project.lead.goal,project.site_name,project.partner.name]
	match project.phase:
		"realizado": return text + "\nProjeto realizado. As reservas locais aumentaram."
		"adiado": return text + "\nProjeto adiado por falta de fundos. As reservas ficaram sob pressão."
		_: return text + ("\nApoio registrado." if project.backed else "\nRecursos próprios reunidos." if project.self_funded else "\nO prazo para reunir os recursos termina no dia %d." % project.deadline)

func open_place(place_id: String) -> void:
	if game.enter_place(place_id):
		place_screen()
	else:
		label("O local não pôde ser registrado.",20,GOLD)

func place_screen() -> void:
	var journey: Dictionary = game.expedition()
	var site: Dictionary = game.expansion.place(journey.place,int(game.state.seed))
	if site.is_empty():
		settlement_screen()
		return
	clear()
	var city: Dictionary = game.expedition_city()
	var conditions: Dictionary = game.expansion.condition(city,int(game.state.seed),int(game.state.day),journey.backing)
	label("%s   /   %s" % [city.name.to_upper(),site.district.to_upper()],17,GOLD)
	expedition_stage(site.art,conditions,site)
	label(site.name,42,TEXT,true)
	label("SERVIÇOS  /  " + site.goods,20,GOLD)
	if site.kind in ["market","temple"]:
		button("Comprar curativo   ·   2 créditos",use_service.bind("bandage"),game.state.credits < 2).icon = icon("bandage",GOLD)
	elif site.kind == "inn":
		button("Pernoitar   ·   1 crédito e 1 dia",use_service.bind("lodging"),game.state.credits < 1)
	var initiative: Dictionary = conditions.project
	if initiative.site == site.id:
		card(initiative_text(initiative),22,true)
		if initiative.phase == "pedido" and not initiative.backed and not initiative.self_funded:
			button("Apoiar a iniciativa   ·   %d créditos" % initiative.cost,back_project.bind(initiative.id),game.state.credits < initiative.cost)
	divider()
	label("QUEM TRABALHA AQUI",17,GOLD)
	for staff in range(4):
		var resident: Dictionary = game.expansion.person(site,staff,int(game.state.seed))
		var present: bool = game.expansion.present(resident,int(game.state.day))
		button("%s   ·   %s%s" % [resident.name,resident.job,"" if present else "  /  folga"],resident_screen.bind(staff))
	button("‹  " + city.name,settlement_screen)

func resident_art(actor: Dictionary) -> Texture2D:
	var bases := {"Humano":[0,6],"Dhorvak":[1],"Aelthari":[2,7],"Nymari":[3],"Varkhen":[4],"Eidrino":[5]}
	var candidates: Array = bases[actor.people]
	var key := "world_npc_%d.png" % candidates[int(actor.pin)%candidates.size()]
	if not portraits.has(key):
		portraits[key] = Stage.load_pixel(key)
	return portraits[key]

func resident_screen(staff: int) -> void:
	clear()
	var journey: Dictionary = game.expedition()
	var site: Dictionary = game.expansion.place(journey.place,int(game.state.seed))
	var actor: Dictionary = game.expansion.person(site,staff,int(game.state.seed))
	var present: bool = game.expansion.present(actor,int(game.state.day))
	var view = Stage.new()
	view.art = illustration(expansion_art(site.art))
	view.face = resident_art(actor)
	view.subject_pin = actor.pin
	view.motion = motion_enabled
	view.custom_minimum_size.y = 272
	column.add_child(view)
	label(actor.name,43,TEXT,true)
	label("%s  ·  %s  ·  %d anos" % [actor.people,actor.job,actor.age],20,GOLD)
	var coworker: Dictionary = game.expansion.person(site,(staff+1)%4,int(game.state.seed))
	var birthplace: Dictionary = game.expansion.city(actor.birthplace,int(game.state.seed))
	var detail := "%s. Nasceu em %s e trabalha em %s com %s. Valoriza %s e quer %s." % [actor.personality,birthplace.name,site.name,coworker.name,actor.value,actor.goal]
	if not actor.household.is_empty():
		var relative: Dictionary = game.expansion.person(site,1-staff,int(game.state.seed))
		detail += " Divide a casa com %s." % relative.name
	card(detail,24,true)
	if journey.known.has(actor.id):
		card("MEMÓRIA DO DIA %s\n%s" % [journey.known[actor.id].day,journey.known[actor.id].memory],21)
	elif present:
		button("Conhecer   ·   1 dia",meet_person.bind(staff))
	else:
		label("Hoje está de folga. O turno volta amanhã.",20,MUTED)
	button("‹  Voltar ao estabelecimento",place_screen)

func meet_person(staff: int) -> void:
	var success: bool = game.meet_resident(staff)
	resident_screen(staff)
	if not success:
		label("O encontro não pôde ser registrado.",20,GOLD)

func use_service(kind: String) -> void:
	var success: bool = game.expedition_service(kind)
	place_screen()
	label("Serviço registrado no diário." if success else "O serviço não está disponível.",20,GOLD)

func back_project(expected_id: String) -> void:
	var success: bool = game.back_initiative(expected_id)
	place_screen()
	if not success:
		label("A iniciativa mudou ou faltam créditos.",20,GOLD)

func inventory() -> void:
	clear()
	var p: Dictionary = game.profile()
	label("INVENTÁRIO   /   PERTENCES",17,GOLD)
	label("Bolsa de viagem",48,TEXT,true)
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation",20)
	column.add_child(item)
	var drawing := TextureRect.new()
	drawing.texture = Icons.icon("bandage",Color("ead6aa"),11)
	drawing.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	drawing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item.add_child(drawing)
	var details := Label.new()
	details.text = "CURATIVO  × %s\nRecupera até 3 pontos de vida." % p.bandages
	details.add_theme_font_size_override("font_size",23)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_child(details)
	button("USAR CURATIVO",perform_basic.bind("bandage"),int(p.bandages)<=0 or int(p.hp)>=int(p.max_hp)).icon = icon("bandage",GOLD)
	label("Itens e equipamentos adicionais serão integrados à campanha conforme forem implementados.",18,MUTED)
	button("‹  VOLTAR À HISTÓRIA",show_scene)

func bestiary() -> void:
	clear()
	label("◆  BESTIÁRIO",34,GOLD)
	if game.discovered_dragon():
		scene_art("quarry",260)
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
