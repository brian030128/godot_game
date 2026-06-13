extends Node2D
class_name SkillIndicator
## World-space targeting overlay shown while the player is aiming a skill. Lives
## as a child of the player so it's centered on the caster automatically (mirrors
## RangeIndicator).
##
## Two modes, chosen by the skill's cast_method:
##   * Arrow / railway — DIRECTION skills: a translucent arrow from the player out
##     to `extent` px along the aim direction.
##   * Radius ring — TAP skills: a translucent filled circle of `extent` px around
##     the player showing the area of effect.
##
## Drawn in node-local space (player at origin); show()/hide() via `visible`.

## Half-width of the directional arrow shaft (px).
@export var arrow_half_width: float = 10.0
## Length of each side of the arrowhead (px).
@export var arrowhead_size: float = 28.0

var _mode: Skill.CastMethod = Skill.CastMethod.TAP
var _direction: Vector2 = Vector2.RIGHT
var _extent: float = 0.0
var _color: Color = Color.WHITE


func _ready() -> void:
	visible = false


## Show the overlay for a DIRECTION skill aimed along `direction` (already
## resolved to a unit vector by the caller), reaching `extent` px.
func show_direction(direction: Vector2, extent: float, color: Color) -> void:
	_mode = Skill.CastMethod.DIRECTION
	_direction = direction if direction != Vector2.ZERO else Vector2.RIGHT
	_extent = extent
	_color = color
	visible = true
	queue_redraw()


## Show the affected-radius overlay for a TAP skill (`extent` = radius px).
func show_radius(extent: float, color: Color) -> void:
	_mode = Skill.CastMethod.TAP
	_extent = extent
	_color = color
	visible = true
	queue_redraw()


func hide_preview() -> void:
	visible = false


func _draw() -> void:
	if _extent <= 0.0:
		return
	match _mode:
		Skill.CastMethod.DIRECTION:
			_draw_arrow()
		_:
			_draw_radius()


func _draw_radius() -> void:
	# Faint fill plus a crisp ring so the area reads clearly.
	draw_circle(Vector2.ZERO, _extent, Color(_color.r, _color.g, _color.b, 0.18))
	draw_arc(Vector2.ZERO, _extent, 0.0, TAU, 64, Color(_color.r, _color.g, _color.b, 0.7), 3.0, true)


func _draw_arrow() -> void:
	# Shaft as a thick translucent line up to where the head begins, then a solid
	# triangular head at the tip. Drawn along the local x-axis and rotated.
	var tip := _direction * _extent
	var head_base := _direction * maxf(_extent - arrowhead_size, 0.0)
	var perp := _direction.orthogonal()

	# Shaft (railway) — a filled quad so it has visible width.
	var shaft: PackedVector2Array = [
		perp * arrow_half_width,
		head_base + perp * arrow_half_width,
		head_base - perp * arrow_half_width,
		-perp * arrow_half_width,
	]
	draw_colored_polygon(shaft, Color(_color.r, _color.g, _color.b, 0.25))

	# Arrowhead.
	var head: PackedVector2Array = [
		tip,
		head_base + perp * arrowhead_size * 0.6,
		head_base - perp * arrowhead_size * 0.6,
	]
	draw_colored_polygon(head, Color(_color.r, _color.g, _color.b, 0.5))
