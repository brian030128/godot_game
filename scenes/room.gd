extends Node2D
## Paints a walled room onto the TileMapLayer procedurally.
##
## Painting in code (set_cell) instead of hand-authoring binary tile_map_data
## keeps the scene robust and easy to tweak. Atlas tile coords:
##   (0,0) floor   (1,0) floor+flower   (2,0) wall   (3,0) wall_top

@onready var ground: TileMapLayer = $Ground

const SOURCE_ID := 0
const FLOOR := Vector2i(0, 0)
const FLOWER := Vector2i(1, 0)
const WALL := Vector2i(2, 0)
const WALL_TOP := Vector2i(3, 0)

## Room size in tiles (50x31 ≈ 1600x992 px at 32px tiles).
@export var cols: int = 50
@export var rows: int = 31


func _ready() -> void:
	for y in rows:
		for x in cols:
			var on_border := x == 0 or y == 0 or x == cols - 1 or y == rows - 1
			if on_border:
				# Use the bright "wall_top" along the top row, plain wall elsewhere.
				ground.set_cell(Vector2i(x, y), SOURCE_ID, WALL_TOP if y == 0 else WALL)
			else:
				# Sparse flowers scattered across the floor.
				var flower := (x * 7 + y * 13) % 17 == 0
				ground.set_cell(Vector2i(x, y), SOURCE_ID, FLOWER if flower else FLOOR)
