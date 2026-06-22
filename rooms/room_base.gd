extends Node2D
class_name RoomBase
## Base for hand-authored rooms. Each concrete room is a subclass that overrides
## _layout() to return a char grid (see legend) plus its entry_side. This base
## parses the grid, paints the TileMapLayer, places props, and exposes build()
## which returns the data the run controller needs: where the player enters, where
## the exits are, and where mobs spawn.
##
## Rooms are authored as text grids (not painted in the editor) because a
## TileMapLayer stores its cells as an un-editable binary blob in the .tscn.
##
## Grid legend (one char per 32px tile):
##   #  wall          .  floor         :  accent (rug inlay)
##   D  exit door cell (painted floor so it's passable; the controller drops a
##      gate + door here). Exits sit in contiguous 3-cell runs on the wall
##      OPPOSITE the entry, so the player can scan all options at once.
##   E  player entry cell (painted floor)
##   m  mob spawn cell (painted floor)
##   B bookshelf   P plant   T table   C crates   (props; cell painted floor)

# Optional: a PNG-skinned room (see room_06.gd) has no TileMapLayer/Props — it draws
# a single map image and builds collision in code — so these resolve to null there.
@onready var ground: TileMapLayer = get_node_or_null("Ground")
@onready var props: Node2D = get_node_or_null("Props")

const SOURCE_ID := 0
const FLOOR := Vector2i(0, 0)
const ACCENT := Vector2i(1, 0)
const WALL := Vector2i(2, 0)
const WALL_TOP := Vector2i(3, 0)

const TILE := 32
## Each exit door run must be this many cells wide to match door.gd's gate width.
const EXIT_RUN := 3
## Minimum room size in tiles so the camera (40x22.5 visible) never shows void.
const MIN_COLS := 42
const MIN_ROWS := 24

const BOOKSHELF := preload("res://assets/props/bookshelf.png")
const PLANT := preload("res://assets/props/plant.png")
const TABLE := preload("res://assets/props/table.png")
const CRATES := preload("res://assets/props/crates.png")

## Which wall the player enters from. Subclasses set this to match their grid.
@export var entry_side: String = "bottom"

## A* grid over this room's tiles, rebuilt every build(). cell_size matches TILE
## and offset is half a tile, so a grid point's position equals _cell_center(x, y).
## Solid cells are the ones _blocks_movement() returns true for (walls + props).
## Mobs query it via find_path() to route around obstacles.
var nav_grid: AStarGrid2D = null


func _ready() -> void:
	# Render standalone (e.g. opening the room scene directly) — build() is
	# idempotent so the controller calling it again at runtime is harmless.
	build()


## Subclasses override to return their layout grid. The base dispatches through
## this method rather than reading a `const LAYOUT` directly, because GDScript
## does not resolve a subclass const from base-class code by name.
func _layout() -> Array[String]:
	return []


## Parse the grid, paint the room, place props, and return room data:
##   {
##     entry_pos: Vector2, exit_side: String, exit_anchors: Array[Vector2],
##     spawns: Array[Vector2], cols: int, rows: int
##   }
func build() -> Dictionary:
	var grid := _layout()
	var rows := grid.size()
	var cols := 0
	for line in grid:
		cols = maxi(cols, line.length())

	assert(rows >= MIN_ROWS and cols >= MIN_COLS,
		"Room grid too small (%dx%d, need >= %dx%d)" % [cols, rows, MIN_COLS, MIN_ROWS])
	for line in grid:
		assert(line.length() == cols, "Room grid is ragged: all rows must be %d wide" % cols)

	ground.clear()
	# Free props synchronously so a rebuild never briefly shows the old set.
	for child in props.get_children():
		props.remove_child(child)
		child.free()

	var spawns: Array[Vector2] = []
	var exit_cells: Array[Vector2i] = []
	var entry_cells: Array[Vector2i] = []

	for y in rows:
		var line := grid[y]
		for x in cols:
			var ch := line[x]
			var cell := Vector2i(x, y)
			match ch:
				"#":
					ground.set_cell(cell, SOURCE_ID, _wall_tile(grid, x, y, rows))
				":":
					ground.set_cell(cell, SOURCE_ID, ACCENT)
				_:
					ground.set_cell(cell, SOURCE_ID, FLOOR)

			match ch:
				"E": entry_cells.append(cell)
				"m": spawns.append(_cell_center(x, y))
				"D": exit_cells.append(cell)
				"B": _add_prop(BOOKSHELF, cell, Rect2(6, 66, 52, 22))
				"P": _add_prop(PLANT, cell, Rect2(12, 40, 24, 18))
				"T": _add_prop(TABLE, cell, Rect2(8, 18, 48, 20))
				"C": _add_prop(CRATES, cell, Rect2(4, 30, 56, 30))

	var exit_side := _wall_of(exit_cells, cols, rows)
	var exit_anchors := _exit_anchors(exit_cells, exit_side)

	# The entry is a single 3-cell doorway on its wall, like an exit but the run
	# controller marks it closed and spawns the player just inside it.
	var detected_entry := _wall_of(entry_cells, cols, rows)
	var entry_runs := _exit_anchors(entry_cells, detected_entry)
	var entry_anchor: Vector2 = entry_runs[0] if not entry_runs.is_empty() \
		else Vector2(cols * TILE / 2, rows * TILE / 2)
	# Stand the player ~1.5 tiles inside the doorway, clear of the entry gate.
	var entry_pos: Vector2 = entry_anchor + _inward_of(detected_entry) * (TILE * 1.5)

	_build_nav(grid, cols, rows)

	return {
		"entry_pos": entry_pos,
		"entry_side": detected_entry,
		"entry_anchor": entry_anchor,
		"exit_side": exit_side,
		"exit_anchors": exit_anchors,
		"spawns": spawns,
		"cols": cols,
		"rows": rows,
	}


## A wall cell reads as WALL_TOP (a face you look at) when the cell below it is
## not a wall; otherwise it's a plain WALL. This makes the top of each wall run
## render correctly from the top-down view.
func _wall_tile(grid: Array[String], x: int, y: int, rows: int) -> Vector2i:
	var below_is_wall := y + 1 < rows and x < grid[y + 1].length() and grid[y + 1][x] == "#"
	return WALL if below_is_wall else WALL_TOP


## Determine which wall a set of door cells sits on, from their grid position.
## All cells in a set share one wall. Used for both exits and the entry.
func _wall_of(cells: Array[Vector2i], cols: int, rows: int) -> String:
	if cells.is_empty():
		return ""
	var c: Vector2i = cells[0]
	if c.y == 0: return "top"
	if c.y == rows - 1: return "bottom"
	if c.x == 0: return "left"
	if c.x == cols - 1: return "right"
	return ""


## Unit vector pointing from a wall into the room (for offsetting the spawn /
## decal inward off the doorway).
func _inward_of(side: String) -> Vector2:
	match side:
		"top": return Vector2.DOWN
		"bottom": return Vector2.UP
		"left": return Vector2.RIGHT
		"right": return Vector2.LEFT
		_: return Vector2.ZERO


## Group contiguous exit-door cells into runs and return the world centre of each
## run. Runs lie along x for top/bottom walls, along y for left/right walls.
func _exit_anchors(cells: Array[Vector2i], exit_side: String) -> Array[Vector2]:
	var anchors: Array[Vector2] = []
	if cells.is_empty():
		return anchors

	var horizontal := exit_side == "top" or exit_side == "bottom"
	# Sort along the run axis so contiguous cells are adjacent in the list.
	if horizontal:
		cells.sort_custom(func(a, b): return a.x < b.x)
	else:
		cells.sort_custom(func(a, b): return a.y < b.y)

	var run: Array[Vector2i] = [cells[0]]
	for i in range(1, cells.size()):
		var prev: Vector2i = run[run.size() - 1]
		var cur: Vector2i = cells[i]
		var adjacent := (cur.x == prev.x + 1 and cur.y == prev.y) if horizontal \
			else (cur.y == prev.y + 1 and cur.x == prev.x)
		if adjacent:
			run.append(cur)
		else:
			anchors.append(_run_center(run))
			run = [cur]
	anchors.append(_run_center(run))
	return anchors


func _run_center(run: Array[Vector2i]) -> Vector2:
	assert(run.size() == EXIT_RUN,
		"Exit door run must be %d cells wide, got %d" % [EXIT_RUN, run.size()])
	var sum := Vector2.ZERO
	for c in run:
		sum += _cell_center(c.x, c.y)
	return sum / run.size()


func _cell_center(x: int, y: int) -> Vector2:
	return Vector2(x * TILE + TILE / 2, y * TILE + TILE / 2)


## Cells that mobs (and the player) cannot walk through: walls and every prop.
## Door/entry/spawn/floor/accent cells are all passable.
func _blocks_movement(ch: String) -> bool:
	return ch == "#" or ch == "B" or ch == "P" or ch == "T" or ch == "C"


## (Re)build nav_grid from the parsed char grid. Must run after region/cell_size
## are set and BEFORE marking solidity, because AStarGrid2D.update() resets every
## point to non-solid.
func _build_nav(grid: Array[String], cols: int, rows: int) -> void:
	nav_grid = AStarGrid2D.new()
	nav_grid.region = Rect2i(0, 0, cols, rows)
	nav_grid.cell_size = Vector2(TILE, TILE)
	nav_grid.offset = Vector2(TILE / 2.0, TILE / 2.0)  # point == _cell_center
	# AT_LEAST_ONE_WALKABLE allows diagonals but never cuts a wall/prop corner;
	# the default ALWAYS would let mobs slip diagonally through a corner.
	nav_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	nav_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	nav_grid.update()  # prepares points AND clears solidity -> set solids after
	for y in rows:
		var line := grid[y]
		for x in cols:
			var ch := line[x] if x < line.length() else "#"
			if _blocks_movement(ch):
				nav_grid.set_point_solid(Vector2i(x, y), true)


## Return world-space waypoints routing from `from_world` to `to_world` around
## solid cells, or an empty array if there's no grid. Callers treat an empty
## result as "steer directly", so out-of-room / unreachable cases degrade
## gracefully instead of freezing. Both endpoints are clamped into the grid and
## snapped off solid cells so A* always has a valid start and goal.
func find_path(from_world: Vector2, to_world: Vector2) -> PackedVector2Array:
	if nav_grid == null:
		return PackedVector2Array()
	var from_id := _nearest_free(_clamp_id(_world_to_id(from_world)))
	var to_id := _nearest_free(_clamp_id(_world_to_id(to_world)))
	if from_id == to_id:
		return PackedVector2Array([_cell_center(to_id.x, to_id.y)])
	# allow_partial_path=true: a walled-off goal still yields a best-effort route.
	return nav_grid.get_point_path(from_id, to_id, true)


func _world_to_id(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func _clamp_id(id: Vector2i) -> Vector2i:
	var r := nav_grid.region
	return Vector2i(
		clampi(id.x, r.position.x, r.position.x + r.size.x - 1),
		clampi(id.y, r.position.y, r.position.y + r.size.y - 1))


## Return `id` if walkable, else the closest non-solid cell found in expanding
## ring shells. Walls/props are thin, so a free cell is always within a few rings.
func _nearest_free(id: Vector2i) -> Vector2i:
	if not nav_grid.is_point_solid(id):
		return id
	for radius in range(1, 4):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue  # ring shell only, skip the filled interior
				var n := Vector2i(id.x + dx, id.y + dy)
				if nav_grid.is_in_boundsv(n) and not nav_grid.is_point_solid(n):
					return n
	return id  # give up; allow_partial_path in find_path handles it


func _add_prop(texture: Texture2D, cell: Vector2i, collision_rect: Rect2) -> void:
	var top_left := Vector2(cell.x * TILE, cell.y * TILE)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = top_left
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	props.add_child(sprite)

	var blocker := StaticBody2D.new()
	blocker.position = top_left + collision_rect.position + collision_rect.size * 0.5
	props.add_child(blocker)

	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = collision_rect.size
	shape.shape = rectangle
	blocker.add_child(shape)
