extends Node2D
## Root of the playable prototype. Wires the virtual joystick to the player
## (dependency injection) and points the camera at the player.

@onready var player: CharacterBody2D = $Player
@onready var joystick: Control = $UI/VirtualJoystick


func _ready() -> void:
	# Inject the joystick into the player rather than having the player reach
	# out and find it (keeps the player scene reusable in other contexts).
	player.joystick = joystick
