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
var _visual_only: bool = false
var _payment_from: Vector2 = Vector2.ZERO
var _payment_to: Vector2 = Vector2.ZERO
var _payment_t: float = 0.0
var _base_sprite_scale: Vector2 = Vector2.ONE


func _ready() -> void:
    collision_layer = 0
    collision_mask = 2
    monitoring = true
    monitorable = false
    var coin_texture: Texture2D = PixelArt.file_tex("res://assets/animals/gold_coin.png")
    _sprite = PixelArt.make_sprite_tex(coin_texture)
    _sprite.scale = Vector2.ONE * (12.0 / float(maxi(coin_texture.get_width(), coin_texture.get_height())))
    _base_sprite_scale = _sprite.scale
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


func start_payment_animation(target_position: Vector2) -> void:
    _visual_only = true
    monitoring = false
    monitorable = false
    _payment_from = global_position
    _payment_to = target_position
    _payment_t = 0.0
    _sprite.rotation = 0.0
    _sprite.scale = _base_sprite_scale


func _process(delta: float) -> void:
    _t += delta
    if _visual_only:
        # Move the coin directly into its assigned empty slot: no bounce, arc, spin, or scale pulse.
        _payment_t = minf(1.0, _payment_t + delta / 0.24)
        global_position = _payment_from.lerp(_payment_to, _payment_t)
        _sprite.rotation = 0.0
        _sprite.scale = _base_sprite_scale
        if _payment_t >= 1.0:
            global_position = _payment_to
            queue_free()
        return
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
    if _visual_only:
        return
    var p := body as Player
    if p == null or p.dead:
        return
    GameState.add_gold(value, p.player_id)
    queue_free()
