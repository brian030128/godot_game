extends Node
## Global game state singleton (autoload as "Game").
##
## Kept deliberately thin per Godot best practices
## (best_practices/autoloads_versus_regular_nodes.rst): gameplay objects
## should manage their own state; this only holds genuinely broad-scoped data.
## Disk persistence lives in SaveManager; login lives in Auth — Game just holds
## the current in-memory session.

## Stable id for the current player. Empty when logged out.
var player_id: String = ""

## Display name for the player.
var player_name: String = "Dreamer"

## Opaque session token from the backend. Empty when logged out.
var session_token: String = ""

## Placeholder bucket for future save data (flags, inventory, progress).
var save_data: Dictionary = {}

## Gold collected during the current run. Reset to 0 when a run starts (in
## main.gd) so it doesn't leak across runs, and read by the victory screen.
var gold: int = 0


## Populate current state from a session dict (from Auth or a loaded save).
func apply_session(session: Dictionary) -> void:
	player_id = session.get("player_id", "")
	player_name = session.get("player_name", "Dreamer")
	session_token = session.get("session_token", "")


## Reset to logged-out state (used on log out).
func clear_session() -> void:
	player_id = ""
	player_name = "Dreamer"
	session_token = ""
