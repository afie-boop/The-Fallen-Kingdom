class_name DayNight
extends CanvasModulate
## Day/night cycle. t: 0.0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset.

signal day_started
signal night_started
signal new_day(day: int)

var t: float = 0.3
var _grad: Gradient


func _ready() -> void:
    _grad = Gradient.new()
    _grad.set_offset(0, 0.0)
    _grad.set_color(0, Color(0.16, 0.18, 0.38))
    _grad.set_offset(1, 1.0)
    _grad.set_color(1, Color(0.16, 0.18, 0.38))
    _grad.add_point(0.2, Color(0.16, 0.18, 0.38))
    _grad.add_point(0.28, Color(0.95, 0.75, 0.65))
    _grad.add_point(0.36, Color(1, 1, 1))
    _grad.add_point(0.64, Color(1, 1, 1))
    _grad.add_point(0.72, Color(0.98, 0.65, 0.5))
    _grad.add_point(0.8, Color(0.16, 0.18, 0.38))
    set_time(t)


func set_time(value: float) -> void:
    t = clampf(value, 0.0, 0.9999)
    GameState.time_of_day = t
    GameState.is_night = _is_night(t)
    if _grad != null:
        color = _grad.sample(t)


func _is_night(v: float) -> bool:
    return v < 0.22 or v > 0.78


func _process(delta: float) -> void:
    t += delta / maxf(1.0, GameConfig.day_length_seconds)
    if t >= 1.0:
        t -= 1.0
        GameState.day_count += 1
        new_day.emit(GameState.day_count)
    var was_night: bool = GameState.is_night
    set_time(t)
    if was_night and not GameState.is_night:
        day_started.emit()
    elif not was_night and GameState.is_night:
        night_started.emit()
