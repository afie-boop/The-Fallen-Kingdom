class_name KingdomCastle
extends StaticBody2D
## Opening kingdom landmark. The old house visual is replaced by an unlit pixel-art campfire.
## This node temporarily retains the legacy class name because combat/save systems reference it.

signal hp_changed(hp: float, max_hp: float)
signal notice(text: String)
signal interacted
signal campfire_upgraded(lit: bool)

var hp: float = 500.0
var max_hp: float = 500.0
var spawn_point: Vector2 = Vector2.ZERO
var prompt_text: String = "Extinguished campfire"
var interact_range: float = 90.0
var _sprite: Sprite2D
var _warn_cd: float = 0.0
var campfire_lit: bool = false
var payment_visible: bool = false
var payment_cost: int = 0
var payment_paid: int = 0
var _payment_timeout: float = 0.0
const COIN_SCENE: PackedScene = preload("res://scenes/coin.tscn")


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
    if _payment_timeout > 0.0:
        _payment_timeout -= delta
        if _payment_timeout <= 0.0 and payment_paid > 0:
            _drop_partial_payment()


func _drop_partial_payment() -> void:
    var coins_to_drop: int = payment_paid
    payment_paid = 0
    _payment_timeout = 0.0
    queue_redraw()
    for i in range(coins_to_drop):
        var coin := COIN_SCENE.instantiate() as CoinPickup
        get_parent().add_child(coin)
        var offset_x: float = (float(i) - float(coins_to_drop - 1) * 0.5) * 12.0
        coin.global_position = global_position + Vector2(offset_x, -43.0)
        coin.start_falling(global_position.y)
    notice.emit("%d Gold Coin(s) fell from the Campfire. Pick them up!" % coins_to_drop)


func set_payment_display(visible: bool, cost: int = 0, paid: int = 0) -> void:
    var next_cost: int = maxi(0, cost)
    var next_paid: int = clampi(paid, 0, next_cost)
    if payment_visible == visible and payment_cost == next_cost and payment_paid == next_paid:
        return
    payment_visible = visible
    payment_cost = next_cost
    payment_paid = next_paid
    queue_redraw()


## Returns -1 if payment cannot continue, 0 for partial payment, 1 when the campfire is lit.
func pay_one_coin(player: Player) -> int:
    if campfire_lit:
        return -1
    if not GameState.spend_gold(1, player.player_id):
        notice.emit("Not enough Gold Coins. Lighting the Campfire costs 3.")
        return -1
    var payment_coin := COIN_SCENE.instantiate() as CoinPickup
    get_parent().add_child(payment_coin)
    payment_coin.global_position = player.global_position + Vector2(player.facing.x * 9.0, -17.0)
    payment_coin.start_payment_animation(global_position + Vector2(0.0, -43.0))

    payment_paid += 1
    if payment_paid >= 3:
        payment_paid = 0
        _payment_timeout = 0.0
        set_lit(true)
        GameState.campfire_lit = true
        campfire_upgraded.emit(campfire_lit)
        notice.emit("Campfire lit! Bow Shop opened on the right; Hammer Shop opened on the left.")
        interacted.emit()
        return 1
    _payment_timeout = 1.0
    notice.emit("Paid %d/3 Gold Coins to light the Campfire." % payment_paid)
    queue_redraw()
    return 0


func _draw() -> void:
    if payment_visible and payment_cost > 0:
        var slot_gap: float = 15.0
        var total_width: float = float(payment_cost - 1) * slot_gap
        var start_x: float = -total_width * 0.5
        var slot_y: float = -43.0
        for i in range(payment_cost):
            var center := Vector2(start_x + float(i) * slot_gap, slot_y)
            draw_circle(center, 6.0, Color("#332719"))
            draw_circle(center, 4.8, Color("#d7dce2") if i >= payment_paid else Color("#f1c34e"))
            draw_circle(center, 2.2, Color("#fff0b5") if i < payment_paid else Color("#7b818a"))
            if i < payment_paid:
                draw_line(center + Vector2(-2.0, 0.0), center + Vector2(2.0, 0.0), Color("#9a681d"), 1.0)
        var label: String = "%d/%d" % [payment_paid, payment_cost]
        draw_string(ThemeDB.fallback_font, Vector2(-13.0, -53.0), label, HORIZONTAL_ALIGNMENT_CENTER, 26.0, 8, Color("#fff0b5"))
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


func set_lit(value: bool) -> void:
    campfire_lit = value
    _sprite.texture = _make_lit_fire_texture() if campfire_lit else _make_unlit_fire_texture()
    queue_redraw()


func _make_lit_fire_texture() -> Texture2D:
    var img := Image.create(48, 32, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    _fill_pixels(img, 9, 17, 30, 5, Color("#493329"))
    _fill_pixels(img, 13, 14, 22, 4, Color("#76513a"))
    _fill_pixels(img, 16, 16, 16, 3, Color("#29272a"))
    _fill_pixels(img, 18, 8, 12, 9, Color("#e36b27"))
    _fill_pixels(img, 21, 3, 7, 9, Color("#ffb83f"))
    _fill_pixels(img, 23, 7, 3, 8, Color("#fff0a0"))
    _fill_pixels(img, 6, 14, 6, 6, Color("#68645c"))
    _fill_pixels(img, 36, 14, 6, 6, Color("#68645c"))
    return ImageTexture.create_from_image(img)


func interact(_player: Player) -> void:
    if campfire_lit:
        notice.emit("The campfire is already lit. Bow Shop and Hammer Shop are open.")
    else:
        notice.emit("Hold USE / E to pay 3 Gold Coins and light the Campfire.")
    interacted.emit()
