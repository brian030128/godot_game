extends CharacterBody2D
## Top-down player. Moves in 8 directions via move_and_slide().
##
## Movement comes from an injected virtual joystick (loose coupling, per
## best_practices/scene_organization.rst) OR keyboard (WASD/arrows) as a
## desktop-testing fallback. The joystick reference is assigned by the parent
## scene rather than looked up by hard-coded path.

## Movement speed in px/sec.
@export var speed: float = 240.0

## Optional joystick whose `output` vector drives movement. Assigned by the
## owning scene (e.g. main.gd). When null, only keyboard input applies.
var joystick: Node = null

# Sprite frame indices in character.png: 0=down, 1=left, 2=right, 3=up.
const FRAME_DOWN := 0
const FRAME_LEFT := 1
const FRAME_RIGHT := 2
const FRAME_UP := 3

@onready var _sprite: Sprite2D = $Sprite2D


func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Joystick overrides keyboard when it is actively pushed.
	if joystick != null and joystick.output != Vector2.ZERO:
		direction = joystick.output

	if direction.length() > 1.0:
		direction = direction.normalized()

	velocity = direction * speed
	move_and_slide()
	_update_facing(direction)


func _update_facing(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return  # keep last facing when idle
	# Choose the dominant axis so diagonals pick one clear facing.
	if absf(direction.x) > absf(direction.y):
		_sprite.frame = FRAME_RIGHT if direction.x > 0.0 else FRAME_LEFT
	else:
		_sprite.frame = FRAME_DOWN if direction.y > 0.0 else FRAME_UP

