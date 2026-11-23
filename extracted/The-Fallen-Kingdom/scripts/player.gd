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
var _horse_sprite: Sprite2D
var _horse_frame: int = -1
var _horse_anim_t: float = 0.0
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
    _horse_sprite = Sprite2D.new()
    _horse_sprite.centered = false
    _horse_sprite.offset = Vector2(-24, -32)
    _horse_sprite.z_index = 1
    _horse_sprite.texture = PixelArt.get_tex("horse_0")
    add_child(_horse_sprite)
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
    # Animate the pixel horse legs; the rider stays seated on its saddle.
    _horse_anim_t += delta
    var frame_duration: float = 0.10 if horse_running else (0.20 if dir.length() > 0.1 else 0.0)
    if frame_duration > 0.0:
        var next_frame: int = int(floor(_horse_anim_t / frame_duration)) % 4
        if next_frame != _horse_frame:
            _horse_frame = next_frame
            _horse_sprite.texture = PixelArt.get_tex("horse_%d" % _horse_frame)
    elif _horse_frame != 0:
        _horse_frame = 0
        _horse_sprite.texture = PixelArt.get_tex("horse_0")
    var horse_bob: float = sin(_horse_t * 2.0) * (1.0 if horse_running else 0.35)
    # Riding pose: lower and compact the hero so the hips sit on the saddle,
    # rather than placing the full standing sprite upright above the horse.
    _sprite.position = Vector2(-1.0, -19.0 + horse_bob - absf(sin(_anim_t * 1.6)) * (0.6 if horse_running else 0.2))
    _sprite.scale = Vector2(0.88, 0.72)
    _sprite.rotation = sin(_anim_t * 1.6) * (0.018 if horse_running else 0.008) if dir.length() > 0.1 else 0.0
    if absf(facing.x) > 0.2:
        _sprite.flip_h = facing.x < 0.0
    _horse_sprite.flip_h = facing.x < 0.0 if absf(facing.x) > 0.2 else false
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
    if _swing_t > 0.0:
        var a: float = facing.angle()
        draw_arc(Vector2(0, -6) + facing * 10.0, 11.0, a - 0.9, a + 0.9, 8, Color(1, 1, 1, 0.85), 2.0)


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
