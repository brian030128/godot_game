extends Node
## Spawns mobs in sequential waves for one room and reports when the room is
## cleared. A wave is a list of spawn positions; the next wave is only spawned
## once every mob in the current wave has died, and `room_cleared` fires when the
## last wave is emptied.
##
## Owns a `Mobs` container node (assigned by the run controller) that all spawned
## mobs are parented to, so the controller can free leftover mobs between rooms
## via clear_all().

## Mob scene instanced for each spawn point.
@export var mob_scene: PackedScene = preload("res://actors/mob/mob.tscn")

## Emitted when the current wave is fully cleared but more waves remain.
signal wave_cleared(wave_index: int)
## Emitted once when the final wave of the room is cleared.
signal room_cleared

## Container the spawned mobs are parented to. Injected by the run controller.
var mob_container: Node = null

var _waves: Array = []
var _player: Node2D = null
var _wave_index: int = 0
## Mobs still alive in the current wave. Tracked explicitly (not via group count)
## because mobs join the "enemies" group in _ready, a frame after spawning.
var _alive: int = 0
var _active: bool = false


## Begin a room. `wave_configs` is an Array of waves; each wave is an Array of
## Vector2 spawn positions. `player` is injected into each mob as its chase target.
func start_room(wave_configs: Array, player: Node2D) -> void:
	_waves = wave_configs
	_player = player
	_wave_index = 0
	_alive = 0
	_active = true
	if _waves.is_empty():
		_active = false
		room_cleared.emit()
		return
	_spawn_wave(0)


## Free every living mob (e.g. between rooms). Stops wave progression.
func clear_all() -> void:
	_active = false
	if mob_container != null:
		for child in mob_container.get_children():
			child.queue_free()
	_alive = 0


func _spawn_wave(index: int) -> void:
	if not _active:
		return
	var spawns: Array = _waves[index]
	_alive = spawns.size()
	if _alive == 0:
		_on_wave_emptied()
		return
	for pos in spawns:
		var mob := mob_scene.instantiate()
		mob.target = _player
		mob.died.connect(_on_mob_died)
		mob_container.add_child(mob)
		# Set position after adding so global_position resolves against the tree.
		mob.global_position = pos


func _on_mob_died() -> void:
	_alive -= 1
	if _alive <= 0:
		_on_wave_emptied()


func _on_wave_emptied() -> void:
	if not _active:
		return
	if _wave_index + 1 < _waves.size():
		_wave_index += 1
		wave_cleared.emit(_wave_index - 1)
		# Defer: the mob that just died is mid-queue_free, so don't add siblings
		# from inside its `died` handler this frame.
		_spawn_wave.call_deferred(_wave_index)
	else:
		_active = false
		room_cleared.emit()
