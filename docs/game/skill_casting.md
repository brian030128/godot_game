# Skill Casting System

How player abilities ("skills") are defined, aimed, and executed. This documents
the data-driven skill system in `skills/`, the player integration in
`actors/player/player.gd`, and the on-screen control in `ui/skill_button/`.

## Overview

A skill is **pure data plus a `cast()` method**, authored as a `.tres` resource
and assigned to one of the player's skill slots. The player carries up to **3
skills plus a dedicated dash** (4 button slots total). The ranged attack is *not*
a skill and has no button: the player **auto-attacks**, firing at the nearest
enemy in range every `attack_interval` seconds and staying idle when nothing is
in range. Dash gets the large dedicated button in the bottom-right thumb spot.

The design splits cleanly into three responsibilities:

| Concern | Owner | Why |
|---|---|---|
| What a skill *is* and *does* | `Skill` resource (`.tres`) | Data-driven, authored in the inspector, reusable |
| Runtime state (cooldowns, dash motion) | The **player** (caster) | A `.tres` is shared; it must stay stateless |
| Aiming (how the cast is targeted) | `SkillButton` control | Touch/drag UX, decoupled from skill logic |

**Golden rule:** a `Skill` resource holds **no mutable runtime state**. Cooldown
timers and dash/lunge motion live on the player, indexed by slot. A single
`dash.tres` could be shared by many casters without interference.

## Cast methods

Every skill declares one `CastMethod` (`skills/skill.gd`), which decides how the
`SkillButton` resolves the cast on release:

- **`TAP`** — fires immediately; the effect originates from the player. Drag is
  ignored. Example: an AOE nova centered on the player.
- **`DIRECTION`** — drag the button's knob to aim a unit vector. A near-still
  release (a tap, under `tap_threshold` px) emits `Vector2.ZERO`, which the
  player resolves to its current **facing**. Examples: a projectile, dash.
- **`POSITION`** — drag maps to a world point near the caster
  (`caster_pos + (offset / max_radius) * max_cast_range`). *Designed and wired
  through the emit path, but no skill uses it yet.* Example: throw a bomb.

## Data flow of a single cast

```
SkillButton._release()
  ├─ released over the CancelArea? → abort: emit nothing, skill stays ready
  └─ otherwise reads player.skills[slot].cast_method, resolves direction / target_position
     └─ emits cast_requested(slot, direction, target_position)
        └─ Player.cast_skill(slot, direction, target_position)   [connected in main.gd]
           ├─ guards: alive? slot valid? skill non-null? off cooldown?
           ├─ builds a SkillContext (caster, world, direction→facing, target, facing)
           ├─ skill.cast(ctx)            # the effect happens here
           └─ _cooldowns[slot] = skill.cooldown
```

`Player._physics_process` ticks every slot's cooldown down each frame, and
`SkillButton._process` polls `player.get_cooldown_ratio(slot)` to draw the
MOBA-style radial cooldown sweep.

## Cancelling a cast

Pressing a skill button starts *aiming*, not casting — the cast only resolves on
release. While a button is held, a **cancel drop-target** (`CancelArea`,
`ui/cancel_area/`) appears as a red circle at the **top-right** of the screen.
Dragging the finger into that circle and releasing there **aborts the cast**: no
`cast_requested` is emitted, so nothing fires and the skill stays off cooldown.

This lets the player peek a skill's targeting overlay — a TAP skill's affected
radius or a DIRECTION skill's aim arrow — and back out if they change their mind
(e.g. press Nova to check its range, then cancel instead of committing).

- `CancelArea` is purely visual plus a hit-test target (`mouse_filter = IGNORE`);
  it never handles input itself. It stays hidden until a button is pressed, is
  shown while held, and highlights while the finger is over it.
- `SkillButton` owns the interaction. It tracks drags **even for TAP skills**
  (which otherwise have no knob to drag) so the finger can reach the circle,
  converts the finger position into the shared `CanvasLayer` space, and queries
  `CancelArea.contains_point()`. While the finger is over the circle the targeting
  overlay is hidden as a "this will be cancelled" cue.
- On release, a cancel short-circuits `_release()` *before* the `cast_method`
  branch, so the abort path is identical for every method (TAP / DIRECTION /
  POSITION).
- `scenes/main.gd` injects the single shared `CancelArea` into every `SkillButton`
  (`button.cancel_area = ...`), alongside `player` and `slot`.

### `SkillContext` (`skills/skill_context.gd`)

The per-cast payload the player hands to `cast()`. Skills read only what they
need:

| Field | Meaning |
|---|---|
| `caster: Node2D` | The player. Read its position/facing; call primitives like `begin_lunge()` on it. |
| `world: Node` | Where spawned nodes go — the caster's parent, so projectiles/VFX live independently. |
| `direction: Vector2` | Normalized aim, already resolved to facing for an un-aimed tap. `ZERO` for pure TAP. |
| `target_position: Vector2` | World point for POSITION skills (deferred). `ZERO` otherwise. |
| `facing: Vector2` | The caster's raw facing at cast time. |

## Authoring a skill

1. Subclass `Skill` (`skills/skill.gd`) with a `class_name`, add `@export` tuning
   vars, and override `cast(ctx: SkillContext)`.
2. Keep `cast()` **stateless**: read from `ctx`, spawn into `ctx.world`, or call a
   primitive on `ctx.caster`. Never store per-cast state on `self`.
3. Create a `.tres` under `skills/data/` and set `cast_method`, `cooldown`,
   `color`, and your tuning fields.
4. Add it to the `SKILLS` array in `scenes/main.gd` (slot order = button order).

### Body-controlling skills

Skills must **never** drive the `CharacterBody2D` directly — only the body calls
its own `move_and_slide()`. For dash-like motion, the player exposes a generic
primitive:

```gdscript
# player.gd
func begin_lunge(dir: Vector2, spd: float, dur: float) -> void
```

`DashSkill.cast()` is therefore a one-liner: `ctx.caster.begin_lunge(ctx.direction,
dash_speed, dash_duration)`. The player owns the lunge state (`_lunge_dir`,
`_lunge_speed`, `_lunge_time_left`) and, while lunging, slides along that vector
and ignores steering input. New motion skills (leap, charge, knockback) reuse the
same primitive.

## Built-in skills

| Skill | File | Method | Effect |
|---|---|---|---|
| `Skill` | `skills/skill.gd` | — | Base class: name, cooldown, cast_method, color, virtual `cast()`. |
| `DashSkill` | `skills/dash_skill.gd` | DIRECTION | Lunges the caster via `begin_lunge()`. Tuning: `dash_speed`, `dash_duration`. |
| `ProjectileSkill` | `skills/projectile_skill.gd` | DIRECTION | Spawns `projectile_scene` traveling along `direction`; sets its `speed`/`damage` if present. |
| `AoeSkill` | `skills/aoe_skill.gd` | TAP | Damages every enemy within `radius` of the caster. |

Authored data lives in `skills/data/`: `dash.tres`, `fireball.tres` (projectile),
`nova.tres` (AOE).

## Player API (`actors/player/player.gd`)

| Member | Purpose |
|---|---|
| `skills: Array[Skill]` | Assigned slots (may contain `null` for empty slots). |
| `set_skills(list: Array)` | Re-types via `skills.assign(list)` and resets cooldowns. Takes an untyped array because `Array[Resource] as Array[Skill]` does not convert element types at runtime. |
| `cast_skill(slot, direction, target_position) -> bool` | Cast entry point. Returns `false` if dead / slot empty / on cooldown. |
| `get_cooldown_ratio(slot) -> float` | `1` just-cast → `0` ready. Drives the button's sweep. |
| `begin_lunge(dir, spd, dur)` | Generic burst-movement primitive for dash-like skills. |

## SkillButton (`ui/skill_button/`)

A generalization of the original dash button: same touch/drag/tap `_gui_input`
and ring+knob `_draw`, plus:

- Injected `player` and `slot`; reads its skill via `player.skills[slot]` so the
  skill is defined in exactly one place. Empty slots draw an inert placeholder
  and ignore input.
- Branches on `cast_method` at release to produce the right `(direction,
  target_position)` — unless the release lands on the cancel target (see
  [Cancelling a cast](#cancelling-a-cast)).
- Injected `cancel_area`; while held it shows/highlights that target and aborts
  the cast on release over it.
- Tints the ring/knob by the skill's `color` and overlays a dark radial cooldown
  pie (`draw_colored_polygon`, sweeping from 12 o'clock).

The scene `scenes/main.tscn` instances four `SkillButton`s: a large dash button
(slot 0) in the bottom-right thumb spot and three smaller buttons in an arc to its
upper-left (Fireball, Nova, and one empty slot), plus one shared `CancelArea` at
the top-right. `scenes/main.gd` injects `player`/`slot`/`cancel_area` and connects
`cast_requested` → `player.cast_skill`.

## Extending: POSITION skills

The path is already scaffolded — `SkillContext.target_position` exists,
`SkillButton`'s POSITION branch maps drag offset to a world point, and
`cast_skill` forwards it untouched. To add (e.g.) a thrown bomb: subclass `Skill`
with `cast_method = POSITION`, read `ctx.target_position` in `cast()`, and author
a `.tres`. No changes to the player or button core are required.
