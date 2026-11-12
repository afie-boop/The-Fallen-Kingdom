class_name IslandMap
extends RefCounted
## Procedural, seed-based island shape. The same world seed always gives the same
## coastline, so only the seed has to be saved (or synced in multiplayer).
## Field value v: > 0 land, 0..0.1 beach, > 0.1 grass, < 0 sea.

const RES: int = 384
const BEACH_END: float = 0.1

var world_size: Vector2 = Vector2(4800, 4800)
var texture: ImageTexture
var center_pos: Vector2 = Vector2.ZERO
var far_inland_pos: Vector2 = Vector2.ZERO  ## good spot for the Zombie Castle

var _vals: PackedFloat32Array = PackedFloat32Array()
var _dirt: PackedFloat32Array = PackedFloat32Array()   ## 0..1, > 0.64 shows bare soil (no grass)
var _img: Image


func build(world_seed: int, size: Vector2) -> void:
    world_size = size
    var noise := FastNoiseLite.new()
    noise.seed = world_seed
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    noise.fractal_octaves = 4
    noise.frequency = 1.0
    var rng := RandomNumberGenerator.new()
    rng.seed = world_seed
    var stretch := Vector2(rng.randf_range(0.9, 1.3), rng.randf_range(0.9, 1.3))
    var ox: float = rng.randf_range(-50.0, 50.0)
    var oy: float = rng.randf_range(-50.0, 50.0)

    var dnoise := FastNoiseLite.new()
    dnoise.seed = world_seed + 101
    dnoise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    dnoise.fractal_type = FastNoiseLite.FRACTAL_FBM
    dnoise.fractal_octaves = 3
    dnoise.frequency = 1.0
    _vals.resize(RES * RES)
    _dirt.resize(RES * RES)
    for y in RES:
        for x in RES:
            var p := Vector2(float(x) / float(RES - 1) * 2.0 - 1.0, float(y) / float(RES - 1) * 2.0 - 1.0)
            var n: float = noise.get_noise_2d(p.x * 2.2 + ox, p.y * 2.2 + oy)
            var r: float = (p * stretch).length()
            var v: float = 0.78 - r + n * 0.4
            var edge: float = maxf(absf(p.x), absf(p.y))
            v -= smoothstep(0.72, 0.98, edge) * 1.6
            _vals[y * RES + x] = v
            _dirt[y * RES + x] = clampf(dnoise.get_noise_2d(p.x * 3.4 + ox, p.y * 3.4 + oy) * 0.5 + 0.5, 0.0, 1.0)

    _keep_main_island()
    _find_far_inland()
    center_pos = size / 2.0
    add_dirt_spot(center_pos + Vector2(0, 20), 230.0)   # bare yard around the kingdom house
    _make_texture()


## Removes land that is not connected to the island centre (tiny islets).
func _keep_main_island() -> void:
    var seen := PackedByteArray()
    seen.resize(RES * RES)
    var half: int = floori(RES / 2.0)
    var stack: Array[int] = [half * RES + half]
    while not stack.is_empty():
        var i: int = stack.pop_back()
        if seen[i] == 1 or _vals[i] <= 0.0:
            continue
        seen[i] = 1
        var x: int = i % RES
        var y: int = floori(i / float(RES))
        if x > 0: stack.append(i - 1)
        if x < RES - 1: stack.append(i + 1)
        if y > 0: stack.append(i - RES)
        if y < RES - 1: stack.append(i + RES)
    for i in RES * RES:
        if seen[i] == 0 and _vals[i] > -0.2:
            _vals[i] = -0.2


func _find_far_inland() -> void:
    var best: float = -1.0
    var mid := Vector2(RES / 2.0, RES / 2.0)
    for y in RES:
        for x in RES:
            if _vals[y * RES + x] > 0.28:
                var d: float = Vector2(x, y).distance_to(mid)
                if d > best:
                    best = d
                    far_inland_pos = Vector2(x, y) / float(RES - 1) * world_size


func _make_texture() -> void:
    _img = Image.create(RES, RES, false, Image.FORMAT_RGBA8)
    _fill_image()
    texture = ImageTexture.create_from_image(_img)


func _fill_image() -> void:
    for y in RES:
        for x in RES:
            var i: int = y * RES + x
            _img.set_pixel(x, y, Color(clampf(_vals[i] * 0.5 + 0.5, 0.0, 1.0), clampf(_dirt[i], 0.0, 1.0), 0.0, 1.0))


## Call after add_dirt_spot() so the ground shader sees the change.
func refresh_texture() -> void:
    _fill_image()
    texture.update(_img)


## Makes a patch of bare soil (e.g. a yard around a house).
func add_dirt_spot(pos: Vector2, radius: float) -> void:
    var cell: Vector2 = world_size / float(RES - 1)
    var x0: int = maxi(0, int((pos.x - radius) / cell.x))
    var x1: int = mini(RES - 1, int((pos.x + radius) / cell.x) + 1)
    var y0: int = maxi(0, int((pos.y - radius) / cell.y))
    var y1: int = mini(RES - 1, int((pos.y + radius) / cell.y) + 1)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            var d: float = Vector2(x * cell.x, y * cell.y).distance_to(pos)
            if d < radius:
                var g: float = lerpf(0.58, 1.0, clampf((1.0 - d / radius) * 3.0, 0.0, 1.0))
                _dirt[y * RES + x] = maxf(_dirt[y * RES + x], g)


## Bilinear field value at a world position (very negative outside the world).
func sample(pos: Vector2) -> float:
    return _bilerp(_vals, pos, -1.0)


## 0..1 amount of bare soil at a world position.
func dirt_at(pos: Vector2) -> float:
    return _bilerp(_dirt, pos, 0.0)


func _bilerp(arr: PackedFloat32Array, pos: Vector2, outside: float) -> float:
    var g: Vector2 = pos / world_size * float(RES - 1)
    if g.x < 0.0 or g.y < 0.0 or g.x > RES - 1 or g.y > RES - 1:
        return outside
    var x0: int = mini(int(g.x), RES - 2)
    var y0: int = mini(int(g.y), RES - 2)
    var fx: float = g.x - float(x0)
    var fy: float = g.y - float(y0)
    var a: float = lerpf(arr[y0 * RES + x0], arr[y0 * RES + x0 + 1], fx)
    var b: float = lerpf(arr[(y0 + 1) * RES + x0], arr[(y0 + 1) * RES + x0 + 1], fx)
    return lerpf(a, b, fy)


func is_walkable(pos: Vector2) -> bool:
    return sample(pos) > 0.0


## Returns where something moving from `from` to `to` may actually end up (no swimming).
func constrain(from: Vector2, to: Vector2) -> Vector2:
    if is_walkable(to):
        return to
    var tx := Vector2(to.x, from.y)
    if is_walkable(tx):
        return tx
    var ty := Vector2(from.x, to.y)
    if is_walkable(ty):
        return ty
    return from


## Random point on land with field value >= min_v (deterministic for a given rng).
func random_land_point(rng: RandomNumberGenerator, min_v: float, margin: float = 40.0) -> Vector2:
    for i in 200:
        var p := Vector2(rng.randf_range(margin, world_size.x - margin), rng.randf_range(margin, world_size.y - margin))
        if sample(p) >= min_v:
            return p
    return center_pos
