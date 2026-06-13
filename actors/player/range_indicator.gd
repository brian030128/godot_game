extends Node2D
## Briefly flashes a white ring showing the player's attack range. Triggered
## when an attack finds no enemy in range, as "nothing to shoot" feedback.
##
## Lives as a child of the player so it's centered on the player automatically.
## Its own modulate is animated independently of the player sprite.

## Seconds for the ring to fade out after a flash.
@export var fade_time: float = 0.3

var _radius: float = 0.0
var _tween: Tween = null


func _ready() -> void:
	modulate.a = 0.0  # hidden until flashed


func flash(radius: float) -> void:
	_radius = radius
	queue_redraw()
	modulate.a = 1.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, fade_time)


func _draw() -> void:
	if _radius <= 0.0:
		return
	# Faint fill plus a crisp ring so the range reads clearly during the flash.
	draw_circle(Vector2.ZERO, _radius, Color(1, 1, 1, 0.12))
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 64, Color.WHITE, 2.0, true)
