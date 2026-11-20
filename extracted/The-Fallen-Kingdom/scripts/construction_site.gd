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

func _draw_wood_beam(a: Vector2, b: Vector2, width: float = 12.0) -> void:
    draw_line(a, b, Color("#4d3423"), width + 6.0, true)
    draw_line(a, b, Color("#895638"), width, true)
    draw_line(a, b, Color("#c18b55"), maxf(2.0, width * 0.18), true)

func _draw() -> void:
    if site_kind == "wall":
        var half: float = 360.0 + float(maxi(1, target_level) - 1) * 180.0
        var brace: float = minf(150.0, half * 0.28)
        var tl := Vector2(-half, -half)
        var tr := Vector2(half, -half)
        var br := Vector2(half, half)
        var bl := Vector2(-half, half)

        # Main square timber frame.
        _draw_wood_beam(tl, tr, 16.0)
        _draw_wood_beam(tr, br, 16.0)
        _draw_wood_beam(br, bl, 16.0)
        _draw_wood_beam(bl, tl, 16.0)

        # Inner parallel rails give the frame a solid, built-up wooden edge.
        var inset: float = 24.0
        var itl := Vector2(-half + inset, -half + inset)
        var itr := Vector2(half - inset, -half + inset)
        var ibr := Vector2(half - inset, half - inset)
        var ibl := Vector2(-half + inset, half - inset)
        _draw_wood_beam(itl, itr, 6.0)
        _draw_wood_beam(itr, ibr, 6.0)
        _draw_wood_beam(ibr, ibl, 6.0)
        _draw_wood_beam(ibl, itl, 6.0)

        # Diagonal wooden braces at all four corners, like a timber building frame.
        _draw_wood_beam(Vector2(-half + brace, -half + 4.0), Vector2(-half + 4.0, -half + brace), 13.0)
        _draw_wood_beam(Vector2(half - brace, -half + 4.0), Vector2(half - 4.0, -half + brace), 13.0)
        _draw_wood_beam(Vector2(half - 4.0, half - brace), Vector2(half - brace, half - 4.0), 13.0)
        _draw_wood_beam(Vector2(-half + 4.0, half - brace), Vector2(-half + brace, half - 4.0), 13.0)

        # Reinforced wooden corner joints.
        for corner in [tl, tr, br, bl]:
            draw_rect(Rect2(corner - Vector2(12, 12), Vector2(24, 24)), Color("#4d3423"), true)
            draw_rect(Rect2(corner - Vector2(8, 8), Vector2(16, 16)), Color("#bd8950"), true)
    else:
        var w: float = 74.0
        var h: float = 58.0
        var tl := Vector2(-w * 0.5, -h * 0.5)
        var tr := Vector2(w * 0.5, -h * 0.5)
        var br := Vector2(w * 0.5, h * 0.5)
        var bl := Vector2(-w * 0.5, h * 0.5)
        _draw_wood_beam(tl, tr, 8.0)
        _draw_wood_beam(tr, br, 8.0)
        _draw_wood_beam(br, bl, 8.0)
        _draw_wood_beam(bl, tl, 8.0)
        _draw_wood_beam(tl + Vector2(18, 0), tl + Vector2(0, 18), 7.0)
        _draw_wood_beam(tr + Vector2(-18, 0), tr + Vector2(0, 18), 7.0)
        _draw_wood_beam(br + Vector2(0, -18), br + Vector2(-18, 0), 7.0)
        _draw_wood_beam(bl + Vector2(0, -18), bl + Vector2(18, 0), 7.0)
