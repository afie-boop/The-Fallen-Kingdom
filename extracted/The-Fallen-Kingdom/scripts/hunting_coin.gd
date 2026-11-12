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
    _sprite = PixelArt.make_sprite("coin")
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
