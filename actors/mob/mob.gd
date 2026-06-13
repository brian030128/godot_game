extends CharacterBody2D
## Top-down enemy. Chases an injected target (the player) and deals contact
## damage on a cooldown while overlapping it. Dies when health reaches 0.
##
## Body: layer 3 (enemies), mask 1 (world) so it walks against walls but not
## through other mobs/the player. A child HitArea (mask 2) detects the player
## for contact damage. Added to group "enemies" so bullets and the player's
## targeting can find it.

## Movement speed in px/sec.
@export var speed: float = 90.0
## Hit points; the mob dies at 0.
@export var max_health: int = 3
## Damage dealt to the player per contact tick.
@export var contact_damage: int = 1
## Seconds between contact-damage ticks while overlapping the player.
@export var damage_interval: float = 0.7

## The node to chase (the player). Injected by the spawning scene.
var target: Node2D = null

var _health: int = 0
var _player_in_range: Node = null

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _damage_timer: Timer = $DamageTimer


func _ready() -> void:
	add_to_group("enemies")
	_health = max_health
	$HitArea.body_entered.connect(_on_hit_area_body_entered)
	$HitArea.body_exited.connect(_on_hit_area_body_exited)
	_damage_timer.wait_time = damage_interval
	_damage_timer.timeout.connect(_on_damage_tick)


func _physics_process(_delta: float) -> void:
	if target == null or not is_instance_valid(target):
		velocity = Vector2.ZERO
		return
	var direction := global_position.direction_to(target.global_position)
	velocity = direction * speed
	move_and_slide()


func take_damage(amount: int) -> void:
	_health -= amount
	_flash()
	if _health <= 0:
		queue_free()


func _flash() -> void:
	# Brief white flash so hits read clearly.
	_sprite.modulate = Color(2.0, 2.0, 2.0)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.15)


func _on_hit_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = body
		_damage_player()  # immediate first hit on contact
		_damage_timer.start()


func _on_hit_area_body_exited(body: Node) -> void:
	if body == _player_in_range:
		_player_in_range = null
		_damage_timer.stop()


func _on_damage_tick() -> void:
	_damage_player()


func _damage_player() -> void:
	if _player_in_range != null and _player_in_range.has_method("take_damage"):
		_player_in_range.take_damage(contact_damage)
