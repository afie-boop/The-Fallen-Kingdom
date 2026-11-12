class_name GameMiniMap
extends Control
## Compact live overview of the island and nearby points of interest.

var island: IslandMap
var player: Node2D
var castle: Node2D
var entities: Node2D
var world_size: Vector2 = Vector2(4800, 4800)
var _refresh_t: float = 0.0
var _map_texture: ImageTexture

func setup(map_data: IslandMap, player_node: Node2D, castle_node: Node2D, world_nodes: Node2D, size: Vector2) -> void:
    island = map_data
    player = player_node
    castle = castle_node
    entities = world_nodes
    world_size = size
    _make_map_texture()
    queue_redraw()

func _process(delta: float) -> void:
    _refresh_t -= delta
    if _refresh_t <= 0.0:
        _refresh_t = 0.18
        queue_redraw()


func _make_map_texture() -> void:
    if island == null:
        return
    var img := Image.create(160, 160, false, Image.FORMAT_RGBA8)
    for y in 160:
        for x in 160:
            var p := Vector2((float(x) + 0.5) / 160.0 * world_size.x, (float(y) + 0.5) / 160.0 * world_size.y)
            var field: float = island.sample(p)
            var col := Color(0.10, 0.30, 0.48)
            if field > 0.1:
                col = Color(0.22, 0.43, 0.20)
            elif field > 0.0:
                col = Color(0.72, 0.64, 0.42)
            img.set_pixel(x, y, col)
    _map_texture = ImageTexture.create_from_image(img)

func _draw() -> void:
    var rect := Rect2(Vector2.ZERO, size)
    draw_rect(rect, Color(0.035, 0.055, 0.065, 0.9), true)
    draw_rect(rect, Color(0.72, 0.75, 0.68, 0.9), false, 2.0)
    if island == null or island.texture == null:
        return
    var pad := Rect2(Vector2(5, 5), size - Vector2(10, 10))
    if _map_texture != null:
        draw_texture_rect(_map_texture, pad, false)
    if entities != null and is_instance_valid(entities):
        _draw_group("zombie_caves", Color(0.78, 0.25, 0.82), 2.8, pad)
        _draw_group("wildlife", Color(0.96, 0.88, 0.53), 1.7, pad)
    if castle != null and is_instance_valid(castle):
        _dot(_to_map(castle.global_position, pad), Color(1.0, 0.72, 0.22), 3.5)
    if player != null and is_instance_valid(player):
        var p := _to_map(player.global_position, pad)
        _dot(p, Color(0.98, 0.98, 1.0), 3.0)
        draw_arc(p, 5.0, 0.0, TAU, 24, Color(0.08, 0.12, 0.16), 1.0)

func _draw_group(group_name: String, color: Color, radius: float, pad: Rect2) -> void:
    for node in get_tree().get_nodes_in_group(group_name):
        if node is Node2D and is_instance_valid(node):
            _dot(_to_map((node as Node2D).global_position, pad), color, radius)

func _to_map(world_pos: Vector2, pad: Rect2) -> Vector2:
    return pad.position + Vector2(world_pos.x / world_size.x * pad.size.x, world_pos.y / world_size.y * pad.size.y)

func _dot(p: Vector2, color: Color, radius: float) -> void:
    draw_circle(p, radius + 1.0, Color(0.02, 0.025, 0.03, 0.8))
    draw_circle(p, radius, color)
