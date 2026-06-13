extends Skill
class_name ProjectileSkill
## DIRECTION skill that spawns a projectile travelling away from the caster.
## Generalizes the player's auto-attack bullet spawn so any projectile scene can
## be fired as a skill.

## Projectile scene to instance (e.g. bullet.tscn). Must expose a `direction`
## property; `speed`/`damage` are set when present.
@export var projectile_scene: PackedScene
## Damage applied to the spawned projectile if it has a `damage` property.
@export var damage: int = 1
## Travel speed applied to the spawned projectile if it has a `speed` property.
@export var speed: float = 600.0
## Length (px) of the aim arrow shown while targeting. Purely visual — the
## projectile's actual lifetime/range is governed by the projectile scene.
@export var cast_range: float = 320.0


func cast(ctx: SkillContext) -> void:
	if projectile_scene == null:
		return
	var p := projectile_scene.instantiate()
	p.global_position = ctx.caster.global_position
	p.direction = ctx.direction
	# Override projectile tuning when the scene exposes it.
	if "speed" in p:
		p.speed = speed
	if "damage" in p:
		p.damage = damage
	# Add to the world (sibling of the caster) so it lives independently.
	ctx.world.add_child(p)


func preview_extent() -> float:
	return cast_range
