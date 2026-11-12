class_name TouchJoystick
extends Control
## On-screen joystick (new class name so it can never clash with older files).
## The idle base sits in the bottom-left corner; touching anywhere in the lower-left
## area moves the stick under your thumb. Raw touch events keep multi-touch working.
## `value` is the stick direction (length 0..1) read by the game every frame.

const RADIUS: float = 70.0
const DEADZONE: float = 0.12
const MOUSE_ID: int = 99

var value: Vector2 = Vector2.ZERO
var home: Vector2 = Vector2(110, 300)   ## idle base centre, local to this control
var _active_id: int = -1
var _base_global: Vector2 = Vector2.ZERO


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE


## Covers the lower-left of the screen; base centre is RADIUS + 36 from the left/bottom edges.
func fit_to(vs: Vector2) -> void:
    var top: float = vs.y * 0.3
    position = Vector2(0.0, top)
    size = Vector2(vs.x * 0.5, vs.y - top)
    var m: float = RADIUS + 36.0
    var inset: float = 0.0
    if OS.has_feature("android") or OS.has_feature("ios"):
        var scr: Vector2i = DisplayServer.screen_get_size()
        if scr.x > 0:
            inset = clampf(float(DisplayServer.get_display_safe_area().position.x) * vs.x / float(scr.x), 0.0, 60.0)
    home = Vector2(m + inset, size.y - m)
    queue_redraw()


func _input(event: InputEvent) -> void:
    if not is_visible_in_tree():
        return
    if event is InputEventScreenTouch:
        var st := event as InputEventScreenTouch
        if st.pressed and _active_id == -1 and get_global_rect().has_point(st.position):
            _begin(st.index, st.position)
        elif not st.pressed and st.index == _active_id:
            _release()
    elif event is InputEventScreenDrag:
        var sd := event as InputEventScreenDrag
        if sd.index == _active_id:
            _update(sd.position)
    elif not DisplayServer.is_touchscreen_available():
        if event is InputEventMouseButton:
            var mb := event as InputEventMouseButton
            if mb.button_index == MOUSE_BUTTON_LEFT:
                if mb.pressed and _active_id == -1 and get_global_rect().has_point(mb.position):
                    _begin(MOUSE_ID, mb.position)
                elif not mb.pressed and _active_id == MOUSE_ID:
                    _release()
        elif event is InputEventMouseMotion and _active_id == MOUSE_ID:
            _update((event as InputEventMouseMotion).position)


func _begin(id: int, pos: Vector2) -> void:
    _active_id = id
    var z: Rect2 = get_global_rect()
    _base_global = Vector2(
        clampf(pos.x, z.position.x + RADIUS, z.end.x - RADIUS),
        clampf(pos.y, z.position.y + RADIUS, z.end.y - RADIUS))
    _update(pos)


func _update(global_pos: Vector2) -> void:
    var v: Vector2 = ((global_pos - _base_global) / RADIUS).limit_length(1.0)
    value = Vector2.ZERO if v.length() < DEADZONE else v
    queue_redraw()


func _release() -> void:
    _active_id = -1
    value = Vector2.ZERO
    queue_redraw()


func _draw() -> void:
    var active: bool = _active_id != -1
    var c: Vector2 = (_base_global - global_position) if active else home
    var a: float = 1.0 if active else 0.8
    draw_circle(c, RADIUS, Color(0, 0, 0, 0.35 * a))
    draw_arc(c, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.85 * a), 3.0)
    var knob: Vector2 = c + value * RADIUS * 0.7
    draw_circle(knob, 30.0, Color(1, 1, 1, 0.55 * a))
    draw_arc(knob, 30.0, 0.0, TAU, 32, Color(1, 1, 1, 0.95 * a), 3.0)
