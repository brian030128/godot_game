extends Control
## Anonymous login screen. Calls Auth.login_anonymous() (mock backend), shows a
## simple busy state, then routes to Home once the session is established.

const HOME_SCENE := "res://scenes/home.tscn"

@onready var _guest_button: Button = $MarginContainer/VBoxContainer/PlayAsGuest
@onready var _status: Label = $MarginContainer/VBoxContainer/Status


func _ready() -> void:
	_status.hide()
	_guest_button.pressed.connect(_on_guest_pressed)
	Auth.login_completed.connect(_on_login_completed)


func _on_guest_pressed() -> void:
	_guest_button.disabled = true
	_status.text = "Signing in..."
	_status.show()
	Auth.login_anonymous()


func _on_login_completed(success: bool, message: String) -> void:
	if success:
		get_tree().change_scene_to_file(HOME_SCENE)  # Auth already populated Game + saved
	else:
		_status.text = "Sign-in failed: %s" % message
		_guest_button.disabled = false
