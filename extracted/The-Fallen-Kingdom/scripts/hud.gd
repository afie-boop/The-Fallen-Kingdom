class_name Hud
extends CanvasLayer
## All on-screen UI: status, mobile controls, messages, death and pause panels.
## Holds no gameplay logic - it only emits signals.

signal attack_pressed
signal interact_pressed
signal pause_pressed
signal respawn_requested
signal resume_requested
signal save_requested
signal menu_requested
signal build_menu_requested
signal build_closed
signal build_action(kind: String, action: String)

const BAR_W: float = 170.0

var joystick: TouchJoystick
var attack_button: TouchActionButton
var interact_button: TouchActionButton
var pause_button: TouchActionButton
var touch_ui: bool = false

var _root: Control
var _hp_fill: ColorRect
var _hp_label: Label
var _gold_label: Label
var _wood_label: Label
var _citizen_label: Label
var _prompt_label: Label
var _clock_label: Label
var _msg_label: Label
var _msg_tween: Tween
var _death_panel: Control
var _death_info: Label
var _respawn_btn: Button
var _pause_panel: Control
var _build_btn: Button
var _build_panel: Control
var _build_rows: VBoxContainer
var _build_info: Label
var _build_msg: Label
var build_open: bool = false
var _clock_t: float = 0.0
var _hint_label: Label
var _minimap: GameMiniMap
var _clock_panel: Panel
var _message_panel: Panel
var _prompt_panel: Panel


func _ready() -> void:
    layer = 10
    process_mode = Node.PROCESS_MODE_ALWAYS
    _root = Control.new()
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_root)
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build_status()
    _build_controls()
    _minimap = GameMiniMap.new()
    _minimap.size = Vector2(142, 142)
    _minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(_minimap)
    _build_death_panel()
    _build_pause_panel()
    _build_build_panel()
    _root.resized.connect(_layout)
    _layout()
    _layout.call_deferred()
    GameState.wallet_changed.connect(_on_wallet_changed)
    GameState.inventory_changed.connect(_on_inventory_changed)
    GameState.kingdom_changed.connect(_refresh_resources)
    _refresh_resources()


func _unhandled_input(event: InputEvent) -> void:
    var k := event as InputEventKey
    if k != null and k.pressed and not k.echo:
        if k.physical_keycode == KEY_ESCAPE:
            if build_open:
                build_closed.emit()
            else:
                pause_pressed.emit()
        elif k.physical_keycode == KEY_B:
            if build_open:
                build_closed.emit()
            else:
                build_menu_requested.emit()


func _process(delta: float) -> void:
    _clock_t -= delta
    if _clock_t > 0.0:
        return
    _clock_t = 0.25
    var total_min: int = int(GameState.time_of_day * 24.0 * 60.0)
    var hh: int = floori(total_min / 60.0)
    var mm: int = total_min % 60
    _clock_label.text = "Day %d   %02d:%02d   %s" % [GameState.day_count, hh, mm, "Night" if GameState.is_night else "Day"]


# --- public API --------------------------------------------------------------

func setup_minimap(island: IslandMap, player_node: Node2D, castle_node: Node2D, world_nodes: Node2D, world_size: Vector2) -> void:
    if _minimap != null:
        _minimap.setup(island, player_node, castle_node, world_nodes, world_size)


func update_hp(hp: float, max_hp: float) -> void:
    _hp_fill.size.x = BAR_W * clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
    _hp_label.text = "HP %d / %d" % [int(ceil(hp)), int(max_hp)]


func show_message(text: String, seconds: float = 2.8) -> void:
    _msg_label.text = text
    _msg_label.modulate.a = 1.0
    _message_panel.visible = true
    _message_panel.modulate.a = 1.0
    if _msg_tween != null and _msg_tween.is_valid():
        _msg_tween.kill()
    _msg_tween = create_tween()
    _msg_tween.tween_interval(seconds)
    _msg_tween.tween_property(_msg_label, "modulate:a", 0.0, 0.55)
    _msg_tween.parallel().tween_property(_message_panel, "modulate:a", 0.0, 0.55)


func set_prompt(text: String) -> void:
    var active: bool = text != ""
    _prompt_label.text = ("Press USE / E: " + text) if active else ""
    _prompt_panel.visible = active


func set_interact_available(available: bool) -> void:
    interact_button.modulate.a = 1.0 if available else 0.45


func show_death(delay: float, lost_gold: int) -> void:
    _death_info.text = "You will respawn at your house."
    if lost_gold > 0:
        _death_info.text += "\nYou lost %d Gold Coin(s)." % lost_gold
    _respawn_btn.disabled = true
    _death_panel.visible = true
    await get_tree().create_timer(delay).timeout
    if _death_panel.visible:
        _respawn_btn.disabled = false


func hide_death() -> void:
    _death_panel.visible = false


func show_pause(value: bool) -> void:
    _pause_panel.visible = value


# --- building ----------------------------------------------------------------

func _make_card(parent: Node, pos: Vector2, card_size: Vector2, fill: Color = Color(0.035, 0.045, 0.052, 0.88), border: Color = Color(0.68, 0.55, 0.32, 0.72)) -> Panel:
    var card := Panel.new()
    card.position = pos
    card.size = card_size
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(9)
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
    style.shadow_size = 7
    style.shadow_offset = Vector2(0, 3)
    card.add_theme_stylebox_override("panel", style)
    parent.add_child(card)
    return card


func _button_style(button: Button) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.12, 0.15, 0.16, 0.98)
    normal.border_color = Color(0.55, 0.47, 0.32, 0.9)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(7)
    var hover := StyleBoxFlat.new()
    hover.bg_color = Color(0.20, 0.22, 0.19, 1.0)
    hover.border_color = Color(0.85, 0.68, 0.36, 1.0)
    hover.set_border_width_all(1)
    hover.set_corner_radius_all(7)
    var pressed := StyleBoxFlat.new()
    pressed.bg_color = Color(0.30, 0.22, 0.12, 1.0)
    pressed.border_color = Color(0.92, 0.70, 0.34, 1.0)
    pressed.set_border_width_all(1)
    pressed.set_corner_radius_all(7)
    var disabled := StyleBoxFlat.new()
    disabled.bg_color = Color(0.08, 0.09, 0.09, 0.88)
    disabled.border_color = Color(0.25, 0.27, 0.25, 0.7)
    disabled.set_border_width_all(1)
    disabled.set_corner_radius_all(7)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("disabled", disabled)
    button.add_theme_color_override("font_color", Color(0.93, 0.90, 0.82))
    button.add_theme_color_override("font_hover_color", Color(1.0, 0.91, 0.68))
    button.add_theme_color_override("font_pressed_color", Color(1.0, 0.84, 0.52))
    button.add_theme_color_override("font_disabled_color", Color(0.48, 0.49, 0.46))


func _make_label(parent: Node, text: String, font_size: int) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_outline_color", Color.BLACK)
    l.add_theme_constant_override("outline_size", 5)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(l)
    return l


func _make_rect(color: Color, pos: Vector2, sz: Vector2) -> ColorRect:
    var r := ColorRect.new()
    r.color = color
    r.position = pos
    r.size = sz
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(r)
    return r


func _build_status() -> void:
    _make_card(_root, Vector2(8, 8), Vector2(206, 112))
    _make_rect(Color(0.01, 0.015, 0.018, 0.9), Vector2(20, 21), Vector2(BAR_W + 8.0, 18))
    _hp_fill = _make_rect(Color(0.72, 0.20, 0.16), Vector2(22, 23), Vector2(BAR_W + 4.0, 14))
    _hp_label = _make_label(_root, "HP", 12)
    _hp_label.position = Vector2(26, 20)
    _gold_label = _make_label(_root, "Gold: 0", 16)
    _gold_label.position = Vector2(20, 45)
    _wood_label = _make_label(_root, "Wood: 0", 14)
    _wood_label.position = Vector2(20, 68)
    _citizen_label = _make_label(_root, "Citizens: 0", 14)
    _citizen_label.position = Vector2(20, 89)

    _prompt_panel = _make_card(_root, Vector2.ZERO, Vector2.ZERO, Color(0.025, 0.035, 0.04, 0.9), Color(0.65, 0.54, 0.34, 0.75))
    _prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    _prompt_panel.offset_left = 40.0
    _prompt_panel.offset_right = -40.0
    _prompt_panel.offset_top = -82.0
    _prompt_panel.offset_bottom = -44.0
    _prompt_panel.visible = false
    _prompt_label = _make_label(_root, "", 16)
    _prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _prompt_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    _prompt_label.offset_left = 48.0
    _prompt_label.offset_right = -48.0
    _prompt_label.offset_top = -76.0
    _prompt_label.offset_bottom = -49.0

    _clock_panel = _make_card(_root, Vector2.ZERO, Vector2.ZERO, Color(0.025, 0.035, 0.04, 0.82), Color(0.60, 0.52, 0.36, 0.72))
    _clock_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    _clock_panel.offset_left = -112.0
    _clock_panel.offset_right = 112.0
    _clock_panel.offset_top = 7.0
    _clock_panel.offset_bottom = 39.0
    _clock_label = _make_label(_root, "", 15)
    _clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _clock_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    _clock_label.offset_left = -104.0
    _clock_label.offset_right = 104.0
    _clock_label.offset_top = 10.0
    _clock_label.offset_bottom = 36.0

    _message_panel = _make_card(_root, Vector2.ZERO, Vector2.ZERO, Color(0.025, 0.035, 0.04, 0.92), Color(0.75, 0.60, 0.34, 0.82))
    _message_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    _message_panel.offset_left = 70.0
    _message_panel.offset_right = -70.0
    _message_panel.offset_top = 43.0
    _message_panel.offset_bottom = 78.0
    _message_panel.modulate.a = 0.0
    _message_panel.visible = false
    _msg_label = _make_label(_root, "", 17)
    _msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _msg_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    _msg_label.offset_left = 78.0
    _msg_label.offset_right = -78.0
    _msg_label.offset_top = 47.0
    _msg_label.offset_bottom = 74.0
    _msg_label.modulate.a = 0.0


func _build_controls() -> void:
    touch_ui = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")

    joystick = TouchJoystick.new()
    _root.add_child(joystick)
    joystick.visible = touch_ui

    attack_button = TouchActionButton.new()
    attack_button.label_text = "HIT"
    attack_button.tint = Color(0.60, 0.22, 0.18)
    _root.add_child(attack_button)
    attack_button.visible = touch_ui
    attack_button.pressed.connect(func() -> void: attack_pressed.emit())

    interact_button = TouchActionButton.new()
    interact_button.label_text = "USE"
    interact_button.tint = Color(0.55, 0.43, 0.20)
    _root.add_child(interact_button)
    interact_button.visible = touch_ui
    interact_button.pressed.connect(func() -> void: interact_pressed.emit())
    set_interact_available(false)

    pause_button = TouchActionButton.new()
    pause_button.label_text = "II"
    pause_button.tint = Color(0.28, 0.34, 0.34)
    _root.add_child(pause_button)
    pause_button.pressed.connect(func() -> void: pause_pressed.emit())

    # PC: show keyboard / mouse help instead of the touch controls.
    _hint_label = _make_label(_root, "WASD / Arrows: move     Space or Left Click: attack     E: use     Esc: pause", 14)
    _hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    _hint_label.offset_top = -34.0
    _hint_label.offset_bottom = -8.0
    _hint_label.visible = not touch_ui


## Positions the controls from the real screen size (works for any phone/PC window).
func _layout() -> void:
    if _root == null or joystick == null:
        return
    var vs: Vector2 = _root.size
    var side: float = 26.0
    var bottom: float = 34.0
    joystick.fit_to(vs)
    var a: float = clampf(vs.x * 0.28, 92.0, 116.0)
    attack_button.size = Vector2(a, a)
    attack_button.position = Vector2(vs.x - a - side, vs.y - a - bottom)
    var u: float = clampf(vs.x * 0.22, 72.0, 88.0)
    interact_button.size = Vector2(u, u)
    interact_button.position = Vector2(attack_button.position.x - u * 0.55, attack_button.position.y - u - 12.0)
    pause_button.size = Vector2(48, 48)
    pause_button.position = Vector2(vs.x - 48.0 - 12.0, 10.0)
    var map_size: float = clampf(vs.x * 0.16, 96.0, 142.0)
    if _minimap != null:
        _minimap.position = Vector2(vs.x - map_size - 12.0, 68.0)
        _minimap.size = Vector2(map_size, map_size)
    if _clock_panel != null and _clock_label != null:
        if vs.x < 650.0:
            _clock_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
            _clock_panel.position = Vector2(8.0, 124.0)
            _clock_panel.size = Vector2(206.0, 30.0)
            _clock_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
            _clock_label.position = Vector2(10.0, 126.0)
            _clock_label.size = Vector2(202.0, 24.0)
        else:
            _clock_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
            _clock_panel.offset_left = -112.0
            _clock_panel.offset_right = 112.0
            _clock_panel.offset_top = 7.0
            _clock_panel.offset_bottom = 39.0
            _clock_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
            _clock_label.offset_left = -104.0
            _clock_label.offset_right = 104.0
            _clock_label.offset_top = 10.0
            _clock_label.offset_bottom = 36.0
    if _build_btn != null:
        _build_btn.size = Vector2(104, 42)
        _build_btn.position = Vector2(vs.x - 104.0 - 12.0, 68.0 + map_size + 8.0)


func _make_overlay() -> Array:
    var panel := ColorRect.new()
    panel.color = Color(0, 0, 0, 0.65)
    panel.visible = false
    _root.add_child(panel)
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var center := CenterContainer.new()
    panel.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    center.add_child(box)
    return [panel, box]


func _make_button(parent: Node, text: String) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(240, 54)
    b.add_theme_font_size_override("font_size", 20)
    _button_style(b)
    parent.add_child(b)
    return b


func _build_death_panel() -> void:
    var parts: Array = _make_overlay()
    _death_panel = parts[0]
    var box: VBoxContainer = parts[1]
    var title := _make_label(box, "You died", 36)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", Color(0.9, 0.25, 0.25))
    _death_info = _make_label(box, "", 18)
    _death_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _respawn_btn = _make_button(box, "Respawn at house")
    _respawn_btn.pressed.connect(func() -> void: respawn_requested.emit())


func _build_pause_panel() -> void:
    var parts: Array = _make_overlay()
    _pause_panel = parts[0]
    var box: VBoxContainer = parts[1]
    var title := _make_label(box, "Paused", 36)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _make_button(box, "Resume").pressed.connect(func() -> void: resume_requested.emit())
    _make_button(box, "Save game").pressed.connect(func() -> void: save_requested.emit())
    _make_button(box, "Save and quit to menu").pressed.connect(func() -> void: menu_requested.emit())


func show_build(rows: Array, info: String, message: String) -> void:
    build_open = true
    _build_panel.visible = true
    _build_info.text = info
    _build_msg.text = message
    for child in _build_rows.get_children():
        child.queue_free()
    for r in rows:
        var row: Dictionary = r
        var h := HBoxContainer.new()
        h.add_theme_constant_override("separation", 10)
        var txt := Label.new()
        txt.text = "%s\n%s" % [row["title"], row["info"]]
        var row_button_width: float = clampf(get_viewport_rect().size.x * 0.30, 112.0, 190.0)
        var row_text_width: float = clampf(get_viewport_rect().size.x - row_button_width - 80.0, 130.0, 330.0)
        txt.custom_minimum_size = Vector2(row_text_width, 0)
        txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        txt.add_theme_font_size_override("font_size", 14)
        h.add_child(txt)
        var b := Button.new()
        b.text = str(row["button"])
        b.disabled = not bool(row["enabled"])
        b.custom_minimum_size = Vector2(190, 52)
        b.add_theme_font_size_override("font_size", 15)
        b.custom_minimum_size = Vector2(row_button_width, 48.0)
        _button_style(b)
        b.pressed.connect(_on_build_pressed.bind(str(row["kind"]), str(row["action"])))
        h.add_child(b)
        _build_rows.add_child(h)
    _refresh_resources()


func hide_build() -> void:
    build_open = false
    _build_panel.visible = false


func _on_build_pressed(kind: String, action: String) -> void:
    build_action.emit(kind, action)


func _build_build_panel() -> void:
    _build_btn = Button.new()
    _build_btn.text = "BUILD"
    _build_btn.add_theme_font_size_override("font_size", 17)
    _button_style(_build_btn)
    _root.add_child(_build_btn)
    _build_btn.pressed.connect(func() -> void: build_menu_requested.emit())

    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.72)
    dim.visible = false
    _root.add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build_panel = dim
    var center := CenterContainer.new()
    dim.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var frame := PanelContainer.new()
    var frame_style := StyleBoxFlat.new()
    frame_style.bg_color = Color(0.055, 0.067, 0.065, 0.98)
    frame_style.border_color = Color(0.64, 0.52, 0.31, 0.95)
    frame_style.set_border_width_all(1)
    frame_style.set_corner_radius_all(12)
    frame_style.shadow_color = Color(0, 0, 0, 0.42)
    frame_style.shadow_size = 12
    frame.add_theme_stylebox_override("panel", frame_style)
    center.add_child(frame)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 8)
    frame.add_child(box)
    var title := Label.new()
    title.text = "Kingdom - Build and Upgrade"
    title.add_theme_font_size_override("font_size", 24)
    box.add_child(title)
    _build_info = Label.new()
    _build_info.add_theme_font_size_override("font_size", 14)
    box.add_child(_build_info)
    _build_msg = Label.new()
    _build_msg.add_theme_font_size_override("font_size", 15)
    _build_msg.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
    box.add_child(_build_msg)
    var scroll := ScrollContainer.new()
    var screen_size: Vector2 = get_viewport_rect().size
    scroll.custom_minimum_size = Vector2(clampf(screen_size.x - 38.0, 310.0, 580.0), clampf(screen_size.y * 0.48, 170.0, 270.0))
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    box.add_child(scroll)
    _build_rows = VBoxContainer.new()
    _build_rows.add_theme_constant_override("separation", 8)
    _build_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(_build_rows)
    var close := Button.new()
    close.text = "Close"
    close.custom_minimum_size = Vector2(0, 46)
    close.add_theme_font_size_override("font_size", 17)
    _button_style(close)
    close.pressed.connect(func() -> void: build_closed.emit())
    box.add_child(close)


func _on_wallet_changed(_id: int, _amount: int) -> void:
    _refresh_resources()


func _on_inventory_changed(_id: int) -> void:
    _refresh_resources()


func _refresh_resources() -> void:
    _gold_label.text = "Gold: %d" % GameState.get_gold()
    _citizen_label.text = "Citizens: %d" % GameState.recruited_beggars.size()
    _wood_label.text = "Wood: %d  (kingdom: %d)" % [GameState.get_item("wood"), int(GameState.kingdom_resources.get("wood", 0))]
