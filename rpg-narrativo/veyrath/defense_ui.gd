extends VBoxContainer

const Icons = preload("res://veyrath/pixel_icons.gd")
const Sim = preload("res://veyrath/defense_sim.gd")
const GOLD := Color("d6b47d")
var game
var back: Callable
var selected := "arcana"
var sim
var accumulator := 0.0
var grid: GridContainer
var cells: Array = []
var tokens: Dictionary = {}
var base_style: StyleBoxFlat
var path_style: StyleBoxFlat
var hit_style: StyleBoxFlat
var status: Label
var report: Label
var wave_button: Button
var back_button: Button
var repair_button: Button
var select_arcane: Button
var select_steam: Button

func configure(game_engine, return_callback: Callable) -> void:
	game = game_engine
	back = return_callback

func _ready() -> void:
	add_theme_constant_override("separation",12)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	base_style = tile_style(Color("233945"),Color("866542"))
	path_style = tile_style(Color("25303a"),Color("53566a"))
	hit_style = tile_style(Color("683845"),Color("c28d63"))
	var colors := {
		"bolt": Color("75d9bd"), "cannon": Color("e7ac6b"), "build": Color("c2b399"),
		"road": Color("8f8e82"), "enemy": Color("f48d83"), "heavy": Color("f1b278")
	}
	for kind in colors:
		tokens[kind] = Icons.icon(kind,colors[kind],5)
	text_label("DEFESA DO POSTO",32,GOLD)
	text_label("Proteja o posto local de saqueadores. Escolha uma torre e toque nas casas acima ou abaixo da estrada.",20,Color("d7dfeb"))
	status = text_label("",21,GOLD)
	var selection := HBoxContainer.new()
	add_child(selection)
	select_arcane = ui_button("Bobina · 2",select_tower.bind("arcana"))
	selection.add_child(select_arcane)
	select_steam = ui_button("Vapor · 3",select_tower.bind("steam"))
	selection.add_child(select_steam)
	grid = GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation",3)
	grid.add_theme_constant_override("v_separation",3)
	add_child(grid)
	for i in range(24):
		var cell := ui_button("",cell_pressed.bind(i))
		cell.custom_minimum_size = Vector2(52,68)
		cell.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(cell)
		cells.append(cell)
	report = text_label("",19,Color("b7c5c6"))
	wave_button = ui_button("INICIAR ONDA",start_wave)
	add_child(wave_button)
	repair_button = ui_button("REPARAR +3 · 1 suprimento",repair)
	add_child(repair_button)
	back_button = ui_button("VOLTAR À HISTÓRIA",return_to_story)
	add_child(back_button)
	refresh()

func text_label(value: String, font_size: int, color: Color) -> Label:
	var item := Label.new()
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",color)
	add_child(item)
	return item

func ui_button(value: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = value
	item.custom_minimum_size.y = 64
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_font_size_override("font_size",19)
	item.pressed.connect(action)
	return item

func tile_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(2)
	box.set_border_width(SIDE_BOTTOM,4)
	return box

func select_tower(kind: String) -> void:
	selected = kind
	refresh()

func cell_pressed(index: int) -> void:
	if sim != null or index >= 8 and index < 16:
		return
	var tile := index if index < 8 else index - 8
	if game.fort_build(tile,selected):
		report.text = "Torre construída. As defesas e os suprimentos foram salvos."
	else:
		report.text = "Espaço ocupado ou suprimentos insuficientes."
	refresh()

func repair() -> void:
	if game.fort_repair():
		report.text = "O posto foi reparado."
	else:
		report.text = "O posto está íntegro ou faltam suprimentos."
	refresh()

func start_wave() -> void:
	var fort: Dictionary = game.fort_state()
	if fort.hp <= 0:
		report.text = "Repare o posto antes de iniciar outra onda."
		return
	sim = Sim.new()
	sim.setup(fort.layout,int(fort.wave),int(fort.hp))
	accumulator = 0.0
	report.text = "A onda avança. As torres atacam automaticamente."
	refresh()

func _process(delta: float) -> void:
	if sim == null:
		return
	accumulator += minf(delta,0.5)
	while accumulator >= Sim.TICK and sim != null:
		accumulator -= Sim.TICK
		sim.step()
		if sim.done:
			var wave := int(sim.wave)
			var won := bool(sim.won)
			var hp := int(sim.base_hp)
			var escaped := int(sim.escaped)
			sim = null
			if game.fort_finish(wave,won,hp,escaped):
				report.text = "Vitória! Posto protegido; +3 suprimentos." if won else "O posto caiu; +2 suprimentos para reconstrução. Repare antes da próxima onda."
			else:
				report.text = "Não foi possível salvar o resultado. A onda poderá ser repetida."
		refresh()

func refresh() -> void:
	if not is_instance_valid(status):
		return
	var fort: Dictionary = game.fort_state()
	var hp := int(sim.base_hp) if sim != null else int(fort.hp)
	status.text = "ONDA %s   ·   POSTO %s/10   ·   SUPRIMENTOS %s" % [fort.wave,hp,fort.supplies]
	select_arcane.text = ("✓ " if selected == "arcana" else "") + "Bobina · 2"
	select_steam.text = ("✓ " if selected == "steam" else "") + "Vapor · 3"
	var moving := sim != null
	select_arcane.disabled = moving
	select_steam.disabled = moving
	wave_button.disabled = moving
	repair_button.disabled = moving
	back_button.disabled = moving
	for index in range(24):
		var b: Button = cells[index]
		if index >= 8 and index < 16:
			b.disabled = true
			b.icon = tokens.road
			var threatened := false
			if moving:
				for enemy in sim.enemies:
					if int(enemy.x) == index - 8:
						b.icon = tokens.heavy if enemy.heavy else tokens.enemy
						threatened = true
						break
			b.add_theme_stylebox_override("disabled",hit_style if threatened else path_style)
		else:
			var tile := index if index < 8 else index - 8
			var type: String = fort.layout[tile]
			b.icon = tokens.bolt if type == "arcana" else (tokens.cannon if type == "steam" else tokens.build)
			b.tooltip_text = "Bobina arcana" if type == "arcana" else ("Canhão a vapor" if type == "steam" else "Terreno de construção")
			b.add_theme_stylebox_override("normal",base_style)
			b.add_theme_stylebox_override("disabled",base_style)
			b.disabled = moving or type != ""

func return_to_story() -> void:
	if sim == null:
		back.call()
