extends Node2D

const PLAYER_SCRIPT = preload("res://scripts/deadzone_player.gd")
const ZOMBIE_SCRIPT = preload("res://scripts/deadzone_zombie.gd")
const BULLET_SCRIPT = preload("res://scripts/deadzone_bullet.gd")
const TURRET_SCRIPT = preload("res://scripts/deadzone_turret.gd")
const JOYSTICK_SCRIPT = preload("res://scripts/touch_joystick.gd")

const MAPS := ["ROOFTOPS", "CARGO SHIP", "SUBWAY"]
const CLASSES := ["MARKSMAN", "ASSAULT", "TITAN"]
const WEAPONS := ["PISTOL", "SHOTGUN", "RIFLE", "MINIGUN"]
const MAP_RADIUS := 680.0

var player: DeadzonePlayer
var wave := 0
var diamonds := 0
var kills := 0
var damage := 18.0
var fire_rate := 0.30
var fire_timer := 0.0
var spawn_timer := 0.0
var intermission := 4.0
var spawning_left := 0
var wave_active := false
var firing := false
var wave_label: Label
var hp_label: Label
var kill_label: Label
var diamond_label: Label
var status_label: Label
var class_label: Label
var map_label: Label
var fire_button: Button
var upgrade_button: Button
var turret_button: Button
var class_button: Button
var weapon_button: Button
var weapon_label: Label
var _weapon_index := 0
var map_button: Button
var joystick: TouchJoystick
var _game_over := false
var _map_index := 0
var _class_index := 0
var _turret_count := 0
var _arena_root: Node2D
var _camera: Camera2D

func _ready() -> void:
    randomize()
    _build_arena()
    _spawn_player()
    _build_hud()
    _update_hud()
    status_label.text = "SURVIVE THE INCOMING WAVES"
    _start_wave()

func _process(delta: float) -> void:
    if _game_over:
        return
    fire_timer = maxf(0.0, fire_timer - delta)
    if joystick != null and player != null:
        player.move_input = joystick.value
    if wave_active:
        if spawning_left > 0:
            spawn_timer -= delta
            if spawn_timer <= 0.0:
                _spawn_zombie()
                spawning_left -= 1
                spawn_timer = maxf(0.30, 1.0 - float(wave) * 0.025)
        elif get_tree().get_nodes_in_group("zombies").is_empty():
            wave_active = false
            intermission = 5.0
            var reward := 2 + int(wave / 3)
            diamonds += reward
            status_label.text = "WAVE CLEARED  +%d DIAMONDS" % reward
            _update_hud()
    else:
        intermission -= delta
        if intermission <= 0.0:
            _start_wave()
    if firing and fire_timer <= 0.0:
        _shoot()
    if player != null and player.dead:
        _show_game_over()

func _build_arena() -> void:
    _arena_root = Node2D.new()
    _arena_root.name = "Arena"
    add_child(_arena_root)
    var ground := Sprite2D.new()
    ground.texture = PixelArt.file_tex("res://assets/terrain/grass.png")
    ground.centered = true
    ground.region_enabled = true
    ground.region_rect = Rect2(0, 0, 1500, 1500)
    ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    ground.z_index = -20
    _arena_root.add_child(ground)

    var floor := Sprite2D.new()
    floor.texture = PixelArt.file_tex("res://assets/terrain/dirt.png")
    floor.centered = true
    floor.region_enabled = true
    floor.region_rect = Rect2(0, 0, 1120, 1120)
    floor.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    floor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    floor.z_index = -10
    _arena_root.add_child(floor)

    # Original arena dressing uses the project's licensed-status-unknown supplied props.
    for i in range(8):
        var ruin := PixelArt.make_sprite_tex(PixelArt.ruin_tex(i % PixelArt.RUIN_COUNT))
        ruin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        ruin.position = Vector2.from_angle(TAU * float(i) / 8.0) * 505.0
        ruin.scale = Vector2(1.25, 1.25)
        ruin.z_index = -2
        _arena_root.add_child(ruin)

    for i in range(18):
        var stump := PixelArt.make_sprite_tex(PixelArt.file_tex("res://assets/trees/stump_01.png"))
        stump.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        stump.position = Vector2.from_angle(TAU * float(i) / 18.0) * randf_range(565.0, 625.0)
        stump.z_index = -1
        _arena_root.add_child(stump)

    # Four arena walls keep the horde inside the playable zone.
    _add_boundary(Vector2(0, -MAP_RADIUS), Vector2(1400, 28))
    _add_boundary(Vector2(0, MAP_RADIUS), Vector2(1400, 28))
    _add_boundary(Vector2(-MAP_RADIUS, 0), Vector2(28, 1400))
    _add_boundary(Vector2(MAP_RADIUS, 0), Vector2(28, 1400))
    _apply_map_theme()

func _apply_map_theme() -> void:
    if _arena_root == null:
        return
    match _map_index:
        0:
            _arena_root.modulate = Color(0.92, 1.0, 0.90)
        1:
            _arena_root.modulate = Color(0.78, 0.86, 0.92)
        2:
            _arena_root.modulate = Color(0.70, 0.76, 0.82)

func _add_boundary(at: Vector2, dimensions: Vector2) -> void:
    var body := StaticBody2D.new()
    body.position = at
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = dimensions
    shape.shape = rect
    body.add_child(shape)
    _arena_root.add_child(body)

func _spawn_player() -> void:
    player = PLAYER_SCRIPT.new() as DeadzonePlayer
    player.position = Vector2.ZERO
    player.hp_changed.connect(_on_hp_changed)
    player.died.connect(_on_player_died)
    add_child(player)
    _camera = Camera2D.new()
    _camera.position_smoothing_enabled = true
    _camera.position_smoothing_speed = 7.0
    _camera.zoom = Vector2(1.12, 1.12)
    player.add_child(_camera)
    _apply_class()

func _apply_class() -> void:
    if player == null:
        return
    match _class_index:
        0: # Marksman: precision damage and longer reach.
            player.set_class_stats(100.0, 145.0, 1.0)
            damage = 26.0
            fire_rate = 0.42
        1: # Assault: balanced automatic fire.
            player.set_class_stats(110.0, 155.0, 1.0)
            damage = 18.0
            fire_rate = 0.24
        2: # Titan: durable, slower heavy gun.
            player.set_class_stats(180.0, 112.0, 1.0)
            damage = 34.0
            fire_rate = 0.58
    if class_label != null:
        class_label.text = "CLASS  " + CLASSES[_class_index]
    _update_hud()

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.name = "HUD"
    add_child(layer)
    wave_label = _make_label(layer, Vector2(18, 10), Vector2(220, 40), 25)
    hp_label = _make_label(layer, Vector2(18, 48), Vector2(220, 28), 17)
    kill_label = _make_label(layer, Vector2(18, 105), Vector2(180, 26), 16)
    status_label = _make_label(layer, Vector2(250, 12), Vector2(460, 36), 18)
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    map_label = _make_label(layer, Vector2(740, 12), Vector2(205, 26), 14)
    class_label = _make_label(layer, Vector2(740, 40), Vector2(205, 26), 14)
    weapon_label = _make_label(layer, Vector2(740, 68), Vector2(205, 26), 14)

    map_button = _make_button(layer, "MAP", Vector2(740, 98), Vector2(90, 38), _cycle_map)
    class_button = _make_button(layer, "CLASS", Vector2(840, 98), Vector2(100, 38), _cycle_class)
    weapon_button = _make_button(layer, "WEAPON", Vector2(740, 142), Vector2(200, 38), _cycle_weapon)
    upgrade_button = _make_button(layer, "UPGRADE  20♦", Vector2(740, 186), Vector2(200, 42), _buy_upgrade)
    turret_button = _make_button(layer, "TURRET  5♦", Vector2(740, 234), Vector2(200, 42), _buy_turret)

    fire_button = _make_button(layer, "FIRE", Vector2(812, 390), Vector2(128, 112), Callable())
    fire_button.add_theme_font_size_override("font_size", 22)
    fire_button.button_down.connect(_begin_fire)
    fire_button.button_up.connect(_end_fire)
    joystick = JOYSTICK_SCRIPT.new() as TouchJoystick
    joystick.name = "TouchJoystick"
    layer.add_child(joystick)
    _layout_hud()
    get_viewport().size_changed.connect(_layout_hud)

func _make_label(parent: Node, at: Vector2, dimensions: Vector2, font_size: int) -> Label:
    var label := Label.new()
    label.position = at
    label.size = dimensions
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.84))
    label.add_theme_color_override("font_shadow_color", Color(0.03, 0.04, 0.03, 0.95))
    label.add_theme_constant_override("shadow_offset_x", 2)
    label.add_theme_constant_override("shadow_offset_y", 2)
    parent.add_child(label)
    return label

func _make_button(parent: Node, caption: String, at: Vector2, dimensions: Vector2, callback: Callable) -> Button:
    var button := Button.new()
    button.text = caption
    button.position = at
    button.size = dimensions
    button.add_theme_font_size_override("font_size", 14)
    if callback.is_valid():
        button.pressed.connect(callback)
    parent.add_child(button)
    return button

func _begin_fire() -> void:
    firing = true
    fire_button.text = "FIRING"

func _end_fire() -> void:
    firing = false
    fire_button.text = "FIRE"

func _layout_hud() -> void:
    var view_size := get_viewport_rect().size
    var right := view_size.x - 220.0
    wave_label.position = Vector2(18, 10)
    hp_label.position = Vector2(18, 48)
    diamond_label.position = Vector2(18, 78)
    kill_label.position = Vector2(18, 105)
    status_label.position = Vector2((view_size.x - 460.0) * 0.5, 12)
    map_label.position = Vector2(right, 12)
    class_label.position = Vector2(right, 40)
    weapon_label.position = Vector2(right, 68)
    map_button.position = Vector2(right, 98)
    class_button.position = Vector2(right + 100.0, 98)
    weapon_button.position = Vector2(right, 142)
    upgrade_button.position = Vector2(right, 186)
    turret_button.position = Vector2(right, 234)
    fire_button.position = Vector2(view_size.x - 148.0, view_size.y - 150.0)
    joystick.fit_to(view_size)

func _start_wave() -> void:
    wave += 1
    spawning_left = 5 + wave * 3
    if wave >= 20:
        spawning_left += int(wave * 0.75)
    spawn_timer = 0.6
    wave_active = true
    status_label.text = "WAVE %d  —  INCOMING!" % wave
    _update_hud()

func _spawn_zombie() -> void:
    var zombie := ZOMBIE_SCRIPT.new() as DeadzoneZombie
    var angle := randf_range(0.0, TAU)
    zombie.position = Vector2.from_angle(angle) * randf_range(545.0, 630.0)
    zombie.configure(player, wave)
    zombie.killed.connect(_on_zombie_killed)
    add_child(zombie)

func _shoot() -> void:
    if player == null or player.dead:
        return
    var target: Node2D = null
    var best_distance := 570.0 if _class_index == 0 else 470.0
    for enemy in get_tree().get_nodes_in_group("zombies"):
        var d: float = player.global_position.distance_to((enemy as Node2D).global_position)
        if d < best_distance:
            best_distance = d
            target = enemy as Node2D
    if target == null:
        return
    var direction := (target.global_position - player.global_position).normalized()
    player.face_toward(direction)
    match _weapon_index:
        0: # Pistol
            _spawn_bullet(direction, damage * 0.9, 1)
            fire_timer = 0.38
        1: # Shotgun: five pellets in a spread.
            _spawn_bullet(direction, damage * 0.48, 5, 0.24)
            fire_timer = 0.82
        2: # Rifle
            _spawn_bullet(direction, damage * 1.25, 1)
            fire_timer = 0.24
        3: # Minigun
            _spawn_bullet(direction, damage * 0.52, 1)
            fire_timer = 0.085

func _spawn_bullet(direction: Vector2, bullet_damage: float, pellet_count: int, spread: float = 0.0) -> void:
    for i in range(pellet_count):
        var angle_offset := 0.0
        if pellet_count > 1:
            angle_offset = lerpf(-spread * 0.5, spread * 0.5, float(i) / float(pellet_count - 1))
        var shot_direction := direction.rotated(angle_offset)
        var bullet := BULLET_SCRIPT.new() as DeadzoneBullet
        bullet.global_position = player.global_position + shot_direction * 18.0
        bullet.direction = shot_direction
        bullet.damage = bullet_damage
        add_child(bullet)

func _on_zombie_killed(zombie: DeadzoneZombie) -> void:
    kills += 1
    # Kill reward goes straight into the player's diamond wallet.
    diamonds += 1
    _update_hud()

func _buy_upgrade() -> void:
    if diamonds < 20:
        status_label.text = "NOT ENOUGH DIAMONDS"
        return
    diamonds -= 20
    damage += 7.0
    fire_rate = maxf(0.08, fire_rate - 0.025)
    status_label.text = "WEAPON UPGRADED!"
    _update_hud()

func _buy_turret() -> void:
    if diamonds < 5:
        status_label.text = "NEED 5 DIAMONDS"
        return
    if _turret_count >= 3:
        status_label.text = "MAX 3 TURRETS"
        return
    diamonds -= 5
    _turret_count += 1
    var turret: DeadzoneTurret = TURRET_SCRIPT.new() as DeadzoneTurret
    turret.position = player.position + Vector2.from_angle(randf_range(0.0, TAU)) * 75.0
    turret.configure(damage * 0.65, 0.65)
    add_child(turret)
    _update_hud()

func _cycle_class() -> void:
    _class_index = (_class_index + 1) % CLASSES.size()
    _apply_class()
    status_label.text = CLASSES[_class_index] + " CLASS SELECTED"

func _cycle_weapon() -> void:
    _weapon_index = (_weapon_index + 1) % WEAPONS.size()
    weapon_label.text = "WEAPON  " + WEAPONS[_weapon_index]
    status_label.text = WEAPONS[_weapon_index] + " EQUIPPED"

func _cycle_map() -> void:
    _map_index = (_map_index + 1) % MAPS.size()
    map_label.text = "MAP  " + MAPS[_map_index]
    _apply_map_theme()
    status_label.text = MAPS[_map_index] + " ARENA"

func _update_hud() -> void:
    if wave_label == null:
        return
    wave_label.text = "WAVE  %d" % wave
    diamond_label.text = "DIAMONDS  %d" % diamonds
    kill_label.text = "KILLS  %d" % kills
    map_label.text = "MAP  " + MAPS[_map_index]
    class_label.text = "CLASS  " + CLASSES[_class_index]
    weapon_label.text = "WEAPON  " + WEAPONS[_weapon_index]
    upgrade_button.text = "UPGRADE  20♦"
    turret_button.text = "TURRET  5♦"
    if player != null:
        hp_label.text = "HP  %d / %d" % [roundi(player.hp), roundi(player.max_hp)]

func _on_hp_changed(value: float, maximum: float) -> void:
    if hp_label != null:
        hp_label.text = "HP  %d / %d" % [roundi(value), roundi(maximum)]

func _on_player_died() -> void:
    _show_game_over()

func _show_game_over() -> void:
    if _game_over:
        return
    _game_over = true
    wave_active = false
    firing = false
    status_label.text = "YOU WERE OVERRUN  —  WAVE %d" % wave
    fire_button.disabled = true
    upgrade_button.disabled = true
    turret_button.disabled = true
    class_button.disabled = true
    map_button.disabled = true
    weapon_button.disabled = true
    var restart := _make_button($HUD, "PLAY AGAIN", Vector2(390, 285), Vector2(180, 54), _restart_game)
    restart.add_theme_font_size_override("font_size", 20)

func _restart_game() -> void:
    get_tree().reload_current_scene()
