extends Resource
class_name Skill
## Base class for player abilities, authored as .tres assets and assigned to the
## player's skill slots. A Skill is pure data plus a virtual cast() — it holds NO
## runtime state (cooldown counters, dash timers); that lives on the caster, so a
## single .tres can be shared safely.
##
## Cast methods describe how the player aims the skill via a SkillButton:
##   TAP       — fires immediately, effect originates from the player (e.g. AOE).
##   DIRECTION — drag the joystick to aim; an un-aimed tap uses the player facing
##               (e.g. projectile, dash).
##   POSITION  — drag to pick a world location (e.g. throw a bomb). Designed for
##               but not yet implemented.

enum CastMethod { TAP, DIRECTION, POSITION }

## Display name for the skill.
@export var skill_name: String = ""
## Seconds before the skill can be cast again.
@export var cooldown: float = 1.0
## How the player aims this skill. See CastMethod.
@export var cast_method: CastMethod = CastMethod.TAP
## Tint used by the on-screen skill button.
@export var color: Color = Color(0.6, 0.8, 0.95)


## Perform the skill's effect. Overridden by concrete skills. Stateless: read
## from ctx, spawn into ctx.world, or call primitives on ctx.caster — never store
## per-cast state on `self` (the resource may be shared).
func cast(_ctx: SkillContext) -> void:
	pass


## Size of the targeting overlay shown while aiming, in px. For DIRECTION skills
## this is the arrow/railway length (reach); for TAP skills the effect radius.
## Returns 0 to draw no overlay. Overridden by concrete skills.
func preview_extent() -> float:
	return 0.0
