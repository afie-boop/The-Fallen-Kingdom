class_name Structure
extends StaticBody2D
## A kingdom building: "castle", "wall" or "builder_hut".
## Zombies attack it, builders repair it (free, daytime only). A wall at 0 HP is breached
## (no collision) until a builder repairs it.

signal changed

const CASTLE_BASE_SCALE: float = 1.6

var kind: String = "wall"
var slot: int = 0
var level: int = 1
var hp: float = -1.0           ## < 0 means "start at full HP"
var max_hp: float = 100.0
var broken: bool = false
var horizontal: bool = true    ## walls only (side walls are vertical)

var _sprite: Sprite2D
var _shape: CollisionShape2D
var _base_scale: Vector2 = Vector2.ONE
var _warn_ms: int = 0


func _ready() -> void:
    collision_layer = 1
    collision_mask = 0
    add_to_group("repairable")
    max_hp = _hp_for_level()
    if hp < 0.0:
        hp = max_hp
    hp = minf(hp, max_hp)
    _shape = CollisionShape2D.new()
    add_child(_shape)
    _build_visual()
    if hp <= 0.0:
        _set_broken(true)
    else:
        add_to_group("structures")


func _hp_for_level() -> float:
    var arr: Array = GameConfig.hp_castle
    match kind:
        "wall":
            arr = GameConfig.hp_wall
        "builder_hut":
            arr = GameConfig.hp_builder_hut
    return float(arr[clampi(level - 1, 0, arr.size() - 1)])


func _build_visual() -> void:
    if _sprite != null:
        _sprite.queue_free()
    var rect := RectangleShape2D.new()
    match kind:
        "castle":
            _sprite = PixelArt.make_sprite("castle")
            _base_scale = Vector2.ONE * (CASTLE_BASE_SCALE + 0.4 * float(level - 1))
            rect.size = Vector2(64.0 * _base_scale.x * 0.8, 28.0)
            _shape.position = Vector2(0, -14)
        "wall":
            _sprite = PixelArt.make_sprite("wall_%s_%d" % ["h" if horizontal else "v", level])
            _base_scale = Vector2.ONE
            if horizontal:
                rect.size = Vector2(64, 14)
                _shape.position = Vector2(0, -7)
            else:
                rect.size = Vector2(18, 54)
                _shape.position = Vector2(0, -27)
            _base_scale = Vector2.ONE
            rect.size = Vector2(30, 14)
            _shape.position = Vector2(0, -7)
        _:
            _sprite = PixelArt.make_sprite("hut_%d" % level)
            _base_scale = Vector2.ONE
            rect.size = Vector2(44, 16)
            _shape.position = Vector2(0, -8)
    _shape.shape = rect
    _sprite.scale = _base_scale
    add_child(_sprite)
    if broken:
        _apply_broken_look()
    queue_redraw()


func sprite_height() -> float:
    return float(_sprite.texture.get_height()) * _base_scale.y if _sprite != null else 40.0


func _draw() -> void:
    if hp < max_hp and _sprite != null:
        var w: float = 36.0
        var y: float = -sprite_height() - 8.0
        draw_rect(Rect2(-w / 2.0, y, w, 5.0), Color(0, 0, 0, 0.6))
        draw_rect(Rect2(-w / 2.0 + 1.0, y + 1.0, (w - 2.0) * hp / max_hp, 3.0), Color(0.3, 0.8, 0.35) if hp > max_hp * 0.35 else Color(0.9, 0.3, 0.25))


func set_level(new_level: int) -> void:
    level = clampi(new_level, 1, 3)
    max_hp = _hp_for_level()
    hp = max_hp
    if broken:
        _set_broken(false)
    _build_visual()
    changed.emit()


func take_damage(amount: float) -> void:
    if broken:
        return
    hp = maxf(0.0, hp - amount)
    queue_redraw()
    changed.emit()
    if hp <= 0.0:
        _set_broken(true)
        GameState.notice.emit("A %s was destroyed! Builders repair it in the daytime." % kind.replace("_", " "))
    elif hp < max_hp * 0.5 and Time.get_ticks_msec() - _warn_ms > 15000:
        _warn_ms = Time.get_ticks_msec()
        GameState.notice.emit("Your %s is under attack!" % kind.replace("_", " "))


func needs_repair() -> bool:
    return hp < max_hp - 0.01


## Free repair, no materials. Called by builders.
func repair(amount: float) -> void:
    hp = minf(max_hp, hp + amount)
    if broken and hp > 0.0:
        _set_broken(false)
    queue_redraw()
    changed.emit()


func _set_broken(value: bool) -> void:
    broken = value
    _shape.set_deferred("disabled", value)
    if value:
        remove_from_group("structures")
        _apply_broken_look()
    else:
        if not is_in_group("structures"):
            add_to_group("structures")
        if _sprite != null:
            _sprite.modulate = Color.WHITE
            _sprite.scale = _base_scale


func _apply_broken_look() -> void:
    if _sprite != null:
        _sprite.modulate = Color(0.42, 0.4, 0.4)
        _sprite.scale = Vector2(_base_scale.x, _base_scale.y * 0.45)


func to_save() -> Dictionary:
    return {"kind": kind, "slot": slot, "level": level, "hp": hp}
