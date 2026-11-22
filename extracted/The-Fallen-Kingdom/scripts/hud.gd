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
signal settings_changed(zoom: float, chunk_distance: int, quality: int)

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
var _settings_panel: Control
var _zoom_slider: HSlider
var _chunk_slider: HSlider
var _quality_select: OptionButton
var _zoom_value_label: Label
var _chunk_value_label: Label
var _build_btn: Button
var _build_panel: Control
var _build_rows: VBoxContainer
var _build_info: Label
var _build_msg: Label
var build_open: bool = false
var _clock_t: float = 0.0
var _hint_label: Label
var _minimap: GameMiniMap
var _minimap_overlay: ColorRect
var _minimap_close_btn: Button
var _minimap_open: bool = false


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
    _minimap.mouse_filter = Control.MOUSE_FILTER_STOP
    _minimap.gui_input.connect(_on_minimap_gui_input)
    _root.add_child(_minimap)
    _minimap_overlay = ColorRect.new()
    _minimap_overlay.color = Color(0, 0, 0, 0.78)
    _minimap_overlay.visible = false
    _minimap_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _minimap_overlay.gui_input.connect(_on_minimap_overlay_input)
    _root.add_child(_minimap_overlay)
    _minimap_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _minimap_overlay.z_index = 5
    _minimap.z_index = 6
    _minimap_close_btn = Button.new()
    _minimap_close_btn.text = "CLOSE MAP"
    _minimap_close_btn.custom_minimum_size = Vector2(130, 44)
    _minimap_close_btn.visible = false
    _minimap_close_btn.z_index = 7
    _root.add_child(_minimap_close_btn)
    _minimap_close_btn.pressed.connect(_close_minimap)
    _build_death_panel()
    _build_pause_panel()
    _build_settings_panel()
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
    if _msg_tween != null and _msg_tween.is_valid():
        _msg_tween.kill()
    _msg_tween = create_tween()
    _msg_tween.tween_interval(seconds)
    _msg_tween.tween_property(_msg_label, "modulate:a", 0.0, 0.6)


func set_prompt(text: String) -> void:
    _prompt_label.text = ("Press USE / E: " + text) if text != "" else ""


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
    _settings_panel.visible = false
    _pause_panel.visible = value


func set_settings_values(zoom: float, chunk_distance: int, quality: int) -> void:
    _zoom_slider.value = zoom
    _chunk_slider.value = chunk_distance
    _quality_select.select(clampi(quality, 0, 2))
    _update_settings_labels()


func _open_settings() -> void:
    _pause_panel.visible = false
    _settings_panel.visible = true


func _close_settings() -> void:
    _settings_panel.visible = false
    _pause_panel.visible = true


func _update_settings_labels() -> void:
    _zoom_value_label.text = "%.2fx" % _zoom_slider.value
    _chunk_value_label.text = "%d chunks" % int(_chunk_slider.value)


func _apply_settings() -> void:
    settings_changed.emit(float(_zoom_slider.value), int(_chunk_slider.value), _quality_select.selected)
    _close_settings()


# --- building ----------------------------------------------------------------

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
    _make_rect(Color(0, 0, 0, 0.55), Vector2(12, 12), Vector2(BAR_W + 4.0, 20))
    _hp_fill = _make_rect(Color(0.8, 0.15, 0.15), Vector2(14, 14), Vector2(BAR_W, 16))
    _hp_label = _make_label(_root, "HP", 13)
    _hp_label.position = Vector2(18, 12)
    _gold_label = _make_label(_root, "Gold: 0", 17)
    _gold_label.position = Vector2(12, 36)
    _wood_label = _make_label(_root, "Wood: 0", 15)
    _wood_label.position = Vector2(12, 60)
    _citizen_label = _make_label(_root, "Citizens: 0", 15)
    _citizen_label.position = Vector2(12, 82)
    _prompt_label = _make_label(_root, "", 17)
    _prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _prompt_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    _prompt_label.offset_top = -78.0
    _prompt_label.offset_bottom = -52.0
    _clock_label = _make_label(_root, "", 16)
    _clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _clock_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    _clock_label.offset_top = 10.0
    _msg_label = _make_label(_root, "", 18)
    _msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _msg_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    _msg_label.offset_top = 44.0
    _msg_label.modulate.a = 0.0


func _build_controls() -> void:
    touch_ui = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")

    joystick = TouchJoystick.new()
    _root.add_child(joystick)
    joystick.visible = touch_ui

    attack_button = TouchActionButton.new()
    attack_button.label_text = "HIT"
    _root.add_child(attack_button)
    attack_button.visible = touch_ui
    attack_button.pressed.connect(func() -> void: attack_pressed.emit())

    interact_button = TouchActionButton.new()
    interact_button.label_text = "USE"
    _root.add_child(interact_button)
    interact_button.visible = touch_ui
    interact_button.pressed.connect(func() -> void: interact_pressed.emit())
    set_interact_available(false)

    pause_button = TouchActionButton.new()
    pause_button.label_text = "II"
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
    var side: float = 44.0
    var bottom: float = 58.0
    joystick.fit_to(vs)
    var a: float = 116.0
    attack_button.size = Vector2(a, a)
    attack_button.position = Vector2(vs.x - a - side, vs.y - a - bottom)
    var u: float = 88.0
    interact_button.size = Vector2(u, u)
    interact_button.position = Vector2(attack_button.position.x - u * 0.6, attack_button.position.y - u - 18.0)
    pause_button.size = Vector2(52, 52)
    pause_button.position = Vector2(vs.x - 52.0 - 14.0, 10.0)
    if _minimap != null:
        if _minimap_open:
            var map_side: float = maxf(180.0, minf(vs.x - 36.0, vs.y - 120.0))
            map_side = minf(map_side, 560.0)
            _minimap.size = Vector2(map_side, map_side)
            _minimap.position = (vs - _minimap.size) * 0.5
            _minimap_overlay.size = vs
            _minimap_close_btn.position = Vector2((vs.x - 130.0) * 0.5, _minimap.position.y + map_side + 12.0)
        else:
            _minimap.position = Vector2(vs.x - 156.0, 72.0)
            _minimap.size = Vector2(142.0, 142.0)
    if _build_btn != null:
        _build_btn.size = Vector2(96, 44)
        var build_y: float = minf(224.0, vs.y - 56.0)
        _build_btn.position = Vector2(vs.x - 96.0 - 12.0, maxf(72.0, build_y))


func _on_minimap_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _open_minimap()
        _minimap.accept_event()
    elif event is InputEventScreenTouch and event.pressed:
        _open_minimap()
        _minimap.accept_event()


func _on_minimap_overlay_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _close_minimap()
    elif event is InputEventScreenTouch and event.pressed:
        _close_minimap()


func _open_minimap() -> void:
    if _minimap_open:
        return
    _minimap_open = true
    _minimap_overlay.visible = true
    _minimap_close_btn.visible = true
    _layout()


func _close_minimap() -> void:
    if not _minimap_open:
        return
    _minimap_open = false
    _minimap_overlay.visible = false
    _minimap_close_btn.visible = false
    _layout()


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
    _make_button(box, "Settings").pressed.connect(_open_settings)
    _make_button(box, "Save game").pressed.connect(func() -> void: save_requested.emit())
    _make_button(box, "Save and quit to menu").pressed.connect(func() -> void: menu_requested.emit())


func _build_settings_panel() -> void:
    var parts: Array = _make_overlay()
    _settings_panel = parts[0]
    var box: VBoxContainer = parts[1]
    var title := _make_label(box, "Settings", 30)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    box.add_child(_make_label(box, "Camera Zoom", 17))
    var zoom_row := HBoxContainer.new()
    box.add_child(zoom_row)
    _zoom_slider = HSlider.new()
    _zoom_slider.min_value = 0.7
    _zoom_slider.max_value = 1.6
    _zoom_slider.step = 0.05
    _zoom_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    zoom_row.add_child(_zoom_slider)
    _zoom_value_label = _make_label(zoom_row, "1.00x", 16)
    _zoom_slider.value_changed.connect(func(_v: float) -> void: _update_settings_labels())

    box.add_child(_make_label(box, "Chunk Render Distance", 17))
    var chunk_row := HBoxContainer.new()
    box.add_child(chunk_row)
    _chunk_slider = HSlider.new()
    _chunk_slider.min_value = 1
    _chunk_slider.max_value = 6
    _chunk_slider.step = 1
    _chunk_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    chunk_row.add_child(_chunk_slider)
    _chunk_value_label = _make_label(chunk_row, "3 chunks", 16)
    _chunk_slider.value_changed.connect(func(_v: float) -> void: _update_settings_labels())

    box.add_child(_make_label(box, "Graphics Quality", 17))
    _quality_select = OptionButton.new()
    _quality_select.add_item("Low")
    _quality_select.add_item("Medium")
    _quality_select.add_item("High")
    _quality_select.custom_minimum_size = Vector2(240, 44)
    box.add_child(_quality_select)

    _make_button(box, "Apply").pressed.connect(_apply_settings)
    _make_button(box, "Back").pressed.connect(_close_settings)
    _settings_panel.visible = false


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
        txt.custom_minimum_size = Vector2(330, 0)
        txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        txt.add_theme_font_size_override("font_size", 14)
        h.add_child(txt)
        var b := Button.new()
        b.text = str(row["button"])
        b.disabled = not bool(row["enabled"])
        b.custom_minimum_size = Vector2(190, 52)
        b.add_theme_font_size_override("font_size", 16)
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
    _build_btn.add_theme_font_size_override("font_size", 18)
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
    scroll.custom_minimum_size = Vector2(580, 270)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    box.add_child(scroll)
    _build_rows = VBoxContainer.new()
    _build_rows.add_theme_constant_override("separation", 8)
    _build_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(_build_rows)
    var close := Button.new()
    close.text = "Close"
    close.custom_minimum_size = Vector2(0, 46)
    close.add_theme_font_size_override("font_size", 18)
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
