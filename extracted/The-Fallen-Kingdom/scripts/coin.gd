class_name CoinPickup
extends Area2D
## Gold Coin dropped by zombies. Whoever touches it first gets it (placeholder
## reward policy - the real split between players is undecided).

var value: int = 1
var _life: float = 90.0
var _sprite: Sprite2D
var _t: float = 0.0


func _ready() -> void:
    collision_layer = 0
    collision_mask = 2
    monitoring = true
    monitorable = false
    _sprite = PixelArt.make_sprite("coin")
    add_child(_sprite)
    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 8.0
    shape.shape = circle
    shape.position = Vector2(0, -4)
    add_child(shape)
    body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
    _t += delta
    _sprite.position.y = sin(_t * 5.0) * 1.5
    _life -= delta
    if _life <= 0.0:
        queue_free()


func _on_body_entered(body: Node2D) -> void:
    var p := body as Player
    if p == null or p.dead:
        return
    GameState.add_gold(value, p.player_id)
    queue_free()
