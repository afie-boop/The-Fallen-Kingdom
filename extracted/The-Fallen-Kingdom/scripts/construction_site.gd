extends Node2D
## Temporary construction blueprint. A builder works here until the real structure is placed.

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
    queue_redraw()
    if work_done >= work_required:
        finished.emit(self)
        queue_free()
        return true
    return false

func _draw() -> void:
    var progress: float = clampf(work_done / maxf(0.01, work_required), 0.0, 1.0)
    var base := Color("#c9b58a", 0.72)
    var bright := Color("#f3d58b", 0.95)
    if site_kind == "wall":
        var half: float = 360.0 + float(maxi(1, target_level) - 1) * 180.0
        var corners: Array[Vector2] = [
            Vector2(-half, -half), Vector2(half, -half),
            Vector2(half, half), Vector2(-half, half), Vector2(-half, -half)
        ]
        for i in range(4):
            draw_line(corners[i], corners[i + 1], base, 3.0, true)
            var segment_progress: float = clampf(progress * 4.0 - float(i), 0.0, 1.0)
            if segment_progress > 0.0:
                draw_line(corners[i], corners[i].lerp(corners[i + 1], segment_progress), bright, 4.0, true)
        for i in range(4):
            draw_rect(Rect2(corners[i] - Vector2(5, 5), Vector2(10, 10)), bright, false, 2.0)
    else:
        var w: float = 74.0
        var h: float = 58.0
        draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), base, false, 3.0)
        draw_line(Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, h * 0.5), base, 2.0)
        draw_line(Vector2(w * 0.5, -h * 0.5), Vector2(-w * 0.5, h * 0.5), base, 2.0)
        draw_arc(Vector2.ZERO, 43.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, bright, 4.0, true)
    draw_string(ThemeDB.fallback_font, Vector2(-20, -16), "%d%%" % roundi(progress * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 10, bright)
