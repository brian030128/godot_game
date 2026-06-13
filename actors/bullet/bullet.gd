extends Area2D
## Player projectile. Travels in a fixed direction, damages the first enemy it
## touches, and despawns on enemy hit, wall hit, or lifetime expiry.
##
## An Area2D (not a body) so it passes through cheaply and reports overlaps via
## body_entered. Layer 4 (player_bullets); mask 1 (world) + 3 (enemies).

## Travel speed in px/sec.
@export var speed: float = 600.0
## Damage dealt to an enemy on contact.
@export var damage: int = 1

## Normalized travel direction, assigned by the shooter before adding to tree.
var direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$Lifetime.timeout.connect(queue_free)
	# Orient the sprite along travel (purely cosmetic for a round bullet).
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta


func _on_body_entered(body: Node) -> void:
	# Enemies expose take_damage(); anything else (a wall) just stops the bullet.
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
