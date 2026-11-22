class_name GameMiniMap
extends Control
## Compact live overview of the island and nearby points of interest.

var island: IslandMap
var player: Node2D
var castle: Node2D
var entities: Node2D
var world_size: Vector2 = Vector2(4800, 4800)
var _refresh_t: float = 0.0

func setup(map_data: IslandMap, player_node: Node2D, castle_node: Node2D, world_nodes: Node2D, size: Vector2) -> void:
    island = map_data
    player = player_node
    castle = castle_node
    entities = world_nodes
    world_size = size
    queue_redraw()

func _process(delta: float) -> void:
    _refresh_t -= delta
    if _refresh_t <= 0.0:
        _refresh_t = 0.18
        queue_redraw()

func _draw() -> void:
    var rect := Rect2(Vector2.ZERO, size)
    draw_rect(rect, Color(0.035, 0.055, 0.065, 0.9), true)
    draw_rect(rect, Color(0.72, 0.75, 0.68, 0.9), false, 2.0)
    if island == null or island.texture == null:
        return
    var pad := Rect2(Vector2(5, 5), size - Vector2(10, 10))
    draw_texture_rect(island.texture, pad, false, Color(0.75, 0.88, 0.76))
    if entities != null and is_instance_valid(entities):
        _draw_group("trees", Color(0.08, 0.25, 0.11), 1.4, pad)
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
