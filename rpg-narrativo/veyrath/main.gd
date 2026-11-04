extends Control

const VeyrathEngine = preload("res://veyrath/engine.gd")
const Art = preload("res://veyrath/art.gd")
const GOLD := Color("d6b47d")
const TEXT := Color("e7e0d2")
const MUTED := Color("aeb6b7")
var game = VeyrathEngine.new()
var column: VBoxContainer
var scroll: ScrollContainer
var name_input: LineEdit
var origin_input: OptionButton
var city_input: OptionButton
var notice := ""

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("101a25")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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
	column.add_theme_constant_override("separation",14)
	margin.add_child(column)
	menu()

func style(bg: Color, border: Color, padding: int = 14) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(padding)
	return box

func clear() -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	scroll.scroll_vertical = 0

func label(value: String, font_size: int = 25, color: Color = TEXT) -> void:
	var item := Label.new()
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",color)
	column.add_child(item)

func button(value: String, action: Callable, disabled: bool = false) -> void:
	var item := Button.new()
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.custom_minimum_size.y = 74
	item.add_theme_font_size_override("font_size",21)
	item.add_theme_color_override("font_color",TEXT)
	item.add_theme_color_override("font_disabled_color",Color("7b8382"))
	item.add_theme_stylebox_override("normal",style(Color("243544"),Color("7b6c58"),15))
	item.add_theme_stylebox_override("hover",style(Color("354a55"),GOLD,15))
	item.add_theme_stylebox_override("pressed",style(Color("325c5b"),GOLD,15))
	item.add_theme_stylebox_override("disabled",style(Color("1b252d"),Color("47504f"),15))
	item.disabled = disabled
	item.pressed.connect(action)
	column.add_child(item)

func card(value: String, font_size: int = 25) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",style(Color("1b2934"),Color("725f49"),22))
	var content := Label.new()
	content.text = value
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_theme_font_size_override("font_size",font_size)
	content.add_theme_color_override("font_color",TEXT)
	panel.add_child(content)
	column.add_child(panel)

func scene_art(which: String, height: int = 225) -> void:
	if which == "city":
		var image := TextureRect.new()
		image.texture = load("res://veyrath/assets/val_doria.jpg")
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.custom_minimum_size = Vector2(0,height)
		image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(image)
		return
	var visual = Art.new()
	visual.kind = "scene"
	visual.scene_id = which
	visual.custom_minimum_size = Vector2(0,height)
	visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(visual)

func portrait(role: String, mood: String = "neutral") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	column.add_child(row)
	var visual = Art.new()
	visual.kind = "portrait"
	visual.variant = game.portrait_variant(role)
	visual.expression = mood
	visual.custom_minimum_size = Vector2(150,110)
	row.add_child(visual)
	var person: Dictionary = game.state.people[role]
	var info := Label.new()
	info.text = person.name.to_upper() + "\n" + person.job
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("font_size",20)
	info.add_theme_color_override("font_color",GOLD)
	row.add_child(info)

func menu() -> void:
	clear()
	label("CRÔNICAS DO CÉU PARTIDO",17,MUTED)
	label("VEYRATH",52,GOLD)
	label("O CÉU SOB FERRO",24,TEXT)
	scene_art("city",230)
	label("Um mundo com memória. Um futuro que você ajuda a escrever.",21,MUTED)
	if not notice.is_empty():
		card(notice,20)
		notice = ""
	button("✦  NOVO JOGO",creation)
	button("◈  CONTINUAR VEYRATH",continue_game)
	button("▣  CAMPANHA ANTERIOR: CINZAS DE ÉTER",legacy)
	button("☼  SOBRE O MUNDO",about)
	label("CAMPANHA SOLO  •  OFFLINE",16,MUTED)

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
	if node in ["council","peace","industry","environment","aftermath_wait"]:
		return "council"
	if node in ["workshop","investigation","evidence"]:
		return "workshop"
	return "city"

func scene_person(node: String) -> String:
	match node:
		"workshop": return "artisan"
		"investigation", "evidence", "dragon": return "researcher"
		"river", "environment", "peace": return "community"
		"council", "aftermath_wait": return "leader"
		"industry": return "artisan"
		_: return ""

func show_scene() -> void:
	clear()
	var scene: Dictionary = game.story[game.state.node]
	label("◆ " + game.render("{city}").to_upper() + "   ·   DIA %s   ·   312 P.R." % game.state.day,17,GOLD)
	scene_art(scene_place(game.state.node),210)
	label(scene.title,34,GOLD)
	var role := scene_person(game.state.node)
	if not role.is_empty():
		portrait(role, "warm" if int(game.state.people[role].trust) > 1 else "neutral")
	card(game.render(scene.text),24)
	if scene.choices.is_empty():
		card(game.reaction(),21)
		label("Esta crise local terminou; o mundo continuará em futuras atualizações.",19,MUTED)
	else:
		label("ESCOLHA SEU CAMINHO",18,GOLD)
	for i in range(scene.choices.size()):
		var choice: Dictionary = scene.choices[i]
		button("›  " + (choice.label if game.available(choice) else choice.label + " — requisito não atendido"),select_choice.bind(i),not game.available(choice))
	label("EXPLORAR REGISTROS",18,GOLD)
	button("◈  PERSONAGEM E DIÁRIO",journal)
	button("♧  PESSOAS E RELAÇÕES",people)
	button("▤  JORNAL LOCAL",news)
	button("‹  MENU PRINCIPAL",menu)

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
	button("‹  VOLTAR",menu)
