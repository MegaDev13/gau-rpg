extends RefCounted
## Offline deterministic skirmish; callers advance fixed-size simulation steps.
const WIDTH := 8
const TICK := 0.2
var towers: Array = []
var enemies: Array = []
var spawn_left := 0
var spawn_clock := 0.0
var fire_clock := 0.0
var base_hp := 10
var wave := 1
var done := false
var won := false
var escaped := 0

func setup(layout: Array, wave_number: int, hp: int) -> void:
	towers = layout.duplicate(true)
	wave = wave_number
	base_hp = hp
	spawn_left = mini(4 + wave_number, 16)
	enemies = []
	spawn_clock = 0.0
	fire_clock = 0.0
	done = false
	won = false
	escaped = 0

func step() -> void:
	if done:
		return
	spawn_clock -= TICK
	if spawn_left > 0 and spawn_clock <= 0:
		var heavy := wave >= 2 and spawn_left % 3 == 0
		enemies.append({"x":0.0,"hp":4 if heavy else 2,"heavy":heavy})
		spawn_left -= 1
		spawn_clock = 1.0
	fire_clock -= TICK
	if fire_clock <= 0:
		fire_clock = 0.8
		for i in range(towers.size()):
			if towers[i] == "":
				continue
			var column := i % WIDTH
			var radius := 2.0 if towers[i] == "arcana" else 1.5
			var damage := 1 if towers[i] == "arcana" else 2
			var target := -1
			var front := -1.0
			for j in range(enemies.size()):
				if enemies[j].hp > 0 and absf(float(enemies[j].x) - (column + 0.5)) <= radius and float(enemies[j].x) > front:
					target = j
					front = float(enemies[j].x)
			if target >= 0:
				enemies[target].hp -= damage
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		if enemy.hp <= 0:
			enemies.remove_at(i)
			continue
		enemy.x += (0.42 if enemy.heavy else 0.56) * TICK
		if enemy.x >= WIDTH:
			base_hp = maxi(0, base_hp - (2 if enemy.heavy else 1))
			escaped += 1
			enemies.remove_at(i)
	if base_hp <= 0:
		done = true
		won = false
	elif spawn_left == 0 and enemies.is_empty():
		done = true
		won = true
