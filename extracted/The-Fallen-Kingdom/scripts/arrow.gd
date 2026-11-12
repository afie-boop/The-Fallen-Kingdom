class_name Arrow
extends Node2D
## A fast arrow fired by an archer. Flies to the target and damages it on arrival.


func launch(from: Vector2, target: Zombie, damage: float) -> void:
    global_position = from
    var sprite := Sprite2D.new()
    sprite.texture = PixelArt.get_tex("arrow")
    add_child(sprite)
    var aim: Vector2 = target.global_position + Vector2(0, -12) - from
    rotation = aim.angle()
    var tw := create_tween()
    tw.tween_property(self, "global_position", target.global_position + Vector2(0, -12), maxf(0.08, aim.length() / 520.0))
    tw.tween_callback(_arrived.bind(target, damage, from))


func _arrived(target: Zombie, damage: float, from: Vector2) -> void:
    if is_instance_valid(target) and target.active:
        target.take_damage(damage, from)
    queue_free()
