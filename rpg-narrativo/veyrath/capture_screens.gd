extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func shot(name: String) -> bool:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	return frame != null and frame.save_png(OS.get_environment("VEY_SCREENSHOTS").path_join(name + ".png")) == OK

func capture() -> void:
	var screen = load("res://veyrath/main.tscn").instantiate()
	root.add_child(screen)
	screen.motion_enabled = false
	if not await shot("01-abertura"):
		quit(1)
		return
	if not screen.game.new_game("Elara","scholar","valdor",1234) or not screen.game.choose(0):
		quit(1)
		return
	screen.show_scene()
	if not await shot("02-cena"):
		quit(1)
		return
	screen.inventory()
	if not await shot("03-inventario"):
		quit(1)
		return
	screen.defense()
	quit(0 if await shot("04-defesa") else 1)
