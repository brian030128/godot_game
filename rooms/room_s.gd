extends RoomBase
class_name RoomS
## A room skinned by a single beautiful image (map2.png) instead of a tile grid.
##
## Same structure as room_06: the look is the image itself (a `Foundation` Sprite2D drawn
## behind everything), plus the same pixels alpha-cut to just the wall band drawn ABOVE the
## player so they're occluded when they step into a doorway — the "walk into the door"
## depth. The top band is split into a depth-sorted `WallsTop` (wall_foreground.gd) and the
## sides+bottom go into an always-on-top `WallsRest`. All three PNGs were cut from map2.png
## by the same numbers that drive the logical grid below — change them together.
##
## There is no TileMapLayer. This script keeps a purely *logical* char grid (never
## rendered) sized to the image, and from it builds the A* nav, the mob spawns, the
## door/entry anchors, and real StaticBody2D wall colliders.
##
## map2.png depicts ONE room: 1 entry doorway at bottom-center, 3 exit doorways across the
## top, all glowing teal. The painted wall band is BAND cells thick, so doors are short
## tunnels; build() is overridden (like room_06) to set the door sides explicitly because
## the thresholds sit on the band's inner row, not the grid edge.

const COLS := 52
const ROWS := 29
## Wall band thickness in tiles, all four sides (matches the asset build numbers).
const BAND := 3

## Door openings as inclusive [first, last] tile columns. Measured from map2.png by
## profiling the teal doorway glow per cell through the top/bottom wall bands.
const TOP_OPENINGS := [[12, 14], [24, 26], [37, 39]]   # three exits, top band
const BOTTOM_OPENINGS := [[24, 26]]                    # one entry, bottom band

## Mob spawn cells (interior), as [col, row]. Spread across the room, clear of walls/doors.
const SPAWN_CELLS := [
	[13, 8], [26, 7], [38, 8],
	[9, 14], [43, 14],
	[13, 21], [26, 22], [38, 21],
]

## Interior props painted into map2s_floor.png that the player must NOT walk onto.
## Pixel boxes (Rect2i x,y,w,h) in the source image's own coordinates (1664x928 ==
## COLS*TILE x ROWS*TILE, so pixels map 1:1 to tiles). Detected by two pipelines and
## reconciled (see tools/sam/detect_obstacles.py for pipeline 1 / SAM auto-mask, and
## tools/sam/obstacles_manual.json for pipeline 2 / visual curation). Each interior
## floor cell whose centre falls inside one of these boxes is stamped 'O' (solid):
## it gets a StaticBody2D collider AND a nav-grid solid, so player and mobs both treat
## it as an obstacle. Cells already in the wall band stay '#' (their box overlap is
## redundant). To re-derive: rerun the detectors, eyeball tmp/obstacles_combined_preview.png.
const OBSTACLES: Array[Rect2i] = [
	Rect2i(40, 70, 175, 145),     # teddy bear (top-left)              [SAM missed / visual]
	Rect2i(20, 215, 130, 125),    # candle + mushroom cluster (left)   [visual]
	Rect2i(790, 455, 72, 70),     # central spool/gear mechanism       [SAM + visual]
	Rect2i(1235, 80, 210, 155),   # rocking horse (top-right)          [SAM missed / visual]
	Rect2i(25, 515, 190, 180),    # cage / spinning wheel (bottom-left)[SAM missed / visual]
	Rect2i(1355, 425, 170, 140),  # loom / machinery (mid-right)       [SAM + visual]
	Rect2i(1420, 600, 180, 225),  # birdcage cluster (bottom-right)    [SAM + visual]
	Rect2i(1500, 250, 100, 110),  # candle cluster (right wall)        [visual]
]


func _init() -> void:
	entry_side = "bottom"


## Build the logical grid (never painted). Legend matches RoomBase: '#' wall,
## '.' floor, 'D' top-exit threshold, 'E' bottom-entry threshold, 'm' mob spawn.
func _layout() -> Array[String]:
	var grid: Array[String] = []
	for y in ROWS:
		var row := ""
		for x in COLS:
			row += _cell_char(x, y)
		grid.append(row)
	return _stamp_obstacles(grid)


## Overlay the detected interior props (OBSTACLES) onto the parsed grid: any walkable
## interior cell ('.' / 'm') whose centre lies inside a prop box becomes 'O' (solid).
## Wall-band '#' and door 'D'/'E' cells are left untouched so doorways stay open.
func _stamp_obstacles(grid: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for y in ROWS:
		var line := grid[y]
		var row := ""
		for x in COLS:
			var ch := line[x]
			if ch == "." or ch == "m":
				var center := Vector2i(x * TILE + TILE / 2, y * TILE + TILE / 2)
				for box in OBSTACLES:
					if box.has_point(center):
						ch = "O"
						break
			row += ch
		out.append(row)
	return out


## Both '#' (walls) and 'O' (interior props) are impassable to player and mobs.
func _is_solid(ch: String) -> bool:
	return ch == "#" or ch == "O"


## Override RoomBase so the A* nav grid marks prop cells solid too (mobs route around).
func _blocks_movement(ch: String) -> bool:
	return _is_solid(ch)


func _cell_char(x: int, y: int) -> String:
	var top := y < BAND
	var bottom := y >= ROWS - BAND
	var left := x < BAND
	var right := x >= COLS - BAND

	if not (top or bottom or left or right):
		for s in SPAWN_CELLS:
			if s[0] == x and s[1] == y:
				return "m"
		return "."

	# Door tunnels punch straight through the band; the threshold (D/E) sits on the
	# band's inner row, the rest of the tunnel above/below it is open floor.
	if top:
		for o in TOP_OPENINGS:
			if x >= o[0] and x <= o[1]:
				return "D" if y == BAND - 1 else "."
	if bottom:
		for o in BOTTOM_OPENINGS:
			if x >= o[0] and x <= o[1]:
				return "E" if y == ROWS - BAND else "."
	return "#"


## Like RoomBase.build() but with the door sides fixed (exits=top, entry=bottom)
## because the thresholds sit on the band's inner row, not the grid edge. Reuses the
## generic nav/anchor helpers and adds code-built wall collision in place of tiles.
func build() -> Dictionary:
	var grid := _layout()

	var spawns: Array[Vector2] = []
	var exit_cells: Array[Vector2i] = []
	var entry_cells: Array[Vector2i] = []
	for y in ROWS:
		var line := grid[y]
		for x in COLS:
			match line[x]:
				"m": spawns.append(_cell_center(x, y))
				"D": exit_cells.append(Vector2i(x, y))
				"E": entry_cells.append(Vector2i(x, y))

	var exit_anchors := _exit_anchors(exit_cells, "top")
	var entry_runs := _exit_anchors(entry_cells, "bottom")
	var entry_anchor: Vector2 = entry_runs[0] if not entry_runs.is_empty() \
		else Vector2(COLS * TILE / 2, ROWS * TILE / 2)
	# Stand the player clear of the BAND-thick entry tunnel, well into the room.
	var entry_pos: Vector2 = entry_anchor + Vector2.UP * (TILE * (BAND + 1))

	_build_nav(grid, COLS, ROWS)
	_build_collision(grid)

	return {
		"entry_pos": entry_pos,
		"entry_side": "bottom",
		"entry_anchor": entry_anchor,
		"exit_side": "top",
		"exit_anchors": exit_anchors,
		# Push the gate + transport trigger ~2 tiles out toward the top edge so the player
		# can walk up into the BAND-thick doorway (occluded by the top wall) any time; the
		# gate blocks only the far end until the room clears, and the transition fires once
		# they're deep in the opening — never warping at the doorway mouth.
		"exit_opening_inset": float((BAND - 1) * TILE),
		"spawns": spawns,
		"cols": COLS,
		"rows": ROWS,
	}


## The player collides at its feet but its sprite stands ~72px tall, so walking up to the
## top wall its body overshoots into the wall band. Extend the innermost TOP wall row
## downward by this much so the player stops with its sprite just below the visible wall
## (it reads as standing in front of the wall, not on it / sunk into it). Tunable.
const TOP_APRON := 36.0


## Replace the tileset's per-tile collision: one StaticBody2D per horizontal run of
## solid cells (walls '#' and interior props 'O'), on collision_layer 1 (world) like
## the tile walls and the door gates.
func _build_collision(grid: Array[String]) -> void:
	for y in ROWS:
		var line := grid[y]
		var x := 0
		while x < COLS:
			if not _is_solid(line[x]):
				x += 1
				continue
			var start := x
			while x < COLS and _is_solid(line[x]):
				x += 1
			# The innermost top-wall row gets an apron extending into the room. Prop
			# rows (y != BAND-1) get a plain one-tile-tall collider.
			var extra := TOP_APRON if y == BAND - 1 else 0.0
			_add_wall(start, x, y, extra)


func _add_wall(x0: int, x1: int, y: int, extra_height: float = 0.0) -> void:
	var width := (x1 - x0) * TILE
	var height := TILE + extra_height
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	shape.shape = rect
	shape.position = Vector2(x0 * TILE + width / 2.0, y * TILE + height / 2.0)
	body.add_child(shape)
