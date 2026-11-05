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
	if not await shot("04-defesa"):
		quit(1)
		return
	screen.region_screen(2)
	if not await shot("05-khar-duren"):
		quit(1)
		return
	if not screen.game.travel_to("khar-0",false) or not screen.game.enter_place("khar-0/mine"):
		quit(1)
		return
	screen.place_screen()
	if not await shot("06-galeria"):
		quit(1)
		return
	screen.resident_screen(0)
	if not await shot("07-morador"):
		quit(1)
		return
	screen.game.travel_to("valdoria-0",false)
	screen.chronicles_screen()
	if not await shot("08-cronicas"):
		quit(1)
		return
	screen.chronicle_detail("ledger")
	if not await shot("09-investigacao"):
		quit(1)
		return
	screen.chronicle_lineage()
	if not await shot("10-linhagem") or not screen.game.chronicle_wait(7):
		quit(1)
		return
	screen.dossier_screen()
	if not await shot("11-dossie") or not screen.game.dossier_view().stories.has("valdoria-0:N01"):
		quit(1)
		return
	screen.dossier_detail("valdoria-0:N01")
	if not await shot("12-saga"):
		quit(1)
		return
	screen.dossier_register("governo")
	if not await shot("13-gabinete"):
		quit(1)
		return
	screen.campaign_transfer()
	if not await shot("14-transferencia"):
		quit(1)
		return
	var book: Dictionary = screen.game.state.dossier
	var city: Dictionary = screen.game.expedition_city()
	var day: int = screen.game.state.day
	screen.game.dossier.open_story(book,city,"N06",day)
	var story: Dictionary = book.stories[city.id+":N06"]
	screen.game.dossier.civic.mobilize(book,story,day)
	screen.game.dossier.civic.begin_march(book,story,day)
	screen.dossier_register("frentes")
	quit(0 if await shot("15-marcha") else 1)
