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
	"orunide":"cron_orunide.png","lineage":"cron_linhagem.png","barge":"cron_barca.png","vault":"cron_cofre.png",
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

func label(value: String, font_size: int = 25, color: Color = TEXT, literary: bool = false, centered: bool = false) -> Label:
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
	return item

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
	button("Crônicas",chronicles_screen).icon = icon("book",GOLD)
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

func chronicles_screen() -> void:
	clear()
	var journal: Dictionary = game.chronicle_view()
	var origin: Dictionary = game.expansion.city(journal.city,int(game.state.seed))
	label("HISTÓRIAS EM MOVIMENTO   /   DIA %d" % int(game.state.day),17,GOLD)
	label("Crônicas",48,TEXT,true)
	button("Sagas e conflitos do dossiê",dossier_screen).icon = icon("book",GOLD)
	scene_art(expansion_art(origin.art),210)
	label("O tempo avança em viagens, ações e espera. Os personagens tomam decisões mesmo quando você está longe.",21,MUTED)
	for tracked in [true,false]:
		for arc in game.director.catalog.arcs:
			var entry: Dictionary = journal.arcs[arc.id]
			if int(entry.phase) < 0 or entry.tracked != tracked:
				continue
			var status: String = ("Dia %d" % int(entry.due)) if entry.outcome.is_empty() else entry.outcome
			button(("%s   /   %s\n%s" % [arc.title,arc.scope,status]),chronicle_detail.bind(arc.id)).icon = icon("book",GOLD if tracked else MUTED)
	if not journal.known.is_empty():
		button("Caderno de pistas",chronicle_clues)
	button("Aguardar 1 dia",chronicle_skip.bind(1))
	button("Aguardar 7 dias",chronicle_skip.bind(7))
	button("‹  Registros",campaign_records)

func dossier_screen() -> void:
	clear()
	var book: Dictionary = game.dossier_view()
	label("Dossiê de Veyrath",47,TEXT,true)
	label("TRAMAS OBSERVADAS  /  DIA %d" % int(game.state.day),18,GOLD)
	var active: Array = book.stories.values()
	active.sort_custom(func(left,right): return int(left.opened)>int(right.opened))
	if active.is_empty():
		card("Nenhuma saga foi observada ainda. Aguarde alguns dias ou visite outros assentamentos para encontrar as condições da história.",23,true)
	for story in active:
		var content: Dictionary = game.dossier.source(story.source)
		var city: Dictionary = game.expansion.city(story.city,int(book.seed))
		var state_text: String = "Prazo: dia %d" % int(story.due) if story.outcome.is_empty() else story.outcome
		button("%s  ·  %s\n%s  /  %s" % [story.source,content.title.capitalize(),city.name,state_text],dossier_detail.bind(story.id))
	button("Caderno de evidências",dossier_knowledge)
	button("Espólios, bens e família",dossier_register.bind("patrimônio"))
	button("Gabinete político",dossier_register.bind("governo"))
	button("Frentes e tratados",dossier_register.bind("frentes"))
	button("Aguardar 1 dia",dossier_wait.bind(1))
	button("Aguardar 7 dias",dossier_wait.bind(7))
	button("‹  Crônicas",chronicles_screen)

func dossier_register(section: String) -> void:
	clear()
	var book: Dictionary = game.dossier_view()
	var registry: Dictionary = book.get("civic",{})
	var city: String = game.expedition().city
	scene_art({"patrimônio":"archive","governo":"council","frentes":"fort"}[section],205)
	label(section.capitalize(),42,TEXT,true)
	var rendered := 0
	match section:
		"patrimônio":
			for record in registry.get("properties",{}).values():
				if record.city != city:
					continue
				rendered += 1
				var owners := PackedStringArray()
				for id in record.shares:
					owners.append("%s · %d%%" % [book.actors.get(id,{}).get("name",id),int(record.shares[id])])
				card("TÍTULO E CUSTÓDIA\n"+(" · ".join(owners) if not owners.is_empty() else "Titularidade em instrução."),23)
			for id in registry.get("estates",{}):
				var entry: Dictionary = registry.estates[id]
				if not id.begins_with(city+":"):
					continue
				card("Espólio %s · dívida %d · contestação até dia %d" % [entry.state,entry.debts,entry.contest_until],23)
			for person in book.actors.values():
				if person.home != city or person.get("parents",[]).is_empty():
					continue
				var parents := PackedStringArray()
				for id in person.parents:
					parents.append(book.actors.get(id,{}).get("name",id))
				card(person.name+" · filiação registrada: "+", ".join(parents),21)
		"governo":
			var office: Dictionary = registry.get("offices",{}).get(city,{})
			if not office.is_empty():
				rendered += 1
				card("%s · %s\nTitular: %s · revisão no dia %d" % [office.method,office.status,book.actors.get(office.incumbent,{}).get("name","cargo vago"),office.review],23)
			for law in registry.get("laws",{}).values():
				if law.city == city:
					rendered += 1
					card("%s · %s · vigência a partir do dia %d" % [law.scope,law.decision,law.effective],22)
		"frentes":
			var front: Dictionary = registry.get("fronts",{}).get(city,{})
			if not front.is_empty():
				rendered += 1
				card("%s · efetivo %d · moral %d · provisões %d" % [front.status,front.strength,front.morale,front.supplies],23)
				for event in front.battles:
					card("Dia %d · %s · baixas %d · perdas civis %d" % [event.day,event.result,event.loss,event.civilians],22)
				if front.has("treaty"):
					card("Tratado com acesso humanitário · revisão no dia %d" % front.treaty.review,22)
	if rendered == 0:
		card("O assentamento ainda não possui registros públicos nesta categoria.")
	button("‹  Dossiê",dossier_screen)

func dossier_wait(days: int) -> void:
	var saved: bool = game.chronicle_wait(days)
	dossier_screen()
	if not saved:
		label("A passagem de tempo não pôde ser salva.",20,GOLD)

func dossier_detail(story_id: String) -> void:
	clear()
	var book: Dictionary = game.dossier_view()
	if not book.stories.has(story_id):
		dossier_screen()
		return
	var story: Dictionary = book.stories[story_id]
	var content: Dictionary = game.dossier.source(story.source)
	var act: Dictionary = game.dossier.act_for(story)
	var plan: Dictionary = game.dossier.plan_for(story)
	var city: Dictionary = game.expansion.city(story.city,int(book.seed))
	var domain: Dictionary = book.places[story.city]
	var view := stage_for(plan.art,276)
	view.site_kind = str(plan.place)
	view.site_trim = int(story.opened)%6
	view.damage = int(domain.damage)
	view.shortage = int(domain.supply) < 10
	if int(domain.damage) > 0:
		view.light = Color("a76a50")
		view.intensity = 0.8
	if not story.cast.is_empty():
		var actor: Dictionary = book.actors[story.cast[0].id]
		if actor.alive:
			view.face = resident_art(actor)
			view.subject_pin = int(actor.pin)
	label("%s  /  %s  /  %s" % [story.source,city.name,city.region_name],17,GOLD)
	column.add_child(view)
	label(content.title.capitalize(),40,TEXT,true)
	label(act.title.capitalize(),22,GOLD)
	card(act.scene,27,true)
	if story.outcome.is_empty():
		label("PRAZO  /  DIA %d" % int(story.due),17,GOLD)
		for option in act.options:
			var reason: String = game.dossier.validate_player(book,story.id,int(story.stage),option.id,game.expedition().city,
				int(game.state.day),int(game.state.credits),int(game.state.flow),game.chronicle_view().flags)
			var action: Dictionary = plan.actions.get(option.id,{})
			var detail := ""
			if not action.is_empty():
				detail = "\n%d crédito(s) · %d Fluxo" % [int(action.cost),int(action.flux)]
			if not reason.is_empty():
				detail += "\n" + reason
			button(option.id + "  /  " + str(option.text) + detail,dossier_decide.bind(story.id,int(story.stage),option.id),not reason.is_empty())
	else:
		card(story.outcome,24,true)
	divider()
	label("RESERVA %d  /  SAÚDE %d  /  RIO %d  /  TENSÃO %d" % [domain.supply,domain.health,domain.river,domain.tension],16,GOLD)
	label("Habitat %d  ·  tarifa %+d  ·  danos %d" % [domain.habitat,domain.route,domain.damage],20,MUTED)
	if story.source in ["N02","S04","S05","S06"]:
		var pair: Dictionary = game.dossier.relationship(book,story.city)
		label("Vínculo: %s" % pair.get("state","conhecidos"),20,GOLD)
		if pair.has("trust"):
			label("Confiança %d  ·  Respeito %d  ·  Familiaridade %d" % [pair.trust,pair.respect,pair.familiarity],18,MUTED)
	if story.source in ["N01","N03","N06"]:
		label("Governo: %s  ·  Legitimidade %d" % [domain.government,domain.legitimacy],18,MUTED)
		if domain.has("treaty"):
			label("Tratado ratificado no dia %d" % int(domain.treaty.day),19,GOLD)
	label("PARTICIPANTES",17,GOLD)
	for seat in story.cast:
		var participant: Dictionary = book.actors[seat.id]
		label("%s  /  %s" % [participant.name,seat.role],19,MUTED)
	label("REGISTROS DO ATO",17,GOLD)
	var entries: Array = story.history.duplicate()
	entries.reverse()
	for item in entries:
		card("DIA %d\n%s" % [int(item.day),item.text],21)
	button("‹  Dossiê",dossier_screen)

func dossier_decide(story_id: String, phase: int, option: String) -> void:
	var saved: bool = game.dossier_choice(story_id,phase,option)
	dossier_detail(story_id)
	if not saved:
		label("A decisão venceu ou não pôde ser salva.",20,GOLD)

func dossier_knowledge() -> void:
	clear()
	var book: Dictionary = game.dossier_view()
	scene_art("barge",215)
	label("Evidências do dossiê",43,TEXT,true)
	if book.known.is_empty():
		card("Nenhuma evidência foi descoberta.")
	for entry in book.known.values():
		if game.dossier.rules.truths.has(entry.id):
			var city: Dictionary = game.expansion.city(entry.city,int(book.seed))
			card("DIA %d  /  %s  /  %s\n%s" % [int(entry.day),city.name,entry.type.to_upper(),game.dossier.rules.truths[entry.id]],23,true)
	button("‹  Dossiê",dossier_screen)

func chronicle_skip(days: int) -> void:
	var saved: bool = game.chronicle_wait(days)
	chronicles_screen()
	if not saved:
		label("A passagem de tempo não pôde ser salva.",20,GOLD)

func chronicle_detail(arc_id: String) -> void:
	clear()
	var journal: Dictionary = game.chronicle_view()
	var arc: Dictionary = game.director.visible(journal,arc_id)
	if arc.is_empty():
		chronicles_screen()
		return
	var entry: Dictionary = journal.arcs[arc_id]
	var stage: Dictionary = arc.stages[int(entry.phase)]
	var art_key: String = {"inheritance":"lineage","ledger":"barge","flux":"vault","dragon":"orunide" if journal.flags.get("dragon_contact",false) else "quarry"}.get(arc_id,arc.art)
	var shot := stage_for(art_key,280)
	for role in arc.cast:
		if role == "dragon" or (role == "elder" and journal.flags.get("elder_dead",false)):
			continue
		var actor: Dictionary = journal.cast[role]
		shot.face = resident_art(actor)
		shot.subject_pin = int(actor.pin)
		break
	label(arc.scope.to_upper() + "   /   " + arc.genre.to_upper(),17,GOLD)
	column.add_child(shot)
	label(arc.title,42,TEXT,true)
	if entry.outcome.is_empty():
		label("%s   ·   PRAZO: DIA %d" % [stage.title,int(entry.due)],19,GOLD)
		card(game.director.render(journal,stage.text),26,true)
		for action in stage.actions:
			var reason: String = game.director.block_reason(journal,arc_id,action,int(game.state.credits),int(game.state.flow),game.expedition().city)
			var cost := "1 dia"
			if int(action.cost) > 0:
				cost += "  ·  %d crédito(s)" % int(action.cost)
			if int(action.flow) > 0:
				cost += "  ·  %d Fluxo" % int(action.flow)
			button(action.label + "\n" + (reason if not reason.is_empty() else cost),chronicle_decide.bind(arc_id,int(entry.phase),action.id),not reason.is_empty())
	else:
		label("LEGADO  /  " + entry.outcome.to_upper(),19,GOLD)
	divider()
	label("PARTICIPANTES",17,GOLD)
	for role in arc.cast:
		if role == "dragon" and not journal.flags.get("dragon_contact",false):
			continue
		button(journal.cast[role].name + "  ·  " + journal.cast[role].job,chronicle_person.bind(arc_id,role))
	if arc_id == "inheritance":
		button("Ver as três gerações",chronicle_lineage)
	divider()
	label("HISTÓRICO",17,GOLD)
	var events: Array = journal.events.duplicate()
	events.reverse()
	for event in events:
		if event.arc == arc_id:
			card("DIA %d\n%s" % [int(event.day),event.text],21)
	button("Deixar de acompanhar" if entry.tracked else "Acompanhar crônica",chronicle_track.bind(arc_id))
	button("‹  Crônicas",chronicles_screen)

func chronicle_person(arc_id: String, role: String) -> void:
	clear()
	var journal: Dictionary = game.chronicle_view()
	var actor: Dictionary = journal.cast[role]
	var deceased: bool = role == "elder" and journal.flags.get("elder_dead",false)
	var view := stage_for("orunide" if role == "dragon" else "lineage",260)
	if role != "dragon":
		view.face = resident_art(actor)
		view.subject_pin = int(actor.pin)
	column.add_child(view)
	label(actor.name,43,TEXT,true)
	label(actor.job + ("   ·   FALECIDA" if deceased else ""),19,GOLD)
	if not deceased:
		var goal: String = game.director.goal_for(journal,actor)
		if not goal.is_empty():
			card("Objetivo atual   /   " + goal,24,true)
		if actor.has("dramatic"):
			card("Posição declarada   /   " + actor.dramatic.stance,22)
		if actor.has("value"):
			card("Valor declarado   /   " + actor.value,22)
	if role == "dragon":
		card("A troca de observações depende de consentimento e sigilo. O pacto pode ser encerrado pelo próprio dragão.",23,true)
	button("‹  Voltar à crônica",chronicle_detail.bind(arc_id))

func chronicle_lineage() -> void:
	clear()
	var journal: Dictionary = game.chronicle_view()
	scene_art("lineage",252)
	label("A casa em três gerações",43,TEXT,true)
	for i in range(3):
		var role: String = ["elder","caretaker","heir"][i]
		var actor: Dictionary = journal.cast[role]
		var relation: String = ["Fundadora","Descendente da fundadora","Descendente da segunda geração"][i]
		card("%s  /  %s\nNascimento: %d P.R.%s" % [relation,actor.name,312-int(actor.age),
			"  ·  Morte registrada no dia %d" % int(actor.died_day) if actor.has("died_day") else ""],22)
	button("‹  Casa com duas chaves",chronicle_detail.bind("inheritance"))

func chronicle_clues() -> void:
	clear()
	var journal: Dictionary = game.chronicle_view()
	scene_art("barge",215)
	label("Caderno de pistas",43,TEXT,true)
	for id in journal.known:
		var evidence: String = game.director.clue_text(journal,id)
		if not evidence.is_empty():
			card(evidence,24,true)
	button("‹  Crônicas",chronicles_screen)

func chronicle_decide(arc_id: String, phase: int, action_id: String) -> void:
	var saved: bool = game.chronicle_choice(arc_id,phase,action_id)
	chronicle_detail(arc_id)
	if not saved:
		label("A decisão não está mais disponível ou não pôde ser salva.",20,GOLD)

func chronicle_track(arc_id: String) -> void:
	var saved: bool = game.track_chronicle(arc_id)
	chronicle_detail(arc_id)
	if not saved:
		label("Não foi possível salvar o acompanhamento.",20,GOLD)

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
	var registry: Dictionary = game.dossier_view().get("civic",{})
	for report in registry.get("reports",{}).values():
		card("DIA %d · %s\n%s" % [report.day,report.kind.to_upper(),report.text],22)
	var recent: Array = registry.get("ledger",[]).filter(func(event): return event.type=="closure")
	for event in recent.slice(maxi(0,recent.size()-8)):
		var title: String = game.dossier.source(event.story.get_slice(":",1)).get("title","Crônica local")
		card("DIA %d · %s\n%s" % [event.day,title,event.text],22)
	if game.state.news.is_empty() and recent.is_empty() and registry.get("reports",{}).is_empty():
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
	button("TRANSFERIR CAMPANHA SOLO",campaign_transfer)
	button("‹  MENU PRINCIPAL",menu)

func campaign_transfer() -> void:
	clear()
	label("Transferir campanha",39,TEXT,true)
	card("Use o código para levar seu save solo a outro perfil ou dispositivo. Guarde uma cópia antes de trocar de instalação.",22)
	var field := TextEdit.new()
	field.custom_minimum_size.y = 195
	field.placeholder_text = "Cole aqui o código do save"
	column.add_child(field)
	var message := label("",20,GOLD)
	button("GERAR E COPIAR CÓDIGO",func():
		field.text = game.export_campaign()
		if not field.text.is_empty():
			DisplayServer.clipboard_set(field.text)
		message.text = "Código gerado." if not field.text.is_empty() else "Nenhuma campanha válida encontrada.")
	button("COLAR CÓDIGO",func(): field.text = DisplayServer.clipboard_get())
	button("IMPORTAR E SUBSTITUIR SAVE LOCAL",func():
		if game.import_campaign(field.text):
			message.text = "Campanha restaurada. O save anterior foi preservado como backup."
		else:
			message.text = "Código inválido, incompatível ou gravação indisponível.")
	button("‹  Configurações",settings)

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
	view.damage = int(conditions.get("damage",0))
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
		var plan: Dictionary = game.expedition_route(current,destination,fast)
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
	var conditions: Dictionary = game.expedition_condition(city)
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
	var conditions: Dictionary = game.expedition_condition(city)
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
		var resident: Dictionary = game.expedition_resident(site,staff)
		if not resident.get("alive",true) or resident.home!=site.city or resident.has("move"):
			continue
		var present: bool = game.resident_available(resident,site.city)
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
	var actor: Dictionary = game.expedition_resident(site,staff)
	var present: bool = game.resident_available(actor,site.city)
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
	var goal: String = game.director.goal_for(game.chronicle_view(),actor)
	var detail := "%s. Nasceu em %s e trabalha em %s com %s. Valoriza %s e quer %s." % [actor.personality,birthplace.name,site.name,coworker.name,actor.value,goal]
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
