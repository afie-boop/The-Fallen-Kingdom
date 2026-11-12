class_name Beggar
extends StaticBody2D
## A beggar found at a poor people's camp. Pay 1 Gold Coin (from your own wallet)
## to recruit them as a citizen of the shared kingdom.

var beggar_id: int = 0
var variant: int = 0
var prompt_text: String = "Recruit beggar (1 Gold Coin)"
var interact_range: float = 56.0
var _sprite: Sprite2D
var _t: float = 0.0


func _ready() -> void:
    collision_layer = 1
    collision_mask = 0
    add_to_group("interactable")
    add_to_group("beggars")
    _sprite = PixelArt.make_sprite_tex(PixelArt.beggar_tex(variant))
    add_child(_sprite)
    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 6.0
    shape.shape = circle
    shape.position = Vector2(0, -4)
    add_child(shape)
    _t = randf() * 6.0


func _process(delta: float) -> void:
    _t += delta
    _sprite.scale.y = 1.0 + 0.025 * sin(_t * 2.2)


func interact(player: Player) -> void:
    if GameState.get_gold(player.player_id) < 1:
        GameState.notice.emit("This beggar asks for 1 Gold Coin.")
        return
    GameState.spend_gold(1, player.player_id)   # only the recruiting player pays, from their own wallet
    GameState.recruit_beggar(beggar_id)
    remove_from_group("interactable")
    GameState.beggar_recruited.emit(beggar_id, variant, global_position)
    queue_free()
