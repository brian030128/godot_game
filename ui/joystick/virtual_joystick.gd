extends Control
## On-screen virtual joystick for touch movement.
##
## Handles InputEventScreenTouch / InputEventScreenDrag within an activation
## radius, draws a base ring + draggable knob via _draw(), and exposes a
## normalized output vector (and signal) for consumers like the player.
##
## Touch emulation from mouse is enabled in project settings, so this also
## works with the mouse on desktop for testing.

## Emitted whenever the output direction changes (including back to Vector2.ZERO on release).
signal direction_changed(direction: Vector2)

## Radius (px) the knob can travel from the base center.
@export var max_radius: float = 90.0
## Visual radius of the base ring (px).
@export var base_radius: float = 110.0
## Visual radius of the knob (px).
@export var knob_radius: float = 48.0

## Normalized direction, components in -1..1. ZERO when released.
var output: Vector2 = Vector2.ZERO

var _touch_index: int = -1          # which touch finger owns the joystick (-1 = none)
var _center: Vector2 = Vector2.ZERO # base center in local coords
var _knob_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	_recenter()
	resized.connect(_recenter)


func _recenter() -> void:
	_center = size * 0.5
	_knob_pos = _center
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_update_knob(event.position)
			accept_event()
		elif not event.pressed and event.index == _touch_index:
			_release()
			accept_event()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_knob(event.position)
		accept_event()


func _update_knob(local_pos: Vector2) -> void:
	var offset: Vector2 = local_pos - _center
	if offset.length() > max_radius:
		offset = offset.normalized() * max_radius
	_knob_pos = _center + offset
	_set_output(offset / max_radius)
	queue_redraw()


func _release() -> void:
	_touch_index = -1
	_knob_pos = _center
	_set_output(Vector2.ZERO)
	queue_redraw()


func _set_output(value: Vector2) -> void:
	if value != output:
		output = value
		direction_changed.emit(output)


func _draw() -> void:
	# Base ring.
	draw_circle(_center, base_radius, Color(0.1, 0.1, 0.15, 0.35))
	draw_arc(_center, base_radius, 0.0, TAU, 48, Color(0.9, 0.85, 0.65, 0.5), 4.0, true)
	# Knob.
	draw_circle(_knob_pos, knob_radius, Color(0.9, 0.85, 0.65, 0.7))
