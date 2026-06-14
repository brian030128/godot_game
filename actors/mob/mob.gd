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

## Emitted exactly once when the mob dies, just before it frees itself. The
## wave manager listens to this to count down remaining enemies.
signal died

## The node to chase (the player). Injected by the spawning scene.
var target: Node2D = null
## Pathfinding source (the current room). Injected by the wave manager. When null,
## or when it returns no path, the mob falls back to direct chase (legacy behaviour).
var nav: RoomBase = null

## How close (px) to a waypoint before advancing to the next one.
const WAYPOINT_REACHED := 10.0
## Seconds between path replans, so a wave of mobs doesn't pathfind every frame.
const REPLAN_INTERVAL := 0.3
## Mobs within this radius (px) push each other apart so they don't stack.
const SEPARATION_RADIUS := 22.0
## How strongly the separation push bends the steering direction (0 = off).
const SEPARATION_WEIGHT := 0.6

var _health: int = 0
## Cached A* route to the target and the index of the waypoint we're heading for.
var _path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
## Counts down to the next replan; also re-plans early when the target changes tile.
var _replan_timer: float = 0.0
## The player's tile the current path was planned toward; replan if it changes.
var _last_target_cell: Vector2i = Vector2i(-9999, -9999)
## Set once when the mob dies; guards take_damage so two hits landing the same
## frame can't emit `died` twice (which would corrupt the wave's alive counter).
var _dead: bool = false
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
	# Stagger first replan across a wave spawned the same frame so they don't all
	# pathfind on the same physics tick.
	_replan_timer = randf() * REPLAN_INTERVAL


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		velocity = Vector2.ZERO
		return

	var to_target := global_position.direction_to(target.global_position)

	# With clear line of sight (or no nav grid), beeline at the target — smooth
	# final approach, and the fallback when pathfinding is unavailable.
	var move_dir: Vector2
	if nav == null or _has_line_of_sight():
		_path.clear()
		_path_index = 0
		move_dir = to_target
	else:
		_replan_timer -= delta
		var target_cell := nav._world_to_id(target.global_position)
		if _replan_timer <= 0.0 or target_cell != _last_target_cell or _path_index >= _path.size():
			_replan(target_cell)
		move_dir = _follow_path()
		# Empty/exhausted path: never freeze — steer straight at the target.
		if move_dir == Vector2.ZERO:
			move_dir = to_target

	# Blend in a push away from nearby mobs so they spread out instead of stacking.
	move_dir = (move_dir + _separation() * SEPARATION_WEIGHT)
	if move_dir.length() > 0.001:
		move_dir = move_dir.normalized()

	velocity = move_dir * speed
	move_and_slide()


## Recompute the path to the target's current cell and reset the replan throttle.
func _replan(target_cell: Vector2i) -> void:
	_replan_timer = REPLAN_INTERVAL
	_last_target_cell = target_cell
	_path = nav.find_path(global_position, target.global_position)
	# The first waypoint is usually our own cell centre; drop any leading
	# waypoints we've already reached so we don't steer backward.
	_path_index = 0
	while _path_index < _path.size() \
			and global_position.distance_to(_path[_path_index]) <= WAYPOINT_REACHED:
		_path_index += 1


## Steer toward the current waypoint, advancing past any already reached. Returns
## a unit direction, or Vector2.ZERO when no waypoints remain.
func _follow_path() -> Vector2:
	while _path_index < _path.size() \
			and global_position.distance_to(_path[_path_index]) <= WAYPOINT_REACHED:
		_path_index += 1
	if _path_index >= _path.size():
		return Vector2.ZERO
	return global_position.direction_to(_path[_path_index])


## True when nothing solid sits between the mob and the target. One raycast on the
## world collision layer (mask 1 = walls + props + door gates); the player (layer
## 2) and other mobs (layer 4) are excluded by layer, so it tests exactly the
## obstacles A* models. LOS only shortcuts the path, so it can never trap the mob.
func _has_line_of_sight() -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position, target.global_position, 1)
	query.exclude = [self]
	return space.intersect_ray(query).is_empty()


## A push away from every other mob within SEPARATION_RADIUS, weighted so closer
## mobs push harder. Keeps mobs from piling onto the same tile (they have no
## body-to-body collision). Returns an un-normalised vector (Vector2.ZERO if none).
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		var offset: Vector2 = global_position - other.global_position
		var dist := offset.length()
		if dist > 0.001 and dist < SEPARATION_RADIUS:
			push += offset / dist * (1.0 - dist / SEPARATION_RADIUS)
	return push


func take_damage(amount: int) -> void:
	if _dead:
		return
	_health -= amount
	_flash()
	if _health <= 0:
		_dead = true
		died.emit()
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
