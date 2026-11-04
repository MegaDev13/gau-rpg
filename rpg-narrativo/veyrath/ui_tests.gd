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
	if not scene.game.new_game("Interface", "scholar", "valdor", 42):
		failed = true
	scene.show_scene()
	await process_frame
	scene.people()
	await process_frame
	scene.journal()
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
	quit(1 if failed else 0)
