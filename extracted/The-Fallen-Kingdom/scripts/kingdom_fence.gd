class_name KingdomFence
extends Node2D
## One continuous perimeter around the kingdom. Expanding the territory moves
## the entire boundary outward; all fence sections are joined and collidable.

const HORIZONTAL_LENGTH: float = 64.0
const VERTICAL_LENGTH: float = 60.0
var level: int = 1

func _ready() -> void:
    _rebuild()


func set_level(new_level: int) -> void:
    level = clampi(new_level, 1, 5)
    _rebuild()


func _rebuild() -> void:
    for child in get_children():
        child.queue_free()
    var half: float = 360.0 + float(level - 1) * 180.0
    var horizontal_count: int = ceili((half * 2.0) / HORIZONTAL_LENGTH)
    for i in horizontal_count:
        var x: float = -half + float(i) * HORIZONTAL_LENGTH + HORIZONTAL_LENGTH * 0.5
        _add_piece(Vector2(x, -half), true)
        _add_piece(Vector2(x, half), true)
    var vertical_count: int = ceili((half * 2.0) / VERTICAL_LENGTH)
    for i in vertical_count:
        var y: float = -half + float(i) * VERTICAL_LENGTH + VERTICAL_LENGTH * 0.5
        _add_piece(Vector2(-half, y), false)
        _add_piece(Vector2(half, y), false)


func _add_piece(at: Vector2, horizontal: bool) -> void:
    var body := StaticBody2D.new()
    body.position = at
    body.collision_layer = 1
    body.collision_mask = 0
    var sprite := PixelArt.make_sprite("wall_%s_1" % ("h" if horizontal else "v"))
    body.add_child(sprite)
    var collision := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    if horizontal:
        rect.size = Vector2(HORIZONTAL_LENGTH, 14.0)
        collision.position = Vector2(0.0, -7.0)
    else:
        rect.size = Vector2(18.0, VERTICAL_LENGTH - 6.0)
        collision.position = Vector2(0.0, -VERTICAL_LENGTH * 0.5)
    collision.shape = rect
    body.add_child(collision)
    add_child(body)
