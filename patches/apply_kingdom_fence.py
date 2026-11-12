from pathlib import Path

root = Path(__file__).resolve().parent
state = root / "scripts/autoload/game_state.gd"
s = state.read_text()
if "var kingdom_fence_built: bool" not in s:
    s = s.replace("var kingdom_level: int = 1\n", "var kingdom_level: int = 1\nvar kingdom_fence_built: bool = false\n", 1)
    s = s.replace("    kingdom_level = 1\n", "    kingdom_level = 1\n    kingdom_fence_built = false\n", 1)
    s = s.replace('            "level": kingdom_level,\n', '            "level": kingdom_level,\n            "fence_built": kingdom_fence_built,\n', 1)
    s = s.replace('        kingdom_level = maxi(1, int(_num(kdict.get("level", 1), 1.0)))\n', '        kingdom_level = maxi(1, int(_num(kdict.get("level", 1), 1.0)))\n        kingdom_fence_built = bool(kdict.get("fence_built", false))\n', 1)
    state.write_text(s)

castle = root / "scripts/castle.gd"
s = castle.read_text()
old = "func interact(player: Player) -> void:\n    player.heal(player.max_hp)\n"
new = """func interact(player: Player) -> void:
    if not GameState.kingdom_fence_built:
        if not GameState.spend_gold(5, player.player_id):
            notice.emit("A kingdom fence costs 5 Gold Coins. Not enough gold.")
            return
        GameState.kingdom_fence_built = true
        var fence := Node2D.new()
        fence.set_script(load("res://scripts/kingdom_fence.gd"))
        fence.position = global_position
        get_parent().add_child(fence)
        notice.emit("Kingdom fence built! 5 Gold Coins paid.")
        interacted.emit()
        return
    player.heal(player.max_hp)
"""
if old in s:
    s = s.replace(old, new, 1)
    castle.write_text(s)

game = root / "scripts/game.gd"
s = game.read_text()
old = "    entities.add_child(castle)\n"
new = """    entities.add_child(castle)
    if GameState.kingdom_fence_built:
        var fence := Node2D.new()
        fence.set_script(load("res://scripts/kingdom_fence.gd"))
        fence.position = castle.position
        entities.add_child(fence)
"""
if old in s and "kingdom_fence_built" not in s:
    s = s.replace(old, new, 1)
    game.write_text(s)

fence_script = root / "scripts/kingdom_fence.gd"
if not fence_script.exists():
    fence_script.write_text('''extends Node2D
## One continuous fence around the kingdom's current territory.

const FENCE_COLOR := Color(0.42, 0.27, 0.13)
const FENCE_HIGHLIGHT := Color(0.68, 0.48, 0.27)
const FENCE_THICKNESS := 10.0
var territory_size: Vector2 = Vector2(640.0, 480.0)

func _ready() -> void:
    var extra: float = float(maxi(0, GameState.kingdom_level - 1)) * 80.0
    territory_size += Vector2(extra, extra * 0.75)
    var body := StaticBody2D.new()
    body.name = "FenceCollision"
    body.collision_layer = 1
    body.collision_mask = 0
    add_child(body)
    var half := territory_size * 0.5
    _add_wall_collision(body, Vector2(0, -half.y), Vector2(territory_size.x, FENCE_THICKNESS))
    _add_wall_collision(body, Vector2(0, half.y), Vector2(territory_size.x, FENCE_THICKNESS))
    _add_wall_collision(body, Vector2(-half.x, 0), Vector2(FENCE_THICKNESS, territory_size.y))
    _add_wall_collision(body, Vector2(half.x, 0), Vector2(FENCE_THICKNESS, territory_size.y))
    queue_redraw()

func _add_wall_collision(body: StaticBody2D, center: Vector2, size: Vector2) -> void:
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = size
    collision.shape = shape
    collision.position = center
    body.add_child(collision)

func _draw() -> void:
    var half := territory_size * 0.5
    draw_rect(Rect2(-half, territory_size), FENCE_COLOR, false, FENCE_THICKNESS)
    var spacing := 28.0
    var x := -half.x
    while x <= half.x:
        draw_line(Vector2(x, -half.y - 7), Vector2(x, -half.y + 7), FENCE_HIGHLIGHT, 4.0)
        draw_line(Vector2(x, half.y - 7), Vector2(x, half.y + 7), FENCE_HIGHLIGHT, 4.0)
        x += spacing
    var y := -half.y
    while y <= half.y:
        draw_line(Vector2(-half.x - 7, y), Vector2(-half.x + 7, y), FENCE_HIGHLIGHT, 4.0)
        draw_line(Vector2(half.x - 7, y), Vector2(half.x + 7, y), FENCE_HIGHLIGHT, 4.0)
        y += spacing
''')
