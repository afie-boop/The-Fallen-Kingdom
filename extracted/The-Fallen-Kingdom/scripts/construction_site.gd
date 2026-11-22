extends Node2D
## Compact timber scaffold sections sized to match the kingdom fence segments.

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
    if site_kind == "employment":
        add_to_group("employment_scaffolds")
    queue_redraw()

func work_on_site(delta: float) -> bool:
    work_done = minf(work_required, work_done + delta)
    if work_done >= work_required:
        finished.emit(self)
        queue_free()
        return true
    return false

func _draw_wood_beam(a: Vector2, b: Vector2, width: float = 5.0) -> void:
    draw_line(a, b, Color("#3d291d"), width + 3.0, true)
    draw_line(a, b, Color("#80502f"), width, true)
    draw_line(a, b, Color("#bd8950"), maxf(1.0, width * 0.18), true)

func _draw_fence_frame(center: Vector2, horizontal: bool) -> void:
    # A compact box section matches the 64 px fence module; neighbouring
    # sections touch edge-to-edge with no visible spacing.
    var transform := Transform2D(0.0 if horizontal else PI * 0.5, center)
    var half_w: float = 32.0
    var half_h: float = 10.0
    var tl: Vector2 = transform * Vector2(-half_w, -half_h)
    var tr: Vector2 = transform * Vector2(half_w, -half_h)
    var br: Vector2 = transform * Vector2(half_w, half_h)
    var bl: Vector2 = transform * Vector2(-half_w, half_h)
    _draw_wood_beam(tl, tr, 5.0)
    _draw_wood_beam(tr, br, 5.0)
    _draw_wood_beam(br, bl, 5.0)
    _draw_wood_beam(bl, tl, 5.0)
    _draw_wood_beam((tl + bl) * 0.5, (tr + br) * 0.5, 3.0)
    for point in [tl, tr, br, bl]:
        draw_rect(Rect2(point - Vector2(3, 3), Vector2(6, 6)), Color("#bd8950"))

func _draw_employment_frame() -> void:
    # Small independent stall-sized frame; created automatically with the
    # campfire job/equipment racks and does not require a Builder.
    var tl := Vector2(-38.0, -48.0)
    var tr := Vector2(38.0, -48.0)
    var br := Vector2(38.0, 4.0)
    var bl := Vector2(-38.0, 4.0)
    _draw_wood_beam(tl, tr, 6.0)
    _draw_wood_beam(tr, br, 6.0)
    _draw_wood_beam(br, bl, 6.0)
    _draw_wood_beam(bl, tl, 6.0)
    _draw_wood_beam(tl, br, 4.0)
    _draw_wood_beam(tr, bl, 4.0)
    for point in [tl, tr, br, bl]:
        draw_rect(Rect2(point - Vector2(4, 4), Vector2(8, 8)), Color("#bd8950"))

func _draw() -> void:
    if site_kind == "wall":
        var half: float = 360.0 + float(maxi(1, target_level) - 1) * 180.0
        var side_length: float = half * 2.0
        var segment_count: int = ceili(side_length / 64.0)
        var step: float = side_length / float(segment_count)
        for i in range(segment_count):
            var offset: float = -half + (float(i) + 0.5) * step
            _draw_fence_frame(Vector2(offset, -half), true)
            _draw_fence_frame(Vector2(half, offset), false)
            _draw_fence_frame(Vector2(-offset, half), true)
            _draw_fence_frame(Vector2(-half, -offset), false)
    elif site_kind == "employment":
        _draw_employment_frame()
    else:
        _draw_employment_frame()
