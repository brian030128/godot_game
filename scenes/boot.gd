extends Control
## Entry scene. Decides the initial route: if a saved session exists, load it
## into Game and go straight to Home; otherwise show Login. Kept tiny on purpose
## so the routing decision lives in exactly one place.

const HOME_SCENE := "res://scenes/home.tscn"
const LOGIN_SCENE := "res://scenes/login.tscn"


func _ready() -> void:
	await get_tree().process_frame  # let boot fully enter the tree before swapping

	var session: Dictionary = SaveManager.load_session()
	if not session.is_empty():
		Game.apply_session(session)
		get_tree().change_scene_to_file(HOME_SCENE)
	else:
		get_tree().change_scene_to_file(LOGIN_SCENE)
