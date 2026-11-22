extends Control
## Main menu: New Game / Continue / Quit.

const GAME_SCENE: String = "res://scenes/game.tscn"

var _continue_btn: Button
var _status: Label


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var bg := ColorRect.new()
    bg.color = Color(0.035, 0.045, 0.06)
    add_child(bg)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var center := CenterContainer.new()
    add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var frame := PanelContainer.new()
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.055, 0.072, 0.075, 0.94)
    panel_style.border_color = Color(0.68, 0.55, 0.31, 0.88)
    panel_style.set_border_width_all(1)
    panel_style.set_corner_radius_all(14)
    panel_style.shadow_color = Color(0, 0, 0, 0.48)
    panel_style.shadow_size = 18
    frame.add_theme_stylebox_override("panel", panel_style)
    center.add_child(frame)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 11)
    box.custom_minimum_size = Vector2(330, 0)
    frame.add_child(box)

    var art := TextureRect.new()
    art.texture = PixelArt.ruin_tex(2)
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    art.custom_minimum_size = Vector2(128, 128)
    box.add_child(art)

    var title := Label.new()
    title.text = "THE FALLEN KINGDOM"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 40)
    title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3))
    box.add_child(title)

    var sub := Label.new()
    sub.text = "A kingdom lost. A home worth defending."
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
    box.add_child(sub)

    _make_button(box, "New Game").pressed.connect(_on_new_pressed)
    _continue_btn = _make_button(box, "Continue")
    _continue_btn.pressed.connect(_on_continue_pressed)
    _continue_btn.disabled = not SaveManager.has_save()
    _make_button(box, "Quit").pressed.connect(func() -> void: get_tree().quit())

    _status = Label.new()
    _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status.add_theme_color_override("font_color", Color(1, 0.6, 0.5))
    box.add_child(_status)

    var ver := Label.new()
    ver.text = "v%s" % GameConfig.GAME_VERSION
    ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ver.add_theme_font_size_override("font_size", 12)
    ver.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
    box.add_child(ver)



func _make_button(parent: Node, text: String) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(260, 54)
    b.add_theme_font_size_override("font_size", 20)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.12, 0.15, 0.16, 0.98)
    normal.border_color = Color(0.52, 0.46, 0.33, 0.95)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(8)
    var hover := StyleBoxFlat.new()
    hover.bg_color = Color(0.20, 0.22, 0.18, 1.0)
    hover.border_color = Color(0.90, 0.70, 0.36, 1.0)
    hover.set_border_width_all(1)
    hover.set_corner_radius_all(8)
    var pressed := StyleBoxFlat.new()
    pressed.bg_color = Color(0.30, 0.23, 0.13, 1.0)
    pressed.border_color = Color(0.95, 0.75, 0.40, 1.0)
    pressed.set_border_width_all(1)
    pressed.set_corner_radius_all(8)
    b.add_theme_stylebox_override("normal", normal)
    b.add_theme_stylebox_override("hover", hover)
    b.add_theme_stylebox_override("pressed", pressed)
    b.add_theme_color_override("font_color", Color(0.94, 0.91, 0.83))
    b.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.70))
    parent.add_child(b)
    return b


func _on_new_pressed() -> void:
    # New Game starts immediately; there is no separate Create/overwrite screen.
    _start_new()


func _start_new() -> void:
    GameState.reset_new_game()
    _go()


func _on_continue_pressed() -> void:
    var data: Dictionary = SaveManager.load_game()
    if data.is_empty():
        _status.text = "Save file is missing or damaged."
        _continue_btn.disabled = true
        return
    GameState.from_dict(data)
    _go()


func _go() -> void:
    _status.text = "Loading..."
    get_tree().change_scene_to_file(GAME_SCENE)


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        get_tree().quit()
