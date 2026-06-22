# PNG-skinned rooms (image map instead of tiles)

Most rooms are painted from a 32px tile grid (`rooms/room_base.gd` paints a
`TileMapLayer`, and wall collision comes from the tileset's `physics_layer_0`).
A **PNG-skinned room** instead shows one beautiful image as the whole map, with no
`TileMapLayer` at all. `rooms/room_06.tscn` is the first example, skinned by `map.png`.

## How it looks like the image *and* works as a level

Three concerns are split across two sprites cut from the **same** source image plus a
logical (never-rendered) grid:

1. **`Foundation` Sprite2D** (`z_index = -20`) — the source image fit to the room size
   (`pngmap_floor.png`). This is the visible floor + walls, drawn behind everything.
2. **Wall foreground**, the *same pixels* with alpha kept only on the wall band and erased
   on the interior and the door openings. Drawing it over the player makes the player
   appear to pass behind/into a wall. It is split in two so a tall sprite isn't wrongly
   swallowed:
   - **`WallsRest` Sprite2D** (`z_index = 20`, always on top, `pngmap_walls_rest.png`) —
     the left/right/bottom bands. These only ever overlap the player's feet/side, which
     reads correctly as "in front of the wall".
   - **`WallsTop` Sprite2D** (`pngmap_walls_top.png`, script `wall_foreground.gd`) — the
     top band. A player walking *up* to the top wall has a sprite that reaches above their
     feet, so an always-on-top top wall would swallow them and look like phasing. Instead
     `wall_foreground.gd` **depth-sorts** it against the player: it draws *behind* the
     player (`z = -10`, still above the foundation) while their feet are below the wall's
     inner edge (`base_y`), and *over* the player (`z = 20`) once their feet cross behind
     it — i.e. as they step into a top doorway. This is the "walk **into** the door" depth.
   Every pixel comes from the source image, so style and position stay perfectly
   consistent (no separately-generated door art).
3. **A logical char grid** in `rooms/room_06.gd` (`_layout()`, never painted) drives the
   A* `nav_grid`, mob spawns, and door/entry anchors — and, replacing the tileset's tile
   collision, **`StaticBody2D` wall colliders built in code** (`_build_collision`, on
   `collision_layer = 1` like the tile walls and door gates). So nothing phases through
   walls.

Unlike the tile rooms (1-cell wall ring, doors on the very edge), the painted wall band
is `BAND` cells thick, so doors are short tunnels through the band with the threshold
(`D`/`E`, the 3-cell run the run controller anchors its gate to) on the band's **inner**
row. That breaks `RoomBase._wall_of`'s "door is on the edge" assumption, so `room_06`
overrides `build()` to set the door sides explicitly and reuses the generic
`_build_nav`/`_exit_anchors`/`_cell_center` helpers. Everything else — waves, A*
pathfinding, locked→reward doors, transitions — is the normal flow via `scenes/main.gd`.

`RoomBase` was made tolerant of a missing `Ground`/`Props` node (`get_node_or_null`) so a
PNG-skinned room can omit the tilemap entirely; the tile rooms are unchanged.

### Tall sprite vs. a thick top wall

The player collides at its feet but its sprite stands ~72px tall, so walking up to the
top wall its body overshoots into the wall band. Two tweaks keep that looking right:

- **Collider apron** (`room_06.gd` `TOP_APRON`): the innermost top-wall collider row is
  extended downward into the room so the player stops with its sprite *just below* the
  visible wall — it reads as standing in front of the wall, not on it or sunk into it.
- **Door opening inset** (`room_06.gd` `exit_opening_inset`, plumbed through `main.gd` to
  `Door.configure`'s `opening_inset`): for a thick wall band the gate and the transport
  trigger are pushed OUT to the far end of the doorway. So the player can walk *into* the
  opening at any time (occluded by the top wall — the "into the door" look) and is only
  stopped from leaving the map at the far end; the room transition fires once they're deep
  in the opening, not at the doorway mouth, and still only after the room is cleared (the
  controller ignores the trigger until `State.CLEARED`). Tile rooms pass inset 0 (gate and
  trigger at the gap centre, as before).

## Regenerating the art

The two PNGs are derived from the source image by `tools/build_pngmap_room.py`:

```
python tools/build_pngmap_room.py
```

It writes `assets/maps/pngmap_floor.png` (image fit to `COLS*TILE × ROWS*TILE`) plus the
two wall overlays `pngmap_walls_top.png` (top band, depth-sorted) and
`pngmap_walls_rest.png` (left/right/bottom, always on top), both with door openings cut.
**The grid size, wall band thickness, and door-opening columns in the script must match
the same constants in
`rooms/room_06.gd`** (`COLS`, `ROWS`, `BAND`, `TOP_OPENINGS`, `BOTTOM_OPENINGS`) — they
are the single source of truth that keeps collision, occlusion, and the visible walls
aligned. After regenerating, let Godot reimport (open the editor or run with `--import`).

To add another PNG-skinned room, copy `room_06.{gd,tscn}`, point the tool at the new
source image with matching constants, and add the scene to `ROOM_POOL` in `scenes/main.gd`.
