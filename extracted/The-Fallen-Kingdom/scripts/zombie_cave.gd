class_name ZombieCave
extends StaticBody2D
## Cave entrances are the only zombie spawn points.

var variant: int = 0
var _sprite: Sprite2D
var _t: float = 0.0

func _ready() -> void:
    collision_layer = 1
    collision_mask = 0
    add_to_group("zombie_caves")
    _sprite = PixelArt.make_sprite("cave_%d" % variant)
    add_child(_sprite)
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(48.0, 16.0)
    shape.shape = rect
    shape.position = Vector2(0.0, -7.0)
    add_child(shape)

func spawn_pos() -> Vector2:
    return global_position + Vector2(randf_range(-22.0, 22.0), randf_range(18.0, 30.0))

func _process(delta: float) -> void:
    _t += delta
    var glow: float = 0.82 + 0.12 * sin(_t * 2.2) if GameState.is_night else 0.8
    _sprite.modulate = Color(glow, glow, glow)
