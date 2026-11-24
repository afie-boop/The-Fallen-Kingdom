extends CharacterBody2D
class_name DeadzonePlayer

signal hp_changed(value: float, maximum: float)
signal died

var max_hp: float = 100.0
var hp: float = 100.0
var move_input: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.RIGHT
var move_speed: float = 145.0
var dead: bool = false
var _sprite: Sprite2D
var _invulnerability: float = 0.0

func _ready() -> void:
    collision_layer = 2
    collision_mask = 0
    motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
    add_to_group("players")
    _sprite = PixelArt.make_sprite_tex(PixelArt.char_tex(1))
    _sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _sprite.scale = Vector2(1.5, 1.5)
    add_child(_sprite)
    var hitbox := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 8.0
    hitbox.shape = circle
    add_child(hitbox)

func _physics_process(delta: float) -> void:
    _invulnerability = maxf(0.0, _invulnerability - delta)
    if dead:
        velocity = Vector2.ZERO
        return
    var direction := move_input + _keyboard_input()
    direction = direction.limit_length(1.0)
    velocity = direction * move_speed
    move_and_slide()
    global_position.x = clampf(global_position.x, -660.0, 660.0)
    global_position.y = clampf(global_position.y, -660.0, 660.0)
    if direction.length_squared() > 0.01:
        facing = direction.normalized()
        _sprite.flip_h = facing.x < -0.1
    _sprite.modulate = Color(1.0, 0.45, 0.45) if _invulnerability > 0.0 and int(_invulnerability * 18.0) % 2 == 0 else Color.WHITE

func _keyboard_input() -> Vector2:
    return Vector2(
        float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
        float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
    )

func take_damage(amount: float) -> void:
    if dead or _invulnerability > 0.0:
        return
    hp = maxf(0.0, hp - amount)
    _invulnerability = 0.65
    hp_changed.emit(hp, max_hp)
    if hp <= 0.0:
        dead = true
        died.emit()

func heal(amount: float) -> void:
    hp = minf(max_hp, hp + amount)
    hp_changed.emit(hp, max_hp)

func upgrade_health(amount: float) -> void:
    max_hp += amount
    hp = minf(max_hp, hp + amount)
    hp_changed.emit(hp, max_hp)
