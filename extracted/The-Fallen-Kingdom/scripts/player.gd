class_name Player
extends CharacterBody2D
## The local hero. Gameplay only - input comes from the game script / HUD.

signal hp_changed(hp: float, max_hp: float)
signal died

var player_id: int = 1
var hp: float = 100.0
var max_hp: float = 100.0
var facing: Vector2 = Vector2.DOWN
var touch_move: Vector2 = Vector2.ZERO
var dead: bool = false

var _attack_cd: float = 0.0
var _swing_t: float = 0.0
var _invuln: float = 0.0
var _flash: float = 0.0
var _anim_t: float = 0.0
var _sprite: Sprite2D
var _was_swinging: bool = false
var sprint_requested: bool = false
var horse_stamina: float = 100.0
var horse_max_stamina: float = 100.0
var horse_running: bool = false
var _horse_t: float = 0.0


func _ready() -> void:
    collision_layer = 2
    collision_mask = 1
    motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
    add_to_group("players")
    max_hp = GameConfig.player_max_hp
    hp = max_hp
    _sprite = PixelArt.make_sprite_tex(PixelArt.char_tex(GameState.player_skin))
    _sprite.z_index = 2
    add_child(_sprite)
    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 6.0
    shape.shape = circle
    shape.position = Vector2(0, -4)
    add_child(shape)


func _physics_process(delta: float) -> void:
    _attack_cd = maxf(0.0, _attack_cd - delta)
    _invuln = maxf(0.0, _invuln - delta)
    _swing_t = maxf(0.0, _swing_t - delta)
    _flash = maxf(0.0, _flash - delta)
    if dead:
        return
    var dir: Vector2 = _keyboard_vector() + touch_move
    dir = dir.limit_length(1.0)
    horse_running = sprint_requested and dir.length() > 0.1 and horse_stamina > 0.0
    if horse_running:
        horse_stamina = maxf(0.0, horse_stamina - 24.0 * delta)
        _horse_t += delta * 15.0
    else:
        horse_stamina = minf(horse_max_stamina, horse_stamina + 13.0 * delta)
        _horse_t += delta * (7.0 if dir.length() > 0.1 else 2.0)
    var horse_speed: float = GameConfig.player_speed * (1.85 if horse_running else 1.0)
    velocity = dir * horse_speed
    var before: Vector2 = global_position
    move_and_slide()
    if GameState.island != null:
        global_position = GameState.island.constrain(before, global_position)  # no walking into the sea
    if dir.length() > 0.1:
        facing = dir.normalized()
        _anim_t += delta * 8.0
    else:
        _anim_t = 0.0
    # One front-facing sprite: animate with a hop/tilt while walking and flip towards the move direction.
    if dir.length() > 0.1:
        _sprite.position.y = -absf(sin(_anim_t * 1.6)) * 2.5
        _sprite.rotation = sin(_anim_t * 1.6) * 0.07
        if absf(facing.x) > 0.2:
            _sprite.flip_h = facing.x < 0.0
    else:
        _sprite.position.y = 0.0
        _sprite.rotation = 0.0
    if _flash > 0.0:
        _sprite.modulate = Color(1.0, 0.4, 0.4)
    elif _invuln > 0.0:
        _sprite.modulate = Color(1, 1, 1, 0.55 + 0.35 * sin(_invuln * 24.0))
    else:
        _sprite.modulate = Color.WHITE
    queue_redraw()
    if _swing_t > 0.0 or _was_swinging:
        queue_redraw()
    _was_swinging = _swing_t > 0.0


func _keyboard_vector() -> Vector2:
    var x: float = 0.0
    var y: float = 0.0
    if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
        x += 1.0
    if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
        x -= 1.0
    if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
        y += 1.0
    if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
        y -= 1.0
    return Vector2(x, y)


func _draw() -> void:
    _draw_horse()
    if _swing_t > 0.0:
        var a: float = facing.angle()
        draw_arc(Vector2(0, -6) + facing * 10.0, 11.0, a - 0.9, a + 0.9, 8, Color(1, 1, 1, 0.85), 2.0)


func _draw_horse() -> void:
    # Clear side-profile horse silhouette with a neck, head, mane, saddle and animated legs.
    var bob: float = sin(_horse_t * 2.0) * (1.8 if horse_running else 0.45)
    var dark := Color(0.16, 0.085, 0.045)
    var coat := Color(0.48, 0.25, 0.12)
    var coat_light := Color(0.66, 0.39, 0.20)
    var mane := Color(0.12, 0.075, 0.045)
    var y: float = bob
    # Tail behind the body.
    draw_line(Vector2(-19, -9 + y), Vector2(-27, -3 + y + sin(_horse_t * 1.4) * 3.0), dark, 4.0, true)
    draw_line(Vector2(-20, -8 + y), Vector2(-27, -3 + y + sin(_horse_t * 1.4) * 3.0), coat_light, 1.2, true)
    # Far legs, then the broad barrel of the horse.
    var stride: float = sin(_horse_t * (2.8 if horse_running else 1.4)) * (5.0 if horse_running else 1.3)
    draw_line(Vector2(-10, 1 + y), Vector2(-13 - stride, 17 + y), dark, 4.0, true)
    draw_line(Vector2(8, 1 + y), Vector2(11 + stride, 17 + y), dark, 4.0, true)
    var body := PackedVector2Array([
        Vector2(-23, -8 + y), Vector2(-19, -17 + y), Vector2(-7, -20 + y),
        Vector2(8, -17 + y), Vector2(17, -9 + y), Vector2(13, 1 + y),
        Vector2(-13, 3 + y), Vector2(-22, -1 + y)
    ])
    draw_colored_polygon(body, dark)
    var inner_body := PackedVector2Array([
        Vector2(-21, -9 + y), Vector2(-17, -15 + y), Vector2(-7, -18 + y),
        Vector2(7, -15 + y), Vector2(14, -9 + y), Vector2(11, -1 + y),
        Vector2(-12, 1 + y), Vector2(-20, -2 + y)
    ])
    draw_colored_polygon(inner_body, coat)
    draw_line(Vector2(-14, -13 + y), Vector2(7, -14 + y), coat_light, 2.0, true)
    # Near legs with animated knee bends and dark hooves.
    draw_line(Vector2(-8, 0 + y), Vector2(-8 + stride, 12 + y), coat, 5.0, true)
    draw_line(Vector2(-8 + stride, 12 + y), Vector2(-11 + stride, 18 + y), dark, 3.5, true)
    draw_line(Vector2(9, -1 + y), Vector2(9 - stride, 11 + y), coat_light, 5.0, true)
    draw_line(Vector2(9 - stride, 11 + y), Vector2(13 - stride, 18 + y), dark, 3.5, true)
    # Neck, cheek and muzzle make the head clearly horse-shaped.
    var neck := PackedVector2Array([
        Vector2(7, -16 + y), Vector2(12, -26 + y), Vector2(20, -31 + y),
        Vector2(25, -26 + y), Vector2(20, -15 + y), Vector2(15, -7 + y)
    ])
    draw_colored_polygon(neck, dark)
    var neck_inner := PackedVector2Array([
        Vector2(10, -17 + y), Vector2(14, -25 + y), Vector2(20, -28 + y),
        Vector2(22, -25 + y), Vector2(18, -16 + y), Vector2(14, -10 + y)
    ])
    draw_colored_polygon(neck_inner, coat_light)
    draw_circle(Vector2(23, -29 + y), 5.0, dark)
    draw_circle(Vector2(23, -29 + y), 3.7, coat)
    draw_colored_polygon(PackedVector2Array([
        Vector2(25, -30 + y), Vector2(31, -27 + y), Vector2(29, -23 + y),
        Vector2(23, -24 + y), Vector2(20, -27 + y)
    ]), coat_light)
    # Ears, forelock, eye and nostril.
    draw_colored_polygon(PackedVector2Array([Vector2(19, -32 + y), Vector2(17, -40 + y), Vector2(23, -34 + y)]), dark)
    draw_colored_polygon(PackedVector2Array([Vector2(24, -32 + y), Vector2(27, -38 + y), Vector2(27, -31 + y)]), dark)
    draw_line(Vector2(12, -28 + y), Vector2(19, -35 + y), mane, 4.0, true)
    draw_circle(Vector2(26, -29 + y), 1.1, Color(0.98, 0.88, 0.55))
    draw_circle(Vector2(30, -25 + y), 0.9, dark)
    # Saddle and reins.
    draw_colored_polygon(PackedVector2Array([
        Vector2(-7, -19 + y), Vector2(5, -19 + y), Vector2(9, -12 + y),
        Vector2(-5, -11 + y), Vector2(-10, -15 + y)
    ]), Color(0.25, 0.12, 0.07))
    draw_line(Vector2(7, -17 + y), Vector2(20, -26 + y), Color(0.86, 0.68, 0.35), 1.2, true)


func try_attack() -> void:
    if dead or _attack_cd > 0.0:
        return
    _attack_cd = GameConfig.player_attack_cooldown
    _swing_t = 0.15
    var origin: Vector2 = global_position + facing * 14.0
    var reach: float = GameConfig.player_attack_range
    for z in get_tree().get_nodes_in_group("zombies"):
        if origin.distance_to((z as Node2D).global_position) < reach:
            z.call("take_damage", GameConfig.player_attack_damage, global_position)
    for animal_node in get_tree().get_nodes_in_group("wildlife"):
        var animal := animal_node as Wildlife
        if animal != null and origin.distance_to(animal.global_position) < reach:
            animal.take_damage(GameConfig.player_attack_damage, global_position)
    for t in get_tree().get_nodes_in_group("trees"):
        if origin.distance_to((t as Node2D).global_position) < reach:
            t.call("take_hit", self)


func take_damage(amount: float) -> void:
    if dead or _invuln > 0.0:
        return
    hp = maxf(0.0, hp - amount)
    _invuln = 0.4
    _flash = 0.15
    hp_changed.emit(hp, max_hp)
    if hp <= 0.0:
        _die()


func heal(amount: float) -> void:
    if dead:
        return
    hp = minf(max_hp, hp + amount)
    hp_changed.emit(hp, max_hp)


func set_hp(value: float) -> void:
    hp = clampf(value, 1.0, max_hp)
    hp_changed.emit(hp, max_hp)


func respawn(pos: Vector2) -> void:
    global_position = pos
    velocity = Vector2.ZERO
    hp = max_hp
    dead = false
    _invuln = 2.0
    _sprite.visible = true
    horse_stamina = horse_max_stamina
    horse_running = false
    hp_changed.emit(hp, max_hp)


func _die() -> void:
    dead = true
    velocity = Vector2.ZERO
    _sprite.modulate = Color(0.5, 0.5, 0.5, 0.6)
    died.emit()
