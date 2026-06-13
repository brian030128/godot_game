extends Node2D
## Paints a cozy room onto the TileMapLayer procedurally and dresses it with
## generated furniture props.
##
## Atlas tile coords:
##   (0,0) floor   (1,0) inlay accent   (2,0) wall   (3,0) wall_top

@onready var ground: TileMapLayer = $Ground
@onready var props: Node2D = $Props

const SOURCE_ID := 0
const FLOOR := Vector2i(0, 0)
const ACCENT := Vector2i(1, 0)
const WALL := Vector2i(2, 0)
const WALL_TOP := Vector2i(3, 0)

const BOOKSHELF := preload("res://assets/props/bookshelf.png")
const PLANT := preload("res://assets/props/plant.png")
const TABLE := preload("res://assets/props/table.png")
const CRATES := preload("res://assets/props/crates.png")

@export var cols: int = 50
@export var rows: int = 31


func _ready() -> void:
	ground.clear()
	for child in props.get_children():
		child.queue_free()

	for y in rows:
		for x in cols:
			var on_border := x == 0 or y == 0 or x == cols - 1 or y == rows - 1
			if on_border:
				ground.set_cell(Vector2i(x, y), SOURCE_ID, WALL_TOP if y == 0 else WALL)
			else:
				ground.set_cell(Vector2i(x, y), SOURCE_ID, ACCENT if _is_accent_tile(x, y) else FLOOR)

	_spawn_props()


func _is_accent_tile(x: int, y: int) -> bool:
	var rug_left := 18
	var rug_right := 31
	var rug_top := 10
	var rug_bottom := 20
	if x < rug_left or x > rug_right or y < rug_top or y > rug_bottom:
		return false

	var border := x == rug_left or x == rug_right or y == rug_top or y == rug_bottom
	var center_cross := x == (rug_left + rug_right) / 2 or y == (rug_top + rug_bottom) / 2
	var inner_pattern := (x + y) % 2 == 0 and x > rug_left + 1 and x < rug_right - 1 and y > rug_top + 1 and y < rug_bottom - 1
	return border or center_cross or inner_pattern


func _spawn_props() -> void:
	_add_prop(BOOKSHELF, Vector2(96, 52), Rect2(6, 66, 52, 22))
	_add_prop(PLANT, Vector2(208, 88), Rect2(12, 40, 24, 18))
	_add_prop(BOOKSHELF, Vector2(1440, 52), Rect2(6, 66, 52, 22))
	_add_prop(PLANT, Vector2(1344, 88), Rect2(12, 40, 24, 18))
	_add_prop(TABLE, Vector2(768, 430), Rect2(8, 18, 48, 20))
	_add_prop(CRATES, Vector2(192, 736), Rect2(4, 30, 56, 30))
	_add_prop(CRATES, Vector2(1280, 736), Rect2(4, 30, 56, 30))


func _add_prop(texture: Texture2D, top_left: Vector2, collision_rect: Rect2) -> void:
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
