class_name EquipmentShop
extends Node2D
## Automatically spawned tool vendor beside a lit campfire.

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
    var dark := Color("#3d291d")
    draw_rect(Rect2(-25, -19, 50, 5), dark)
    draw_rect(Rect2(-23, -17, 46, 3), wood)
    draw_rect(Rect2(-23, -14, 3, 22), dark)
    draw_rect(Rect2(20, -14, 3, 22), dark)
    draw_rect(Rect2(-24, 5, 48, 4), wood)
    var stock: int = int(GameState.equipment_stock.get(item_kind, 0))
    for i in range(stock):
        var x: float = -15.0 + float(i) * 10.0
        if item_kind == "bow":
            draw_arc(Vector2(x, -4), 5.0, -1.25, 1.25, 8, Color("#c99a55"), 2.0)
            draw_line(Vector2(x, -9), Vector2(x, 1), Color("#d8d1bd"), 1.0)
        else:
            draw_line(Vector2(x, -11), Vector2(x, 2), Color("#9b9da5"), 2.0)
            draw_rect(Rect2(x - 4, -12, 8, 3), Color("#8b929e"))
    draw_string(ThemeDB.fallback_font, Vector2(-24, -24), "BOW" if item_kind == "bow" else "HAMMER", HORIZONTAL_ALIGNMENT_LEFT, 52, 9, Color("#f0dfbd"))
