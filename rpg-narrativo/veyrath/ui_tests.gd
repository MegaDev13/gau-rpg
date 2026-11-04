extends SceneTree
var failed := false
func _initialize() -> void:
	call_deferred("test_ui")
func test_ui() -> void:
	var scene = load("res://veyrath/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	if scene.column.get_child_count() == 0:
		failed = true
	if scene.reading_font == null:
		push_error("Fonte da crônica não carregou.")
		failed = true
	for place in scene.ILLUSTRATIONS:
		if scene.illustration(place) == null or not scene.illustrations.has(place):
			push_error("Ilustração ausente: " + place)
			failed = true
	if not scene.game.new_game("Interface", "scholar", "valdor", 42):
		failed = true
	for role in scene.game.state.people:
		var face: Texture2D = scene.portrait_texture(role)
		if face == null or face.get_size() != Vector2(112,112):
			push_error("Retrato inválido: " + role)
			failed = true
	scene.show_scene()
	await process_frame
	var save_before := FileAccess.get_file_as_string(scene.game.SAVE)
	scene.turn_page(1)
	await process_frame
	if scene.reading_page != 1 or save_before != FileAccess.get_file_as_string(scene.game.SAVE):
		push_error("Paginação alterou a campanha ou não avançou.")
		failed = true
	scene.turn_page(50)
	await process_frame
	if scene.reading_page != scene.game.scene_text().split("\n\n",false).size()-1:
		failed = true
	scene.select_choice(0)
	await process_frame
	if scene.reading_page != 0 or scene.game.state.node != "investigation":
		failed = true
	scene.grimoire()
	await process_frame
	for entry in scene.column.get_children():
		if entry is Button and entry.text == "Executar leitura de Eco":
			entry.pressed.emit()
			break
	await process_frame
	if scene.game.state.node != "evidence" or scene.game.state.flow != 2:
		push_error("Grimório não executou o custo e o avanço da leitura de Eco.")
		failed = true
	scene.campaign_records()
	await process_frame
	scene.chronicles_screen()
	await process_frame
	scene.chronicle_detail("apprentice")
	await process_frame
	scene.chronicle_person("apprentice","assistant")
	await process_frame
	scene.chronicle_lineage()
	await process_frame
	scene.atlas()
	await process_frame
	scene.people()
	await process_frame
	scene.journal()
	await process_frame
	scene.character_sheet()
	await process_frame
	scene.inventory()
	await process_frame
	scene.bestiary()
	await process_frame
	scene.world_panel()
	await process_frame
	scene.settings()
	await process_frame
	scene.updates_screen()
	await process_frame
	scene.news()
	await process_frame
	scene.region_screen(4)
	await process_frame
	scene.travel_screen("namaris-0")
	await process_frame
	scene.travel("namaris-0",false)
	await process_frame
	scene.open_place("namaris-0/harbor")
	await process_frame
	scene.resident_screen(0)
	await process_frame
	if scene.game.expedition().place != "namaris-0/harbor":
		failed = true
	scene.travel("valdoria-0",false)
	await process_frame
	scene.defense()
	await process_frame
	scene.multiplayer_screen()
	await process_frame
	var online = scene.column.get_child(0)
	if online.uuid4().length() != 36 or online.request == null:
		failed = true
	print("Interface Veyrath: ", "falhou" if failed else "aberta e navegada")
	scene.queue_free()
	await process_frame
	quit(1 if failed else 0)
