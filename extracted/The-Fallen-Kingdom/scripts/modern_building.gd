extends Node2D
class_name ModernBuilding

var building_type: String = "office"
var building_name: String = "CITY BUILDING"
var building_style: String = "glass_tower"
var door_side: String = "south"
var footprint: Vector2 = Vector2(205.0, 225.0)

var door_position: Vector2:
    get:
        return global_position + Vector2(0, footprint.y * 0.5 + 8.0)

func _ready() -> void:
    z_index = 2
    _add_collision()
    queue_redraw()

func _add_collision() -> void:
    var body := StaticBody2D.new()
    body.collision_layer = 1
    body.collision_mask = 0
    add_child(body)
    var half_w := footprint.x * 0.5
    var half_h := footprint.y * 0.5
    var wall := 14.0
    _add_wall(body, Vector2(0, -half_h + wall * 0.5), Vector2(footprint.x, wall))
    _add_wall(body, Vector2(-half_w + wall * 0.5, 0), Vector2(wall, footprint.y - wall))
    _add_wall(body, Vector2(half_w - wall * 0.5, 0), Vector2(wall, footprint.y - wall))
    if door_side == "south":
        var segment := (footprint.x - 52.0) * 0.5
        _add_wall(body, Vector2(-half_w + segment * 0.5, half_h - wall * 0.5), Vector2(segment, wall))
        _add_wall(body, Vector2(half_w - segment * 0.5, half_h - wall * 0.5), Vector2(segment, wall))
    else:
        var segment := (footprint.x - 52.0) * 0.5
        _add_wall(body, Vector2(-half_w + segment * 0.5, -half_h + wall * 0.5), Vector2(segment, wall))
        _add_wall(body, Vector2(half_w - segment * 0.5, -half_h + wall * 0.5), Vector2(segment, wall))

func _add_wall(parent: StaticBody2D, at: Vector2, dimensions: Vector2) -> void:
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = dimensions
    collision.shape = shape
    collision.position = at
    parent.add_child(collision)

func _draw() -> void:
    var w := footprint.x
    var h := footprint.y
    var half_w := w * 0.5
    var half_h := h * 0.5
    var roof := Color("#536a78")
    var edge := Color("#293943")
    var detail := Color("#9ab8c2")
    match building_style:
        "glass_tower":
            roof = Color("#536d7c")
            edge = Color("#263b4b")
            detail = Color("#a9d5df")
        "art_deco":
            roof = Color("#8b877f")
            edge = Color("#49413a")
            detail = Color("#c8b99a")
        "brick_apartment":
            roof = Color("#8b5145")
            edge = Color("#4c302d")
            detail = Color("#d7a28a")
        "brownstone":
            roof = Color("#9b604b")
            edge = Color("#50372f")
            detail = Color("#d5a77f")
        "store":
            roof = Color("#497d78")
            edge = Color("#294e50")
            detail = Color("#b7d8d2")
        "modern":
            roof = Color("#b8c7ca")
            edge = Color("#536b75")
            detail = Color("#d9edf0")

    # Deep shadow, pavement, exterior wall and roof slab.
    draw_rect(Rect2(-half_w - 12, -half_h - 8, w + 24, h + 24), Color(0.04, 0.06, 0.08, 0.30))
    draw_rect(Rect2(-half_w - 7, -half_h - 6, w + 14, h + 14), Color("#a7aaa7"))
    draw_rect(Rect2(-half_w, -half_h, w, h), edge)
    draw_rect(Rect2(-half_w + 8, -half_h + 8, w - 16, h - 16), roof)
    draw_rect(Rect2(-half_w + 14, -half_h + 14, w - 28, h - 28), roof.lightened(0.10))

    # Rooftop grid and equipment distinguish skyscrapers from small houses.
    for x in range(-int(half_w) + 24, int(half_w) - 12, 28):
        draw_line(Vector2(float(x), -half_h + 18), Vector2(float(x), half_h - 18), detail.darkened(0.12), 2.0)
    for y in range(-int(half_h) + 24, int(half_h) - 12, 30):
        draw_line(Vector2(-half_w + 18, float(y)), Vector2(half_w - 18, float(y)), detail.darkened(0.12), 2.0)

    if building_style == "glass_tower":
        draw_rect(Rect2(-w * 0.22, -h * 0.25, w * 0.44, h * 0.50), Color("#294b60"))
        draw_rect(Rect2(-w * 0.18, -h * 0.21, w * 0.36, h * 0.42), Color("#80b5c6"))
        draw_line(Vector2(0, -h * 0.21), Vector2(0, h * 0.21), Color("#d6edf2"), 3.0)
        draw_line(Vector2(-w * 0.18, 0), Vector2(w * 0.18, 0), Color("#d6edf2"), 3.0)
        # Rooftop helipad marking.
        draw_arc(Vector2(0, 0), minf(w, h) * 0.18, 0.0, TAU, 32, Color("#e2e8e8"), 2.0)
        draw_string(ThemeDB.fallback_font, Vector2(-8, 5), "H", HORIZONTAL_ALIGNMENT_CENTER, 16, 16, Color.WHITE)
    elif building_style == "art_deco":
        draw_rect(Rect2(-w * 0.30, -h * 0.30, w * 0.60, h * 0.60), roof.darkened(0.16))
        draw_rect(Rect2(-w * 0.24, -h * 0.24, w * 0.48, h * 0.48), detail.darkened(0.25))
        draw_rect(Rect2(-w * 0.10, -h * 0.43, w * 0.20, h * 0.18), Color("#c9b58c"))
        draw_line(Vector2(-w * 0.34, -h * 0.34), Vector2(w * 0.34, h * 0.34), detail, 3.0)
        draw_line(Vector2(w * 0.34, -h * 0.34), Vector2(-w * 0.34, h * 0.34), detail, 3.0)
    elif building_style == "brick_apartment" or building_style == "brownstone":
        for row in range(4):
            for col in range(3):
                var p := Vector2(-w * 0.28 + float(col) * w * 0.28, -h * 0.30 + float(row) * h * 0.20)
                draw_rect(Rect2(p, Vector2(24, 16)), Color("#3c4548"))
                draw_rect(Rect2(p + Vector2(3, 3), Vector2(18, 10)), detail)
        draw_rect(Rect2(-w * 0.18, h * 0.23, w * 0.36, h * 0.12), edge)
        draw_rect(Rect2(-w * 0.13, h * 0.26, w * 0.26, h * 0.06), Color("#b7a18b"))
    elif building_style == "store":
        draw_rect(Rect2(-w * 0.38, -h * 0.22, w * 0.76, h * 0.42), roof.darkened(0.20))
        draw_rect(Rect2(-w * 0.32, -h * 0.16, w * 0.64, h * 0.30), detail)
        for x in [-w * 0.20, 0.0, w * 0.20]:
            draw_rect(Rect2(x - 13, h * 0.22, 26, 20), Color("#f4d17a"))
    else:
        # HVAC units, skylights and rooftop service structures.
        for p in [Vector2(-w * 0.28, -h * 0.26), Vector2(w * 0.12, -h * 0.26), Vector2(-w * 0.28, h * 0.14), Vector2(w * 0.12, h * 0.14)]:
            draw_rect(Rect2(p, Vector2(38, 30)), Color("#45545a"))
            draw_rect(Rect2(p + Vector2(5, 5), Vector2(28, 20)), Color("#a9b9bc"))

    # Entrance apron and a clear south-facing door.
    draw_rect(Rect2(-30, half_h - 2, 60, 18), Color("#c3c2b8"))
    draw_rect(Rect2(-20, half_h - 5, 40, 9), Color("#293c46"))
    draw_rect(Rect2(-half_w + 8, -half_h + 8, w - 16, 5), detail.lightened(0.15))
    draw_string(ThemeDB.fallback_font, Vector2(0, -half_h - 12), building_name.to_upper(),
        HORIZONTAL_ALIGNMENT_CENTER, w + 30, 11, Color("#f5f3e9"))
