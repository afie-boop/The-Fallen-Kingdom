class_name CampProp
extends StaticBody2D
## Decoration for the poor people's camps: "tent" or "fire".

var kind: String = "tent"
var _sprite: Sprite2D
var _t: float = 0.0


func _ready() -> void:
    collision_layer = 1
    collision_mask = 0
    var shape := CollisionShape2D.new()
    if kind == "fire":
        _sprite = PixelArt.make_sprite("fire_0")
        var circle := CircleShape2D.new()
        circle.radius = 5.0
        shape.shape = circle
        shape.position = Vector2(0, -4)
        _t = randf() * 3.0
    else:
        _sprite = PixelArt.make_sprite("tent")
        var rect := RectangleShape2D.new()
        rect.size = Vector2(38.0, 14.0)
        shape.shape = rect
        shape.position = Vector2(0, -7)
        set_process(false)
    add_child(_sprite)
    add_child(shape)


func _process(delta: float) -> void:
    _t += delta
    _sprite.texture = PixelArt.get_tex("fire_%d" % (int(_t / 0.18) % 2))
    var g: float = 0.9 + 0.1 * sin(_t * 9.0)
    _sprite.modulate = Color(1.0, g, g * 0.9)
