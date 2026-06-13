extends Skill
class_name DashSkill
## DIRECTION skill that propels the caster in a straight line for a short burst.
## Refactored from the player's former built-in dash. The actual body movement is
## owned by the caster (only the CharacterBody2D drives move_and_slide); this skill
## just kicks off the lunge with its tuning.

## Lunge speed in px/sec.
@export var dash_speed: float = 720.0
## How long the lunge lasts (sec).
@export var dash_duration: float = 0.16


func cast(ctx: SkillContext) -> void:
	# ctx.direction is already resolved to facing for an un-aimed tap.
	ctx.caster.begin_lunge(ctx.direction, dash_speed, dash_duration)


func preview_extent() -> float:
	# Arrow reaches as far as the lunge travels.
	return dash_speed * dash_duration
