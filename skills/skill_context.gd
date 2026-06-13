extends RefCounted
class_name SkillContext
## Per-cast payload handed to Skill.cast(). Built by the caster (the player) each
## time a skill fires, so skills stay stateless and read only what they need.

## The node casting the skill (the player). Skills read its position/facing and
## may call movement primitives like begin_lunge() on it.
var caster: Node2D = null
## Where spawned nodes (projectiles, VFX) should be added — typically the
## caster's parent, so they live independently in the world.
var world: Node = null
## Normalized aim direction for DIRECTION skills, already resolved to the
## caster's facing when the cast was an un-aimed tap. ZERO for pure TAP skills.
var direction: Vector2 = Vector2.ZERO
## World position for POSITION skills (deferred — not yet wired). ZERO otherwise.
var target_position: Vector2 = Vector2.ZERO
## The caster's raw facing direction at cast time.
var facing: Vector2 = Vector2.DOWN
