extends Resource
class_name Reward
## A room-clear reward. Mirrors the data-driven Skill resource style: a small
## stateless value object describing what the player earns. The same instance is
## used both to preview a reward on a door's floor decal and to grant it when the
## next room is cleared.
##
## Two kinds for now: GOLD (a currency counter on the Game autoload) and HEAL
## (restore player HP). `color` and `glyph` drive the door decal's appearance so
## the player can read at a glance what a door leads to.

enum Kind { GOLD, HEAL }

## What this reward grants.
@export var kind: Kind = Kind.GOLD
## Amount of gold, or HP to restore.
@export var amount: int = 0
## Tint for the door's glowing floor decal.
@export var color: Color = Color.WHITE
## Single-character label drawn on the decal (e.g. "$" for gold, "+" for heal).
@export var glyph: String = ""

const GOLD_COLOR := Color(0.98, 0.82, 0.30)
const HEAL_COLOR := Color(0.45, 0.92, 0.55)


## Grant this reward. GOLD bumps the run's gold counter; HEAL restores HP on the
## player (which clamps to max and emits its health_changed signal for the UI).
func apply(player: Node) -> void:
	match kind:
		Kind.GOLD:
			Game.gold += amount
		Kind.HEAL:
			if player != null and player.has_method("heal"):
				player.heal(amount)


## Build a randomized reward (~half gold, half heal). Used for room rewards and
## door previews. Kept as a factory so callers don't repeat the color/glyph setup.
static func random() -> Reward:
	var r := Reward.new()
	if randi() % 2 == 0:
		r.kind = Kind.GOLD
		r.amount = 10 + randi() % 21  # 10..30
		r.color = GOLD_COLOR
		r.glyph = "$"
	else:
		r.kind = Kind.HEAL
		r.amount = 1 + randi() % 2  # 1..2
		r.color = HEAL_COLOR
		r.glyph = "+"
	return r
