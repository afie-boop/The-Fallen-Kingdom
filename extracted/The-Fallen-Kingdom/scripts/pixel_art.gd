class_name PixelArt
extends RefCounted
## Procedurally generated original pixel art (no external image files needed).
## Sprites are anchored at the bottom-centre, so a node's origin is its "feet".

static var _cache: Dictionary = {}


static func get_tex(key: String) -> Texture2D:
    if _cache.has(key):
        return _cache[key]
    var tex := ImageTexture.create_from_image(_build(key))
    _cache[key] = tex
    return tex


## Loads an imported image from res:// (cached). Falls back to a magenta
## placeholder if the file is missing so the game never crashes on a bad path.
static func file_tex(path: String) -> Texture2D:
    if _cache.has(path):
        return _cache[path]
    var tex: Texture2D
    if ResourceLoader.exists(path):
        tex = load(path) as Texture2D
    if tex == null:
        push_warning("PixelArt: missing texture %s" % path)
        tex = ImageTexture.create_from_image(_fallback())
    _cache[path] = tex
    return tex


const TREE_COUNT: int = 9
const RUIN_COUNT: int = 5
const CHAR_COUNT: int = 11


static func tree_tex(i: int) -> Texture2D:
    return file_tex("res://assets/trees/tree_%02d.png" % (posmod(i, TREE_COUNT) + 1))


static func ruin_tex(i: int) -> Texture2D:
    return file_tex("res://assets/buildings/ruin_%d.png" % (posmod(i, RUIN_COUNT) + 1))


static func char_tex(i: int) -> Texture2D:
    return file_tex("res://assets/characters/char_%02d.png" % (posmod(i - 1, CHAR_COUNT) + 1))


const ZOMBIE_VARIANTS: int = 11
const BEGGAR_VARIANTS: int = 11


static func zombie_tex(i: int) -> Texture2D:
    return file_tex("res://assets/characters/zombie_%02d.png" % (posmod(i, ZOMBIE_VARIANTS) + 1))


static func citizen_tex(i: int) -> Texture2D:
    return file_tex("res://assets/characters/citizen_%02d.png" % (posmod(i, 11) + 1))


static func archer_tex(i: int) -> Texture2D:
    return file_tex("res://assets/characters/archer_%02d.png" % (posmod(i, 11) + 1))


static func builder_tex(i: int) -> Texture2D:
    return file_tex("res://assets/characters/builder_%02d.png" % (posmod(i, 11) + 1))


static func beggar_tex(i: int) -> Texture2D:
    return file_tex("res://assets/characters/beggar_%02d.png" % (posmod(i, BEGGAR_VARIANTS) + 1))


static func make_sprite_tex(t: Texture2D) -> Sprite2D:
    var s := Sprite2D.new()
    s.texture = t
    s.centered = false
    s.offset = Vector2(-t.get_width() / 2.0, -t.get_height())
    return s


static func make_sprite(key: String) -> Sprite2D:
    var s := Sprite2D.new()
    var t: Texture2D = get_tex(key)
    s.texture = t
    s.centered = false
    s.offset = Vector2(-t.get_width() / 2.0, -t.get_height())
    return s


static func _build(key: String) -> Image:
    if key == "ground":
        return _ground()
    if key == "tree":
        return _tree()
    if key == "castle":
        return _castle()
    if key == "enemy_castle":
        return _enemy_castle()
    if key == "coin":
        return _coin()
    if key.begins_with("bld_"):
        var bp: PackedStringArray = key.split("_")
        if bp.size() == 3:
            return _building(bp[1], int(bp[2]))
    if key == "tent":
        return _tent()
    if key == "arrow":
        return _arrow()
    if key.begins_with("wall_"):      # wall_h_1 / wall_v_3
        var w: PackedStringArray = key.split("_")
        if w.size() == 3:
            return _wall(w[1] == "h", int(w[2]))
    if key.begins_with("post_"):
        return _post(int(key.substr(5)))
    if key.begins_with("hut_"):
        return _hut(int(key.substr(4)))
    if key == "nest":
        return _nest()
    if key == "fire_0" or key == "fire_1":
        return _fire(int(key.substr(5)))
    if key.begins_with("player_"):
        var p: PackedStringArray = key.split("_")
        if p.size() == 3:
            return _player(int(p[1]), int(p[2]))
    if key.begins_with("zombie_"):
        var z: PackedStringArray = key.split("_")
        if z.size() == 2:
            return _zombie(int(z[1]))
    push_warning("PixelArt: unknown texture key '%s'" % key)
    return _fallback()


# --- drawing helpers -------------------------------------------------------

static func _new(w: int, h: int) -> Image:
    var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    return img


static func _px(img: Image, x: int, y: int, c: Color) -> void:
    if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
        img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            _px(img, xx, yy, c)


static func _disc(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
    for yy in range(cy - r, cy + r + 1):
        for xx in range(cx - r, cx + r + 1):
            if (xx - cx) * (xx - cx) + (yy - cy) * (yy - cy) <= r * r:
                _px(img, xx, yy, c)


@warning_ignore("integer_division")
static func _fallback() -> Image:
    var img := _new(16, 16)
    for y in 16:
        for x in 16:
            _px(img, x, y, Color(1, 0, 1) if (x / 4 + y / 4) % 2 == 0 else Color(0, 0, 0))
    return img


# --- sprites ---------------------------------------------------------------

static func _ground() -> Image:
    var img := _new(32, 32)
    var base := Color(0.27, 0.48, 0.24)
    img.fill(base)
    var rng := RandomNumberGenerator.new()
    rng.seed = 1234
    for i in 100:
        var shade: float = rng.randf_range(-0.05, 0.06)
        _px(img, rng.randi() % 32, rng.randi() % 32, Color(base.r + shade, base.g + shade * 1.4, base.b + shade))
    for i in 14:
        var x: int = rng.randi() % 32
        var y: int = 1 + rng.randi() % 30
        _px(img, x, y, Color(0.2, 0.38, 0.19))
        _px(img, x, y - 1, Color(0.33, 0.56, 0.28))
    for i in 3:
        _px(img, rng.randi() % 32, rng.randi() % 32, Color(0.95, 0.9, 0.4))
    return img


static func _player(dir: int, frame: int) -> Image:
    # dir: 0 down, 1 up, 2 left, 3 right. frame: 0 idle, 1/2 walk.
    var img := _new(16, 16)
    var skin := Color(0.93, 0.74, 0.58)
    var hair := Color(0.35, 0.22, 0.12)
    var tunic := Color(0.2, 0.38, 0.75)
    var tunic_d := Color(0.14, 0.27, 0.55)
    var boots := Color(0.25, 0.17, 0.1)
    var eye := Color(0.1, 0.1, 0.15)
    _rect(img, 3, 14, 10, 2, Color(0, 0, 0, 0.28))
    var lh_l: int = 3
    var lh_r: int = 3
    if frame == 1:
        lh_r = 2
    elif frame == 2:
        lh_l = 2
    _rect(img, 5, 14 - lh_l, 2, lh_l, boots)
    _rect(img, 9, 14 - lh_r, 2, lh_r, boots)
    var side: bool = dir >= 2
    var bx: int = 5 if side else 4
    var bw: int = 6 if side else 8
    _rect(img, bx, 6, bw, 5, tunic)
    _rect(img, bx, 6, bw, 1, tunic_d)
    _rect(img, bx, 10, bw, 1, boots)
    if side:
        _rect(img, 7, 7, 2, 4, tunic_d)
    else:
        _rect(img, 3, 7, 1, 4, tunic_d)
        _rect(img, 12, 7, 1, 4, tunic_d)
    _rect(img, 5, 1, 6, 5, skin)
    if dir == 1:
        _rect(img, 5, 1, 6, 5, hair)
    else:
        _rect(img, 5, 1, 6, 2, hair)
    if dir == 0:
        _px(img, 6, 3, eye)
        _px(img, 9, 3, eye)
    elif dir == 2:
        _px(img, 6, 3, eye)
        _rect(img, 9, 1, 2, 4, hair)
    elif dir == 3:
        _px(img, 9, 3, eye)
        _rect(img, 5, 1, 2, 4, hair)
    return img


static func _zombie(frame: int) -> Image:
    var img := _new(16, 16)
    var skin := Color(0.45, 0.62, 0.38)
    var skin_d := Color(0.32, 0.46, 0.28)
    var cloth := Color(0.38, 0.33, 0.3)
    var blood := Color(0.6, 0.1, 0.1)
    var legs := Color(0.22, 0.2, 0.18)
    _rect(img, 3, 14, 10, 2, Color(0, 0, 0, 0.28))
    var lh_l: int = 3
    var lh_r: int = 3
    if frame == 1:
        lh_l = 2
    _rect(img, 5, 14 - lh_l, 2, lh_l, legs)
    _rect(img, 9, 14 - lh_r, 2, lh_r, legs)
    _rect(img, 4, 6, 8, 5, cloth)
    _rect(img, 5, 7, 2, 2, blood)
    _px(img, 10, 11, cloth)
    var ay: int = 6 if frame == 1 else 7
    _rect(img, 2, ay, 2, 4, skin)
    _rect(img, 12, ay, 2, 4, skin)
    _rect(img, 2, ay + 3, 2, 1, skin_d)
    _rect(img, 12, ay + 3, 2, 1, skin_d)
    _rect(img, 5, 1, 6, 5, skin)
    _rect(img, 5, 1, 6, 1, skin_d)
    _px(img, 6, 3, Color(0.9, 0.1, 0.1))
    _px(img, 9, 3, Color(0.9, 0.1, 0.1))
    _rect(img, 7, 5, 2, 1, Color(0.15, 0.1, 0.1))
    return img


static func _tree() -> Image:
    var img := _new(24, 32)
    var trunk := Color(0.38, 0.25, 0.14)
    var trunk_d := Color(0.28, 0.18, 0.1)
    _rect(img, 6, 29, 12, 3, Color(0, 0, 0, 0.25))
    _rect(img, 10, 18, 4, 12, trunk)
    _rect(img, 12, 18, 2, 12, trunk_d)
    _disc(img, 12, 12, 10, Color(0.12, 0.34, 0.16))
    _disc(img, 8, 14, 7, Color(0.17, 0.43, 0.2))
    _disc(img, 16, 14, 7, Color(0.17, 0.43, 0.2))
    _disc(img, 12, 9, 7, Color(0.22, 0.52, 0.24))
    _disc(img, 9, 8, 3, Color(0.3, 0.62, 0.3))
    return img


static func _castle() -> Image:
    var img := _new(64, 64)
    var stone := Color(0.6, 0.6, 0.66)
    var stone_d := Color(0.42, 0.42, 0.5)
    var stone_l := Color(0.72, 0.72, 0.78)
    var dark := Color(0.12, 0.1, 0.16)
    _rect(img, 2, 60, 60, 4, Color(0, 0, 0, 0.25))
    _rect(img, 10, 26, 44, 34, stone)
    for row in 6:
        var y: int = 28 + row * 6
        _rect(img, 10, y, 44, 1, stone_d)
        var off: int = 0 if row % 2 == 0 else 5
        for x in range(10 + off, 54, 10):
            _rect(img, x, y, 1, 6, stone_d)
    for x in range(10, 54, 8):
        _rect(img, x, 22, 5, 4, stone)
    for tx in [0, 50]:
        _rect(img, tx, 12, 14, 48, stone_l)
        _rect(img, tx + 12, 12, 2, 48, stone_d)
        for by in range(16, 60, 6):
            _rect(img, tx, by, 14, 1, stone_d)
        for bx in range(tx, tx + 14, 5):
            _rect(img, bx, 8, 3, 4, stone_l)
        _rect(img, tx + 5, 24, 4, 7, dark)
    _rect(img, 24, 10, 16, 16, stone)
    for bx in range(24, 40, 5):
        _rect(img, bx, 7, 3, 3, stone)
    _rect(img, 28, 14, 3, 5, dark)
    _rect(img, 33, 14, 3, 5, dark)
    _rect(img, 31, 0, 1, 8, Color(0.42, 0.29, 0.16))
    _rect(img, 32, 1, 9, 5, Color(0.75, 0.2, 0.18))
    _rect(img, 25, 40, 14, 20, dark)
    _disc(img, 32, 40, 7, dark)
    return img


static func _enemy_castle() -> Image:
    var img := _new(64, 64)
    var stone := Color(0.28, 0.24, 0.34)
    var stone_d := Color(0.18, 0.15, 0.23)
    var stone_l := Color(0.38, 0.33, 0.45)
    var glow := Color(0.45, 1.0, 0.4)
    var dark := Color(0.06, 0.04, 0.09)
    _rect(img, 2, 60, 60, 4, Color(0, 0, 0, 0.35))
    _rect(img, 8, 28, 48, 32, stone)
    for row in 5:
        _rect(img, 8, 30 + row * 6, 48, 1, stone_d)
    for tx in [2, 48]:
        _rect(img, tx, 14, 14, 46, stone_l)
        _rect(img, tx + 11, 14, 3, 46, stone_d)
        for sx in range(tx, tx + 14, 4):
            _rect(img, sx, 8, 2, 6, stone_l)
        _rect(img, tx + 5, 26, 4, 6, glow)
    _rect(img, 22, 12, 20, 18, stone)
    for sx in range(22, 42, 4):
        _rect(img, sx, 5, 2, 7, stone)
    _rect(img, 28, 16, 3, 5, glow)
    _rect(img, 34, 16, 3, 5, glow)
    _rect(img, 24, 40, 16, 20, dark)
    _disc(img, 32, 40, 8, dark)
    _rect(img, 29, 44, 2, 2, glow)
    _rect(img, 34, 44, 2, 2, glow)
    return img


static func _coin() -> Image:
    var img := _new(8, 8)
    _disc(img, 4, 4, 3, Color(0.7, 0.5, 0.1))
    _disc(img, 4, 4, 2, Color(1.0, 0.82, 0.2))
    _px(img, 3, 3, Color(1.0, 0.96, 0.7))
    return img


static func _shade(c: Color, f: float) -> Color:
    return Color(clampf(c.r * f, 0.0, 1.0), clampf(c.g * f, 0.0, 1.0), clampf(c.b * f, 0.0, 1.0), 1.0)


## A poor patchwork tent (64x44).
@warning_ignore("integer_division")
static func _tent() -> Image:
    var img := _new(64, 44)
    var pal: Array[Color] = [Color(0.59, 0.46, 0.31), Color(0.49, 0.38, 0.27), Color(0.66, 0.53, 0.36), Color(0.42, 0.44, 0.38)]
    _rect(img, 4, 40, 56, 4, Color(0, 0, 0, 0.25))
    for y in range(3, 41):
        var hw: int = int(lerpf(1.0, 29.0, float(y - 3) / 37.0))
        for x in range(32 - hw, 32 + hw + 1):
            var c: Color = pal[(x / 9 + y / 8) % 4]
            if x <= 32 - hw + 2:
                c = _shade(c, 0.72)
            elif x >= 32 + hw - 2:
                c = _shade(c, 0.84)
            _px(img, x, y, c)
    for y in range(22, 41):
        var dw: int = int((y - 22) / 2.2) + 1
        _rect(img, 32 - dw, y, dw * 2 + 1, 1, Color(0.12, 0.09, 0.08))
    for pt in [Vector2i(20, 28), Vector2i(41, 33), Vector2i(26, 16), Vector2i(36, 24), Vector2i(14, 36)]:
        _rect(img, pt.x, pt.y, 2, 2, Color(0.2, 0.15, 0.1))
    _rect(img, 32, 0, 1, 5, Color(0.36, 0.25, 0.14))
    _rect(img, 1, 38, 1, 3, Color(0.36, 0.25, 0.14))
    _rect(img, 62, 38, 1, 3, Color(0.36, 0.25, 0.14))
    return img


## Small campfire (16x16), two flicker frames.
@warning_ignore("integer_division")
static func _fire(frame: int) -> Image:
    var img := _new(16, 16)
    _rect(img, 2, 13, 12, 3, Color(0, 0, 0, 0.25))
    for pt in [Vector2i(3, 12), Vector2i(6, 14), Vector2i(10, 14), Vector2i(12, 12), Vector2i(5, 11), Vector2i(11, 11)]:
        _disc(img, pt.x, pt.y, 1, Color(0.5, 0.5, 0.54))
    _rect(img, 4, 11, 8, 2, Color(0.3, 0.19, 0.1))
    var h: int = 7 + frame
    _disc(img, 8, 9, 3, Color(0.85, 0.25, 0.1))
    _rect(img, 6, 9 - h / 2, 5, h / 2 + 1, Color(0.95, 0.45, 0.1))
    _rect(img, 7, 8 - h / 2, 3, h / 2, Color(1.0, 0.75, 0.2))
    _px(img, 8, 9 - h / 2 - 1, Color(1.0, 0.9, 0.5))
    return img


## Zombie nest (44x30): a burrow in a dirt mound with glowing eyes, bones and a reaching hand.
static func _nest() -> Image:
    var img := _new(44, 30)
    _rect(img, 2, 26, 40, 4, Color(0, 0, 0, 0.25))
    for y in range(6, 29):
        for x in range(2, 43):
            var dx: float = (x - 22.0) / 20.0
            var dy: float = (y - 18.0) / 11.0
            if dx * dx + dy * dy <= 1.0:
                var n: int = (x * 7 + y * 13) % 5
                var c: Color = Color(0.36, 0.26, 0.17) if n < 3 else Color(0.29, 0.2, 0.13)
                if dx * dx + dy * dy > 0.8:
                    c = _shade(c, 0.75)
                _px(img, x, y, c)
    for y in range(14, 25):
        for x in range(12, 33):
            var ex: float = (x - 22.0) / 10.0
            var ey: float = (y - 19.0) / 5.0
            if ex * ex + ey * ey <= 1.0:
                _px(img, x, y, Color(0.05, 0.03, 0.04))
    _rect(img, 18, 18, 2, 2, Color(0.4, 0.95, 0.4))
    _rect(img, 25, 18, 2, 2, Color(0.4, 0.95, 0.4))
    for pt in [Vector2i(5, 21), Vector2i(6, 20), Vector2i(7, 21), Vector2i(36, 22), Vector2i(37, 21), Vector2i(38, 22)]:
        _px(img, pt.x, pt.y, Color(0.9, 0.88, 0.8))
    _rect(img, 30, 11, 1, 5, Color(0.42, 0.6, 0.36))
    _rect(img, 32, 10, 1, 6, Color(0.42, 0.6, 0.36))
    _rect(img, 34, 11, 1, 5, Color(0.42, 0.6, 0.36))
    _rect(img, 30, 15, 5, 2, Color(0.35, 0.5, 0.3))
    return img


# --- kingdom buildings (levels 1-3) -----------------------------------------------

static func _building(kind: String, level: int) -> Image:
    var lv: int = clampi(level, 1, 3)
    if kind == "castle":
        return _bld_castle(lv)
    if kind == "wall":
        return _bld_wall(lv)
    if kind == "tower":
        return _bld_tower(lv)
    if kind == "hut":
        return _bld_hut(lv)
    return _fallback()


static func _bld_castle(level: int) -> Image:
    var img: Image = _castle()
    var gold := Color(0.95, 0.8, 0.2)
    var blue := Color(0.2, 0.36, 0.82)
    if level >= 2:
        _rect(img, 32, 1, 9, 5, blue)
        _rect(img, 5, 0, 1, 9, Color(0.42, 0.29, 0.16))
        _rect(img, 6, 1, 6, 4, blue)
        _rect(img, 55, 0, 1, 9, Color(0.42, 0.29, 0.16))
        _rect(img, 56, 1, 6, 4, blue)
    if level >= 3:
        _rect(img, 32, 1, 9, 5, gold)
        _rect(img, 6, 1, 6, 4, gold)
        _rect(img, 56, 1, 6, 4, gold)
        _rect(img, 0, 12, 14, 2, gold)
        _rect(img, 50, 12, 14, 2, gold)
        _rect(img, 24, 10, 16, 2, gold)
    img.resize(96, 96, Image.INTERPOLATE_NEAREST)
    return img


static func _bld_wall(level: int) -> Image:
    var img := _new(48, 28)
    _rect(img, 0, 25, 48, 3, Color(0, 0, 0, 0.25))
    if level == 1:
        for i in 6:
            var top: int = 6 + (i % 2) * 3
            var c := Color(0.46, 0.31, 0.18) if i % 2 == 0 else Color(0.4, 0.27, 0.16)
            _rect(img, i * 8 + 1, top, 6, 25 - top, c)
            _rect(img, i * 8 + 3, top - 2, 2, 2, c)
            _rect(img, i * 8 + 1, top, 1, 25 - top, _shade(c, 0.7))
        _rect(img, 0, 13, 48, 2, Color(0.28, 0.18, 0.1))
        _rect(img, 0, 20, 48, 2, Color(0.28, 0.18, 0.1))
    else:
        var stone := Color(0.6, 0.6, 0.66) if level == 2 else Color(0.48, 0.5, 0.58)
        var dark: Color = _shade(stone, 0.7)
        _rect(img, 0, 9, 48, 16, stone)
        for r in 3:
            var y: int = 11 + r * 5
            _rect(img, 0, y, 48, 1, dark)
            for x in range((r % 2) * 4, 48, 8):
                _rect(img, x, y, 1, 5, dark)
        for x in range(0, 48, 12):
            _rect(img, x, 4, 7, 5, stone)
            _rect(img, x, 4, 7, 1, _shade(stone, 1.2))
        _rect(img, 0, 9, 48, 1, _shade(stone, 1.2))
        if level == 3:
            _rect(img, 0, 9, 48, 2, Color(0.35, 0.4, 0.55))
            for x in range(3, 48, 9):
                _px(img, x, 10, Color(0.8, 0.82, 0.9))
    return img


static func _bld_tower(level: int) -> Image:
    var img := _new(32, 56)
    var wood := Color(0.45, 0.3, 0.17)
    var wood_d: Color = _shade(wood, 0.65)
    _rect(img, 2, 53, 28, 3, Color(0, 0, 0, 0.25))
    if level == 1:
        _rect(img, 6, 26, 2, 28, wood)
        _rect(img, 24, 26, 2, 28, wood)
        _rect(img, 6, 40, 20, 2, wood_d)
        for i in 14:
            _px(img, 8 + i, 28 + i, wood_d)
            _px(img, 23 - i, 28 + i, wood_d)
    else:
        var stone := Color(0.58, 0.58, 0.64) if level == 2 else Color(0.46, 0.48, 0.56)
        _rect(img, 6, 30, 20, 24, stone)
        for y in range(32, 54, 5):
            _rect(img, 6, y, 20, 1, _shade(stone, 0.7))
        _rect(img, 13, 42, 6, 12, Color(0.12, 0.1, 0.14))
    _rect(img, 3, 24, 26, 4, wood_d)
    _rect(img, 5, 17, 22, 7, Color(0.12, 0.09, 0.08, 0.8))
    _rect(img, 3, 15, 2, 10, wood)
    _rect(img, 27, 15, 2, 10, wood)
    var roof := Color(0.55, 0.42, 0.22)
    if level == 2:
        roof = Color(0.5, 0.3, 0.2)
    elif level == 3:
        roof = Color(0.58, 0.2, 0.18)
    for y in range(3, 15):
        var hw: int = int(lerpf(2.0, 15.0, float(y - 3) / 11.0))
        _rect(img, 16 - hw, y, hw * 2, 1, roof if y % 3 != 0 else _shade(roof, 0.8))
    if level == 3:
        _rect(img, 16, 0, 1, 4, Color(0.42, 0.29, 0.16))
        _rect(img, 17, 0, 6, 3, Color(0.85, 0.2, 0.2))
    return img


static func _bld_hut(level: int) -> Image:
    var img := _new(48, 40)
    _rect(img, 2, 37, 44, 3, Color(0, 0, 0, 0.25))
    var wall := Color(0.5, 0.36, 0.22)
    if level == 2:
        wall = Color(0.62, 0.5, 0.4)
    elif level == 3:
        wall = Color(0.6, 0.6, 0.64)
    _rect(img, 6, 18, 36, 19, wall)
    for x in range(6, 42, 6):
        _rect(img, x, 18, 1, 19, _shade(wall, 0.75))
    var roof := Color(0.45, 0.3, 0.2)
    if level == 2:
        roof = Color(0.4, 0.26, 0.18)
    elif level == 3:
        roof = Color(0.7, 0.26, 0.2)
    for y in range(3, 19):
        var hw: int = int(lerpf(4.0, 23.0, float(y - 3) / 15.0))
        _rect(img, 24 - hw, y, hw * 2, 1, roof if y % 3 != 0 else _shade(roof, 0.8))
    _rect(img, 20, 26, 9, 11, Color(0.15, 0.1, 0.08))
    _rect(img, 9, 24, 6, 6, Color(0.2, 0.25, 0.3))
    _rect(img, 33, 22, 1, 6, Color(0.6, 0.6, 0.65))       # hammer sign
    _rect(img, 31, 22, 5, 2, Color(0.6, 0.6, 0.65))
    if level == 3:
        _rect(img, 34, 0, 5, 8, Color(0.55, 0.55, 0.6))
        _rect(img, 35, -1 + 1, 3, 1, Color(0.8, 0.8, 0.85))
    return img


static func _arrow() -> Image:
    var img := _new(12, 3)
    _rect(img, 1, 1, 9, 1, Color(0.5, 0.35, 0.2))
    _rect(img, 10, 0, 2, 3, Color(0.75, 0.77, 0.82))
    _rect(img, 0, 0, 2, 1, Color(0.9, 0.9, 0.85))
    _rect(img, 0, 2, 2, 1, Color(0.9, 0.9, 0.85))
    return img


## Wall segment. Horizontal: 64x30, vertical: 22x60. Level 1 palisade, 2 stone, 3 reinforced stone. Bottom-anchored.
@warning_ignore("integer_division")
static func _wall(horizontal: bool, level: int) -> Image:
    var w: int = 64 if horizontal else 22
    var h: int = 30 if horizontal else 60
    var img := _new(w, h)
    _rect(img, 0, h - 3, w, 3, Color(0, 0, 0, 0.25))
    var wood := Color(0.45, 0.31, 0.18)
    var wood_d := Color(0.32, 0.21, 0.12)
    var stone := Color(0.58, 0.58, 0.63) if level == 2 else Color(0.42, 0.42, 0.5)
    var stone_d := _shade(stone, 0.7)
    var band := Color(0.3, 0.32, 0.4)
    if level <= 1:
        if horizontal:
            for x in range(0, w - 6, 8):
                _rect(img, x, 7, 7, h - 10, wood)
                _rect(img, x + 5, 7, 2, h - 10, wood_d)
                _rect(img, x + 2, 4, 3, 3, wood)
                _px(img, x + 3, 3, wood)
            _rect(img, 0, 15, w, 3, wood_d)
        else:
            _rect(img, 3, 6, 16, h - 9, wood)
            for y in range(10, h - 4, 8):
                _rect(img, 3, y, 16, 1, wood_d)
            _rect(img, 16, 6, 3, h - 9, wood_d)
            _rect(img, 3, 2, 16, 4, wood_d)
    else:
        var x0: int = 0 if horizontal else 3
        var ww: int = w if horizontal else 16
        var top: int = 8 if horizontal else 6
        _rect(img, x0, top, ww, h - top - 3, stone)
        for y in range(top + 1, h - 3, 5):
            _rect(img, x0, y, ww, 1, stone_d)
            var off: int = 0 if ((y - top) / 5) % 2 == 0 else 4
            for x in range(x0 + off, x0 + ww, 8):
                _rect(img, x, y, 1, 5, stone_d)
        for x in range(x0, x0 + ww - 3, 10):
            _rect(img, x, top - 5, 6, 5, stone)
        if level >= 3:
            _rect(img, x0, top + 6, ww, 2, band)
            for x in range(x0 + 3, x0 + ww - 2, 12):
                _rect(img, x, top - 8, 1, 3, Color(0.75, 0.77, 0.82))
    return img


## Archer post / watchtower (40x64).
static func _post(level: int) -> Image:
    var img := _new(40, 64)
    var wood := Color(0.45, 0.3, 0.17)
    var wood_d := Color(0.3, 0.2, 0.11)
    _rect(img, 4, 60, 32, 4, Color(0, 0, 0, 0.25))
    if level >= 3:
        _rect(img, 6, 44, 28, 17, Color(0.5, 0.5, 0.56))
        for y in range(46, 60, 5):
            _rect(img, 6, y, 28, 1, Color(0.36, 0.36, 0.42))
        _rect(img, 5, 24, 4, 20, wood)
        _rect(img, 31, 24, 4, 20, wood)
    else:
        _rect(img, 5, 26, 4, 35, wood)
        _rect(img, 31, 26, 4, 35, wood)
        _rect(img, 8, 40, 24, 2, wood_d)
        _rect(img, 8, 52, 24, 2, wood_d)
    _rect(img, 2, 22, 36, 6, wood)
    _rect(img, 2, 27, 36, 1, wood_d)
    _rect(img, 3, 12, 2, 10, wood_d)
    _rect(img, 35, 12, 2, 10, wood_d)
    _rect(img, 3, 12, 34, 2, wood_d)
    if level >= 2:
        var roof := Color(0.55, 0.27, 0.2) if level == 2 else Color(0.35, 0.36, 0.42)
        for i in 8:
            _rect(img, 4 + i, 4 + i, 32 - i * 2, 1, roof)
        _rect(img, 3, 0, 34, 4, _shade(roof, 0.85))
    return img


## Builder's hut (52x40).
@warning_ignore("integer_division")
static func _hut(level: int) -> Image:
    var img := _new(52, 40)
    var wall := Color(0.5, 0.36, 0.22) if level < 3 else Color(0.55, 0.55, 0.6)
    var wall_d := _shade(wall, 0.72)
    var roof := Color(0.72, 0.58, 0.32) if level == 1 else (Color(0.55, 0.28, 0.2) if level == 2 else Color(0.35, 0.36, 0.42))
    _rect(img, 2, 36, 48, 4, Color(0, 0, 0, 0.25))
    _rect(img, 5, 18, 42, 19, wall)
    for y in range(21, 36, 4):
        _rect(img, 5, y, 42, 1, wall_d)
    for i in 16:
        _rect(img, 26 - 26 + i * 1, 17 - i, 52 - i * 2, 1, roof if i % 4 != 3 else _shade(roof, 0.8))
    _rect(img, 21, 24, 10, 13, Color(0.13, 0.09, 0.07))
    _rect(img, 9, 24, 7, 6, Color(0.2, 0.16, 0.12))
    _rect(img, 38, 24, 7, 6, Color(0.2, 0.16, 0.12))
    _rect(img, 40, 4, 5, 8, Color(0.4, 0.4, 0.45))   # chimney
    return img


## Natural-looking large boulders, four shape/shade variations (64x48).
static func _rock(variant: int) -> Image:
    var img := _new(64, 48)
    var base_colors: Array[Color] = [Color(0.43, 0.45, 0.47), Color(0.49, 0.46, 0.41), Color(0.38, 0.43, 0.45), Color(0.52, 0.51, 0.48)]
    var base: Color = base_colors[posmod(variant, base_colors.size())]
    var dark: Color = _shade(base, 0.62)
    var light: Color = _shade(base, 1.28)
    _disc(img, 32, 39, 23, Color(0, 0, 0, 0.25))
    var widths: Array[int] = [23, 20, 25, 22]
    var heights: Array[int] = [17, 20, 15, 18]
    var rx: int = widths[posmod(variant, 4)]
    var ry: int = heights[posmod(variant, 4)]
    for y in range(9, 43):
        for x in range(7, 58):
            var dx: float = float(x - 32) / float(rx)
            var dy: float = float(y - (27 + (variant % 2) * 2)) / float(ry)
            if dx * dx + dy * dy <= 1.0:
                var shade: Color = base
                if y < 20 or x < 22:
                    shade = light
                elif y > 34 or x > 43:
                    shade = dark
                if (x * 7 + y * 11 + variant * 13) % 19 == 0:
                    shade = _shade(shade, 0.82)
                _px(img, x, y, shade)
    _rect(img, 21, 15, 10, 3, light)
    _rect(img, 15, 22, 5, 2, light)
    _rect(img, 37, 31, 8, 3, dark)
    return img
