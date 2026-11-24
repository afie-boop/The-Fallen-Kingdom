extends Node2D

const PLAYER_SCRIPT = preload("res://scripts/deadzone_player.gd")
const ZOMBIE_SCRIPT = preload("res://scripts/deadzone_zombie.gd")
const BULLET_SCRIPT = preload("res://scripts/deadzone_bullet.gd")
const JOYSTICK_SCRIPT = preload("res://scripts/touch_joystick.gd")

var player: DeadzonePlayer
var wave: int = 0
var coins: int = 0
var kills: int = 0
var damage: float = 18.0
var fire_rate: float = 0.28
var fire_timer: float = 0.0
var spawn_timer: float = 0.0
var intermission: float = 4.0
var spawning_left: int = 0
var wave_active: bool = false
var firing: bool = false
var aim_position: Vector2 = Vector2.ZERO
var wave_label: Label
var hp_label: Label
var coin_label: Label
var kill_label: Label
var status_label: Label
var fire_button: Button
var upgrade_button: Button
var joystick: TouchJoystick
var _game_over: bool = false

func _ready() -> void:
    randomize()
    _build_arena()
    _spawn_player()
    _build_hud()
    _update_hud()
    status_label.text = "GET READY"
    
func _process(delta: float) -> void:
    if _game_over:
        return
    fire_timer = maxf(0.0, fire_timer - delta)
    if wave_active:
        if spawning_left > 0:
            spawn_timer -= delta
            if spawn_timer <= 0.0:
                _spawn_zombie()
                spawning_left -= 1
                spawn_timer = maxf(0.32, 1.05 - float(wave) * 0.035)
        elif get_tree().get_nodes_in_group("zombies").is_empty():
            wave_active = false
            intermission = 5.0
            coins += 20 + wave * 5
            status_label.text = "WAVE CLEARED  +%d COINS" % (20 + wave * 5)
            _update_hud()
    else:
        intermission -= delta
        if intermission <= 0.0:
            _start_wave()
    if firing and fire_timer <= 0.0:
        _shoot()
    if player != null and player.dead:
        _game_over = true
        status_label.text = "YOU WERE OVERRUN"
        fire_button.disabled = true
        upgrade_button.disabled = true
        var restart := Button.new()
        restart.text = "PLAY AGAIN"
        restart.position = Vector2(390, 290)
        restart.size = Vector2(180, 54)
        restart.add_theme_font_size_override("font_size", 20)
        restart.pressed.connect(_restart_game)
        $HUD.add_child(restart)

func _build_arena() -> void:
    var ground := Sprite2D.new()
    ground.texture = PixelArt.file_tex("res://assets/terrain/grass.png")
    ground.centered = true
    ground.region_enabled = true
    ground.region_rect = Rect2(0, 0, 1500, 1500)
    ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    ground.z_index = -20
    add_child(ground)
    var arena := Sprite2D.new()
    arena.texture = PixelArt.file_tex("res://assets/terrain/dirt.png")
    arena.centered = true
    arena.region_enabled = true
    arena.region_rect = Rect2(0, 0, 1160, 1160)
    arena.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    arena.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    arena.z_index = -10
    add_child(arena)
    # Ruined structures and dead trees dress the combat zone using the project's pixel-art assets.
    for i in 8:
        var ruin := Sprite2D.new()
        ruin.texture = PixelArt.ruin_tex(i % PixelArt.RUIN_COUNT)
        ruin.centered = true
        ruin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        ruin.position = Vector2.from_angle(TAU * float(i) / 8.0) * 520.0
        ruin.scale = Vector2(1.35, 1.35)
        ruin.z_index = -2
        add_child(ruin)
    for i in 24:
        var tree := PixelArt.make_sprite_tex(PixelArt.tree_tex(i % PixelArt.TREE_COUNT))
        tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        var angle := TAU * float(i) / 24.0
        tree.position = Vector2.from_angle(angle) * randf_range(610.0, 700.0)
        tree.z_index = -1
        add_child(tree)
    _add_boundary(Vector2(0, -710), Vector2(1450, 28))
    _add_boundary(Vector2(0, 710), Vector2(1450, 28))
    _add_boundary(Vector2(-710, 0), Vector2(28, 1450))
    _add_boundary(Vector2(710, 0), Vector2(28, 1450))

func _add_boundary(at: Vector2, dimensions: Vector2) -> void:
    var body := StaticBody2D.new()
    body.position = at
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = dimensions
    shape.shape = rect
    body.add_child(shape)
    add_child(body)

func _spawn_player() -> void:
    player = PLAYER_SCRIPT.new() as DeadzonePlayer
    player.position = Vector2.ZERO
    player.hp_changed.connect(_on_hp_changed)
    player.died.connect(_on_player_died)
    add_child(player)

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.name = "HUD"
    add_child(layer)
    wave_label = _make_label(layer, Vector2(18, 12), Vector2(220, 42), 25)
    hp_label = _make_label(layer, Vector2(18, 54), Vector2(220, 30), 18)
    coin_label = _make_label(layer, Vector2(18, 88), Vector2(180, 28), 17)
    kill_label = _make_label(layer, Vector2(18, 118), Vector2(180, 28), 17)
    status_label = _make_label(layer, Vector2(290, 18), Vector2(380, 38), 20)
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var upgrade := Button.new()
    upgrade.text = "UPGRADE  $100"
    upgrade.position = Vector2(780, 18)
    upgrade.size = Vector2(160, 48)
    upgrade.pressed.connect(_buy_upgrade)
    layer.add_child(upgrade)
    upgrade_button = upgrade
    var fire := Button.new()
    fire.text = "FIRE"
    fire.position = Vector2(800, 390)
    fire.size = Vector2(130, 110)
    fire.add_theme_font_size_override("font_size", 24)
    fire.button_down.connect(func(): firing = true)
    fire.button_up.connect(func(): firing = false)
    layer.add_child(fire)
    fire_button = fire
    joystick = JOYSTICK_SCRIPT.new() as TouchJoystick
    joystick.name = "TouchJoystick"
    layer.add_child(joystick)
    joystick.fit_to(get_viewport_rect().size)
    get_viewport().size_changed.connect(func(): joystick.fit_to(get_viewport_rect().size))

func _make_label(parent: Node, at: Vector2, dimensions: Vector2, font_size: int) -> Label:
    var label := Label.new()
    label.position = at
    label.size = dimensions
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.84))
    label.add_theme_color_override("font_shadow_color", Color(0.05, 0.04, 0.04, 0.9))
    label.add_theme_constant_override("shadow_offset_x", 2)
    label.add_theme_constant_override("shadow_offset_y", 2)
    parent.add_child(label)
    return label

func _start_wave() -> void:
    wave += 1
    spawning_left = 5 + wave * 3
    spawn_timer = 0.6
    wave_active = true
    status_label.text = "WAVE %d — INCOMING!" % wave
    _update_hud()

func _spawn_zombie() -> void:
    var zombie := ZOMBIE_SCRIPT.new() as DeadzoneZombie
    var angle := randf_range(0.0, TAU)
    zombie.position = Vector2.from_angle(angle) * randf_range(570.0, 650.0)
    zombie.configure(player, wave)
    zombie.killed.connect(_on_zombie_killed)
    add_child(zombie)

func _shoot() -> void:
    if player == null or player.dead:
        return
    var target: Node2D = null
    var best_distance := 520.0
    for enemy in get_tree().get_nodes_in_group("zombies"):
        var d: float = player.global_position.distance_to((enemy as Node2D).global_position)
        if d < best_distance:
            best_distance = d
            target = enemy as Node2D
    if target == null:
        return
    var direction := (target.global_position - player.global_position).normalized()
    var bullet := BULLET_SCRIPT.new() as DeadzoneBullet
    bullet.global_position = player.global_position + direction * 18.0
    bullet.direction = direction
    bullet.damage = damage
    add_child(bullet)
    fire_timer = fire_rate

func _on_zombie_killed(_zombie: DeadzoneZombie) -> void:
    kills += 1
    coins += 10
    _update_hud()

func _on_hp_changed(value: float, maximum: float) -> void:
    hp_label.text = "HP  %d / %d" % [roundi(value), roundi(maximum)]

func _on_player_died() -> void:
    status_label.text = "YOU WERE OVERRUN"

func _buy_upgrade() -> void:
    if coins < 100:
        status_label.text = "NOT ENOUGH COINS"
        return
    coins -= 100
    damage += 8.0
    fire_rate = maxf(0.12, fire_rate - 0.025)
    status_label.text = "WEAPON UPGRADED!"
    _update_hud()

func _update_hud() -> void:
    wave_label.text = "WAVE  %d" % wave
    coin_label.text = "COINS  %d" % coins
    kill_label.text = "KILLS  %d" % kills
    if player != null:
        hp_label.text = "HP  %d / %d" % [roundi(player.hp), roundi(player.max_hp)]

func _restart_game() -> void:
    get_tree().reload_current_scene()
