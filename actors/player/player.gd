extends CharacterBody2D
## Top-down player. Moves in 8 directions via move_and_slide() and fires a
## ranged weapon at the nearest enemy in range.
##
## Movement comes from an injected virtual joystick (loose coupling, per
## best_practices/scene_organization.rst) OR keyboard (WASD/arrows) as a
## desktop-testing fallback. The joystick and attack button references are
## assigned by the parent scene rather than looked up by hard-coded path.

## Movement speed in px/sec.
@export var speed: float = 240.0
## Max hit points.
@export var max_health: int = 5
## Targeting range (px): bullets only fire at enemies within this distance.
@export var attack_range: float = 320.0
## Bullet scene instanced on each attack.
@export var bullet_scene: PackedScene
## Seconds between walk-frame advances while moving.
@export var walk_frame_time: float = 0.12

## Emitted when health changes, so UI can react.
signal health_changed(health: int, max_health: int)
## Emitted once when health reaches 0.
signal died

## Optional joystick whose `output` vector drives movement. Assigned by the
## owning scene (e.g. main.gd). When null, only keyboard input applies.
var joystick: Node = null
## Optional on-screen attack button. Assigned by the owning scene; its `pressed`
## signal is wired up on assignment (the parent's _ready runs after ours, so we
## can't connect from our own _ready).
var attack_button: Node = null:
	set(value):
		attack_button = value
		if attack_button != null and not attack_button.pressed.is_connected(_on_attack):
			attack_button.pressed.connect(_on_attack)

var _health: int = 0
var _alive: bool = true
var _walk_frame: int = 0
var _walk_timer: float = 0.0
var _facing_row: int = 0

const ROW_DOWN := 0
const ROW_LEFT := 1
const ROW_RIGHT := 2
const ROW_UP := 3

const WALK_FRAMES := [0, 1, 2, 1]

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _range_indicator: Node2D = $RangeIndicator


func _ready() -> void:
	add_to_group("player")
	_health = max_health
	health_changed.emit(_health, max_health)


func _physics_process(delta: float) -> void:
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Joystick overrides keyboard when it is actively pushed.
	if joystick != null and joystick.output != Vector2.ZERO:
		direction = joystick.output

	if direction.length() > 1.0:
		direction = direction.normalized()

	velocity = direction * speed
	move_and_slide()
	_update_animation(direction, delta)


func _unhandled_input(event: InputEvent) -> void:
	# Desktop fallback: the on-screen button is the primary trigger on mobile.
	if event.is_action_pressed("attack"):
		_on_attack()


func _update_animation(direction: Vector2, delta: float) -> void:
	if direction != Vector2.ZERO:
		if absf(direction.x) > absf(direction.y):
			_facing_row = ROW_RIGHT if direction.x > 0.0 else ROW_LEFT
		else:
			_facing_row = ROW_DOWN if direction.y > 0.0 else ROW_UP

		_walk_timer += delta
		if _walk_timer >= walk_frame_time:
			_walk_timer = 0.0
			_walk_frame = (_walk_frame + 1) % WALK_FRAMES.size()
	else:
		_walk_frame = 0
		_walk_timer = 0.0

	_sprite.frame_coords = Vector2i(WALK_FRAMES[_walk_frame], _facing_row)


func take_damage(amount: int) -> void:
	if not _alive:
		return
	_health = maxi(_health - amount, 0)
	health_changed.emit(_health, max_health)
	if _health == 0:
		_alive = false
		died.emit()


func _on_attack() -> void:
	if not _alive or bullet_scene == null:
		return
	var target := _nearest_enemy_in_range()
	if target == null:
		# Nothing to shoot: flash the attack range as feedback instead of firing.
		_range_indicator.flash(attack_range)
		return
	var bullet := bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = global_position.direction_to(target.global_position)
	# Add to the world (sibling tree) so the bullet lives independent of the player.
	get_parent().add_child(bullet)


func _nearest_enemy_in_range() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := attack_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node2D):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest
