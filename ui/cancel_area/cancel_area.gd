extends Control
class_name CancelArea
## A drop-target circle shown at the top-right while a skill is being aimed.
## Dragging a skill button's finger into this circle and releasing there cancels
## the cast instead of firing it — letting the player peek a skill's range/aim and
## then back out without spending it.
##
## Purely a visual + hit-test target: it never handles input itself (mouse_filter
## IGNORE). The active SkillButton drives its visibility/hover state and queries
## contains_point() in shared canvas space (both live in the same CanvasLayer).

## Visual + hit-test radius of the cancel circle (px).
@export var radius: float = 70.0
## Base tint of the circle and "X" glyph.
@export var color: Color = Color(0.9, 0.3, 0.3)

var _hovered: bool = false


func _ready() -> void:
	visible = false


## Canvas-space center of the circle (control center).
func _canvas_center() -> Vector2:
	return global_position + size * 0.5


## True if `point` (canvas space) falls within the cancel circle.
func contains_point(point: Vector2) -> bool:
	return point.distance_to(_canvas_center()) <= radius


## Reveal the target (called when a skill aim begins).
func show_area() -> void:
	_hovered = false
	visible = true
	queue_redraw()


## Hide the target (called on release/cancel).
func hide_area() -> void:
	visible = false


## Highlight while the dragging finger is over the circle.
func set_hovered(hovered: bool) -> void:
	if hovered == _hovered:
		return
	_hovered = hovered
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var fill_alpha := 0.45 if _hovered else 0.2
	draw_circle(center, radius, Color(color.r, color.g, color.b, fill_alpha))
	draw_arc(center, radius, 0.0, TAU, 48, Color(color.r, color.g, color.b, 0.85), 4.0, true)

	# An "X" glyph so the circle reads as "cancel".
	var s := radius * 0.4
	var glyph := Color(1, 1, 1, 0.9 if _hovered else 0.65)
	draw_line(center + Vector2(-s, -s), center + Vector2(s, s), glyph, 5.0, true)
	draw_line(center + Vector2(-s, s), center + Vector2(s, -s), glyph, 5.0, true)
