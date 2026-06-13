extends Control
## Home / main menu. Shows the logged-in profile (from Game), launches the game,
## and offers Log Out (clears the saved session and returns to Login).

const GAME_SCENE := "res://scenes/main.tscn"
const LOGIN_SCENE := "res://scenes/login.tscn"

@onready var _greeting: Label = $MarginContainer/VBoxContainer/Greeting
@onready var _player_id: Label = $MarginContainer/VBoxContainer/PlayerId
@onready var _play_button: Button = $MarginContainer/VBoxContainer/Play
@onready var _logout_button: Button = $MarginContainer/VBoxContainer/LogOut


func _ready() -> void:
	_greeting.text = "Welcome back, %s" % Game.player_name
	_player_id.text = "Player ID: %s" % Game.player_id
	_play_button.pressed.connect(_on_play_pressed)
	_logout_button.pressed.connect(_on_logout_pressed)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_logout_pressed() -> void:
	SaveManager.clear_session()
	Game.clear_session()
	get_tree().change_scene_to_file(LOGIN_SCENE)
