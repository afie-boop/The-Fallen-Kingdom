extends Node2D
## Island world with a small modern town and enterable buildings.

var _world_rect: Rect2
var _terrain_chunks: Array[Sprite2D] = []
var _world: Node2D
var _player: Player
var _interior: BuildingInterior
var _active_building: ModernBuilding
var _interact_button: Button
var _touch_up := false
var _touch_down := false
var _touch_left := false
var _touch_right := false
var _interact_key_was_down := false
var _interact_cooldown := 0.0
const CHUNK_SIZE := 1024.0
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const BUILDING_SCRIPT = preload("res://scripts/modern_building.gd")
const INTERIOR_SCRIPT = preload("res://scripts/building_interior.gd")

func _ready() -> void:
    if not GameState.initialized:
        GameState.reset_new_game()
    _world_rect = Rect2(Vector2.ZERO, GameConfig.world_size())

    GameState.island = IslandMap.new()
    await GameState.island.build(GameState.world_seed, _world_rect.size)
    _place_small_lake()
    _build_ground()

    _world = Node2D.new()
    _world.name = "World"
    _world.y_sort_enabled = true
    add_child(_world)

    var city_avoid := _spawn_modern_city()
    await WorldGenerator.spawn_trees(
        _world, GameState.island, GameState.world_seed,
        GameConfig.tree_count, city_avoid, [], Callable()
    )
    GameState.island.refresh_texture()
    WorldGenerator.spawn_wildlife(
        _world, GameState.island, GameState.world_seed, 24,
        GameState.island.center_pos, Callable()
    )

    _spawn_player()
    _create_touch_controls()

func _process(delta: float) -> void:
    _interact_cooldown = maxf(0.0, _interact_cooldown - delta)
    if _player == null:
        return
    _player.touch_move = Vector2(
        (1.0 if _touch_right else 0.0) - (1.0 if _touch_left else 0.0),
        (1.0 if _touch_down else 0.0) - (1.0 if _touch_up else 0.0)
    ).limit_length(1.0)
    var interact_down := Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_ENTER)
    if interact_down and not _interact_key_was_down and _interact_cooldown <= 0.0:
        _try_interact()
    _interact_key_was_down = interact_down
    _update_interact_button()

func _spawn_player() -> void:
    _player = PLAYER_SCENE.instantiate() as Player
    _player.position = GameState.island.center_pos + Vector2(0, 110)
    add_child(_player)
    var camera := Camera2D.new()
    camera.zoom = Vector2(0.8, 0.8)
    camera.enabled = true
    _player.add_child(camera)
    camera.make_current()

func _spawn_modern_city() -> Array:
    var center: Vector2 = GameState.island.center_pos
    var road := Node2D.new()
    road.name = "ModernCityRoad"
    road.position = center
    road.z_index = -1
    _world.add_child(road)
    _draw_city_roads(road)

    var specs := [
        {"name": "RUMAH", "type": "house", "x": -440.0},
        {"name": "KAFE", "type": "cafe", "x": -220.0},
        {"name": "KEDAI", "type": "market", "x": 0.0},
        {"name": "KLINIK", "type": "clinic", "x": 220.0},
        {"name": "PEJABAT", "type": "office", "x": 440.0}
    ]
    var avoid: Array = []
    for spec in specs:
        var b := BUILDING_SCRIPT.new() as ModernBuilding
        b.building_name = str(spec["name"])
        b.building_type = str(spec["type"])
        b.position = center + Vector2(float(spec["x"]), -245.0)
        _world.add_child(b)
        GameState.island.add_dirt_spot(b.position, 115.0)
        avoid.append({"pos": b.position, "r": 125.0})
    GameState.island.add_dirt_spot(center + Vector2(0, -90), 700.0)
    return avoid

func _draw_city_roads(road: Node2D) -> void:
    var asphalt := Color("#454d52")
    var sidewalk := Color("#b8b8ad")
    var paint := Color("#eee7c8")
    var road_poly := Polygon2D.new()
    road_poly.polygon = PackedVector2Array([
        Vector2(-680, -105), Vector2(680, -105),
        Vector2(680, 5), Vector2(-680, 5)
    ])
    road_poly.color = sidewalk
    road.add_child(road_poly)
    var asphalt_poly := Polygon2D.new()
    asphalt_poly.polygon = PackedVector2Array([
        Vector2(-680, -91), Vector2(680, -91),
        Vector2(680, -9), Vector2(-680, -9)
    ])
    asphalt_poly.color = asphalt
    road.add_child(asphalt_poly)
    for x in range(-640, 641, 100):
        var dash := ColorRect.new()
        dash.color = paint
        dash.size = Vector2(42, 3)
        dash.position = Vector2(float(x), -52)
        road.add_child(dash)
    for x in [-550.0, -330.0, -110.0, 110.0, 330.0, 550.0]:
        var curb := ColorRect.new()
        curb.color = Color("#d7d4c8")
        curb.size = Vector2(4, 16)
        curb.position = Vector2(x, -8)
        road.add_child(curb)

func _try_interact() -> void:
    if _interact_cooldown > 0.0:
        return
    _interact_cooldown = 0.3
    if _interior != null:
        var exit_pos := _interior.global_position + Vector2(0, 190)
        if _player.global_position.distance_to(exit_pos) <= 90.0:
            _leave_building()
        return
    var nearest: ModernBuilding
    var nearest_dist := 999999.0
    for child in _world.get_children():
        if child is ModernBuilding:
            var building := child as ModernBuilding
            var d := _player.global_position.distance_to(building.door_position)
            if d < nearest_dist:
                nearest_dist = d
                nearest = building
    if nearest != null and nearest_dist <= 105.0:
        _enter_building(nearest)

func _enter_building(building: ModernBuilding) -> void:
    _active_building = building
    _world.visible = false
    _interior = INTERIOR_SCRIPT.new() as BuildingInterior
    _interior.building_type = building.building_type
    _interior.building_name = building.building_name
    _interior.position = _player.global_position - Vector2(0, 125)
    add_child(_interior)
    _player.global_position = _interior.global_position + Vector2(0, 125)
    _interact_cooldown = 0.5

func _leave_building() -> void:
    if _active_building == null:
        return
    var outside := _active_building.door_position + Vector2(0, 42)
    _interior.queue_free()
    _interior = null
    _world.visible = true
    _player.global_position = outside
    _active_building = null
    _interact_cooldown = 0.5

func _update_interact_button() -> void:
    if _interact_button == null:
        return
    if _interior != null:
        var exit_pos := _interior.global_position + Vector2(0, 190)
        var can_exit := _player.global_position.distance_to(exit_pos) <= 90.0
        _interact_button.visible = can_exit
        _interact_button.text = "KELUAR"
        return
    var can_enter := false
    for child in _world.get_children():
        if child is ModernBuilding and _player.global_position.distance_to((child as ModernBuilding).door_position) <= 105.0:
            can_enter = true
            break
    _interact_button.visible = can_enter
    _interact_button.text = "MASUK"

func _create_touch_controls() -> void:
    var layer := CanvasLayer.new()
    layer.name = "TouchControls"
    add_child(layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(root)
    _add_touch_button(root, "↑", Vector2(82, -178), "up")
    _add_touch_button(root, "↓", Vector2(82, -66), "down")
    _add_touch_button(root, "←", Vector2(26, -122), "left")
    _add_touch_button(root, "→", Vector2(138, -122), "right")
    _interact_button = Button.new()
    _interact_button.text = "MASUK"
    _interact_button.visible = false
    _interact_button.anchor_left = 1.0
    _interact_button.anchor_right = 1.0
    _interact_button.anchor_top = 1.0
    _interact_button.anchor_bottom = 1.0
    _interact_button.offset_left = -164
    _interact_button.offset_top = -104
    _interact_button.offset_right = -24
    _interact_button.offset_bottom = -44
    root.add_child(_interact_button)
    _interact_button.pressed.connect(_try_interact)

func _add_touch_button(root: Control, caption: String, offset: Vector2, direction: String) -> void:
    var button := Button.new()
    button.text = caption
    button.size = Vector2(54, 54)
    button.anchor_left = 0.0
    button.anchor_right = 0.0
    button.anchor_top = 1.0
    button.anchor_bottom = 1.0
    button.position = Vector2(offset.x, offset.y)
    root.add_child(button)
    button.button_down.connect(_set_touch_direction.bind(direction, true))
    button.button_up.connect(_set_touch_direction.bind(direction, false))

func _set_touch_direction(direction: String, pressed: bool) -> void:
    match direction:
        "up": _touch_up = pressed
        "down": _touch_down = pressed
        "left": _touch_left = pressed
        "right": _touch_right = pressed

func _place_small_lake() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = GameState.world_seed + 481516
    for _attempt in 120:
        var angle := rng.randf_range(0.0, TAU)
        var radius := rng.randf_range(760.0, 1450.0)
        var p := GameState.island.center_pos + Vector2.from_angle(angle) * radius
        if GameState.island.sample(p) < 0.28:
            continue
        if p.distance_to(GameState.island.far_inland_pos) < 650.0:
            continue
        GameState.island.add_lake(p, rng.randf_range(110.0, 155.0))
        return

func _build_ground() -> void:
    var ground_root := Node2D.new()
    ground_root.name = "Terrain"
    ground_root.z_index = -10
    add_child(ground_root)
    var white_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
    white_image.fill(Color.WHITE)
    var quad_texture := ImageTexture.create_from_image(white_image)
    var shader := load("res://assets/shaders/ground.gdshader") as Shader
    var grass_tex := PixelArt.file_tex("res://assets/terrain/Rumput.jpg")
    var sand_tex := PixelArt.file_tex("res://assets/terrain/sand.png")
    var water_tex := PixelArt.file_tex("res://assets/terrain/water.png")
    var dirt_tex := PixelArt.file_tex("res://assets/terrain/dirt.png")
    var y := 0.0
    while y < _world_rect.size.y:
        var x := 0.0
        while x < _world_rect.size.x:
            var chunk_size := Vector2(
                minf(CHUNK_SIZE, _world_rect.size.x - x),
                minf(CHUNK_SIZE, _world_rect.size.y - y)
            )
            var mat := ShaderMaterial.new()
            mat.shader = shader
            mat.set_shader_parameter("mask_tex", GameState.island.texture)
            mat.set_shader_parameter("grass_tex", grass_tex)
            mat.set_shader_parameter("sand_tex", sand_tex)
            mat.set_shader_parameter("water_tex", water_tex)
            mat.set_shader_parameter("dirt_tex", dirt_tex)
            mat.set_shader_parameter("world_size", _world_rect.size)
            mat.set_shader_parameter("world_origin", Vector2(x, y))
            mat.set_shader_parameter("chunk_size", chunk_size)
            mat.set_shader_parameter("graphics_quality", 0.5)
            var chunk := Sprite2D.new()
            chunk.texture = quad_texture
            chunk.centered = true
            chunk.position = Vector2(x, y) + chunk_size * 0.5
            chunk.scale = chunk_size
            chunk.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
            chunk.material = mat
            ground_root.add_child(chunk)
            _terrain_chunks.append(chunk)
            x += CHUNK_SIZE
        y += CHUNK_SIZE
