class_name KingdomFence
extends Node2D
## One continuous perimeter around the kingdom. Every side is evenly divided
## so the final piece reaches the corner exactly without gaps or same-side overlap.

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
    var side_length: float = half * 2.0

    # Distribute pieces evenly over the exact side length. Scale only along
    # the wall, so the last segment meets the corner instead of overshooting.
    var horizontal_count: int = ceili(side_length / HORIZONTAL_LENGTH)
    var horizontal_step: float = side_length / float(horizontal_count)
    for i in horizontal_count:
        var x: float = -half + (float(i) + 0.5) * horizontal_step
        _add_piece(Vector2(x, -half), true, horizontal_step)
        _add_piece(Vector2(x, half), true, horizontal_step)

    var vertical_count: int = ceili(side_length / VERTICAL_LENGTH)
    var vertical_step: float = side_length / float(vertical_count)
    for i in vertical_count:
        var y: float = -half + (float(i) + 0.5) * vertical_step
        _add_piece(Vector2(-half, y), false, vertical_step)
        _add_piece(Vector2(half, y), false, vertical_step)

    # Trees caught by the new perimeter are felled automatically.
    _clear_trees_on_perimeter(half)

    # Cap each junction with one solid timber/stone post so the two wall
    # directions meet cleanly instead of showing a crossed, doubled corner.
    for corner_x in [-half, half]:
        for corner_y in [-half, half]:
            _add_corner_post(Vector2(corner_x, corner_y))


func _clear_trees_on_perimeter(half: float) -> void:
    for node in get_tree().get_nodes_in_group("trees"):
        var tree := node as ChoppableTree
        if tree == null or not is_instance_valid(tree):
            continue
        var p: Vector2 = to_local(tree.global_position)
        var along_x: bool = absf(p.y) <= half + 24.0 and absf(absf(p.x) - half) <= 24.0
        var along_y: bool = absf(p.x) <= half + 24.0 and absf(absf(p.y) - half) <= 24.0
        if along_x or along_y:
            tree.fell_by_fence()


func _add_corner_post(at: Vector2) -> void:
    var post := Sprite2D.new()
    post.texture = PixelArt.get_tex("post_%d" % level)
    post.centered = true
    post.offset = Vector2.ZERO
    post.position = at
    post.scale = Vector2(0.8, 0.8)
    post.z_index = 8
    add_child(post)


func _add_piece(at: Vector2, horizontal: bool, segment_length: float) -> void:
    var body := StaticBody2D.new()
    body.position = at
    # The perimeter is a visual boundary, not a movement barrier. Players
    # and hunting units must be able to cross it freely to reach wildlife.
    body.collision_layer = 4
    body.collision_mask = 0

    var sprite := PixelArt.make_sprite("wall_%s_%d" % ["h" if horizontal else "v", level])
    # Fence sprites are centred on their segment positions. The default
    # PixelArt helper is bottom-anchored for characters/buildings.
    sprite.centered = true
    sprite.offset = Vector2.ZERO
    if horizontal:
        sprite.scale = Vector2((segment_length + 18.0) / HORIZONTAL_LENGTH, 1.0)
    else:
        sprite.scale = Vector2(1.0, (segment_length + 18.0) / VERTICAL_LENGTH)
    body.add_child(sprite)

    var collision := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    if horizontal:
        rect.size = Vector2(segment_length + 18.0, 14.0)
    else:
        rect.size = Vector2(18.0, segment_length + 18.0)
    collision.shape = rect
    body.add_child(collision)
    add_child(body)
