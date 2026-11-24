extends Node2D
class_name ModernBuilding

var building_type: String = "house"
var building_name: String = "Rumah"
var door_side: String = "south"

var door_position: Vector2:
    get:
        return global_position + (Vector2(0, 68) if door_side == "south" else Vector2(0, -68))

func _ready() -> void:
    z_index = 2
    _add_collision()
    queue_redraw()

func _add_collision() -> void:
    var body := StaticBody2D.new()
    body.collision_layer = 1
    body.collision_mask = 0
    add_child(body)
    _add_wall(body, Vector2(0, -54), Vector2(142, 12))
    _add_wall(body, Vector2(-70, 0), Vector2(12, 96))
    _add_wall(body, Vector2(70, 0), Vector2(12, 96))
    if door_side == "south":
        _add_wall(body, Vector2(-43, 48), Vector2(54, 12))
        _add_wall(body, Vector2(43, 48), Vector2(54, 12))
    else:
        _add_wall(body, Vector2(-43, -48), Vector2(54, 12))
        _add_wall(body, Vector2(43, -48), Vector2(54, 12))

func _add_wall(parent: StaticBody2D, at: Vector2, dimensions: Vector2) -> void:
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = dimensions
    collision.shape = shape
    collision.position = at
    parent.add_child(collision)

func _draw() -> void:
    # Drop shadow and concrete foundation.
    draw_rect(Rect2(-82, -56, 164, 128), Color(0.08, 0.10, 0.12, 0.22))
    draw_rect(Rect2(-76, -62, 152, 120), Color("#aeb8bd"))
    draw_rect(Rect2(-70, -56, 140, 108), Color("#e1e5e6"))
    var roof := Color("#536875")
    var wall := Color("#d9dfe1")
    var trim := Color("#344b59")
    match building_type:
        "cafe":
            roof = Color("#8c5542")
            wall = Color("#f0d8b8")
            trim = Color("#653b32")
        "market":
            roof = Color("#3d7a72")
            wall = Color("#d9e6d6")
            trim = Color("#24534e")
        "apartment":
            roof = Color("#647b91")
            wall = Color("#cbd6df")
            trim = Color("#354b60")
        "clinic":
            roof = Color("#6d9a9c")
            wall = Color("#eef1ed")
            trim = Color("#477477")
        "office":
            roof = Color("#425c78")
            wall = Color("#b9cbd4")
            trim = Color("#263d55")
    # Roof slab and front facade give the buildings a clean modern silhouette.
    draw_rect(Rect2(-72, -62, 144, 76), roof)
    draw_rect(Rect2(-72, 8, 144, 44), wall)
    draw_rect(Rect2(-72, 8, 144, 7), trim)
    draw_rect(Rect2(-72, 49, 144, 4), trim)
    # Roof panels / rooftop details.
    draw_rect(Rect2(-61, -51, 122, 53), roof.lightened(0.12))
    draw_rect(Rect2(-56, -46, 42, 42), roof.darkened(0.12))
    draw_rect(Rect2(12, -46, 42, 42), roof.darkened(0.12))
    # Windows and entrance.
    for x in [-48.0, 0.0, 48.0]:
        draw_rect(Rect2(x - 13, 18, 26, 23), trim)
        draw_rect(Rect2(x - 10, 21, 20, 17), Color("#a8d7e6"))
        draw_line(Vector2(x, 21), Vector2(x, 38), Color("#e9f4f5"), 2.0)
    draw_rect(Rect2(-14, 15, 28, 38), Color("#263b49"))
    draw_rect(Rect2(-10, 19, 20, 30), Color("#9cc6d0"))
    draw_rect(Rect2(-3, 32, 3, 3), Color("#f3d27a"))
    if door_side == "north":
        draw_rect(Rect2(-19, -62, 38, 8), Color("#e5e9e9"))
    # Signboard.
    draw_rect(Rect2(-48, -78, 96, 14), trim)
    draw_string(ThemeDB.fallback_font, Vector2(0, -67), building_name.to_upper(),
        HORIZONTAL_ALIGNMENT_CENTER, 92, 9, Color.WHITE)
    # Pavement at the entrance.
    if door_side == "south":
        draw_rect(Rect2(-25, 58, 50, 16), Color("#b9c0c2"))
    else:
        draw_rect(Rect2(-25, -78, 50, 16), Color("#b9c0c2"))
