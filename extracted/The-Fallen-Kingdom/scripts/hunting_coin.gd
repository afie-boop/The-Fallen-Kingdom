class_name HuntingCoin
extends Node2D
## Visible gold dropped by hunted wildlife. An archer collects it and carries it home.

var value: int = 1
var collector: Node2D = null
var _life: float = 90.0
var _t: float = 0.0
var _pickup_scan_t: float = 0.0
var _sprite: Sprite2D

func _ready() -> void:
    add_to_group("hunting_coins")
    var coin_texture: Texture2D = PixelArt.file_tex("res://assets/animals/gold_coin.png")
    _sprite = PixelArt.make_sprite_tex(coin_texture)
    _sprite.scale = Vector2.ONE * (12.0 / float(maxi(coin_texture.get_width(), coin_texture.get_height())))
    add_child(_sprite)

func _process(delta: float) -> void:
    _life -= delta
    _t += delta
    _sprite.position.y = sin(_t * 5.0) * 1.5
    # Scan for nearby players a few times per second instead of every frame.
    # This keeps multiple dropped coins from repeatedly traversing the player group.
    # A player has priority over an archer's claim: never let a claimed coin
    # become impossible for the player to pick up by walking over it.
    _pickup_scan_t -= delta
    if _pickup_scan_t <= 0.0:
        _pickup_scan_t = 0.08
        for node in get_tree().get_nodes_in_group("players"):
            var player := node as Player
            if player != null and not player.dead and global_position.distance_to(player.global_position) <= 32.0:
                GameState.add_gold(value, player.player_id)
                GameState.notice.emit("Collected %d Gold Coin%s." % [value, "" if value == 1 else "s"])
                queue_free()
                return
    if _life <= 0.0:
        queue_free()

func claim(by: Node2D) -> bool:
    if collector != null and is_instance_valid(collector) and collector != by:
        return false
    collector = by
    return true

func collect(by: Node2D) -> int:
    if collector != by:
        return 0
    var amount: int = value
    queue_free()
    return amount
