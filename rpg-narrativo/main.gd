extends Control

const EngineScript = preload("res://engine.gd")
var game = EngineScript.new()
var column: VBoxContainer
var name_input: LineEdit
var class_input: OptionButton
var notice := ""

func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("101623")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 32)
	scroll.add_child(margin)
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 20)
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
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	column.add_child(item)

func button(value: String, action: Callable) -> void:
	var item := Button.new()
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.custom_minimum_size.y = 72
	item.add_theme_font_size_override("font_size", 23)
	item.pressed.connect(action)
	column.add_child(item)

func menu() -> void:
	clear()
	label("CINZAS DE ÉTER", 46, Color("e7bf79"))
	label("Uma cidade. Muitas escolhas. Consequências que permanecem.", 24)
	if not notice.is_empty():
		label(notice, 22, Color("f3bd79"))
		notice = ""
	button("NOVO JOGO", creation)
	button("CONTINUAR", continue_game)
	button("CRÉDITOS", credits)
	label("Campanha solo • funciona offline\nVersão inicial: capítulo 1", 20)

func creation() -> void:
	clear()
	label("CRIE SEU PERSONAGEM", 36, Color("e7bf79"))
	label("Nome")
	name_input = LineEdit.new()
	name_input.placeholder_text = "Como você se chama?"
	name_input.max_length = 40
	name_input.custom_minimum_size.y = 70
	name_input.add_theme_font_size_override("font_size", 24)
	column.add_child(name_input)
	label("Origem profissional")
	class_input = OptionButton.new()
	class_input.custom_minimum_size.y = 70
	class_input.add_theme_font_size_override("font_size", 22)
	for title in ["Cavaleiro arcano", "Tecnomago", "Artífice mecânico", "Diplomata imperial"]:
		class_input.add_item(title)
	column.add_child(class_input)
	label("Iniciar uma campanha substituirá o progresso atual.", 19)
	button("COMEÇAR", start_game)
	button("VOLTAR", menu)

func start_game() -> void:
	if name_input.text.strip_edges().is_empty():
		name_input.placeholder_text = "Digite um nome para continuar"
		return
	if game.new_game(name_input.text, class_input.get_item_text(class_input.selected)):
		show_scene()
	else:
		notice = "Não foi possível salvar a campanha."
		menu()

func continue_game() -> void:
	if game.load_game():
		show_scene()
	else:
		notice = "Nenhuma campanha válida foi encontrada."
		menu()

func show_scene() -> void:
	clear()
	var scene: Dictionary = game.story[game.state.node]
	label("CINZAS DE ÉTER  /  CAPÍTULO I", 19, Color("e7bf79"))
	label(scene.title, 38, Color("f6e3bd"))
	label(scene.text, 26)
	label("O que você faz?" if not scene.choices.is_empty() else "Seu caminho continua em uma próxima atualização.", 22, Color("e7bf79"))
	for i in range(scene.choices.size()):
		button(scene.choices[i].label, select_choice.bind(i))
	button("PERSONAGEM E DIÁRIO", journal)
	button("MENU PRINCIPAL", menu)

func select_choice(index: int) -> void:
	if game.choose(index):
		show_scene()
	else:
		clear()
		label("Não foi possível salvar sua decisão. Tente novamente.", 25)
		button("VOLTAR", show_scene)

func journal() -> void:
	clear()
	label("PERSONAGEM", 36, Color("e7bf79"))
	label("%s · %s" % [game.state.name, game.state["class"]])
	label("Confiança de Lia: %s\nCréditos: %s\nEstabilidade: %s\nConhecimento: %s" % [game.state.trust, game.state.credits, game.state.stability, game.state.insight])
	label("DIÁRIO", 32, Color("e7bf79"))
	if game.state.history.is_empty():
		label("Sua história ainda está começando.")
	for entry in game.state.history:
		label("• " + str(entry), 22)
	button("VOLTAR À HISTÓRIA", show_scene)

func credits() -> void:
	clear()
	label("CRÉDITOS", 36, Color("e7bf79"))
	label("Cinzas de Éter — campanha narrativa original.\nDesenvolvido com Godot Engine.")
	button("VOLTAR", menu)
