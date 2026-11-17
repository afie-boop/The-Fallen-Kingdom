class_name EquipmentShop
extends Node2D
## Medieval weapon/tool stall automatically spawned beside a lit campfire.

var item_kind: String = "bow"
var interact_range: float = 82.0
var prompt_text: String = "Buy equipment"


func _ready() -> void:
    add_to_group("interactable")
    add_to_group("equipment_shops")
    queue_redraw()


func _cost() -> int:
    return 2 if item_kind == "bow" else 3


func _job() -> String:
    return "archer" if item_kind == "bow" else "builder"


func has_stock() -> bool:
    return int(GameState.equipment_stock.get(item_kind, 0)) > 0


func interact(player: Player) -> void:
    var stock: int = int(GameState.equipment_stock.get(item_kind, 0))
    if stock >= 4:
        GameState.notice.emit("The %s rack is full (4)." % item_kind.capitalize())
        return
    var cost: int = _cost()
    if not GameState.spend_gold(cost, player.player_id):
        GameState.notice.emit("A %s costs %d Gold Coins." % [item_kind, cost])
        return
    GameState.equipment_stock[item_kind] = stock + 1
    GameState.notice.emit("%s purchased. Stock: %d/4." % [item_kind.capitalize(), stock + 1])
    queue_redraw()


func take_tool() -> String:
    var stock: int = int(GameState.equipment_stock.get(item_kind, 0))
    if stock <= 0:
        return ""
    GameState.equipment_stock[item_kind] = stock - 1
    queue_redraw()
    return _job()


func _draw() -> void:
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
