extends Skill
class_name AoeSkill
## TAP skill that damages every enemy within a radius of the caster, all at once.
## Effect originates from the caster's position; aim direction is ignored.

## Damage radius in px, measured from the caster.
@export var radius: float = 160.0
## Damage dealt to each enemy in range.
@export var damage: int = 2


func cast(ctx: SkillContext) -> void:
	var origin := ctx.caster.global_position
	for enemy in ctx.caster.get_tree().get_nodes_in_group("enemies"):
		if enemy is Node2D and enemy.has_method("take_damage") \
				and origin.distance_to(enemy.global_position) <= radius:
			enemy.take_damage(damage)


func preview_extent() -> float:
	# The affected radius around the caster.
	return radius
