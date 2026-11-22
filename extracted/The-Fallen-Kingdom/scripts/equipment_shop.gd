class_name EquipmentShop
extends Node2D
## Medieval weapon/tool stall automatically spawned beside a lit campfire.

var item_kind: String = "bow"
var interact_range: float = 82.0
var prompt_text: String = "Hold USE / E to pay"
const MAX_STOCK: int = 4
var payment_visible: bool = false
var payment_cost: int = 0
var payment_paid: int = 0
var _payment_timeout: float = 0.0
var animate_on_spawn: bool = true
const COIN_SCENE: PackedScene = preload("res://scenes/coin.tscn")


func _ready() -> void:
    add_to_group("interactable")
    add_to_group("equipment_shops")
    _update_prompt()
    if animate_on_spawn:
        _play_appearance_animation()
    queue_redraw()


func _play_appearance_animation() -> void:
    var final_position: Vector2 = position
    modulate = Color(1.0, 1.0, 1.0, 0.0)
    scale = Vector2(0.72, 0.72)
    position = final_position + Vector2(0.0, 13.0)

    var tween := create_tween().set_parallel(true)
    tween.tween_property(self, "modulate:a", 1.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "scale", Vector2.ONE, 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "position", final_position, 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
    if _payment_timeout > 0.0:
        _payment_timeout -= delta
        if _payment_timeout <= 0.0 and payment_paid > 0:
            _drop_partial_payment()


func _drop_partial_payment() -> void:
    var coins_to_drop: int = payment_paid
    payment_paid = 0
    _payment_timeout = 0.0
    _update_prompt()
    queue_redraw()
    for i in range(coins_to_drop):
        var coin := COIN_SCENE.instantiate() as CoinPickup
        get_parent().add_child(coin)
        var offset_x: float = (float(i) - float(coins_to_drop - 1) * 0.5) * 12.0
        coin.global_position = global_position + Vector2(offset_x, -72.0)
        coin.start_falling(global_position.y)
    GameState.notice.emit("%d Gold Coin(s) fell from the %s rack. Pick them up!" % [coins_to_drop, item_kind])


func set_payment_display(visible: bool, cost: int = 0, paid: int = 0) -> void:
    var next_cost: int = maxi(0, cost)
    var next_paid: int = clampi(paid, 0, next_cost)
    if payment_visible == visible and payment_cost == next_cost and payment_paid == next_paid:
        return
    payment_visible = visible
    payment_cost = next_cost
    payment_paid = next_paid
    queue_redraw()


func _cost() -> int:
    return 2 if item_kind == "bow" else 3


func _job() -> String:
    return "archer" if item_kind == "bow" else "builder"


func has_stock() -> bool:
    return int(GameState.equipment_stock.get(item_kind, 0)) > 0


func _update_prompt() -> void:
    var stock: int = int(GameState.equipment_stock.get(item_kind, 0))
    var paid: int = payment_paid
    if stock >= MAX_STOCK:
        prompt_text = "Rack full (%d/%d)" % [stock, MAX_STOCK]
    else:
        prompt_text = "Hold USE / E to pay %d coins (%d/%d)" % [_cost(), paid, _cost()]


## Returns -1 if payment cannot continue, 0 for a partial payment, 1 when one item is bought.
func pay_one_coin(player: Player) -> int:
    var stock: int = int(GameState.equipment_stock.get(item_kind, 0))
    if stock >= MAX_STOCK:
        _update_prompt()
        GameState.notice.emit("The %s rack is full (%d)." % [item_kind.capitalize(), MAX_STOCK])
        return -1

    var paid: int = payment_paid
    if not GameState.spend_gold(1, player.player_id):
        _update_prompt()
        GameState.notice.emit("Not enough Gold Coins. %s costs %d." % [item_kind.capitalize(), _cost()])
        return -1

    var payment_coin := COIN_SCENE.instantiate() as CoinPickup
    get_parent().add_child(payment_coin)
    payment_coin.global_position = player.global_position + Vector2(player.facing.x * 9.0, -17.0)
    var slot_x: float = (float(paid) - float(_cost() - 1) * 0.5) * 15.0
    payment_coin.start_payment_animation(global_position + Vector2(slot_x, -72.0))

    paid += 1
    if paid >= _cost():
        payment_paid = 0
        _payment_timeout = 0.0
        GameState.equipment_stock[item_kind] = stock + 1
        GameState.notice.emit("%s purchased. Stock: %d/%d." % [item_kind.capitalize(), stock + 1, MAX_STOCK])
        _update_prompt()
        queue_redraw()
        return 1

    payment_paid = paid
    _payment_timeout = 1.0
    GameState.notice.emit("Paid %d/%d Gold Coins for %s." % [paid, _cost(), item_kind])
    _update_prompt()
    queue_redraw()
    return 0


func take_tool() -> String:
    var stock: int = int(GameState.equipment_stock.get(item_kind, 0))
    if stock <= 0:
        return ""
    GameState.equipment_stock[item_kind] = stock - 1
    _update_prompt()
    queue_redraw()
    return _job()


func _draw() -> void:
    if payment_visible and payment_cost > 0:
        # Payment slots float above the stall being paid for, not above the player.
        var slot_gap: float = 15.0
        var total_width: float = float(payment_cost - 1) * slot_gap
        var start_x: float = -total_width * 0.5
        var slot_y: float = -72.0
        for i in range(payment_cost):
            var center := Vector2(start_x + float(i) * slot_gap, slot_y)
            draw_circle(center, 6.0, Color("#332719"))
            draw_circle(center, 4.8, Color("#d7dce2") if i >= payment_paid else Color("#f1c34e"))
            draw_circle(center, 2.2, Color("#fff0b5") if i < payment_paid else Color("#7b818a"))
            if i < payment_paid:
                draw_line(center + Vector2(-2.0, 0.0), center + Vector2(2.0, 0.0), Color("#9a681d"), 1.0)
        var label: String = "%d/%d" % [payment_paid, payment_cost]
        draw_string(ThemeDB.fallback_font, Vector2(-13.0, -82.0), label, HORIZONTAL_ALIGNMENT_CENTER, 26.0, 8, Color("#fff0b5"))

    var wood := Color("#76502f")
    var wood_light := Color("#a97843")
    var wood_dark := Color("#3d291d")
    var iron := Color("#9b9da5")
    var cloth_red := Color("#78352c")
    var cloth_light := Color("#c2a477")
    var parchment := Color("#ead7ae")

    # Ground shadow and sturdy timber stall frame.
    draw_colored_polygon(PackedVector2Array([Vector2(-34.0, -1.0), Vector2(-27.0, -5.0), Vector2(-15.0, -7.0), Vector2(0.0, -8.0), Vector2(15.0, -7.0), Vector2(27.0, -5.0), Vector2(34.0, -1.0), Vector2(27.0, 2.0), Vector2(15.0, 4.0), Vector2(0.0, 5.0), Vector2(-15.0, 4.0), Vector2(-27.0, 2.0)]), Color(0.0, 0.0, 0.0, 0.24))
    draw_rect(Rect2(-29.0, -43.0, 4.0, 43.0), wood_dark)
    draw_rect(Rect2(25.0, -43.0, 4.0, 43.0), wood_dark)
    draw_rect(Rect2(-27.0, -42.0, 2.0, 39.0), wood_light)
    draw_rect(Rect2(25.0, -42.0, 2.0, 39.0), wood_light)

    # Medieval striped canvas awning with a dark wooden ridge.
    draw_colored_polygon(PackedVector2Array([
        Vector2(-34.0, -45.0), Vector2(34.0, -45.0),
        Vector2(28.0, -30.0), Vector2(-28.0, -30.0)
    ]), cloth_red)
    draw_colored_polygon(PackedVector2Array([
        Vector2(-22.0, -45.0), Vector2(-10.0, -45.0),
        Vector2(-8.0, -30.0), Vector2(-18.0, -30.0)
    ]), cloth_light)
    draw_colored_polygon(PackedVector2Array([
        Vector2(2.0, -45.0), Vector2(14.0, -45.0),
        Vector2(16.0, -30.0), Vector2(4.0, -30.0)
    ]), cloth_light)
    draw_line(Vector2(-35.0, -45.0), Vector2(35.0, -45.0), wood_dark, 3.0)
    draw_line(Vector2(-28.0, -30.0), Vector2(28.0, -30.0), wood_dark, 2.0)

    # Small hanging shop sign.
    draw_rect(Rect2(-16.0, -55.0, 32.0, 8.0), wood_dark)
    draw_rect(Rect2(-14.0, -54.0, 28.0, 5.0), wood)
    var sign_text: String = "BOWS" if item_kind == "bow" else "TOOLS"
    draw_string(ThemeDB.fallback_font, Vector2(-12.0, -50.0), sign_text, HORIZONTAL_ALIGNMENT_LEFT, 26.0, 7, parchment)

    # Display shelf and counter, built from layered planks.
    draw_rect(Rect2(-29.0, -19.0, 58.0, 5.0), wood_dark)
    draw_rect(Rect2(-28.0, -19.0, 56.0, 2.0), wood_light)
    draw_rect(Rect2(-27.0, -14.0, 54.0, 5.0), wood)
    draw_line(Vector2(-26.0, -11.0), Vector2(26.0, -11.0), wood_dark, 1.0)
    draw_rect(Rect2(-23.0, -9.0, 4.0, 9.0), wood_dark)
    draw_rect(Rect2(19.0, -9.0, 4.0, 9.0), wood_dark)
    draw_rect(Rect2(-25.0, -2.0, 50.0, 2.0), wood_light)

    # Iron corner brackets and nail heads make the stall feel hand-built.
    for x in [-25.0, 23.0]:
        draw_rect(Rect2(x, -18.0, 2.0, 4.0), iron)
        draw_circle(Vector2(x + 1.0, -16.0), 0.8, wood_dark)
    draw_rect(Rect2(-30.0, -44.0, 5.0, 2.0), wood_dark)
    draw_rect(Rect2(25.0, -44.0, 5.0, 2.0), wood_dark)

    # Display the actual stock as individual pixel-art equipment.
    var stock: int = int(GameState.equipment_stock.get(item_kind, 0))
    for i in range(stock):
        var x: float = -16.0 + float(i) * 10.0
        if item_kind == "bow":
            draw_arc(Vector2(x, -25.0), 5.0, -1.25, 1.25, 8, Color("#d2a45e"), 2.0)
            draw_line(Vector2(x + 1.6, -29.7), Vector2(x + 1.6, -20.3), parchment, 1.0)
            draw_line(Vector2(x + 1.6, -29.7), Vector2(x + 3.5, -32.0), wood_light, 1.0)
            draw_line(Vector2(x + 1.6, -20.3), Vector2(x + 3.5, -18.0), wood_light, 1.0)
        else:
            draw_line(Vector2(x, -31.0), Vector2(x, -19.0), wood_light, 3.0)
            draw_line(Vector2(x, -31.0), Vector2(x, -19.0), wood_dark, 1.0)
            draw_rect(Rect2(x - 4.0, -32.0, 8.0, 4.0), iron)
            draw_rect(Rect2(x - 3.0, -33.0, 6.0, 1.0), Color("#d5d8df"))
            draw_rect(Rect2(x - 1.0, -28.0, 2.0, 2.0), wood_dark)

    # Quiver of arrows for archers, or a small tool bundle for builders.
    if item_kind == "bow":
        draw_rect(Rect2(20.0, -29.0, 6.0, 10.0), wood_dark)
        draw_rect(Rect2(21.0, -28.0, 4.0, 8.0), wood)
        for ax in [22.0, 24.0]:
            draw_line(Vector2(ax, -28.0), Vector2(ax, -35.0), wood_light, 1.0)
            draw_line(Vector2(ax, -35.0), Vector2(ax - 1.0, -33.0), iron, 1.0)
    else:
        draw_rect(Rect2(19.0, -29.0, 7.0, 8.0), wood_dark)
        draw_line(Vector2(20.0, -28.0), Vector2(25.0, -22.0), Color("#c49a62"), 1.0)
        draw_line(Vector2(25.0, -28.0), Vector2(20.0, -22.0), Color("#c49a62"), 1.0)

    # Stock marker on the front of the counter.
    draw_rect(Rect2(-8.0, -8.0, 16.0, 5.0), wood_dark)
    draw_rect(Rect2(-7.0, -7.0, 14.0, 3.0), Color("#59402a"))
    var stock_text: String = "%d/4" % stock
    draw_string(ThemeDB.fallback_font, Vector2(-6.0, -5.0), stock_text, HORIZONTAL_ALIGNMENT_LEFT, 14.0, 6, parchment)
