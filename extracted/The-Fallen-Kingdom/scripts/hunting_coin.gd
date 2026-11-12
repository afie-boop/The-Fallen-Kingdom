class_name HuntingCoin
extends Node2D
## Visible gold dropped by hunted wildlife. An archer collects it and carries it home.

var value: int = 1
var collector: Node2D = null
var _life: float = 90.0
var _t: float = 0.0
var _sprite: Sprite2D

func _ready() -> void:
    add_to_group("hunting_coins")
    var coin_texture: Texture2D = PixelArt.file_tex("res://assets/animals/gold_coin.png")
    _sprite = PixelArt.make_sprite_tex(coin_texture)
    _sprite.scale = Vector2.ONE * (28.0 / float(maxi(coin_texture.get_width(), coin_texture.get_height())))
    add_child(_sprite)

func _process(delta: float) -> void:
    _life -= delta
    _t += delta
    _sprite.position.y = sin(_t * 5.0) * 1.5
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
