extends Node2D
## Temporary wooden construction frame. Pieces appear one by one as the builder works.

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

func _draw_wood_beam(a: Vector2, b: Vector2, width: float = 12.0) -> void:
    draw_line(a, b, Color("#4d3423"), width + 6.0, true)
    draw_line(a, b, Color("#895638"), width, true)
    draw_line(a, b, Color("#c18b55"), maxf(2.0, width * 0.18), true)

func _piece_visible(index: int, total: int) -> bool:
    var progress: float = clampf(work_done / maxf(0.01, work_required), 0.0, 1.0)
    return progress >= float(index + 1) / float(total)

func _draw() -> void:
    if site_kind == "wall":
        var half: float = 360.0 + float(maxi(1, target_level) - 1) * 180.0
        var brace: float = minf(150.0, half * 0.28)
        var tl := Vector2(-half, -half)
        var tr := Vector2(half, -half)
        var br := Vector2(half, half)
        var bl := Vector2(-half, half)

        # Outer square beams are placed one at a time.
        var outer_a: Array[Vector2] = [tl, tr, br, bl]
        var outer_b: Array[Vector2] = [tr, br, bl, tl]
        for i in range(4):
            if _piece_visible(i, 16):
                _draw_wood_beam(outer_a[i], outer_b[i], 16.0)

        # Inner rails are added individually after the outer frame.
        var inset: float = 24.0
        var itl := Vector2(-half + inset, -half + inset)
        var itr := Vector2(half - inset, -half + inset)
        var ibr := Vector2(half - inset, half - inset)
        var ibl := Vector2(-half + inset, half - inset)
        var inner_a: Array[Vector2] = [itl, itr, ibr, ibl]
        var inner_b: Array[Vector2] = [itr, ibr, ibl, itl]
        for i in range(4):
            if _piece_visible(i + 4, 16):
                _draw_wood_beam(inner_a[i], inner_b[i], 6.0)

        # Diagonal braces are installed one corner at a time.
        var brace_a: Array[Vector2] = [
            Vector2(-half + brace, -half + 4.0),
            Vector2(half - brace, -half + 4.0),
            Vector2(half - 4.0, half - brace),
            Vector2(-half + 4.0, half - brace)
        ]
        var brace_b: Array[Vector2] = [
            Vector2(-half + 4.0, -half + brace),
            Vector2(half - 4.0, -half + brace),
            Vector2(half - brace, half - 4.0),
            Vector2(-half + brace, half - 4.0)
        ]
        for i in range(4):
            if _piece_visible(i + 8, 16):
                _draw_wood_beam(brace_a[i], brace_b[i], 13.0)

        # Corner joints finish the frame one by one.
        var corners: Array[Vector2] = [tl, tr, br, bl]
        for i in range(4):
            if _piece_visible(i + 12, 16):
                var corner: Vector2 = corners[i]
                draw_rect(Rect2(corner - Vector2(12, 12), Vector2(24, 24)), Color("#4d3423"), true)
                draw_rect(Rect2(corner - Vector2(8, 8), Vector2(16, 16)), Color("#bd8950"), true)
    else:
        var w: float = 74.0
        var h: float = 58.0
        var tl := Vector2(-w * 0.5, -h * 0.5)
        var tr := Vector2(w * 0.5, -h * 0.5)
        var br := Vector2(w * 0.5, h * 0.5)
        var bl := Vector2(-w * 0.5, h * 0.5)
        var beam_a: Array[Vector2] = [
            tl, tr, br, bl,
            tl + Vector2(18, 0), tr + Vector2(-18, 0),
            br + Vector2(0, -18), bl + Vector2(0, -18)
        ]
        var beam_b: Array[Vector2] = [
            tr, br, bl, tl,
            tl + Vector2(0, 18), tr + Vector2(0, 18),
            br + Vector2(-18, 0), bl + Vector2(18, 0)
        ]
        for i in range(8):
            if _piece_visible(i, 8):
                _draw_wood_beam(beam_a[i], beam_b[i], 8.0 if i < 4 else 7.0)
