class_name KingdomCastle
extends StaticBody2D
## The shared kingdom house (class keeps its old name): respawn point, healing, wood deposit and save point.

signal hp_changed(hp: float, max_hp: float)
signal notice(text: String)
signal interacted

var hp: float = 500.0
var max_hp: float = 500.0
var spawn_point: Vector2 = Vector2.ZERO
var prompt_text: String = "Rest, store wood and save"
const HOUSE_VARIANT: int = 2   # ruin_3: the tile-roofed house
var _sprite: Sprite2D
var _top: float = 90.0
var _warn_cd: float = 0.0


func _ready() -> void:
    collision_layer = 1
    collision_mask = 0
    add_to_group("interactable")
    add_to_group("castle")
    add_to_group("repairable")
    max_hp = GameConfig.castle_max_hp
    hp = max_hp
    var tex: Texture2D = PixelArt.ruin_tex(HOUSE_VARIANT)
    _top = float(tex.get_height()) + 14.0
    _sprite = PixelArt.make_sprite_tex(tex)
    add_child(_sprite)
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(tex.get_width() * 0.75, 26.0)
    shape.shape = rect
    shape.position = Vector2(0, -13)
    add_child(shape)
    spawn_point = global_position + Vector2(0, 34)


func _process(delta: float) -> void:
    _warn_cd = maxf(0.0, _warn_cd - delta)


func _draw() -> void:
    if hp < max_hp:
        var w: float = 90.0
        draw_rect(Rect2(-w / 2.0, -_top, w, 6.0), Color(0, 0, 0, 0.6))
        draw_rect(Rect2(-w / 2.0 + 1.0, -_top + 1.0, (w - 2.0) * hp / max_hp, 4.0), Color(0.3, 0.8, 0.35))


func take_damage(amount: float) -> void:
    # Stage 1: the castle cannot be destroyed (HP floors at 1). It is restored at dawn.
    hp = maxf(1.0, hp - amount)
    hp_changed.emit(hp, max_hp)
    queue_redraw()
    if _warn_cd <= 0.0:
        _warn_cd = 12.0
        notice.emit("Your house is under attack!")


func needs_repair() -> bool:
    return hp < max_hp - 0.01


## Free repair by builders (daytime only - enforced by the builder).
func repair(amount: float) -> void:
    hp = minf(max_hp, hp + amount)
    hp_changed.emit(hp, max_hp)
    queue_redraw()


func restore() -> void:
    hp = max_hp
    hp_changed.emit(hp, max_hp)
    queue_redraw()


func set_hp(value: float) -> void:
    hp = clampf(value, 1.0, max_hp)
    queue_redraw()


func interact(player: Player) -> void:
    player.heal(player.max_hp)
    var moved: int = GameState.deposit_to_kingdom("wood", player.player_id)
    if moved > 0:
        notice.emit("Deposited %d wood. Health restored. Game saved." % moved)
    else:
        notice.emit("Health restored. Game saved.")
    interacted.emit()
