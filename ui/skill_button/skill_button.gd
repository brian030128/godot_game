extends Control
class_name SkillButton
## On-screen skill control: a generalization of the dash button that drives any
## skill slot. Combines a tap-button and a directional joystick, and shows a
## MOBA-style radial cooldown sweep.
##
## The skill's behaviour comes from the player's slot (single source of truth);
## this widget only resolves how the cast is aimed, based on the skill's
## cast_method:
##   TAP       — a press/release fires immediately (direction ZERO). No joystick:
##               drawn as a plain button. Holding shows the affected-radius preview.
##   DIRECTION — drag the knob to aim; a near-still release (a tap) fires ZERO,
##               which the player resolves to its facing. Holding/dragging shows
##               an aim arrow.
##   POSITION  — drag maps to a world point near the caster. [Stub: not wired to
##               a skill yet, but the emit path is in place.]
##
## While held, the button drives the player's world-space targeting overlay
## (SkillIndicator) and clears it on release.
##
## Drawn via _draw() in the same ring+knob style as the movement joystick and
## attack button. Touch emulation from mouse (project setting) lets this work
## with the mouse on desktop too.

## Emitted once per release. `direction` is the aimed unit vector (ZERO = use
## facing); `target_position` is a world point for POSITION skills (ZERO else).
signal cast_requested(slot: int, direction: Vector2, target_position: Vector2)

## Radius (px) the knob can travel from the base center.
@export var max_radius: float = 40.0
## Visual radius of the base ring (px).
@export var base_radius: float = 48.0
## Visual radius of the knob (px).
@export var knob_radius: float = 22.0
## Drag distance (px) below which a release counts as a tap rather than an aim.
@export var tap_threshold: float = 12.0
## POSITION: max world distance a full knob deflection maps to (px).
@export var max_cast_range: float = 320.0

## Player providing the skill + cooldown for this slot. Injected by the scene.
var player: Node = null
## Which of the player's skill slots this button controls. Injected by the scene.
var slot: int = -1

var _touch_index: int = -1          # which finger owns the control (-1 = none)
var _center: Vector2 = Vector2.ZERO # base center in local coords
var _knob_pos: Vector2 = Vector2.ZERO
var _cooldown_ratio: float = 0.0    # cached for redraw-on-change


func _ready() -> void:
	_recenter()
	resized.connect(_recenter)


func _recenter() -> void:
	_center = size * 0.5
	_knob_pos = _center
	queue_redraw()


func _process(_delta: float) -> void:
	# Poll the player's cooldown so the sweep tracks it; redraw only on change.
	var ratio: float = 0.0 if player == null else player.get_cooldown_ratio(slot)
	if not is_equal_approx(ratio, _cooldown_ratio):
		_cooldown_ratio = ratio
		queue_redraw()


func _skill() -> Skill:
	if player == null or slot < 0 or slot >= player.skills.size():
		return null
	return player.skills[slot]


func _gui_input(event: InputEvent) -> void:
	var skill := _skill()
	if skill == null:
		return  # empty slot: inert
	# TAP skills have no joystick: the knob never moves, but we still show the
	# affected-radius preview while the finger is held.
	var aims := skill.cast_method != Skill.CastMethod.TAP
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			if aims:
				_move_knob(event.position)
			_update_preview()
			accept_event()
		elif not event.pressed and event.index == _touch_index:
			_release()
			accept_event()
	elif event is InputEventScreenDrag and event.index == _touch_index and aims:
		_move_knob(event.position)
		_update_preview()
		accept_event()


## Drive the player's world-space targeting overlay from the current knob offset.
func _update_preview() -> void:
	if player == null:
		return
	var offset: Vector2 = _knob_pos - _center
	var direction := Vector2.ZERO
	if offset.length() >= tap_threshold:
		direction = offset.normalized()
	player.update_skill_preview(slot, direction)


func _move_knob(local_pos: Vector2) -> void:
	var offset: Vector2 = local_pos - _center
	if offset.length() > max_radius:
		offset = offset.normalized() * max_radius
	_knob_pos = _center + offset
	queue_redraw()


func _release() -> void:
	var skill := _skill()
	var offset: Vector2 = _knob_pos - _center
	_touch_index = -1
	_knob_pos = _center
	queue_redraw()
	if player != null:
		player.clear_skill_preview()
	if skill == null:
		return

	var direction := Vector2.ZERO
	var target := Vector2.ZERO
	match skill.cast_method:
		Skill.CastMethod.DIRECTION:
			# A barely-moved knob is a tap: ZERO tells the player to use facing.
			if offset.length() >= tap_threshold:
				direction = offset.normalized()
		Skill.CastMethod.POSITION:
			# Map the deflection to a world point near the caster (stub).
			if player != null and player is Node2D:
				target = player.global_position + (offset / max_radius) * max_cast_range
		_:
			pass  # TAP: fire from player, direction/target ignored.
	cast_requested.emit(slot, direction, target)


func _draw() -> void:
	var skill := _skill()
	if skill == null:
		# Empty slot: faint placeholder ring.
		draw_arc(_center, base_radius, 0.0, TAU, 48, Color(0.5, 0.5, 0.5, 0.25), 3.0, true)
		return

	var held := _touch_index != -1
	var tint: Color = skill.color
	if skill.cast_method == Skill.CastMethod.TAP:
		# TAP: a plain filled button — no joystick knob to drag.
		var fill_alpha := 0.5 if held else 0.3
		draw_circle(_center, base_radius, Color(tint.r, tint.g, tint.b, fill_alpha))
		draw_arc(_center, base_radius, 0.0, TAU, 48, Color(tint.r, tint.g, tint.b, 0.7), 4.0, true)
	else:
		# DIRECTION / POSITION: ring + draggable knob.
		draw_circle(_center, base_radius, Color(tint.r, tint.g, tint.b, 0.18))
		draw_arc(_center, base_radius, 0.0, TAU, 48, Color(tint.r, tint.g, tint.b, 0.55), 4.0, true)
		var knob_alpha := 0.85 if held else 0.6
		draw_circle(_knob_pos, knob_radius, Color(tint.r, tint.g, tint.b, knob_alpha))

	# MOBA-style cooldown sweep: a dark pie shrinking clockwise as the skill
	# comes off cooldown.
	if _cooldown_ratio > 0.0:
		var points: PackedVector2Array = [_center]
		var start := -PI / 2.0          # 12 o'clock
		var span := _cooldown_ratio * TAU
		var segments := maxi(2, int(48 * _cooldown_ratio))
		for i in range(segments + 1):
			var a := start + span * (float(i) / segments)
			points.append(_center + Vector2(cos(a), sin(a)) * base_radius)
		draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.55))
