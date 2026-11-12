class_name EnemyCastle
extends StaticBody2D
## The Zombie Castle. Stage 1: an indestructible origin point for zombie spawns.
## (Destroying it, rebuild behaviour and island unlocks belong to Stage 3.)

var _sprite: Sprite2D
var _t: float = 0.0


func _ready() -> void:
    collision_layer = 1
    collision_mask = 0
    add_to_group("enemy_castle")
    add_to_group("nests")
    _sprite = PixelArt.make_sprite("enemy_castle")
    _sprite.scale = Vector2(2, 2)
    add_child(_sprite)
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(104, 36)
    shape.shape = rect
    shape.position = Vector2(0, -18)
    add_child(shape)


func spawn_pos() -> Vector2:
    return global_position + Vector2(randf_range(-50.0, 50.0), randf_range(44.0, 80.0))


func _process(delta: float) -> void:
    _t += delta
    var g: float = 0.9 + 0.1 * sin(_t * 2.0)
    _sprite.modulate = Color(g, g, g)
