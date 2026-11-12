class_name Building
extends StaticBody2D
## A kingdom building: castle, wall, archer tower or builder hut (levels 1-3).

signal changed

var type: String = "wall"
var level: int = 1
var hp: float = 0.0
var max_hp: float = 100.0
var hp_init: float = -1.0           ## saved HP to restore (-1 = full)
var worker_id: int = -1             ## beggar id of the assigned citizen
var worker: Node = null
var reach: float = 34.0
var prompt_text: String = "Rest, store wood and save"
var interact_range: float = 90.0

var _sprite: Sprite2D
var _shape: CollisionShape2D
var _top: float = 40.0


func _ready() -> void:
    collision_layer = 1
    collision_mask = 0
    add_to_group("buildings")
    add_to_group("repairable")
    if type == "castle":
        add_to_group("interactable")
    _shape = CollisionShape2D.new()
    add_child(_shape)
    _refresh_visual()
    max_hp = BuildingData.max_hp(type, level)
    hp = max_hp if hp_init < 0.0 else clampf(hp_init, 1.0, max_hp)


func display_name() -> String:
    return str(BuildingData.info(type).get("name", type))


func _refresh_visual() -> void:
    var d: Dictionary = BuildingData.info(type)
    reach = float(d.get("reach", 34.0))
    if _sprite != null:
        _sprite.queue_free()
    var tex: Texture2D = PixelArt.get_tex("bld_%s_%d" % [type, level])
    _sprite = PixelArt.make_sprite_tex(tex)
    add_child(_sprite)
    _top = float(tex.get_height()) + 8.0
    var rect := RectangleShape2D.new()
    var fp: Vector2 = d.get("footprint", Vector2(30, 14))
    rect.size = fp
    _shape.shape = rect
    _shape.position = Vector2(0, -fp.y / 2.0)
    queue_redraw()


func take_damage(amount: float) -> void:
    # Buildings are never destroyed in this stage: HP floors at 1 until a builder repairs them.
    hp = maxf(1.0, hp - amount)
    changed.emit()
    queue_redraw()


func repair(amount: float) -> void:
    hp = minf(max_hp, hp + amount)
    changed.emit()
    queue_redraw()


func is_damaged() -> bool:
    return hp < max_hp - 0.01


## Raises the level by one. The caller has already checked and charged the cost.
func upgrade() -> void:
    level = mini(BuildingData.MAX_LEVEL, level + 1)
    max_hp = BuildingData.max_hp(type, level)
    hp = max_hp
    _refresh_visual()
    changed.emit()


func interact(player: Player) -> void:
    if type != "castle":
        return
    player.heal(player.max_hp)
    var moved: int = GameState.deposit_to_kingdom("wood", player.player_id)
    if moved > 0:
        GameState.notice.emit("Deposited %d wood. Health restored. Game saved." % moved)
    else:
        GameState.notice.emit("Health restored. Game saved.")
    GameState.save_requested.emit()


func to_save() -> Dictionary:
    return {"type": type, "level": level, "x": position.x, "y": position.y, "hp": hp, "worker": worker_id}


func _draw() -> void:
    var font: Font = ThemeDB.fallback_font
    var label: String = "%s Lv %d" % [display_name(), level]
    var needs_worker: bool = str(BuildingData.info(type).get("worker", "")) != "" and not is_instance_valid(worker)
    if needs_worker:
        label += "  (needs a citizen)"
    var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
    var pos := Vector2(-w / 2.0, -_top - 8.0)
    draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Color.BLACK)
    draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.95))
    if is_damaged():
        var bw: float = 40.0
        draw_rect(Rect2(-bw / 2.0, -_top, bw, 5.0), Color(0, 0, 0, 0.6))
        draw_rect(Rect2(-bw / 2.0 + 1.0, -_top + 1.0, (bw - 2.0) * hp / max_hp, 3.0), Color(0.3, 0.8, 0.35))
