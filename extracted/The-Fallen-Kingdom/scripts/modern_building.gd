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
    # Buildings are drawn on a four-pixel grid so the rooftops match the game's
    # hand-made pixel sprites instead of looking like smooth vector boxes.
    var w := floorf(footprint.x / 4.0) * 4.0
    var h := floorf(footprint.y / 4.0) * 4.0
    var half_w := w * 0.5
    var half_h := h * 0.5
    var roof := Color("#596f7c")
    var edge := Color("#26343c")
    var light := Color("#a8c4ca")
    var mid := Color("#78949a")
    match building_style:
        "glass_tower":
            roof = Color("#476b7b")
            edge = Color("#203b4b")
            light = Color("#b1d9df")
            mid = Color("#6f9eae")
        "art_deco":
            roof = Color("#918a7c")
            edge = Color("#49443e")
            light = Color("#d2c19a")
            mid = Color("#b0a184")
        "brick_apartment":
            roof = Color("#874d43")
            edge = Color("#432d2b")
            light = Color("#d7a18a")
            mid = Color("#a96b59")
        "brownstone":
            roof = Color("#99634c")
            edge = Color("#4b332b")
            light = Color("#dfb48b")
            mid = Color("#bd8161")
        "store":
            roof = Color("#477d78")
            edge = Color("#244b4b")
            light = Color("#c4dfcf")
            mid = Color("#78aaa0")
        "modern":
            roof = Color("#aabfc0")
            edge = Color("#50636a")
            light = Color("#e1eeee")
            mid = Color("#819da2")

    # Sidewalk pad, hard pixel shadow, dark outline and rooftop surface.
    draw_rect(Rect2(-half_w - 8, -half_h - 4, w + 16, h + 16), Color("#777b78"))
    draw_rect(Rect2(-half_w - 4, -half_h - 4, w + 8, h + 8), Color(0.035, 0.045, 0.05, 0.42))
    draw_rect(Rect2(-half_w, -half_h, w, h), edge)
    draw_rect(Rect2(-half_w + 4, -half_h + 4, w - 8, h - 8), roof)
    draw_rect(Rect2(-half_w + 8, -half_h + 8, w - 16, 4), light.darkened(0.18))
    draw_rect(Rect2(-half_w + 8, half_h - 12, w - 16, 4), edge)

    # Small roof panels and vents use hard-edged 4/8-pixel blocks.
    for x in range(int(-half_w + 16), int(half_w - 12), 16):
        for y in range(int(-half_h + 20), int(half_h - 16), 20):
            draw_rect(Rect2(float(x), float(y), 8, 8), mid.darkened(0.28))
            draw_rect(Rect2(float(x) + 4, float(y) + 4, 4, 4), mid.lightened(0.18))

    if building_style == "glass_tower":
        # Blue rooftop core and bright window/roof strips.
        draw_rect(Rect2(-w * 0.22, -h * 0.26, w * 0.44, h * 0.52), edge)
        draw_rect(Rect2(-w * 0.22 + 4, -h * 0.26 + 4, w * 0.44 - 8, h * 0.52 - 8), mid)
        for x in [-w * 0.14, -w * 0.02, w * 0.10]:
            draw_rect(Rect2(x, -h * 0.22, 4, h * 0.44), light)
        draw_rect(Rect2(-8, -8, 16, 16), Color("#dce9df"))
        draw_rect(Rect2(-4, -4, 8, 8), Color("#456f80"))
        draw_rect(Rect2(-4, -h * 0.42, 8, 12), edge)
    elif building_style == "art_deco":
        # Stepped crown and a central spire, inspired by the Chrysler/Empire skyline.
        draw_rect(Rect2(-w * 0.34, -h * 0.30, w * 0.68, h * 0.60), mid)
        draw_rect(Rect2(-w * 0.26, -h * 0.38, w * 0.52, h * 0.16), light)
        draw_rect(Rect2(-w * 0.18, -h * 0.46, w * 0.36, h * 0.12), roof.darkened(0.12))
        draw_rect(Rect2(-8, -h * 0.50, 16, h * 0.18), edge)
        draw_rect(Rect2(-4, -h * 0.56, 8, 12), light)
        for x in [-w * 0.22, -w * 0.10, w * 0.10, w * 0.22]:
            draw_rect(Rect2(x, -h * 0.22, 4, h * 0.42), light.darkened(0.12))
    elif building_style == "brick_apartment":
        # Dense red roof, water tank, chimney and small rooftop access.
        draw_rect(Rect2(-w * 0.30, -h * 0.30, w * 0.60, h * 0.58), roof.darkened(0.12))
        draw_rect(Rect2(-w * 0.24, -h * 0.24, w * 0.48, 4), light.darkened(0.25))
        draw_rect(Rect2(-w * 0.20, h * 0.10, 24, 20), edge)
        draw_rect(Rect2(-w * 0.20 + 4, h * 0.10 + 4, 16, 12), mid)
        draw_rect(Rect2(w * 0.20, -h * 0.30, 12, 12), Color("#59433b"))
        draw_rect(Rect2(w * 0.20 + 4, -h * 0.30 - 4, 4, 4), light)
    elif building_style == "brownstone":
        # Narrow row-house roof with rear fire-escape landing and skylights.
        draw_rect(Rect2(-w * 0.34, -h * 0.34, w * 0.68, h * 0.68), roof.darkened(0.08))
        for y in [-h * 0.22, -h * 0.02, h * 0.18]:
            draw_rect(Rect2(-w * 0.26, y, w * 0.52, 4), edge)
        draw_rect(Rect2(-w * 0.12, -h * 0.24, 20, 16), light.darkened(0.2))
        draw_rect(Rect2(w * 0.12, -h * 0.24, 20, 16), light.darkened(0.2))
        draw_rect(Rect2(-8, h * 0.18, 16, 20), mid)
        draw_rect(Rect2(-4, h * 0.18 + 4, 8, 12), edge)
    elif building_style == "store":
        # Flat commercial roof and striped awning at the street-facing edge.
        draw_rect(Rect2(-w * 0.40, -h * 0.28, w * 0.80, h * 0.56), mid)
        draw_rect(Rect2(-w * 0.36, -h * 0.24, w * 0.72, h * 0.48), roof)
        for x in range(int(-w * 0.32), int(w * 0.32), 16):
            draw_rect(Rect2(float(x), h * 0.22, 8, 8), light)
            draw_rect(Rect2(float(x) + 8, h * 0.22, 8, 8), Color("#d96c50"))
        draw_rect(Rect2(-w * 0.12, -h * 0.12, w * 0.24, 20), edge)
    else:
        # Modern office roof with chunky HVAC units and skylights.
        for p in [
            Vector2(-w * 0.28, -h * 0.26), Vector2(w * 0.12, -h * 0.26),
            Vector2(-w * 0.28, h * 0.14), Vector2(w * 0.12, h * 0.14)
        ]:
            draw_rect(Rect2(p, Vector2(28, 24)), edge)
            draw_rect(Rect2(p + Vector2(4, 4), Vector2(20, 12)), light)
            draw_rect(Rect2(p + Vector2(8, 16), Vector2(12, 4)), mid)

    # A clear entrance notch and pixel-stepped doorway face south.
    draw_rect(Rect2(-28, half_h - 4, 56, 12), Color("#b8b4a7"))
    draw_rect(Rect2(-20, half_h - 8, 40, 8), edge)
    draw_rect(Rect2(-12, half_h - 8, 24, 4), light)
    if building_name not in ["OFFICE", "APARTMENTS", "DELI", "CAFE"]:
        draw_string(ThemeDB.fallback_font, Vector2(0, -half_h - 10), building_name.to_upper(),
            HORIZONTAL_ALIGNMENT_CENTER, w + 32, 9, Color("#f5f0df"))
