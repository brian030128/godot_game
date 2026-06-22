extends SceneTree
## Headless check that room_s stamps obstacles into collision + nav without blocking
## doors/entry. Run: <godot_console> --headless --script tools/verify_obstacles.gd


func _init() -> void:
	var room = preload("res://rooms/room_s.gd").new()
	get_root().add_child(room)  # _ready() -> build() once

	var grid: Array[String] = room._layout()
	print("=== grid ('#' wall, 'O' prop, 'D'/'E' door, '.' floor, 'm' spawn) ===")
	for line in grid:
		print(line)

	# Count colliders actually built.
	var bodies := 0
	for c in room.get_children():
		if c is StaticBody2D:
			bodies += 1
	print("StaticBody2D colliders built: ", bodies)

	# Every 'O' cell must be nav-solid; every door/entry cell must stay walkable.
	var o_total := 0
	var o_solid := 0
	var door_open := 0
	var door_blocked := 0
	for y in grid.size():
		var line: String = grid[y]
		for x in line.length():
			var ch := line[x]
			var solid: bool = room.nav_grid.is_point_solid(Vector2i(x, y))
			if ch == "O":
				o_total += 1
				if solid:
					o_solid += 1
			elif ch == "D" or ch == "E":
				if solid:
					door_blocked += 1
				else:
					door_open += 1
	print("obstacle cells: %d (nav-solid %d)" % [o_total, o_solid])
	print("door/entry cells: open %d, blocked %d" % [door_open, door_blocked])
	print("RESULT: ", "OK" if (o_total > 0 and o_total == o_solid and door_blocked == 0) else "FAIL")
	quit()
