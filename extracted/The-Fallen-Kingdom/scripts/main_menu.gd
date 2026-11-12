extends Control
## Main menu: New Game / Continue / Quit.

const GAME_SCENE: String = "res://scenes/game.tscn"

var _continue_btn: Button
var _status: Label
var _confirm: ConfirmationDialog


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var bg := ColorRect.new()
    bg.color = Color(0.07, 0.06, 0.1)
    add_child(bg)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var center := CenterContainer.new()
    add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    center.add_child(box)

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
    sub.text = "Stage 1 - playable foundation"
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

    _confirm = ConfirmationDialog.new()
    _confirm.dialog_text = "Starting a new game will replace your saved game. Continue?"
    _confirm.ok_button_text = "Replace save"
    _confirm.confirmed.connect(_start_new)
    add_child(_confirm)


func _make_button(parent: Node, text: String) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(260, 54)
    b.add_theme_font_size_override("font_size", 22)
    parent.add_child(b)
    return b


func _on_new_pressed() -> void:
    if SaveManager.has_save():
        _confirm.popup_centered()
    else:
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
