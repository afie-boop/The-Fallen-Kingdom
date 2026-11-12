extends Node2D
## Main gameplay scene: builds the world, wires systems together, handles
## pause / save / respawn. Systems themselves live in their own scripts.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const CASTLE_SCENE: PackedScene = preload("res://scenes/castle.tscn")
const COIN_SCENE: PackedScene = preload("res://scenes/coin.tscn")
const CITIZEN_SCENE: PackedScene = preload("res://scenes/citizen.tscn")
const MENU_SCENE: String = "res://scenes/main_menu.tscn"

var entities: Node2D
var player: Player
var castle: KingdomCastle
var hud: Hud
var day_night: DayNight
var spawner: ZombieSpawner
var kingdom: KingdomManager

var _world_rect: Rect2
var _autosave_t: float = 0.0
var _interact_t: float = 0.0


func _ready() -> void:
    if not GameState.initialized:
        GameState.reset_new_game()  # e.g. scene started directly from the editor
    _world_rect = Rect2(Vector2.ZERO, GameConfig.world_size())

    GameState.island = IslandMap.new()
    GameState.island.build(GameState.world_seed, _world_rect.size)
    _place_small_lake()
    _build_ground()
    _build_bounds()
    entities = Node2D.new()
    entities.name = "Entities"
    entities.y_sort_enabled = true
    add_child(entities)

    castle = CASTLE_SCENE.instantiate() as KingdomCastle
    castle.position = GameState.island.center_pos
    entities.add_child(castle)

    var avoid: Array = [
        {"pos": castle.position, "r": 330.0},
    ]
    # Random caves replace the old zombie nests and Zombie Castle.
    var cave_avoid: Array = [{"pos": castle.position, "r": 480.0}]
    var cave_spots: Array[Vector2] = WorldGenerator.spawn_caves(entities, GameState.island, GameState.world_seed, 8, cave_avoid)
    for cp in cave_spots:
        avoid.append({"pos": cp, "r": 150.0})
    var camp_avoid: Array = [
        {"pos": castle.position, "r": 760.0},
    ]
    for cp in cave_spots:
        camp_avoid.append({"pos": cp, "r": 240.0})
    var camp_spots: Array[Vector2] = WorldGenerator.spawn_camps(entities, GameState.island, GameState.world_seed, camp_avoid, GameState.recruited_beggars)
    WorldGenerator.spawn_jungle_trees(entities, GameState.island, GameState.world_seed, camp_spots, GameState.removed_trees)
    for cp in camp_spots:
        avoid.append({"pos": cp, "r": 130.0})
    WorldGenerator.spawn_kingdom_beggars(entities, GameState.island, GameState.world_seed, castle.position, GameState.recruited_beggars)
    GameState.island.refresh_texture()
    # No ruined houses are scattered around the island; tents mark poor camps.
    WorldGenerator.spawn_trees(entities, GameState.island, GameState.world_seed, GameConfig.tree_count, avoid, GameState.removed_trees)
    # Spawn deer and rabbits using the three transparent reference assets.
    WorldGenerator.spawn_wildlife(entities, GameState.island, GameState.world_seed, 17, castle.position)

    kingdom = KingdomManager.new()
    add_child(kingdom)
    kingdom.setup(entities, castle.position)
    _spawn_castle_beggars()
    _build_player()
    _restore_citizens()
    kingdom.assign_jobs()
    GameState.beggar_recruited.connect(_on_beggar_recruited)

    day_night = DayNight.new()
    add_child(day_night)
    day_night.set_time(GameState.time_of_day)

    spawner = ZombieSpawner.new()
    add_child(spawner)
    spawner.setup(entities, castle)
    spawner.zombie_killed.connect(_on_zombie_killed)

    hud = Hud.new()
    add_child(hud)
    _connect_signals()
    hud.update_hp(player.hp, player.max_hp)

    if GameState.castle_hp > 0.0:
        castle.set_hp(GameState.castle_hp)
    hud.show_message("Loaded saved game." if GameState.loaded_from_save else "Defend the kingdom. Chop trees, fight zombies, collect coins.", 4.0)


func _place_small_lake() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = GameState.world_seed + 481516
    for attempt in 120:
        var angle: float = rng.randf_range(0.0, TAU)
        var radius: float = rng.randf_range(760.0, 1450.0)
        var p: Vector2 = GameState.island.center_pos + Vector2.from_angle(angle) * radius
        if GameState.island.sample(p) < 0.28:
            continue
        if p.distance_to(GameState.island.far_inland_pos) < 650.0:
            continue
        GameState.island.add_lake(p, rng.randf_range(110.0, 155.0))
        return


func _build_ground() -> void:
    # One full-world rectangle drawn by a shader: sea, beach sand and grass in the shape of the island.
    var ground := ColorRect.new()
    ground.name = "Ground"
    ground.position = Vector2.ZERO
    ground.size = _world_rect.size
    ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ground.z_index = -10
    var mat := ShaderMaterial.new()
    mat.shader = load("res://assets/shaders/ground.gdshader") as Shader
    mat.set_shader_parameter("mask_tex", GameState.island.texture)
    mat.set_shader_parameter("grass_tex", PixelArt.file_tex("res://assets/terrain/grass.png"))
    mat.set_shader_parameter("sand_tex", PixelArt.file_tex("res://assets/terrain/sand.png"))
    mat.set_shader_parameter("water_tex", PixelArt.file_tex("res://assets/terrain/water.png"))
    mat.set_shader_parameter("dirt_tex", PixelArt.file_tex("res://assets/terrain/dirt.png"))
    mat.set_shader_parameter("world_size", _world_rect.size)
    ground.material = mat
    add_child(ground)


func _build_bounds() -> void:
    var body := StaticBody2D.new()
    body.name = "WorldBounds"
    body.collision_layer = 1
    body.collision_mask = 0
    add_child(body)
    var t: float = 64.0
    var w: float = _world_rect.size.x
    var h: float = _world_rect.size.y
    var rects: Array[Rect2] = [
        Rect2(-t, -t, w + 2.0 * t, t),
        Rect2(-t, h, w + 2.0 * t, t),
        Rect2(-t, 0.0, t, h),
        Rect2(w, 0.0, t, h),
    ]
    for r in rects:
        var cs := CollisionShape2D.new()
        var rs := RectangleShape2D.new()
        rs.size = r.size
        cs.shape = rs
        cs.position = r.position + r.size / 2.0
        body.add_child(cs)


func _build_player() -> void:
    player = PLAYER_SCENE.instantiate() as Player
    var pos: Vector2 = castle.spawn_point
    if GameState.loaded_from_save and GameState.has_player_pos:
        pos = GameState.player_pos
    if not GameState.island.is_walkable(pos):
        pos = castle.spawn_point  # e.g. an old save made before the island shape existed
    player.position = pos
    player.player_id = GameState.local_player_id
    entities.add_child(player)
    if GameState.player_hp > 0.0:
        player.set_hp(GameState.player_hp)
    var cam := Camera2D.new()
    cam.zoom = Vector2(GameConfig.camera_zoom, GameConfig.camera_zoom)
    cam.position = Vector2(0, -8)
    cam.limit_left = 0
    cam.limit_top = 0
    cam.limit_right = int(_world_rect.size.x)
    cam.limit_bottom = int(_world_rect.size.y)
    cam.position_smoothing_enabled = true
    cam.position_smoothing_speed = 8.0
    player.add_child(cam)


func _connect_signals() -> void:
    hud.attack_pressed.connect(player.try_attack)
    hud.interact_pressed.connect(_on_interact)
    hud.pause_pressed.connect(_toggle_pause)
    hud.resume_requested.connect(_toggle_pause)
    hud.save_requested.connect(_save.bind(true))
    hud.menu_requested.connect(_to_menu)
    hud.respawn_requested.connect(_respawn)
    hud.build_menu_requested.connect(_open_build)
    hud.build_closed.connect(_close_build)
    hud.build_action.connect(_on_build_action)
    player.hp_changed.connect(hud.update_hp)
    player.died.connect(_on_player_died)
    castle.notice.connect(hud.show_message)
    castle.interacted.connect(_save.bind(false))
    GameState.notice.connect(hud.show_message)
    day_night.day_started.connect(_on_dawn)
    day_night.night_started.connect(_on_dusk)


func _process(delta: float) -> void:
    if not is_instance_valid(player):
        return
    player.touch_move = hud.joystick.value
    if hud.attack_button.held or Input.is_physical_key_pressed(KEY_SPACE):
        player.try_attack()
    elif not hud.touch_ui and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not get_tree().paused:
        # PC: left click attacks towards the mouse pointer.
        var aim: Vector2 = get_global_mouse_position() - player.global_position - Vector2(0, -6)
        if aim.length() > 4.0:
            player.facing = aim.normalized()
        player.try_attack()
    if not player.dead:
        GameState.player_pos = player.global_position
        GameState.player_hp = player.hp
    GameState.castle_hp = castle.hp
    _interact_t -= delta
    if _interact_t <= 0.0:
        _interact_t = 0.2
        var target: Node2D = _nearest_interactable()
        hud.set_interact_available(target != null and not player.dead)
        hud.set_prompt(_prompt_for(target) if not player.dead else "")
    _autosave_t += delta
    if _autosave_t >= GameConfig.autosave_interval:
        _save(false)


func _unhandled_input(event: InputEvent) -> void:
    var k := event as InputEventKey
    if k != null and k.pressed and not k.echo and k.physical_keycode == KEY_E:
        _on_interact()


func _nearest_interactable() -> Node2D:
    var best: Node2D = null
    var best_d: float = 1000000.0
    for n in get_tree().get_nodes_in_group("interactable"):
        var node := n as Node2D
        if node == null:
            continue
        var rv: Variant = node.get("interact_range")
        var reach: float = float(rv) if rv != null else 96.0
        var d: float = player.global_position.distance_to(node.global_position)
        if d < reach and d < best_d:
            best_d = d
            best = node
    return best


func _prompt_for(node: Node2D) -> String:
    if node == null:
        return ""
    var pv: Variant = node.get("prompt_text")
    return str(pv) if pv != null else "Use"


func _restore_citizens() -> void:
    for id in GameState.recruited_beggars:
        var b: int = int(id)
        _spawn_citizen(b, (b * 7 + 3) % PixelArt.BEGGAR_VARIANTS, castle.position + Vector2(randf_range(-90.0, 90.0), randf_range(40.0, 110.0)))


func _spawn_citizen(id: int, variant: int, pos: Vector2) -> void:
    var c := CITIZEN_SCENE.instantiate() as Citizen
    c.citizen_id = id
    c.variant = variant
    c.home = castle.position
    c.position = pos
    entities.add_child(c)


func _on_beggar_recruited(beggar_id: int, variant: int, pos: Vector2) -> void:
    _spawn_citizen(beggar_id, variant, pos)
    kingdom.assign_jobs()
    hud.show_message("A beggar joined your kingdom as a citizen! Citizens: %d" % GameState.recruited_beggars.size())


func _on_interact() -> void:
    if player.dead:
        return
    var target: Node2D = _nearest_interactable()
    if target != null and target.has_method("interact"):
        target.call("interact", player)
    else:
        hud.show_message("Nothing to use here. Walk up to your house.")


func _on_zombie_killed(pos: Vector2) -> void:
    if randf() < GameConfig.zombie_coin_drop_chance:
        var coin := COIN_SCENE.instantiate() as CoinPickup
        coin.position = pos
        entities.add_child.call_deferred(coin)


func _on_player_died() -> void:
    # Death only ever affects this player's own wallet. Percentage is configurable (default 0).
    var lost: int = floori(float(GameState.get_gold(player.player_id)) * GameConfig.death_penalty_percent / 100.0)
    if lost > 0:
        GameState.spend_gold(lost, player.player_id)
    hud.show_death(GameConfig.respawn_delay, lost)


func _respawn() -> void:
    hud.hide_death()
    player.respawn(castle.spawn_point)
    _save(false)


func _on_dawn() -> void:
    spawner.retreat_all()
    _reset_morning_wildlife()
    hud.show_message("Dawn breaks. The zombies retreat into caves.")


func _reset_morning_wildlife() -> void:
    # Clear survivors so the morning population stays capped and respawns elsewhere.
    for node in get_tree().get_nodes_in_group("wildlife"):
        if is_instance_valid(node):
            node.queue_free()
    WorldGenerator.spawn_wildlife(entities, GameState.island, GameState.world_seed, 17, castle.position)


func _on_dusk() -> void:
    hud.show_message("Night falls. Zombies emerge from caves...")


func _open_build() -> void:
    if player.dead or get_tree().paused:
        return
    get_tree().paused = true
    hud.show_build(kingdom.menu_rows(), kingdom.info_text(), "")


func _close_build() -> void:
    hud.hide_build()
    get_tree().paused = false


func _on_build_action(kind: String, action: String) -> void:
    var msg: String = kingdom.do_action(kind, action, player.player_id)
    _spawn_castle_beggars()
    hud.show_build(kingdom.menu_rows(), kingdom.info_text(), msg)


func _spawn_castle_beggars() -> void:
    # Four beggars live beside the starting castle before any upgrade.
    if entities == null or castle == null:
        return
    WorldGenerator.spawn_castle_beggars(entities, castle.position, GameState.recruited_beggars)


func _toggle_pause() -> void:
    if hud.build_open:
        _close_build()
        return
    var p: bool = not get_tree().paused
    get_tree().paused = p
    hud.show_pause(p)


func _save(show_message: bool) -> void:
    if not is_instance_valid(player):
        return
    _autosave_t = 0.0
    if player.dead:
        GameState.player_hp = player.max_hp
        GameState.player_pos = castle.spawn_point
        GameState.has_player_pos = true
    else:
        GameState.has_player_pos = true
    GameState.castle_hp = castle.hp
    kingdom.sync_state()
    var ok: bool = SaveManager.save_game(GameState.to_dict())
    if show_message:
        hud.show_message("Game saved." if ok else "Saving failed!")


func _to_menu() -> void:
    _save(false)
    get_tree().paused = false
    get_tree().change_scene_to_file(MENU_SCENE)


func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
        _save(false)
    elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
        if hud != null:
            _toggle_pause()
