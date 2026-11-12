class_name TouchActionButton
extends Control
## Round on-screen button with multi-touch support (also reacts to the mouse
## when no touchscreen is present). High-contrast so it is easy to see.

signal pressed

const MOUSE_ID: int = 99

var label_text: String = ""
var font_size: int = 22
var tint: Color = Color(1, 1, 1)
var held: bool = false
var _active_id: int = -1


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _hit(pos: Vector2) -> bool:
    var r: float = minf(size.x, size.y) / 2.0
    return pos.distance_to(get_global_rect().get_center()) <= r * 1.15


func _input(event: InputEvent) -> void:
    if not is_visible_in_tree():
        return
    if event is InputEventScreenTouch:
        var st := event as InputEventScreenTouch
        if st.pressed and _active_id == -1 and _hit(st.position):
            _press(st.index)
        elif not st.pressed and st.index == _active_id:
            _release()
    elif not DisplayServer.is_touchscreen_available() and event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_LEFT:
            if mb.pressed and _active_id == -1 and _hit(mb.position):
                _press(MOUSE_ID)
            elif not mb.pressed and _active_id == MOUSE_ID:
                _release()


func _press(id: int) -> void:
    _active_id = id
    held = true
    pressed.emit()
    queue_redraw()


func _release() -> void:
    _active_id = -1
    held = false
    queue_redraw()


func _draw() -> void:
    var c: Vector2 = size / 2.0
    var r: float = minf(size.x, size.y) / 2.0 - 2.0
    var fill: Color = tint.lerp(Color.WHITE, 0.2)
    fill.a = 0.55 if held else 0.3
    draw_circle(c, r, Color(0, 0, 0, 0.35))
    draw_circle(c, r, fill)
    draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.9), 3.0)
    var font: Font = ThemeDB.fallback_font
    var ts: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
    var pos := Vector2(c.x - ts.x / 2.0, c.y + ts.y / 4.0)
    draw_string_outline(font, pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color.BLACK)
    draw_string(font, pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
