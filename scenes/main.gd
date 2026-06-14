extends Node2D
## Run controller for a roguelike run. Owns the room lifecycle and run-level
## state (gold, current room index) and rebuilds the room in place each
## transition rather than swapping scenes, so the player's HP, skills, cooldowns
## and gold persist across rooms.
##
## Per room: build the tilemap (carving 1-3 door gaps), spawn 1-3 mob waves via
## the WaveManager, and on clear grant the room's reward and open the doors. Each
## open door shows a glowing floor decal previewing the reward in the room it
## leads to; walking through one queues that reward and loads the next room.
## After the final room comes victory; dying comes game over.
##
## Dependencies (joystick, bullet scene, skills, projectile container) are
## injected into the player rather than looked up, matching the existing style.

## Bullet scene injected into the player for its ranged weapon.
@export var bullet_scene: PackedScene = preload("res://actors/bullet/bullet.tscn")

## Skills assigned to the player's slots, in button order (slot 0 = dash). A null
## entry leaves that button empty/inert.
const SKILLS: Array[Resource] = [
	preload("res://skills/data/dash.tres"),
	preload("res://skills/data/fireball.tres"),
	preload("res://skills/data/nova.tres"),
	null,
]

const DOOR_SCRIPT := preload("res://actors/door/door.gd")
const VICTORY_SCENE := "res://scenes/victory.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"

## Rooms in a run; clearing the last shows the victory screen.
const TOTAL_ROOMS := 8

## Pool of hand-authored rooms. Each transition picks one whose entry_side
## matches the wall the player just exited through (opposite of the door's side),
## so the openings line up. Authored entry=bottom / exits=top for now.
const ROOM_POOL: Array[PackedScene] = [
	preload("res://rooms/room_01.tscn"),
	preload("res://rooms/room_02.tscn"),
	preload("res://rooms/room_03.tscn"),
	preload("res://rooms/room_04.tscn"),
]

enum State { BUILDING, FIGHTING, CLEARED, TRANSITIONING }

@onready var room_holder: Node2D = $RoomHolder
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var mobs: Node2D = $Mobs
@onready var projectiles: Node2D = $Projectiles
@onready var doors: Node2D = $Doors
@onready var wave_manager: Node = $WaveManager
@onready var joystick: Control = $UI/VirtualJoystick
@onready var skill_buttons: Array[Node] = [
	$UI/SkillButton1, $UI/SkillButton2, $UI/SkillButton3, $UI/SkillButton4,
]
@onready var health_label: Label = $UI/HealthLabel
@onready var gold_label: Label = $UI/GoldLabel

var _state: State = State.BUILDING
var _room_index: int = 0
## The current room instance (under room_holder).
var _room: RoomBase = null
## Reward granted when the current room is cleared (chosen at the previous door).
var _pending_reward: Reward = null
## Whether the current room has exits (false on the final room → victory on clear).
var _has_exits: bool = false


func _ready() -> void:
	Game.gold = 0  # fresh run; gold lives on the autoload so reset it here

	# Inject dependencies rather than having the player reach out and find them.
	player.joystick = joystick
	player.bullet_scene = bullet_scene
	player.projectile_parent = projectiles
	player.set_skills(SKILLS)
	for i in skill_buttons.size():
		var button: SkillButton = skill_buttons[i]
		button.player = player
		button.slot = i
		button.cast_requested.connect(player.cast_skill)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	_on_player_health_changed(player.max_health, player.max_health)
	_update_gold_label()

	wave_manager.mob_container = mobs
	wave_manager.room_cleared.connect(_on_room_cleared)

	# First room's reward is a free starter (no door was chosen to reach it).
	_pending_reward = Reward.random()
	_start_room(0, "")


## Build room `index`: swap in a pooled room whose entry matches `required_entry`,
## clear leftovers, place doors at the room's authored exits, reposition the
## player at the room's entry, and spawn the first wave. `required_entry` is the
## wall the new room must let the player in from (opposite the door they exited);
## "" lets room 0 use any room.
func _start_room(index: int, required_entry: String) -> void:
	_room_index = index
	_state = State.BUILDING

	# Free the previous room's doors (gates/decals go with them) and combatants.
	for child in doors.get_children():
		child.queue_free()
	wave_manager.clear_all()
	for bullet in projectiles.get_children():
		bullet.queue_free()
	if _room != null:
		_room.queue_free()

	# Instance the chosen room under the holder and build it.
	_room = _pick_room(required_entry).instantiate()
	room_holder.add_child(_room)
	var data: Dictionary = _room.build()

	# Confine the camera to this room so walls never reveal void beyond it.
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(data.cols) * RoomBase.TILE
	camera.limit_bottom = int(data.rows) * RoomBase.TILE

	# Doors at the room's authored exits (suppressed on the final room, whose
	# clear ends the run). All exits share one wall (data.exit_side).
	_has_exits = index < TOTAL_ROOMS - 1 and not data.exit_anchors.is_empty()
	if _has_exits:
		for anchor in data.exit_anchors:
			var door: Door = DOOR_SCRIPT.new()
			doors.add_child(door)
			door.configure(data.exit_side, anchor)
			door.entered.connect(_on_door_entered)

	# A closed door marking the entry the player came through (stays shut so they
	# can't walk back out into the void; purely a visual landmark).
	if data.entry_side != "":
		var entry_door: Door = DOOR_SCRIPT.new()
		doors.add_child(entry_door)
		entry_door.configure(data.entry_side, data.entry_anchor)
		entry_door.mark_entry()

	# Place the player at the room's entry; snap the camera so it doesn't lerp
	# across the map from the previous room's position.
	player.global_position = data.entry_pos
	camera.reset_smoothing()
	# Let the previous frame's queue_frees flush (mobs join "enemies" a frame late).
	await get_tree().process_frame

	wave_manager.start_room(_build_waves(index, data.spawns), player, _room)
	_state = State.FIGHTING


## Pick a random pooled room whose entry_side matches `required_entry`. With ""
## (room 0) any room qualifies. Falls back to the whole pool if none match.
func _pick_room(required_entry: String) -> PackedScene:
	var candidates: Array[PackedScene] = []
	for scene in ROOM_POOL:
		if required_entry == "" or _entry_side_of(scene) == required_entry:
			candidates.append(scene)
	if candidates.is_empty():
		candidates = ROOM_POOL
	return candidates[randi() % candidates.size()]


## Read a room scene's authored entry_side without keeping the instance.
func _entry_side_of(scene: PackedScene) -> String:
	var probe: RoomBase = scene.instantiate()
	var side: String = probe.entry_side
	probe.free()
	return side


## Group the room's authored spawn points into 1-3 waves, scaling the count and
## per-wave size with depth. The room owns *where* mobs appear; the controller
## owns *how many* and the difficulty ramp.
func _build_waves(index: int, spawns: Array) -> Array:
	if spawns.is_empty():
		return []
	var pool: Array = spawns.duplicate()
	pool.shuffle()
	var wave_count := clampi(1 + index / 3, 1, 3)
	var per_wave := clampi(3 + index / 2, 3, pool.size())
	var waves := []
	for w in wave_count:
		var slice := pool.slice(0, per_wave)
		waves.append(slice)
	return waves


func _on_room_cleared() -> void:
	if _state != State.FIGHTING:
		return
	_state = State.CLEARED

	# Grant the reward the player was promised at the door into this room.
	if _pending_reward != null:
		_pending_reward.apply(player)
		_update_gold_label()

	# Final room: no doors — end the run.
	if not _has_exits:
		get_tree().change_scene_to_file(VICTORY_SCENE)
		return

	# Open each exit door, attaching a preview of the reward in the room beyond.
	# Skip the entry door (it stays shut and shows no reward).
	for door in doors.get_children():
		if door.is_entry:
			continue
		door.reward = Reward.random()
		door.open()


func _on_door_entered(door: Door) -> void:
	if _state != State.CLEARED:
		return
	_state = State.TRANSITIONING
	_pending_reward = door.reward
	# Enter the next room from the wall opposite the door we left through.
	_start_room(_room_index + 1, _opposite_side(door.side))


## The wall facing a given side, so exiting "right" puts the player at the next
## room's "left" wall (as if they walked straight through).
func _opposite_side(side: String) -> String:
	match side:
		"top": return "bottom"
		"bottom": return "top"
		"left": return "right"
		"right": return "left"
		_: return ""


func _on_player_died() -> void:
	get_tree().change_scene_to_file(GAME_OVER_SCENE)


func _on_player_health_changed(health: int, max_health: int) -> void:
	health_label.text = "HP %d / %d" % [health, max_health]


func _update_gold_label() -> void:
	gold_label.text = "Gold %d" % Game.gold
