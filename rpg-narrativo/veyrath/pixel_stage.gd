extends Control
## All scene layers share the same two-unit pixel grid at the reference viewport.
const ART_DIR := "res://veyrath/assets/pixel/"
const BRONZE := Color("9e7949")
var art: Texture2D
var face: Texture2D
var light := Color("579a83")
var atmosphere := "mist"
var motion := true
var intensity := 0.4
var elapsed := 0.0
var spark_seed := 0
var subject_pin := -1
var site_trim := -1
var site_kind := ""
var shortage := false
var vertical_focus := 0.5
var reaction_light := Color("657b9c")

static func load_pixel(file: String) -> Texture2D:
	var path := ART_DIR + file
	if ResourceLoader.exists(path):
		return load(path)
	# The source path is also usable before Godot has imported it.
	var bytes := FileAccess.get_file_as_bytes(path)
	if not bytes.is_empty():
		var image := Image.new()
		if image.load_png_from_buffer(bytes) == OK:
			return ImageTexture.create_from_image(image)
	return null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	set_process(motion)
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	var old_frame := int(elapsed * 12.0)
	elapsed += delta
	if int(elapsed * 12.0) != old_frame:
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("0d121b"))
	if art:
		var source := art.get_size()
		var ratio := maxf(size.x / source.x,size.y / source.y)
		var scale_pixels := ceilf(ratio) if ratio > 1.0 else ratio
		var scaled := source * scale_pixels
		var offset := ((size - scaled) * Vector2(0.5,vertical_focus)).floor()
		draw_texture_rect(art,Rect2(offset,scaled),false)
	var tick := floorf(elapsed * 12.0) / 12.0
	var shimmer := 0.88 + 0.12 * sin(tick * 2.0)
	draw_rect(Rect2(Vector2.ZERO,size),Color(light,0.025 + intensity * 0.065 * shimmer))
	for i in range(4):
		var band := Color(0.025,0.035,0.06,0.05 + 0.035 * i)
		draw_rect(Rect2(0,size.y * (0.75 + i * 0.0625),size.x,size.y * 0.0625 + 1),band)
	if motion:
		_draw_weather(tick)
	if site_trim >= 0:
		_draw_site_props()
	if face:
		var scale_pixels := clampf(floorf(size.y / float(face.get_height()) * 0.58),1.0,2.0)
		var portrait_size := face.get_size() * scale_pixels
		var pos := Vector2(14,size.y - portrait_size.y - 14).floor()
		draw_rect(Rect2(pos - Vector2(4,4),portrait_size + Vector2(8,8)),Color("0b1017"))
		draw_rect(Rect2(pos - Vector2(3,3),portrait_size + Vector2(6,6)),reaction_light,false,2.0)
		draw_texture_rect(face,Rect2(pos,portrait_size),false)
		if subject_pin >= 0:
			_draw_pin(pos + portrait_size - Vector2(14,14))
	elif subject_pin >= 0:
		_draw_pin(size - Vector2(18,18))
	draw_rect(Rect2(1,1,size.x-2,size.y-2),BRONZE,false,2.0)
	for corner in [Vector2(4,4),Vector2(size.x-12,4),Vector2(4,size.y-12),size-Vector2(12,12)]:
		draw_rect(Rect2(corner,Vector2(8,8)),BRONZE)
		draw_rect(Rect2(corner+Vector2(2,2),Vector2(4,4)),Color("141c28"))

func _draw_pin(anchor: Vector2) -> void:
	var palette := [Color("be955d"),Color("7bb49b"),Color("a385ad"),Color("a6b5c4")]
	var metal: Color = palette[subject_pin % palette.size()]
	draw_rect(Rect2(anchor - Vector2(3,3),Vector2(16,16)),Color("101620"))
	draw_rect(Rect2(anchor + Vector2(2,0),Vector2(6,10)),metal)
	draw_rect(Rect2(anchor + Vector2(0,2),Vector2(10,6)),metal)
	if subject_pin % 2 == 0:
		draw_rect(Rect2(anchor + Vector2(4,4),Vector2(2,2)),Color("172330"))

func _draw_weather(tick: float) -> void:
	for i in range(28):
		var seed := i + spark_seed
		var x := fposmod(seed * 83.0 + tick * (8 + i % 5),maxf(1.0,size.x))
		var y := fposmod(seed * 47.0 - tick * (14 + i % 7),maxf(1.0,size.y))
		var point := Vector2(floorf(x/2)*2,floorf(y/2)*2)
		match atmosphere:
			"rain":
				draw_rect(Rect2(point,Vector2(2,8)),Color("8fb2bf52"))
			"embers":
				draw_rect(Rect2(point,Vector2(2,2) * (1 + i % 2)),Color(light,0.25+0.35*intensity))
			_:
				if i < 14:
					draw_rect(Rect2(point,Vector2(2,2)),Color("b0c9b83e"))
	if atmosphere == "mist":
		for i in range(3):
			var x := fposmod(tick * (10+i*4) + i*187,maxf(1.0,size.x)) - 110.0
			draw_rect(Rect2(floorf(x/2)*2,size.y * (0.68+i*0.07),224,4),Color("a3b0c21b"))


func _draw_site_props() -> void:
	# Foreground geometry is keyed to the establishment and its available supplies.
	var count := 1 if shortage else 2 + site_trim % 3
	for i in range(count):
		var x := floorf((size.x - 32.0 - i*26.0 - site_trim*4.0)/2.0)*2.0
		var y := size.y - 27.0 - float(i % 2)*6.0
		match site_kind:
			"archive", "lab", "council", "temple":
				draw_rect(Rect2(x,y,18,15),Color("202635"))
				draw_rect(Rect2(x+4,y-2,10,4),Color("b39058"))
				draw_rect(Rect2(x+8,y+5,4,6),Color("85a6a8"))
			"rail", "fort", "workshop", "mine", "quarry":
				draw_rect(Rect2(x,y,20,16),Color("3b4146"))
				draw_rect(Rect2(x,y+2,20,3),Color("a1774e"))
				draw_rect(Rect2(x+3,y+7,14,2),Color("1b222d"))
			_:
				draw_rect(Rect2(x,y,20,14),Color("463b35"))
				draw_rect(Rect2(x+2,y+2,16,2),Color("9c7752"))
				draw_rect(Rect2(x+4,y+6,3,7),Color("766047"))
