class_name Wildlife
extends Node2D
## Passive deer and rabbits. Archers can claim and hunt them during daylight.

var animal_type: String = "deer"
var hp: float = 18.0
var coin_value: int = 2
var hunter: Node2D = null
var _target: Vector2 = Vector2.ZERO
var _wait: float = 0.0
var _t: float = 0.0
var _sprite: Sprite2D

func _ready() -> void:
    add_to_group("wildlife")
    _sprite = Sprite2D.new()
    _sprite.texture = _make_texture(animal_type)
    _sprite.centered = false
    _sprite.offset = Vector2(-_sprite.texture.get_width() / 2.0, -_sprite.texture.get_height())
    add_child(_sprite)
    _target = global_position

func configure(kind: String) -> void:
    animal_type = kind
    hp = 24.0 if kind == "deer" else 12.0
    coin_value = 3 if kind == "deer" else 1

func _process(delta: float) -> void:
    _t += delta
    if hunter != null and is_instance_valid(hunter):
        return
    _wait -= delta
    if global_position.distance_to(_target) < 4.0 or _wait <= 0.0:
        _wait = randf_range(1.5, 4.0)
        for attempt in 8:
            var candidate: Vector2 = global_position + Vector2(randf_range(-65.0, 65.0), randf_range(-65.0, 65.0))
            if GameState.island == null or GameState.island.is_walkable(candidate):
                _target = candidate
                break
    var before: Vector2 = global_position
    var direction: Vector2 = _target - global_position
    if direction.length() > 3.0:
        global_position += direction.normalized() * (22.0 if animal_type == "deer" else 30.0) * delta
        if GameState.island != null:
            global_position = GameState.island.constrain(before, global_position)
        _sprite.flip_h = direction.x < 0.0
        _sprite.position.y = -absf(sin(_t * 8.0)) * 1.5

func claim(by: Node2D) -> bool:
    if hunter != null and is_instance_valid(hunter) and hunter != by:
        return false
    hunter = by
    return true

func release(by: Node2D) -> void:
    if hunter == by:
        hunter = null

func take_damage(amount: float, _from: Vector2 = Vector2.ZERO) -> bool:
    if hunter == null:
        return false
    hp -= amount
    if hp <= 0.0:
        var dropped := HuntingCoin.new()
        dropped.value = coin_value
        dropped.global_position = global_position
        get_parent().add_child(dropped)
        queue_free()
        return true
    return false

static func _make_texture(kind: String) -> Texture2D:
    var w: int = 24 if kind == "deer" else 16
    var h: int = 20 if kind == "deer" else 14
    var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    var body := Color(0.55, 0.32, 0.16) if kind == "deer" else Color(0.62, 0.48, 0.32)
    var dark := Color(0.25, 0.16, 0.1)
    var light := Color(0.78, 0.58, 0.35)
    if kind == "deer":
        for y in range(6, 14):
            for x in range(4, 20):
                img.set_pixel(x, y, body)
        for x in [6, 16]:
            for y in range(13, 19):
                img.set_pixel(x, y, dark)
                img.set_pixel(x + 1, y, dark)
        for x in range(17, 22):
            img.set_pixel(x, 4, body)
            img.set_pixel(x, 5, body)
        for x in [18, 21]:
            img.set_pixel(x, 1, dark)
            img.set_pixel(x, 2, dark)
        img.set_pixel(20, 5, light)
    else:
        for y in range(5, 11):
            for x in range(3, 13):
                img.set_pixel(x, y, body)
        for x in [4, 10]:
            for y in range(10, 14):
                img.set_pixel(x, y, dark)
        for x in [5, 9]:
            for y in range(0, 6):
                img.set_pixel(x, y, light)
        img.set_pixel(12, 6, dark)
    return ImageTexture.create_from_image(img)
