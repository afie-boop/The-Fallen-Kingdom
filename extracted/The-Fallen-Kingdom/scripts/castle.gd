class_name KingdomCastle
extends StaticBody2D
## Opening kingdom landmark. The old house visual is replaced by an unlit pixel-art campfire.
## This node temporarily retains the legacy class name because combat/save systems reference it.

signal hp_changed(hp: float, max_hp: float)
signal notice(text: String)
signal interacted

var hp: float = 500.0
var max_hp: float = 500.0
var spawn_point: Vector2 = Vector2.ZERO
var prompt_text: String = "Extinguished campfire"
var interact_range: float = 90.0
var _sprite: Sprite2D
var _warn_cd: float = 0.0


func _ready() -> void:
    collision_layer = 1
    collision_mask = 0
    add_to_group("interactable")
    add_to_group("castle")
    add_to_group("repairable")
    max_hp = GameConfig.castle_max_hp
    hp = max_hp
    _sprite = Sprite2D.new()
    _sprite.texture = _make_unlit_fire_texture()
    _sprite.centered = true
    _sprite.position = Vector2(0, -3)
    add_child(_sprite)
    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 17.0
    shape.shape = circle
    shape.position = Vector2(0, -2)
    add_child(shape)
    spawn_point = global_position + Vector2(0, 30)


func _make_unlit_fire_texture() -> Texture2D:
    var img := Image.create(48, 32, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    _fill_pixels(img, 9, 17, 30, 5, Color("#493329"))
    _fill_pixels(img, 13, 14, 22, 4, Color("#76513a"))
    _fill_pixels(img, 16, 16, 16, 3, Color("#29272a"))
    _fill_pixels(img, 18, 13, 12, 4, Color("#77716a"))
    _fill_pixels(img, 6, 14, 6, 6, Color("#68645c"))
    _fill_pixels(img, 36, 14, 6, 6, Color("#68645c"))
    _fill_pixels(img, 12, 23, 5, 3, Color("#77716a"))
    _fill_pixels(img, 31, 23, 5, 3, Color("#77716a"))
    _fill_pixels(img, 21, 18, 6, 3, Color("#a39b8d"))
    return ImageTexture.create_from_image(img)


func _fill_pixels(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
    for py in range(y, y + h):
        for px in range(x, x + w):
            img.set_pixel(px, py, color)


func _process(delta: float) -> void:
    _warn_cd = maxf(0.0, _warn_cd - delta)


func _draw() -> void:
    if hp < max_hp:
        var w: float = 48.0
        var bar_y: float = -28.0
        draw_rect(Rect2(-w / 2.0, bar_y, w, 5.0), Color(0, 0, 0, 0.6))
        draw_rect(Rect2(-w / 2.0 + 1.0, bar_y + 1.0, (w - 2.0) * hp / max_hp, 3.0), Color(0.3, 0.8, 0.35))


func take_damage(amount: float) -> void:
    hp = maxf(1.0, hp - amount)
    hp_changed.emit(hp, max_hp)
    queue_redraw()
    if _warn_cd <= 0.0:
        _warn_cd = 12.0
        notice.emit("The campfire area is under attack!")


func needs_repair() -> bool:
    return hp < max_hp - 0.01


func repair(amount: float) -> void:
    hp = minf(max_hp, hp + amount)
    hp_changed.emit(hp, max_hp)
    queue_redraw()


func restore() -> void:
    hp = max_hp
    hp_changed.emit(hp, max_hp)
    queue_redraw()


func set_hp(value: float) -> void:
    hp = clampf(value, 1.0, max_hp)
    queue_redraw()


func interact(_player: Player) -> void:
    notice.emit("The campfire is extinguished. Build the two workstations to light it.")
    interacted.emit()
