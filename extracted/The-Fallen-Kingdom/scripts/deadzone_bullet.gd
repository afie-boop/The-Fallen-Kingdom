extends Node2D
class_name DeadzoneBullet

var direction: Vector2 = Vector2.RIGHT
var speed: float = 520.0
var damage: float = 18.0
var lifetime: float = 1.2
var _visual: ColorRect

func _ready() -> void:
    _visual = ColorRect.new()
    _visual.size = Vector2(7, 4)
    _visual.position = Vector2(-3.5, -2.0)
    _visual.color = Color(1.0, 0.82, 0.35)
    _visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_visual)
    rotation = direction.angle()

func _process(delta: float) -> void:
    lifetime -= delta
    if lifetime <= 0.0:
        queue_free()
        return
    global_position += direction * speed * delta
    for enemy in get_tree().get_nodes_in_group("zombies"):
        if not is_instance_valid(enemy):
            continue
        if global_position.distance_to((enemy as Node2D).global_position) <= 15.0:
            enemy.call("take_damage", damage)
            queue_free()
            return
