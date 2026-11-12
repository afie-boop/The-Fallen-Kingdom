class_name Citizen
extends Node2D
## A recruited beggar. Jobless citizens wander in front of the kingdom house.
## Archers (work at an Archer Post) shoot zombies; builders (work at a Builder Hut) repair
## damaged buildings and walls for free, in the daytime only.

const SPEED: float = 32.0
const WORK_SPEED: float = 46.0

var citizen_id: int = 0
var variant: int = 0
var home: Vector2 = Vector2.ZERO
var job: String = ""               ## "" | "archer" | "builder"
var workplace: Structure = null

var _target: Vector2 = Vector2.ZERO
var _wait: float = 0.0
var _t: float = 0.0
var _scan_t: float = 0.0
var _shoot_cd: float = 0.0
var _zombie: Zombie = null
var _repair: Node2D = null
var _sprite: Sprite2D


func _ready() -> void:
    add_to_group("citizens")
    _sprite = Sprite2D.new()
    _sprite.centered = false
    add_child(_sprite)
    _apply_texture()
    _t = randf() * 6.0
    _target = _wander_target()


func set_job(new_job: String, place: Structure) -> void:
    job = new_job
    workplace = place
    if new_job == "":
        GameState.citizen_jobs.erase(citizen_id)
    else:
        GameState.citizen_jobs[citizen_id] = new_job
    _apply_texture()


func _apply_texture() -> void:
    var tex: Texture2D
    match job:
        "archer":
            tex = PixelArt.archer_tex(variant)
        "builder":
            tex = PixelArt.builder_tex(variant)
        _:
            tex = PixelArt.citizen_tex(variant)
    _sprite.texture = tex
    _sprite.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())


func _process(delta: float) -> void:
    _t += delta
    _shoot_cd = maxf(0.0, _shoot_cd - delta)
    match job:
        "archer":
            _archer(delta)
        "builder":
            _builder(delta)
        _:
            _wander(delta)


# --- movement helpers ------------------------------------------------------

## Moves towards `to`; returns true when there.
func _step(to: Vector2, speed: float, delta: float) -> bool:
    var d: Vector2 = to - global_position
    if d.length() <= 3.0:
        _sprite.position.y = 0.0
        _sprite.rotation = 0.0
        return true
    var before: Vector2 = global_position
    global_position += d.normalized() * speed * delta
    if GameState.island != null:
        global_position = GameState.island.constrain(before, global_position)
    _sprite.position.y = -absf(sin(_t * 9.0)) * 2.0
    _sprite.rotation = sin(_t * 9.0) * 0.06
    if absf(d.x) > 1.0:
        _sprite.flip_h = d.x < 0.0
    return false


func _wander_target() -> Vector2:
    for i in 12:
        var p: Vector2 = home + Vector2(randf_range(-100.0, 100.0), randf_range(40.0, 110.0))
        if GameState.island == null or GameState.island.is_walkable(p):
            return p
    return home + Vector2(0, 50)


func _wander(delta: float) -> void:
    if _step(_target, SPEED, delta):
        _wait -= delta
        if _wait <= 0.0:
            _wait = randf_range(2.0, 6.0)
            _target = _wander_target()


func _station() -> Vector2:
    return workplace.global_position + Vector2(0, 14) if is_instance_valid(workplace) else home + Vector2(0, 60)


# --- archer ----------------------------------------------------------------

func _archer(delta: float) -> void:
    if not _step(_station(), WORK_SPEED, delta):
        return
    var lvl: int = clampi(workplace.level if is_instance_valid(workplace) else 1, 1, 3)
    var reach: float = float(GameConfig.archer_range[lvl - 1])
    _scan_t -= delta
    if _scan_t <= 0.0:
        _scan_t = 0.4
        _zombie = null
        var best: float = reach
        for z in get_tree().get_nodes_in_group("zombies"):
            var zz := z as Zombie
            if zz == null or not zz.active:
                continue
            var d: float = global_position.distance_to(zz.global_position)
            if d < best:
                best = d
                _zombie = zz
    if _zombie != null and is_instance_valid(_zombie) and _zombie.active:
        _sprite.flip_h = _zombie.global_position.x < global_position.x
        if _shoot_cd <= 0.0 and global_position.distance_to(_zombie.global_position) <= reach:
            _shoot_cd = GameConfig.archer_cooldown
            var arrow := Arrow.new()
            get_parent().add_child(arrow)
            arrow.launch(global_position + Vector2(0, -14), _zombie, float(GameConfig.archer_damage[lvl - 1]))


# --- builder ---------------------------------------------------------------

func _builder(delta: float) -> void:
    if GameState.is_night:
        _repair = null
        _step(_station(), WORK_SPEED, delta)     # builders do not work at night
        return
    _scan_t -= delta
    if (_repair == null or not is_instance_valid(_repair) or not _repair.call("needs_repair")) and _scan_t <= 0.0:
        _scan_t = 0.5
        _repair = _nearest_damaged()
    if _repair == null or not is_instance_valid(_repair) or not _repair.call("needs_repair"):
        _repair = null
        _step(_station(), WORK_SPEED, delta)
        return
    var spot: Vector2 = _repair.global_position + Vector2(0, 18)
    if _step(spot, WORK_SPEED, delta):
        var lvl: int = clampi(workplace.level if is_instance_valid(workplace) else 1, 1, 3)
        _repair.call("repair", float(GameConfig.builder_repair_rate[lvl - 1]) * delta)


func _nearest_damaged() -> Node2D:
    var best: Node2D = null
    var best_d: float = 1000000.0
    for n in get_tree().get_nodes_in_group("repairable"):
        var node := n as Node2D
        if node == null or not node.call("needs_repair"):
            continue
        var d: float = global_position.distance_to(node.global_position)
        if d < best_d:
            best_d = d
            best = node
    return best
