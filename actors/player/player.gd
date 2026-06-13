extends CharacterBody2D
## Top-down player. Moves in 8 directions via move_and_slide(), fires a ranged
## auto-attack at the nearest enemy in range, and casts assigned skills.
##
## Movement comes from an injected virtual joystick (loose coupling, per
## best_practices/scene_organization.rst) OR keyboard (WASD/arrows) as a
## desktop-testing fallback. The joystick and attack button references are
## assigned by the parent scene rather than looked up by hard-coded path.
##
## Skills (including dash) are data-driven Skill resources assigned via
## set_skills(). The player owns all runtime skill state — per-slot cooldowns and
## the generic "lunge" body-movement primitive that dash-like skills drive — so
## the shared Skill .tres assets stay stateless.

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

## Skills assigned to the player's slots (slot 0 is conventionally dash). Set via
## set_skills(); may contain nulls for empty slots.
var skills: Array[Skill] = []

var _health: int = 0
var _alive: bool = true
var _walk_frame: int = 0
var _walk_timer: float = 0.0
var _facing_row: int = 0
## Last non-zero movement direction, used to aim an un-aimed (tapped) skill.
var _facing: Vector2 = Vector2.DOWN
## Remaining cooldown (sec) per skill slot; parallel to `skills`.
var _cooldowns: Array[float] = []
## Active lunge (dash-like burst movement) state; ZERO/0 when not lunging.
var _lunge_dir: Vector2 = Vector2.ZERO
var _lunge_speed: float = 0.0
var _lunge_time_left: float = 0.0

const ROW_DOWN := 0
const ROW_LEFT := 1
const ROW_RIGHT := 2
const ROW_UP := 3

const WALK_FRAMES := [0, 1, 2, 1]

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _range_indicator: Node2D = $RangeIndicator
@onready var _skill_indicator: Node2D = $SkillIndicator


func _ready() -> void:
	add_to_group("player")
	_health = max_health
	health_changed.emit(_health, max_health)


func _physics_process(delta: float) -> void:
	# Tick down every skill cooldown.
	for i in _cooldowns.size():
		if _cooldowns[i] > 0.0:
			_cooldowns[i] = maxf(_cooldowns[i] - delta, 0.0)

	# While lunging (dash-like skills), ignore steering and slide along the lunge
	# vector. Only the body drives its own movement.
	if _lunge_time_left > 0.0:
		_lunge_time_left -= delta
		velocity = _lunge_dir * _lunge_speed
		move_and_slide()
		_update_animation(_lunge_dir, delta)
		return

	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Joystick overrides keyboard when it is actively pushed.
	if joystick != null and joystick.output != Vector2.ZERO:
		direction = joystick.output

	if direction.length() > 1.0:
		direction = direction.normalized()

	if direction != Vector2.ZERO:
		_facing = direction.normalized()

	velocity = direction * speed
	move_and_slide()
	_update_animation(direction, delta)


## Assign the player's skills and reset all cooldowns to ready. Accepts an
## untyped array and re-types it via assign() (callers often hold Array[Resource]
## from preloaded .tres, which `as Array[Skill]` won't convert).
func set_skills(list: Array) -> void:
	skills.assign(list)
	_cooldowns.clear()
	_cooldowns.resize(skills.size())  # resize zero-fills (all skills start ready)


## Begin a burst of straight-line movement. Skills (e.g. DashSkill) call this
## rather than touching the body directly. ZERO dir means "lunge toward facing".
func begin_lunge(dir: Vector2, spd: float, dur: float) -> void:
	_lunge_dir = _facing if dir == Vector2.ZERO else dir.normalized()
	_lunge_speed = spd
	_lunge_time_left = dur


## Cast the skill in `slot`, aimed by `direction` (ZERO = use facing) and/or
## `target_position`. Returns false if the slot is empty/dead/on cooldown.
func cast_skill(slot: int, direction: Vector2, target_position: Vector2) -> bool:
	if not _alive or slot < 0 or slot >= skills.size():
		return false
	var skill := skills[slot]
	if skill == null or _cooldowns[slot] > 0.0:
		return false
	var ctx := SkillContext.new()
	ctx.caster = self
	ctx.world = get_parent()
	ctx.facing = _facing
	ctx.direction = _facing if direction == Vector2.ZERO else direction.normalized()
	ctx.target_position = target_position
	skill.cast(ctx)
	_cooldowns[slot] = skill.cooldown
	return true


## Fraction of cooldown remaining for a slot (1 = just cast, 0 = ready). Drives
## the skill button's radial sweep.
func get_cooldown_ratio(slot: int) -> float:
	if slot < 0 or slot >= skills.size() or skills[slot] == null:
		return 0.0
	var cd := skills[slot].cooldown
	return 0.0 if cd <= 0.0 else clampf(_cooldowns[slot] / cd, 0.0, 1.0)


## Show the targeting overlay for the skill in `slot` while the player aims it.
## `direction` is the current aim (ZERO = use facing). DIRECTION skills draw an
## arrow; TAP skills draw their affected radius. No-op for empty slots.
func update_skill_preview(slot: int, direction: Vector2) -> void:
	if slot < 0 or slot >= skills.size():
		return
	var skill := skills[slot]
	if skill == null:
		return
	var extent := skill.preview_extent()
	if extent <= 0.0:
		return
	if skill.cast_method == Skill.CastMethod.DIRECTION:
		var aim := _facing if direction == Vector2.ZERO else direction.normalized()
		_skill_indicator.show_direction(aim, extent, skill.color)
	else:
		_skill_indicator.show_radius(extent, skill.color)


## Hide the targeting overlay (on release/cancel).
func clear_skill_preview() -> void:
	_skill_indicator.hide_preview()


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
