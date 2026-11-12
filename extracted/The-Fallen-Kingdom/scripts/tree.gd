class_name ChoppableTree
extends StaticBody2D
## A tree that can be chopped with the sword. Gives wood to the player's
## personal inventory. The tree id is saved so chopped trees stay gone.

var tree_id: int = -1
var hp: int = 3
var _sprite: Sprite2D


func _ready() -> void:
    collision_layer = 1
    collision_mask = 0
    add_to_group("trees")
    hp = GameConfig.tree_hp
    _sprite = PixelArt.make_sprite_tex(PixelArt.tree_tex(maxi(tree_id, 0)))
    add_child(_sprite)
    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 6.0
    shape.shape = circle
    shape.position = Vector2(0, -4)
    add_child(shape)


func take_hit(by: Node) -> void:
    hp -= 1
    var tw := create_tween()
    tw.tween_property(_sprite, "position:x", 2.0, 0.04)
    tw.tween_property(_sprite, "position:x", -2.0, 0.08)
    tw.tween_property(_sprite, "position:x", 0.0, 0.04)
    if hp > 0:
        return
    var amount: int = randi_range(GameConfig.wood_per_tree_min, GameConfig.wood_per_tree_max)
    var pid: int = GameState.local_player_id
    if by is Player:
        pid = (by as Player).player_id
    GameState.add_item("wood", amount, pid)
    if tree_id >= 0 and not GameState.removed_trees.has(tree_id):
        GameState.removed_trees.append(tree_id)
    remove_from_group("trees")
    queue_free()
