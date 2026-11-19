extends Node2D
## Temporary wooden construction frame. A builder works here until the real structure is placed.

signal finished(site: Node2D)

var site_kind: String = "wall"
var site_action: String = "build"
var site_slot: int = 0
var target_level: int = 1
var work_required: float = 6.0
var work_done: float = 0.0
var work_position: Vector2 = Vector2.ZERO

func _ready() -> void:
    add_to_group("construction_sites")
    queue_redraw()

func work_on_site(delta: float) -> bool:
    work_done = minf(work_required, work_done + delta)
    if work_done >= work_required:
        finished.emit(self)
        queue_free()
        return true
    return false

func _draw() -> void:
    var wood := Color("#79502f")
    var wood_light := Color("#bd8950")
    var wood_dark := Color("#4d3423")
    if site_kind == "wall":
        var half: float = 360.0 + float(maxi(1, target_level) - 1) * 180.0
        var corners: Array[Vector2] = [
            Vector2(-half, -half), Vector2(half, -half),
            Vector2(half, half), Vector2(-half, half)
        ]
        # Thick wooden beams form a clear square construction frame.
        for i in range(4):
            var a: Vector2 = corners[i]
            var b: Vector2 = corners[(i + 1) % 4]
            draw_line(a, b, wood_dark, 14.0, true)
            draw_line(a, b, wood, 10.0, true)
            draw_line(a, b, wood_light, 2.0, true)
        # Solid timber posts at each corner.
        for corner in corners:
            draw_rect(Rect2(corner - Vector2(9, 9), Vector2(18, 18)), wood_dark, true)
            draw_rect(Rect2(corner - Vector2(6, 6), Vector2(12, 12)), wood_light, true)
    else:
        var w: float = 74.0
        var h: float = 58.0
        var frame := Rect2(-w * 0.5, -h * 0.5, w, h)
        # Small building blueprint shown as a wooden box frame.
        draw_rect(frame, wood_dark, false, 12.0)
        draw_rect(frame, wood, false, 8.0)
        draw_line(Vector2(-w * 0.5, 0), Vector2(w * 0.5, 0), wood, 6.0, true)
        draw_line(Vector2(0, -h * 0.5), Vector2(0, h * 0.5), wood, 6.0, true)
        for corner in [
            Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.5),
            Vector2(w * 0.5, h * 0.5), Vector2(-w * 0.5, h * 0.5)
        ]:
            draw_rect(Rect2(corner - Vector2(5, 5), Vector2(10, 10)), wood_light, true)
