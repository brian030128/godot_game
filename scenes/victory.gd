extends Control
## Shown after the player clears the final room of a run. Reports the gold
## collected (read from the Game autoload, which survives the scene change) and
## returns to Home. Modeled on home.gd.

const HOME_SCENE := "res://scenes/home.tscn"

@onready var _summary: Label = $MarginContainer/VBoxContainer/Summary
@onready var _continue_button: Button = $MarginContainer/VBoxContainer/Continue


func _ready() -> void:
	_summary.text = "Gold collected: %d" % Game.gold
	_continue_button.pressed.connect(_on_continue_pressed)


func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file(HOME_SCENE)
