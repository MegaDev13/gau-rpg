extends Control
## Generated illustrations are deterministic and need no save migration.
var kind := "scene"
var scene_id := "city"
var variant := 0
var expression := "neutral"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _draw() -> void:
	if kind == "portrait":
		paint_portrait()
	else:
		paint_scene()

func block(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(x * size.x / 160.0, y * size.y / 100.0, w * size.x / 160.0, h * size.y / 100.0), c)

func paint_scene() -> void:
	var night := Color("172535")
	var gold := Color("d4a66b")
	var teal := Color("5ab1aa")
	block(0, 0, 160, 100, night)
	if scene_id == "quarry":
		block(0,0,160,68,Color("203747"))
		block(0,54,160,46,Color("594b47"))
		for i in range(8):
			block(i * 24 - 5, 60 - (i % 3) * 6, 25, 40, Color("3b3b41"))
		block(81,53,20,9,Color("101a25"))
		block(75,58,35,7,Color("101a25"))
		block(104,51,10,5,teal)
	elif scene_id == "council":
		block(0,0,160,100,Color("34313a"))
		for i in range(5):
			block(i*36+2,0,9,86,Color("695956"))
			block(i*36+4,6,3,55,gold)
		block(17,65,126,14,Color("68483b"))
		block(22,79,116,6,Color("211c27"))
		block(69,12,24,32,Color("447b80"))
		block(79,12,3,32,gold)
	elif scene_id == "workshop":
		block(0,0,160,100,Color("3d373b"))
		block(5,15,48,48,Color("223543"))
		block(10,20,38,38,Color("497178"))
		block(27,20,3,38,gold)
		block(57,64,96,14,Color("9a735a"))
		block(68,32,29,32,Color("252b35"))
		block(75,39,15,17,teal)
		block(80,43,5,9,Color("c8eee2"))
		block(105,40,34,6,Color("998474"))
		block(111,46,6,18,gold)
	else:
		block(0,0,160,100,Color("263447"))
		block(0,36,160,64,Color("37424e"))
		block(5,35,18,44,Color("1b242f"))
		block(8,28,12,7,Color("1b242f"))
		block(28,27,25,53,Color("242a35"))
		block(33,17,15,10,Color("242a35"))
		block(58,42,16,38,Color("1a2631"))
		block(78,23,25,58,Color("2b3038"))
		block(84,10,6,30,Color("222b35"))
		block(115,33,30,47,Color("212b35"))
		for i in range(10):
			block(10+(i*15),54+(i%3)*7,4,7,gold)
		block(0,80,160,20,Color("1a252d"))
		block(20,85,115,2,teal)
	# A stylized rift and fine border unify each place without simulating a map.
	block(105,8,27,2,Color("a7dad0"))
	block(113,10,18,1,Color("a7dad0"))
	block(0,0,160,2,Color("bd9567"))
	block(0,98,160,2,Color("bd9567"))

func paint_portrait() -> void:
	var skins := [Color("d5a985"),Color("a8735f"),Color("714b3d"),Color("e2c3a1"),Color("bd8b70"),Color("8b6651")]
	var hairs := [Color("241e29"),Color("3b3031"),Color("66503d"),Color("b9a394"),Color("70483f"),Color("1e2730")]
	var clothes := [Color("3d6263"),Color("6e464c"),Color("4f5368"),Color("715b3d"),Color("395161"),Color("5b554b")]
	var skin: Color = skins[posmod(variant,skins.size())]
	var hair: Color = hairs[posmod(int(variant / 7),hairs.size())]
	var coat: Color = clothes[posmod(int(variant / 31),clothes.size())]
	block(0,0,160,100,Color("202a36"))
	block(8,5,144,90,Color("2c3c49"))
	block(35,70,90,30,coat)
	block(51,57,58,30,skin)
	block(45,18,70,52,hair)
	block(51,27,58,37,skin)
	block(51,23,58,8,hair)
	block(46,32,7,23,hair)
	block(107,31,7,23,hair)
	if posmod(int(variant / 13),2) == 0:
		block(56,19,37,7,hair)
		block(88,24,21,7,hair)
	else:
		block(50,17,60,9,hair)
		block(48,22,11,16,hair)
	block(63,42,6,3,Color("211f25"))
	block(91,42,6,3,Color("211f25"))
	block(76,52,10,2,Color("583d39"))
	if expression == "worried":
		block(59,36,12,2,Color("241e29"))
		block(89,36,12,2,Color("241e29"))
	elif expression == "warm":
		block(72,55,16,2,Color("724b43"))
	block(72,70,16,10,Color("b7956a"))
	block(77,72,6,6,Color("2c5662"))
	block(2,2,156,3,Color("be9564"))
	block(2,95,156,3,Color("be9564"))
