extends Node2D
## Root of the playable prototype. Wires the virtual joystick and attack button
## to the player (dependency injection), points the camera at the player, and
## spawns the initial wave of mobs.

## Mob scene spawned at game start.
@export var mob_scene: PackedScene = preload("res://actors/mob/mob.tscn")
## Bullet scene injected into the player for its ranged weapon.
@export var bullet_scene: PackedScene = preload("res://actors/bullet/bullet.tscn")

## How many mobs to place when the room loads.
const MOB_COUNT := 4
## Spawn positions spread around the room, away from the player's start (~800,500).
const MOB_SPAWNS: Array[Vector2] = [
	Vector2(300, 200),
	Vector2(1300, 200),
	Vector2(300, 800),
	Vector2(1300, 800),
]

@onready var player: CharacterBody2D = $Player
@onready var joystick: Control = $UI/VirtualJoystick
@onready var attack_button: Control = $UI/AttackButton
@onready var health_label: Label = $UI/HealthLabel


func _ready() -> void:
	# Inject dependencies rather than having the player reach out and find them
	# (keeps the player scene reusable in other contexts).
	player.joystick = joystick
	player.attack_button = attack_button
	player.bullet_scene = bullet_scene
	# Connect first so the player's _ready() emit isn't missed, then prime the UI.
	player.health_changed.connect(_on_player_health_changed)
	_on_player_health_changed(player.max_health, player.max_health)

	_spawn_mobs()


func _spawn_mobs() -> void:
	for i in MOB_COUNT:
		var mob := mob_scene.instantiate()
		mob.global_position = MOB_SPAWNS[i % MOB_SPAWNS.size()]
		mob.target = player
		add_child(mob)


func _on_player_health_changed(health: int, max_health: int) -> void:
	health_label.text = "HP %d / %d" % [health, max_health]
