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
var _wildlife: Wildlife = null
var _carried_gold: int = 0
var _patrol_target: Vector2 = Vector2.ZERO


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
    _deliver_hunting_gold()
    var radius: float = _kingdom_radius()
    var night_target: Zombie = _nearest_zombie(radius + 120.0)
    if GameState.is_night:
        _release_wildlife()
        # At night archers return to their post, but can reposition to attack
        # zombies that enter the kingdom perimeter.
        if night_target != null:
            _engage_zombie(night_target, delta, radius)
            return
        _step(_station(), WORK_SPEED * 1.35, delta)
        return

    # Daytime: defend the fenced kingdom first, then hunt wildlife.
    if night_target != null:
        _release_wildlife()
        _engage_zombie(night_target, delta, radius)
        return

    if _wildlife == null or not is_instance_valid(_wildlife):
        _wildlife = _nearest_wildlife(radius)
        if _wildlife != null:
            _wildlife.claim(self)
    if _wildlife != null and is_instance_valid(_wildlife):
        var animal_distance: float = global_position.distance_to(_wildlife.global_position)
        if animal_distance > 18.0:
            _step(_wildlife.global_position, WORK_SPEED, delta)
        else:
            _sprite.flip_h = _wildlife.global_position.x < global_position.x
            _shoot_cd -= delta
            if _shoot_cd <= 0.0:
                _shoot_cd = 0.85
                var killed: bool = _wildlife.take_damage(12.0, global_position)
                if killed:
                    _carried_gold += _wildlife.coin_value
                    _wildlife = null
        return

    # No prey nearby: patrol randomly, remaining safely inside the fence.
    if _patrol_target == Vector2.ZERO or global_position.distance_to(_patrol_target) < 12.0:
        _patrol_target = _random_patrol_point(radius)
    _step(_patrol_target, WORK_SPEED, delta)


func _kingdom_radius() -> float:
    var fence_level: int = 0
    for building in GameState.buildings:
        var data: Dictionary = building
        if str(data.get("kind", "")) == "wall":
            fence_level = maxi(fence_level, int(data.get("level", 1)))
    return 320.0 + float(maxi(1, fence_level) - 1) * 180.0


func _inside_kingdom(pos: Vector2, radius: float) -> bool:
    return pos.distance_to(home) <= radius


func _random_patrol_point(radius: float) -> Vector2:
    for attempt in 20:
        var candidate: Vector2 = home + Vector2.from_angle(randf_range(0.0, TAU)) * randf_range(70.0, maxf(90.0, radius - 55.0))
        if GameState.island == null or GameState.island.is_walkable(candidate):
            return candidate
    return _station()


func _nearest_zombie(radius: float) -> Zombie:
    var best: Zombie = null
    var best_distance: float = radius
    for node in get_tree().get_nodes_in_group("zombies"):
        var zombie := node as Zombie
        if zombie == null or not zombie.active:
            continue
        if not _inside_kingdom(zombie.global_position, _kingdom_radius() - 12.0):
            continue
        var distance: float = global_position.distance_to(zombie.global_position)
        if distance < best_distance:
            best_distance = distance
            best = zombie
    return best


func _engage_zombie(zombie: Zombie, delta: float, radius: float) -> void:
    if not is_instance_valid(zombie) or not zombie.active:
        return
    var distance: float = global_position.distance_to(zombie.global_position)
    var lvl: int = clampi(workplace.level if is_instance_valid(workplace) else 1, 1, 3)
    var reach: float = float(GameConfig.archer_range[lvl - 1])
    if distance > reach * 0.72:
        var desired: Vector2 = zombie.global_position
        var offset: Vector2 = desired - home
        if offset.length() > radius - 45.0:
            desired = home + offset.normalized() * (radius - 45.0)
        _step(desired, WORK_SPEED * (1.35 if GameState.is_night else 1.0), delta)
        return
    _sprite.flip_h = zombie.global_position.x < global_position.x
    _shoot_cd = maxf(0.0, _shoot_cd - delta)
    if _shoot_cd <= 0.0:
        _shoot_cd = GameConfig.archer_cooldown
        var arrow := Arrow.new()
        get_parent().add_child(arrow)
        arrow.launch(global_position + Vector2(0, -14), zombie, float(GameConfig.archer_damage[lvl - 1]))


func _nearest_wildlife(radius: float) -> Wildlife:
    var best: Wildlife = null
    var best_distance: float = radius
    for node in get_tree().get_nodes_in_group("wildlife"):
        var animal := node as Wildlife
        if animal == null or (animal.hunter != null and is_instance_valid(animal.hunter)):
            continue
        if not _inside_kingdom(animal.global_position, radius - 20.0):
            continue
        var distance: float = global_position.distance_to(animal.global_position)
        if distance < best_distance:
            best_distance = distance
            best = animal
    return best


func _release_wildlife() -> void:
    if is_instance_valid(_wildlife):
        _wildlife.release(self)
    _wildlife = null


func _deliver_hunting_gold() -> void:
    if _carried_gold <= 0:
        return
    for node in get_tree().get_nodes_in_group("players"):
        var pl := node as Player
        if pl == null or pl.dead:
            continue
        if global_position.distance_to(pl.global_position) <= 58.0:
            GameState.add_gold(_carried_gold, pl.player_id)
            GameState.notice.emit("Your archer delivered %d Gold Coins from hunting." % _carried_gold)
            _carried_gold = 0
            return


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
