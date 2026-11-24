extends Area2D
class_name DeadzonePickup

signal collected(amount: int)

var value := 1
var _pulse := 0.0

func _ready() -> void:
    collision_layer = 0
    collision_mask = 0
    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 18.0
    shape.shape = circle
    add_child(shape)
    body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
    _pulse += delta * 4.0
    queue_redraw()

func _draw() -> void:
    var y := sin(_pulse) * 2.0
    var pts := PackedVector2Array([Vector2(0, -10 + y), Vector2(8, 0 + y), Vector2(0, 10 + y), Vector2(-8, 0 + y)])
    draw_colored_polygon(pts, Color("#65e7e0"))
    draw_rect(Rect2(-2, -5 + y, 4, 10), Color("#d8ffff"))
    draw_rect(Rect2(-1, -2 + y, 2, 4), Color("#ffffff"))

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("players"):
        collected.emit(value)
        queue_free()
