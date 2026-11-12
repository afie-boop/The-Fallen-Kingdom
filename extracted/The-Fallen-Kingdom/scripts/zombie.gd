class_name Zombie
extends CharacterBody2D
## Basic zombie. Pooled: the spawner activates/deactivates instances instead of
## creating and freeing them.

signal killed(zombie: Zombie)

var active: bool = false
var hp: float = 30.0
var kingdom_castle: Node2D

var _target: Node2D
var _reach: float = 16.0
var _retarget_t: float = 0.0
var _attack_cd: float = 0.0
var _anim_t: float = 0.0
var _flash: float = 0.0
var _knock: Vector2 = Vector2.ZERO
var _sprite: Sprite2D
var _shape: CollisionShape2D
var _retreating: bool = false


func _ready() -> void:
    collision_layer = 8
    collision_mask = 1 | 4
    motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
    _sprite = PixelArt.make_sprite_tex(PixelArt.zombie_tex(0))
    add_child(_sprite)
    _shape = CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 6.0
    _shape.shape = circle
    _shape.position = Vector2(0, -4)
    add_child(_shape)
    deactivate()


func activate(pos: Vector2) -> void:
    global_position = pos
    hp = GameConfig.zombie_max_hp
    active = true
    visible = true
    _target = null
    _retarget_t = 0.0
    _attack_cd = 0.5
    _knock = Vector2.ZERO
    _retreating = false
    _sprite.modulate = Color.WHITE
    _sprite.texture = PixelArt.zombie_tex(randi() % PixelArt.ZOMBIE_VARIANTS)
    process_mode = Node.PROCESS_MODE_INHERIT
    _shape.set_deferred("disabled", false)
    if not is_in_group("zombies"):
        add_to_group("zombies")


func deactivate() -> void:
    active = false
    visible = false
    process_mode = Node.PROCESS_MODE_DISABLED
    if _shape != null:
        _shape.set_deferred("disabled", true)
    if is_in_group("zombies"):
        remove_from_group("zombies")


func _physics_process(delta: float) -> void:
    if not active or _retreating:
        return
    _attack_cd = maxf(0.0, _attack_cd - delta)
    _flash = maxf(0.0, _flash - delta)
    _retarget_t -= delta
    if _retarget_t <= 0.0:
        _retarget_t = 0.4
        _pick_target()
    var desired: Vector2 = Vector2.ZERO
    if is_instance_valid(_target):
        var to: Vector2 = _target.global_position - global_position
        var dist: float = to.length()
        if dist > _reach:
            desired = to / dist * GameConfig.zombie_speed
        else:
            _try_attack()
    velocity = desired + _knock
    _knock = _knock.move_toward(Vector2.ZERO, 500.0 * delta)
    var before: Vector2 = global_position
    move_and_slide()
    if GameState.island != null:
        global_position = GameState.island.constrain(before, global_position)
    if desired.length() > 1.0:
        _anim_t += delta * 6.0
        if absf(desired.x) > 1.0:
            _sprite.flip_h = desired.x < 0.0
    _sprite.position.y = -absf(sin(_anim_t * 1.5)) * 2.0 if desired.length() > 1.0 else 0.0
    _sprite.rotation = sin(_anim_t * 1.5) * 0.09 if desired.length() > 1.0 else 0.0
    _sprite.modulate = Color(1.0, 0.45, 0.45) if _flash > 0.0 else Color.WHITE


## At dawn zombies fade away (back into their nests).
func retreat() -> void:
    if not active or _retreating:
        return
    _retreating = true
    velocity = Vector2.ZERO
    var tw := create_tween()
    tw.tween_property(_sprite, "modulate:a", 0.0, 1.2)
    tw.tween_callback(deactivate)


func _pick_target() -> void:
    var best: Node2D = null
    var best_d: float = GameConfig.zombie_aggro_night if GameState.is_night else GameConfig.zombie_aggro_day
    for p in get_tree().get_nodes_in_group("players"):
        var pl := p as Player
        if pl == null or pl.dead:
            continue
        var d: float = global_position.distance_to(pl.global_position)
        if d < best_d:
            best_d = d
            best = pl
    if best != null:
        _target = best
        _reach = 20.0
        return
    # no player nearby: chew through any kingdom building that is in the way, otherwise head for the house
    var near_struct: Node2D = null
    var near_d: float = 90.0
    for s in get_tree().get_nodes_in_group("structures"):
        var sn := s as Node2D
        if sn == null:
            continue
        var sd: float = global_position.distance_to(sn.global_position)
        if sd < near_d:
            near_d = sd
            near_struct = sn
    if near_struct != null:
        _target = near_struct
        _reach = 52.0
    else:
        _target = kingdom_castle
        _reach = 84.0


func _try_attack() -> void:
    if _attack_cd > 0.0:
        return
    _attack_cd = GameConfig.zombie_attack_cooldown
    if _target is Player:
        (_target as Player).take_damage(GameConfig.zombie_damage)
    elif _target != null and _target.has_method("take_damage"):
        _target.call("take_damage", GameConfig.zombie_castle_damage)


func take_damage(amount: float, from_pos: Vector2 = Vector2.ZERO) -> void:
    if not active:
        return
    hp -= amount
    _flash = 0.15
    var away: Vector2 = global_position - from_pos
    if away.length() > 0.01:
        _knock = away.normalized() * 140.0
    if hp <= 0.0:
        killed.emit(self)
        deactivate()
