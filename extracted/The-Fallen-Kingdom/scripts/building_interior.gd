extends Node2D
class_name BuildingInterior

var building_type: String = "house"
var building_name: String = "Bangunan"

func _draw() -> void:
    # A simple furnished top-down interior, kept lightweight for web/mobile.
    draw_rect(Rect2(-360, -250, 720, 500), Color("#26343b"))
    draw_rect(Rect2(-345, -235, 690, 470), Color("#c9b99c"))
    for x in range(-320, 321, 64):
        draw_line(Vector2(x, -230), Vector2(x, 230), Color(0.52, 0.43, 0.34, 0.18), 1.0)
    for y in range(-220, 221, 64):
        draw_line(Vector2(-335, y), Vector2(335, y), Color(0.52, 0.43, 0.34, 0.18), 1.0)
    draw_rect(Rect2(-345, -235, 690, 18), Color("#52616a"))
    draw_rect(Rect2(-345, -235, 18, 470), Color("#52616a"))
    draw_rect(Rect2(327, -235, 18, 470), Color("#52616a"))
    draw_rect(Rect2(-345, 217, 290, 18), Color("#52616a"))
    draw_rect(Rect2(55, 217, 290, 18), Color("#52616a"))
    draw_string(ThemeDB.fallback_font, Vector2(0, -190), building_name.to_upper(),
        HORIZONTAL_ALIGNMENT_CENTER, 620, 24, Color("#253640"))
    match building_type:
        "cafe":
            _table(Vector2(-130, -30))
            _table(Vector2(115, -30))
            draw_rect(Rect2(-300, -150, 110, 58), Color("#795443"))
            draw_rect(Rect2(-286, -138, 82, 34), Color("#d6b18a"))
            draw_string(ThemeDB.fallback_font, Vector2(-245, -112), "KAUNTER", HORIZONTAL_ALIGNMENT_CENTER, 80, 11, Color.WHITE)
        "market":
            for x in [-230.0, -80.0, 70.0, 220.0]:
                draw_rect(Rect2(x - 45, -65, 90, 145), Color("#65836d"))
                draw_rect(Rect2(x - 39, -59, 78, 132), Color("#d9d0b2"))
        "clinic":
            draw_rect(Rect2(-300, -130, 170, 75), Color("#e7e9e8"))
            draw_rect(Rect2(-286, -118, 140, 50), Color("#8eb7c2"))
            draw_rect(Rect2(70, -135, 200, 75), Color("#e7e9e8"))
            draw_rect(Rect2(84, -123, 172, 50), Color("#8eb7c2"))
            draw_rect(Rect2(-40, 35, 80, 100), Color("#f2f3ef"))
        "office":
            for y in [-90.0, 35.0]:
                for x in [-220.0, 0.0, 220.0]:
                    draw_rect(Rect2(x - 75, y - 25, 150, 60), Color("#6c7d85"))
                    draw_rect(Rect2(x - 62, y - 16, 124, 42), Color("#b8c7c9"))
                    draw_rect(Rect2(x - 24, y - 9, 48, 24), Color("#344d5b"))
        "apartment":
            draw_rect(Rect2(-270, -125, 190, 90), Color("#7c6555"))
            draw_rect(Rect2(-250, -111, 150, 62), Color("#d9c9b5"))
            draw_rect(Rect2(80, -125, 190, 90), Color("#7c6555"))
            draw_rect(Rect2(100, -111, 150, 62), Color("#d9c9b5"))
            _table(Vector2(0, 70))
        _:
            draw_rect(Rect2(-260, -130, 180, 90), Color("#7c6555"))
            draw_rect(Rect2(-245, -115, 150, 60), Color("#d7c2a4"))
            _table(Vector2(130, -60))
            draw_rect(Rect2(75, 70, 180, 90), Color("#526d78"))
            draw_rect(Rect2(88, 82, 154, 66), Color("#8faeb3"))
    # The exit door is always at the south wall.
    draw_rect(Rect2(-34, 210, 68, 28), Color("#30434e"))
    draw_rect(Rect2(-26, 214, 52, 18), Color("#b9d5d9"))
    draw_string(ThemeDB.fallback_font, Vector2(0, 195), "PINTU KELUAR",
        HORIZONTAL_ALIGNMENT_CENTER, 180, 12, Color("#263640"))

func _table(at: Vector2) -> void:
    draw_rect(Rect2(at.x - 55, at.y - 32, 110, 64), Color("#765541"))
    draw_rect(Rect2(at.x - 46, at.y - 24, 92, 48), Color("#c49b70"))
    draw_rect(Rect2(at.x - 70, at.y - 8, 18, 18), Color("#53636b"))
    draw_rect(Rect2(at.x + 52, at.y - 8, 18, 18), Color("#53636b"))
