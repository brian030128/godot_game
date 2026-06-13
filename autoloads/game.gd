extends Node
## Global game state singleton (autoload as "Game").
##
## Kept deliberately thin per Godot best practices
## (best_practices/autoloads_versus_regular_nodes.rst): gameplay objects
## should manage their own state; this only holds genuinely broad-scoped data.

## Display name for the player. Placeholder until a real profile/save system exists.
var player_name: String = "Dreamer"

## Placeholder bucket for future save data (flags, inventory, progress).
var save_data: Dictionary = {}
