extends Control
## On-screen fire button for touch. Emits `pressed` on each tap (tap-to-fire-one).
##
## Drawn via _draw() in the same ring+knob style as the virtual joystick for
## visual consistency. Touch emulation from mouse (project setting) lets this
## work with the mouse on desktop too. Keyboard "attack" is handled by the
## player as a separate desktop fallback.

## Emitted once per press (a fresh finger landing on the button).
signal pressed

## Visual radius of the button (px).
@export var radius: float = 90.0

var _touch_index: int = -1          # which finger is holding the button (-1 = none)
var _center: Vector2 = Vector2.ZERO


func _ready() -> void:
	_recenter()
	resized.connect(_recenter)


func _recenter() -> void:
	_center = size * 0.5
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			pressed.emit()
			queue_redraw()
			accept_event()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			queue_redraw()
			accept_event()


func _draw() -> void:
	var held := _touch_index != -1
	# Filled body — brighten while held for tactile feedback.
	var fill := Color(0.85, 0.45, 0.45, 0.75) if held else Color(0.8, 0.3, 0.3, 0.55)
	draw_circle(_center, radius, fill)
	draw_arc(_center, radius, 0.0, TAU, 48, Color(0.95, 0.85, 0.7, 0.6), 4.0, true)
