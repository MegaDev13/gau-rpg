extends Control

const VeyrathEngine = preload("res://veyrath/engine.gd")
var game = VeyrathEngine.new()
var column: VBoxContainer
var name_input: LineEdit
var origin_input: OptionButton
var city_input: OptionButton
var notice := ""

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("101623")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["margin_left","margin_top","margin_right","margin_bottom"]:
		margin.add_theme_constant_override(side,32)
	scroll.add_child(margin)
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",20)
	margin.add_child(column)
	menu()

func clear() -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()

func label(value: String, size: int = 25, color: Color = Color("d7dfeb")) -> void:
	var item := Label.new()
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size",size)
	item.add_theme_color_override("font_color",color)
	column.add_child(item)

func button(value: String, action: Callable, disabled: bool = false) -> void:
	var item := Button.new()
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.custom_minimum_size.y = 72
	item.add_theme_font_size_override("font_size",22)
	item.disabled = disabled
	item.pressed.connect(action)
	column.add_child(item)

func menu() -> void:
	clear()
	label("VEYRATH",48,Color("e7bf79"))
	label("O CÉU SOB FERRO",27,Color("f6e3bd"))
	label("Um mundo com memória. Seu futuro começa com escolhas.")
	if not notice.is_empty():
		label(notice,21,Color("f3bd79"))
		notice = ""
	button("NOVO JOGO",creation)
	button("CONTINUAR VEYRATH",continue_game)
	button("CAMPANHA ANTERIOR: CINZAS DE ÉTER",legacy)
	button("SOBRE O MUNDO",about)
	label("Campanha solo • offline • versão inicial",20)

func creation() -> void:
	clear()
	label("SUA HISTÓRIA",38,Color("e7bf79"))
	label("Nome")
	name_input = LineEdit.new()
	name_input.placeholder_text = "Nome do personagem adulto"
	name_input.max_length = 40
	name_input.custom_minimum_size.y = 70
	name_input.add_theme_font_size_override("font_size",24)
	column.add_child(name_input)
	label("Origem")
	origin_input = OptionButton.new()
	origin_input.custom_minimum_size.y = 70
	origin_input.add_theme_font_size_override("font_size",21)
	for origin in game.world.origins:
		origin_input.add_item(origin.name)
	column.add_child(origin_input)
	label("Cidade inicial")
	city_input = OptionButton.new()
	city_input.custom_minimum_size.y = 70
	city_input.add_theme_font_size_override("font_size",21)
	for city in game.world.cities:
		city_input.add_item(city.name + " · " + city.region)
	column.add_child(city_input)
	label("Uma nova campanha substitui o progresso anterior de Veyrath. A campanha Cinzas de Éter permanece separada.",19)
	for origin in game.world.origins:
		label(origin.name + ": " + origin.detail,19)
	button("COMEÇAR",start_game)
	button("VOLTAR",menu)

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

func show_scene() -> void:
	clear()
	var scene: Dictionary = game.story[game.state.node]
	label(game.render("{city}") + " · Dia %s · 312 P.R." % game.state.day,19,Color("e7bf79"))
	label(scene.title,36,Color("f6e3bd"))
	label(game.render(scene.text))
	if scene.choices.is_empty():
		label(game.reaction(),22,Color("e7bf79"))
		label("Esta crise local terminou; a história do mundo continua em futuras atualizações.",20)
	else:
		label("SUA DECISÃO",20,Color("e7bf79"))
	for i in range(scene.choices.size()):
		var choice: Dictionary = scene.choices[i]
		button(choice.label if game.available(choice) else choice.label + " — requisito não atendido",select_choice.bind(i),not game.available(choice))
	button("PERSONAGEM E DIÁRIO",journal)
	button("PESSOAS",people)
	button("JORNAL LOCAL",news)
	button("MENU PRINCIPAL",menu)

func select_choice(index: int) -> void:
	if game.choose(index):
		show_scene()
	else:
		clear()
		label("Não foi possível salvar a decisão. Tente novamente.")
		button("VOLTAR",show_scene)

func journal() -> void:
	clear()
	label("PERSONAGEM E DIÁRIO",34,Color("e7bf79"))
	var origin := game.find_entry(game.world.origins,game.state.origin)
	label("%s · %s\nCréditos: %s · Fluxo: %s · Fadiga: %s\nRisco arcano local: %s" % [game.state.name,origin.name,game.state.credits,game.state.flow,game.state.fatigue,game.state.risk])
	for event in game.state.history:
		label("Dia %s, %s: %s." % [event.day,game.render("{city}"),event.description],21)
	button("VOLTAR",show_scene)

func people() -> void:
	clear()
	label("PESSOAS DA CIDADE",34,Color("e7bf79"))
	for role in game.world.roles:
		var person: Dictionary = game.state.people[role.id]
		label("%s — %s\nObjetivo: %s" % [person.name,person.job,person.goal],22)
		if not person.memories.is_empty():
			var memory: Dictionary = person.memories[-1]
			label("Lembra que você %s (dia %s)." % [memory.summary,memory.day],20)
	button("VOLTAR",show_scene)

func news() -> void:
	clear()
	label("GAZETA LOCAL",34,Color("e7bf79"))
	if game.state.news.is_empty():
		label("Ainda não há notícias desta campanha.")
	for item in game.state.news:
		label("Dia %s · %s\n%s" % [item.day,item.source,item.text],22)
	button("VOLTAR",show_scene)

func about() -> void:
	clear()
	label("VEY RATH — O MUNDO".replace("VEY RATH","VEYRATH"),32,Color("e7bf79"))
	label("A Trama é descrita pelos princípios Forma, Fluxo e Eco. Toda transformação arcana exige Compensação. A Grande Ruptura ocorreu no ano zero e a Fenda Celeste permanece visível; suas causas ainda são disputadas.")
	label("Dragões sapientes têm autonomia; dragões ferais são animais de ecologias diversas. Povos e culturas não determinam moralidade.")
	button("VOLTAR",menu)
