class_name CoinPickup
extends Area2D
## Gold Coin dropped by zombies. Whoever touches it first gets it (placeholder
## reward policy - the real split between players is undecided).

var value: int = 1
var _life: float = 90.0
var _sprite: Sprite2D
var _t: float = 0.0
var _falling: bool = false
var _fall_velocity: float = 0.0
var _fall_target_y: float = 0.0


func _ready() -> void:
    collision_layer = 0
    collision_mask = 2
    monitoring = true
    monitorable = false
    var coin_texture: Texture2D = PixelArt.file_tex("res://assets/animals/gold_coin.png")
    _sprite = PixelArt.make_sprite_tex(coin_texture)
    _sprite.scale = Vector2.ONE * (12.0 / float(maxi(coin_texture.get_width(), coin_texture.get_height())))
    add_child(_sprite)
    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 8.0
    shape.shape = circle
    shape.position = Vector2(0, -4)
    add_child(shape)
    body_entered.connect(_on_body_entered)


func start_falling(target_y: float) -> void:
    _falling = true
    _fall_velocity = -80.0
    _fall_target_y = target_y


func _process(delta: float) -> void:
    _t += delta
    if _falling:
        _fall_velocity += 520.0 * delta
        global_position.y += _fall_velocity * delta
        if global_position.y >= _fall_target_y:
            global_position.y = _fall_target_y
            _falling = false
            _fall_velocity = 0.0
        _sprite.position.y = 0.0
    else:
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
