extends Node2D
class_name DeadzoneTurret

var damage := 12.0
var fire_interval := 0.65
var fire_timer := 0.0
var range_limit := 420.0
var barrel_angle := 0.0

func configure(power: float, interval: float) -> void:
    damage = power
    fire_interval = interval

func _process(delta: float) -> void:
    fire_timer = maxf(0.0, fire_timer - delta)
    if fire_timer > 0.0:
        return
    var target: Node2D
    var best := range_limit
    for enemy in get_tree().get_nodes_in_group("zombies"):
        if not is_instance_valid(enemy):
            continue
        var distance := global_position.distance_to((enemy as Node2D).global_position)
        if distance < best:
            best = distance
            target = enemy as Node2D
    if target == null:
        return
    barrel_angle = (target.global_position - global_position).angle()
    target.call("take_damage", damage)
    fire_timer = fire_interval
    queue_redraw()

func _draw() -> void:
    # Compact turret built on a crisp pixel grid.
    draw_rect(Rect2(-13, 4, 26, 8), Color("#252d32"))
    draw_rect(Rect2(-10, -4, 20, 12), Color("#65727a"))
    draw_rect(Rect2(-5, -10, 10, 8), Color("#aeb8b5"))
    draw_set_transform(Vector2.ZERO, barrel_angle)
    draw_rect(Rect2(0, -3, 22, 6), Color("#303b42"))
    draw_rect(Rect2(15, -2, 9, 4), Color("#d6a64b"))
    draw_set_transform(Vector2.ZERO, 0.0)
