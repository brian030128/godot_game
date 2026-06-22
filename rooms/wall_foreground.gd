extends Sprite2D
class_name WallForeground
## Depth-sorts a wall-foreground sprite against the player instead of always drawing on
## top. Used for the TOP wall of a PNG-skinned room (see room_06): a player walking UP
## to the top wall has a tall sprite that reaches above their feet, so an always-on-top
## wall would swallow them and look like phasing. Here the wall draws BEHIND the player
## while their feet are in front of it (below base_y) and only IN FRONT once their feet
## cross behind it (above base_y) — i.e. as they step into a top doorway. This is the
## "give the cut wall piece a larger y so it sorts in front when you're behind it" idea.

## World Y of the wall's inner edge. The player is "behind" the wall (occluded) when
## their feet are above this line, "in front" (visible) when below it.
@export var base_y: float = 96.0

## z while the player is in front (below base_y): behind the player (0) but still above
## the Foundation (-20), so the wall itself stays visible.
const Z_IN_FRONT := -10
## z while the player is behind/in the wall (above base_y): over the player.
const Z_BEHIND := 20

var _player: Node2D = null


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	z_index = Z_BEHIND if _player.global_position.y < base_y else Z_IN_FRONT
