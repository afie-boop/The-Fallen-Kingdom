extends CharacterBody2D
class_name DeadzoneZombie

signal killed(zombie: DeadzoneZombie)

var target: Node2D
var hp: float = 35.0
var move_speed: float = 42.0
var attack_damage: float = 9.0
var attack_cooldown: float = 0.0
var alive: bool = true
var _sprite: Sprite2D
var _anim_time: float = 0.0

func _ready() -> void:
    collision_layer = 0
    collision_mask = 0
    motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
    add_to_group("zombies")
    _sprite = PixelArt.make_sprite_tex(PixelArt.zombie_tex(randi_range(0, PixelArt.ZOMBIE_VARIANTS - 1)))
    _sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _sprite.scale = Vector2(1.6, 1.6)
    add_child(_sprite)

func configure(player: Node2D, wave: int) -> void:
    target = player
    hp = 28.0 + float(wave) * 8.0
    move_speed = minf(42.0 + float(wave) * 1.8, 86.0)
    attack_damage = 7.0 + float(wave) * 0.8
    attack_cooldown = randf_range(0.1, 0.6)

func _physics_process(delta: float) -> void:
    if not alive or not is_instance_valid(target):
        velocity = Vector2.ZERO
        return
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    var to_player := target.global_position - global_position
    var distance := to_player.length()
    if distance > 19.0:
        velocity = to_player.normalized() * move_speed
        move_and_slide()
        _anim_time += delta * 7.0
        _sprite.position.y = -absf(sin(_anim_time)) * 1.5
        _sprite.flip_h = velocity.x < -0.1
    else:
        velocity = Vector2.ZERO
        if attack_cooldown <= 0.0 and target.has_method("take_damage"):
            target.call("take_damage", attack_damage)
            attack_cooldown = 1.0

func take_damage(amount: float) -> void:
    if not alive:
        return
    hp -= amount
    _sprite.modulate = Color(1.0, 0.35, 0.35)
    var tween := create_tween()
    tween.tween_property(_sprite, "modulate", Color.WHITE, 0.12)
    if hp <= 0.0:
        alive = false
        killed.emit(self)
        queue_free()
