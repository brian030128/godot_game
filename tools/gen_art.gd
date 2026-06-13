extends SceneTree
## Tool script: procedurally renders 32x32 pixel-art PNGs for Stitched Dreams.
## Run headless:  godot --headless --script res://tools/gen_art.gd
##
## Outputs:
##   res://assets/tiles/tiles_atlas.png   (4 tiles in a row: floor, floor_flower, wall, wall_top)
##   res://assets/sprites/character.png   (4 facing frames: down, left, right, up)
##   res://assets/sprites/mob.png         (single 32x32 creature frame)
##   res://assets/sprites/bullet.png      (single 8x8 projectile)
##
## Deliberately simple/clean placeholder art — flat colors with light shading and
## dithering so tiles read as intentional pixel art, not programmer rectangles.
## Trivially swappable for a real CC0 pack later.

const TILE := 32

# Palette (sRGB-ish, kept muted/cozy to fit a "dream" mood).
const GRASS_A := Color8(86, 134, 90)
const GRASS_B := Color8(74, 120, 80)
const GRASS_HI := Color8(104, 152, 104)
const DIRT := Color8(150, 116, 84)
const DIRT_HI := Color8(170, 138, 104)
const FLOWER := Color8(228, 196, 96)
const FLOWER_C := Color8(214, 96, 110)
const STONE := Color8(120, 116, 138)
const STONE_HI := Color8(150, 146, 168)
const STONE_LO := Color8(86, 82, 104)
const STONE_TOP := Color8(168, 164, 186)

# Character palette.
const SKIN := Color8(240, 198, 160)
const HAIR := Color8(74, 54, 70)
const SHIRT := Color8(210, 96, 120)
const SHIRT_HI := Color8(232, 128, 150)
const PANTS := Color8(70, 86, 130)
const OUTLINE := Color8(40, 32, 48)

# Mob palette — a sickly purple blob to read as "menacing dream creature".
const MOB_A := Color8(96, 70, 120)
const MOB_B := Color8(78, 56, 100)
const MOB_HI := Color8(126, 96, 150)
const MOB_EYE := Color8(228, 220, 120)

# Bullet palette — a bright warm projectile that pops against the cozy room.
const BULLET_CORE := Color8(255, 236, 160)
const BULLET_EDGE := Color8(232, 150, 80)


func _initialize() -> void:
	seed(20260613)
	var tiles := _make_tiles()
	var chars := _make_character()
	var mob := _make_mob()
	var bullet := _make_bullet()

	var d := DirAccess.open("res://")
	d.make_dir_recursive("assets/tiles")
	d.make_dir_recursive("assets/sprites")

	var e1 := tiles.save_png("res://assets/tiles/tiles_atlas.png")
	var e2 := chars.save_png("res://assets/sprites/character.png")
	var e3 := mob.save_png("res://assets/sprites/mob.png")
	var e4 := bullet.save_png("res://assets/sprites/bullet.png")
	print("tiles_atlas.png -> ", error_string(e1))
	print("character.png -> ", error_string(e2))
	print("mob.png -> ", error_string(e3))
	print("bullet.png -> ", error_string(e4))
	quit()


# --- Tiles ----------------------------------------------------------------

func _make_tiles() -> Image:
	var img := Image.create(TILE * 4, TILE, false, Image.FORMAT_RGBA8)
	_grass(img, 0)            # 0: plain floor
	_flower(img, 1)           # 1: floor with flower accent
	_wall(img, 2, false)      # 2: wall body
	_wall(img, 3, true)       # 3: wall top edge
	return img


func _grass(img: Image, col: int) -> void:
	var ox := col * TILE
	for y in TILE:
		for x in TILE:
			# Checker-ish base with two greens.
			var base := GRASS_A if ((x >> 2) + (y >> 2)) % 2 == 0 else GRASS_B
			# Sparse highlight specks.
			if randi() % 23 == 0:
				base = GRASS_HI
			img.set_pixel(ox + x, y, base)


func _flower(img: Image, col: int) -> void:
	_grass(img, col)
	var ox := col * TILE
	# A few little dirt + flower clusters.
	for _i in 3:
		var cx := 5 + randi() % (TILE - 10)
		var cy := 5 + randi() % (TILE - 10)
		img.set_pixel(ox + cx, cy, FLOWER_C)
		img.set_pixel(ox + cx + 1, cy, FLOWER)
		img.set_pixel(ox + cx - 1, cy, FLOWER)
		img.set_pixel(ox + cx, cy + 1, FLOWER)
		img.set_pixel(ox + cx, cy - 1, FLOWER)


func _wall(img: Image, col: int, top_edge: bool) -> void:
	var ox := col * TILE
	for y in TILE:
		for x in TILE:
			var c := STONE
			# Brick mortar lines every 8px, offset per row band.
			var row_band := y / 8
			var bx := x + (8 if row_band % 2 == 1 else 0)
			if y % 8 == 0 or bx % 16 == 0:
				c = STONE_LO
			elif randi() % 17 == 0:
				c = STONE_HI
			img.set_pixel(ox + x, y, c)
	if top_edge:
		# Bright cap along the top few rows to read as a wall top.
		for y in 6:
			for x in TILE:
				img.set_pixel(ox + x, y, STONE_TOP if y < 4 else STONE_HI)


# --- Character ------------------------------------------------------------
# 4 frames, 32x32 each: [0]=down [1]=left [2]=right [3]=up

func _make_character() -> Image:
	var img := Image.create(TILE * 4, TILE, false, Image.FORMAT_RGBA8)
	# transparent background
	for y in TILE:
		for x in TILE * 4:
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	_char_frame(img, 0, "down")
	_char_frame(img, 1, "side_left")
	_char_frame(img, 2, "side_right")
	_char_frame(img, 3, "up")
	return img


func _px(img: Image, ox: int, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < TILE and y >= 0 and y < TILE:
		img.set_pixel(ox + x, y, c)


func _rect(img: Image, ox: int, x0: int, y0: int, w: int, h: int, c: Color) -> void:
	for yy in h:
		for xx in w:
			_px(img, ox, x0 + xx, y0 + yy, c)


func _char_frame(img: Image, col: int, facing: String) -> void:
	var ox := col * TILE
	# Common body proportions, centered on 32px tile.
	# Legs / pants
	_rect(img, ox, 12, 24, 3, 5, PANTS)
	_rect(img, ox, 17, 24, 3, 5, PANTS)
	# Torso / shirt
	_rect(img, ox, 11, 16, 10, 9, SHIRT)
	_rect(img, ox, 11, 16, 10, 2, SHIRT_HI)
	# Arms
	_rect(img, ox, 9, 17, 2, 6, SHIRT)
	_rect(img, ox, 21, 17, 2, 6, SHIRT)
	# Head
	_rect(img, ox, 12, 7, 8, 9, SKIN)
	# Hair cap
	_rect(img, ox, 11, 5, 10, 4, HAIR)
	_rect(img, ox, 11, 7, 2, 4, HAIR)
	_rect(img, ox, 19, 7, 2, 4, HAIR)

	match facing:
		"down":
			# Eyes
			_px(img, ox, 14, 11, OUTLINE)
			_px(img, ox, 17, 11, OUTLINE)
		"up":
			# Back of head: hair covers face area
			_rect(img, ox, 12, 7, 8, 7, HAIR)
		"side_left":
			# Face shifted; one visible eye, hair to the right.
			_rect(img, ox, 11, 7, 9, 9, SKIN)
			_rect(img, ox, 18, 5, 3, 11, HAIR)
			_px(img, ox, 13, 11, OUTLINE)
		"side_right":
			_rect(img, ox, 12, 7, 9, 9, SKIN)
			_rect(img, ox, 11, 5, 3, 11, HAIR)
			_px(img, ox, 18, 11, OUTLINE)

	# Simple outline pass: darken transparent neighbours of body pixels.
	_outline(img, ox)


func _outline(img: Image, ox: int) -> void:
	var solid := []
	for y in TILE:
		var row := []
		for x in TILE:
			row.append(img.get_pixel(ox + x, y).a > 0.5)
		solid.append(row)
	for y in TILE:
		for x in TILE:
			if solid[y][x]:
				continue
			var near := false
			for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				var nx: int = x + d[0]
				var ny: int = y + d[1]
				if nx >= 0 and nx < TILE and ny >= 0 and ny < TILE and solid[ny][nx]:
					near = true
					break
			if near:
				_px(img, ox, x, y, OUTLINE)


# --- Mob ------------------------------------------------------------------
# Single 32x32 frame: a rounded purple blob with two glowing eyes.

func _make_mob() -> Image:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	for y in TILE:
		for x in TILE:
			img.set_pixel(x, y, Color(0, 0, 0, 0))

	var cx := 16.0
	var cy := 18.0  # sit the body slightly low so it reads as grounded
	var rx := 11.0
	var ry := 10.0
	for y in TILE:
		for x in TILE:
			var nx := (x + 0.5 - cx) / rx
			var ny := (y + 0.5 - cy) / ry
			if nx * nx + ny * ny <= 1.0:
				# Two-tone dither plus sparse highlights for a blobby texture.
				var c := MOB_A if ((x >> 2) + (y >> 2)) % 2 == 0 else MOB_B
				if ny < -0.3 and randi() % 3 == 0:
					c = MOB_HI  # lit top
				elif randi() % 19 == 0:
					c = MOB_HI
				img.set_pixel(x, y, c)

	# Glowing eyes.
	_rect(img, 0, 11, 15, 3, 3, MOB_EYE)
	_rect(img, 0, 18, 15, 3, 3, MOB_EYE)
	_px(img, 0, 12, 16, OUTLINE)
	_px(img, 0, 19, 16, OUTLINE)

	_outline(img, 0)
	return img


# --- Bullet ---------------------------------------------------------------
# Small 8x8 glowing orb.

func _make_bullet() -> Image:
	var size := 8
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var dx := x - c
			var dy := y - c
			var dist := sqrt(dx * dx + dy * dy)
			if dist <= c - 0.5:
				img.set_pixel(x, y, BULLET_CORE)
			elif dist <= c + 0.5:
				img.set_pixel(x, y, BULLET_EDGE)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return img
