extends Node2D
## Wooden scaffold frames arranged as repeated box sections around the build area.

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

func _draw_wood_beam(a: Vector2, b: Vector2, width: float = 9.0) -> void:
    draw_line(a, b, Color("#3d291d"), width + 4.0, true)
    draw_line(a, b, Color("#80502f"), width, true)
    draw_line(a, b, Color("#bd8950"), maxf(2.0, width * 0.2), true)

func _draw_scaffold_box(center: Vector2, rotation: float) -> void:
    var transform := Transform2D(rotation, center)
    var hw: float = 72.0
    var hh: float = 43.0
    var tl: Vector2 = transform * Vector2(-hw, -hh)
    var tr: Vector2 = transform * Vector2(hw, -hh)
    var br: Vector2 = transform * Vector2(hw, hh)
    var bl: Vector2 = transform * Vector2(-hw, hh)

    # Each section is a separate rectangular timber scaffold.
    _draw_wood_beam(tl, tr, 10.0)
    _draw_wood_beam(tr, br, 10.0)
    _draw_wood_beam(br, bl, 10.0)
    _draw_wood_beam(bl, tl, 10.0)

    # A middle rail and a single diagonal brace make the box read clearly.
    _draw_wood_beam((tl + bl) * 0.5, (tr + br) * 0.5, 6.0)
    _draw_wood_beam(tl, br, 6.0)

    for point in [tl, tr, br, bl]:
        draw_rect(Rect2(point - Vector2(6, 6), Vector2(12, 12)), Color("#3d291d"), true)
        draw_rect(Rect2(point - Vector2(3, 3), Vector2(6, 6)), Color("#c18b55"), true)

func _draw() -> void:
    if site_kind == "wall":
        var half: float = 360.0 + float(maxi(1, target_level) - 1) * 180.0
        var side_step: float = (half * 2.0) / 4.0

        # Four separate scaffold boxes on each side, laid out one after another.
        for i in range(4):
            var offset: float = -half + side_step * (float(i) + 0.5)
            _draw_scaffold_box(Vector2(offset, -half), 0.0)
            _draw_scaffold_box(Vector2(half, offset), PI * 0.5)
            _draw_scaffold_box(Vector2(-offset, half), 0.0)
            _draw_scaffold_box(Vector2(-half, -offset), PI * 0.5)
    else:
        _draw_scaffold_box(Vector2.ZERO, 0.0)
