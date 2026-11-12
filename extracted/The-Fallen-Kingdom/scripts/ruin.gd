class_name RuinProp
extends StaticBody2D
## Decorative ruined house (also the visual base for future Houses / ancient ruins).

var variant: int = 0


func _ready() -> void:
    collision_layer = 1
    collision_mask = 0
    add_to_group("ruins")
    var tex: Texture2D = PixelArt.ruin_tex(variant)
    var sprite: Sprite2D = PixelArt.make_sprite_tex(tex)
    add_child(sprite)
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(tex.get_width() * 0.7, 22.0)
    shape.shape = rect
    shape.position = Vector2(0, -11)
    add_child(shape)
