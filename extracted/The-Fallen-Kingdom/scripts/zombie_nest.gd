class_name ZombieNest
extends StaticBody2D
## A small zombie nest. Zombies crawl out of it at night.

var _sprite: Sprite2D
var _t: float = 0.0


func _ready() -> void:
    collision_layer = 1
    collision_mask = 0
    add_to_group("nests")
    _sprite = PixelArt.make_sprite("nest")
    add_child(_sprite)
    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 12.0
    shape.shape = circle
    shape.position = Vector2(0, -9)
    add_child(shape)
    _t = randf() * 6.0


func spawn_pos() -> Vector2:
    return global_position + Vector2(randf_range(-14.0, 14.0), randf_range(10.0, 24.0))


func _process(delta: float) -> void:
    _t += delta
    # Eerie glow at night only.
    var g: float = (0.85 + 0.15 * sin(_t * 2.5)) if GameState.is_night else 0.8
    _sprite.modulate = Color(g, g, g)
