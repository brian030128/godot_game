extends Area2D
class_name Door
## A room exit. While the room's mobs are alive the door is locked: a child gate
## StaticBody2D blocks the carved wall gap and the door's own detection is off.
## When the room is cleared the run controller calls open(), which drops the gate
## and lights a glowing floor decal previewing the reward in the room beyond.
## Walking into an open door emits `entered(self)` exactly once.
##
## Built entirely in code from a side + anchor so the run controller can place
## one at each carved gap without per-door scene authoring. Detection mask is
## layer 2 (player); the gate sits on layer 1 (world) like the room walls.

## Emitted once when the player walks into this (opened) door.
signal entered(door: Door)

## The reward shown on the decal and granted by the next room. Set by the controller.
var reward: Reward = null

## Which wall this door sits on ("top"/"bottom"/"left"/"right"); set by configure().
## The run controller reads it to spawn the player at the opposite wall of the
## next room, as if they walked through.
var side: String = ""

## True for the entry doorway (the one the player came in through). Entry doors
## stay shut, never transport, and get no reward decal.
var is_entry: bool = false

## Inward normal (points into the room) for this door's side; set by configure().
var _inward: Vector2 = Vector2.DOWN
var _gate_shape: CollisionShape2D = null
var _decal: _Decal = null
var _consumed: bool = false

const GAP := 96.0       # carved gap width (3 tiles)
const WALL_THICK := 40.0
const TRIGGER_THICK := 28.0  # how deep the "in the doorway" trigger zone is
const DECAL_OFFSET := 72.0  # how far into the room the floor icon sits
const TILE := 32


## Position this door at a carved gap. `side` is one of room.gd's SIDE_* values
## ("top"/"bottom"/"left"/"right"); `anchor` is the gap centre in world space.
## `opening_inset` pushes BOTH the gate and the transport trigger OUTWARD from the anchor
## (toward the wall/edge, away from the room) by this many pixels. With a thick wall band
## (a PNG-skinned room like room_06) this lets the player walk *into* the doorway opening:
## the gate blocks only the far end (so they can't leave the map before the room clears,
## and they aren't stuck out at the doorway mouth), and the transport trigger sits deep in
## the opening so the next room loads only once they're well inside. 0 keeps the gate and
## trigger at the gap centre — the default for the 1-cell-wall tile rooms.
func configure(side: String, anchor: Vector2, opening_inset: float = 0.0) -> void:
	self.side = side
	global_position = anchor
	collision_layer = 0
	collision_mask = 2  # detect the player (layer 2)
	# Locked until open(). Deferred because configure() runs while the previous
	# door's body_entered is still flushing (the transition that spawned us), and
	# monitoring can't be toggled synchronously mid-flush.
	set_deferred("monitoring", false)

	match side:
		"top": _inward = Vector2.DOWN
		"bottom": _inward = Vector2.UP
		"left": _inward = Vector2.RIGHT
		"right": _inward = Vector2.LEFT

	var horizontal := side == "top" or side == "bottom"

	# Trigger zone: a thin band sitting in the doorway opening itself (at the wall
	# line, where `anchor` is), so transport only fires when the player steps into
	# the actual door — well away from the reward icon further into the room.
	var trigger_size := Vector2(GAP, TRIGGER_THICK) if horizontal else Vector2(TRIGGER_THICK, GAP)
	var detect := CollisionShape2D.new()
	var detect_rect := RectangleShape2D.new()
	detect_rect.size = trigger_size
	detect.shape = detect_rect
	detect.position = -_inward * opening_inset  # outward, deeper into the opening
	add_child(detect)

	# Gate that physically blocks the gap while locked.
	var gap_size := Vector2(GAP, WALL_THICK) if horizontal else Vector2(WALL_THICK, GAP)
	var gate := StaticBody2D.new()
	gate.collision_layer = 1
	gate.collision_mask = 0
	gate.position = -_inward * opening_inset  # block the far end, leaving the opening walkable
	add_child(gate)
	_gate_shape = CollisionShape2D.new()
	var gate_rect := RectangleShape2D.new()
	gate_rect.size = gap_size
	_gate_shape.shape = gate_rect
	gate.add_child(_gate_shape)

	# Floor decal previewing the reward, sitting in front of the door.
	_decal = _Decal.new()
	_decal.position = _inward * DECAL_OFFSET
	_decal.visible = false
	add_child(_decal)

	body_entered.connect(_on_body_entered)


## Mark this as the entry doorway: the one the player just walked in through.
## It stays permanently shut (gate kept solid so the player can't leave into the
## void) and never transports. The carved gap in the wall already shows where the
## player came in, so the entry draws NO floor icon (only exits, which preview a
## reward, get a floor decal). Call instead of open().
func mark_entry() -> void:
	is_entry = true
	# Leave the decal hidden; the wall opening itself marks the entry.


## Unlock the door: drop the gate, light the decal, start watching for the player.
func open() -> void:
	if _gate_shape != null:
		_gate_shape.set_deferred("disabled", true)
	if _decal != null and reward != null:
		_decal.setup(reward.color, reward.kind)
		_decal.visible = true
	set_deferred("monitoring", true)


func _on_body_entered(body: Node) -> void:
	if _consumed or not body.is_in_group("player"):
		return
	_consumed = true
	entered.emit(self)


## Glowing floor decal: a soft filled disc, a crisp ring, and a reward icon
## (heart for heal, coin for gold), gently pulsing. Same fill+arc+modulate idiom
## as range_indicator.gd. Only exit doors get one; the entry has no floor icon.
class _Decal extends Node2D:
	var _color: Color = Color.WHITE
	var _kind: int = Reward.Kind.GOLD
	const RADIUS := 34.0

	func setup(color: Color, kind: int) -> void:
		_color = color
		_kind = kind
		queue_redraw()
		var tween := create_tween().set_loops()
		tween.tween_property(self, "modulate:a", 0.45, 0.8).from(1.0)
		tween.tween_property(self, "modulate:a", 1.0, 0.8)

	func _draw() -> void:
		draw_circle(Vector2.ZERO, RADIUS, Color(_color.r, _color.g, _color.b, 0.22))
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, _color, 3.0, true)
		if _kind == Reward.Kind.HEAL:
			_draw_heart()
		else:
			_draw_coin()

	## A filled heart from two lobe circles plus a downward triangle tip.
	func _draw_heart() -> void:
		var s := 9.0
		draw_circle(Vector2(-s * 0.6, -s * 0.35), s * 0.62, _color)
		draw_circle(Vector2(s * 0.6, -s * 0.35), s * 0.62, _color)
		var tip := PackedVector2Array([
			Vector2(-s * 1.15, -s * 0.2),
			Vector2(s * 1.15, -s * 0.2),
			Vector2(0.0, s * 1.15),
		])
		draw_colored_polygon(tip, _color)

	## A coin: filled disc with a darker rim ring and a small inner mark.
	func _draw_coin() -> void:
		var r := 11.0
		draw_circle(Vector2.ZERO, r, _color)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, _color.darkened(0.35), 2.0, true)
		draw_arc(Vector2.ZERO, r * 0.45, 0.0, TAU, 24, _color.darkened(0.35), 2.0, true)
