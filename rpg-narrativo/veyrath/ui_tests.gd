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
	scene.show_scene()
	await process_frame
	scene.campaign_records()
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
	scene.defense()
	await process_frame
	scene.multiplayer_screen()
	await process_frame
	var online = scene.column.get_child(0)
	if online.uuid4().length() != 36 or online.request == null:
		failed = true
	if not ResourceLoader.exists("res://veyrath/assets/val_doria.jpg"):
		failed = true
	print("Interface Veyrath: ", "falhou" if failed else "aberta e navegada")
	scene.queue_free()
	await process_frame
	quit(1 if failed else 0)
