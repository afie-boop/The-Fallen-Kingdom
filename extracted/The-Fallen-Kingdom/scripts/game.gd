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
    _player.z_index = 3
    add_child(_player)
    var camera := Camera2D.new()
    camera.zoom = Vector2(0.8, 0.8)
    camera.enabled = true
    _player.add_child(camera)
    camera.make_current()

func _spawn_modern_city() -> Array:
    var center: Vector2 = GameState.island.center_pos
    var city := Node2D.new()
    city.name = "NewYorkInspiredCity"
    city.position = center
    city.z_index = -2
    _world.add_child(city)

    _draw_city_roads(city)
    _draw_broadway(city)
    _draw_central_park(city)
    _draw_times_square(city)

    var rng := RandomNumberGenerator.new()
    rng.seed = GameState.world_seed + 192837
    var avoid: Array = [{"pos": center, "r": 1840.0}]
    var landmarks: Array[Dictionary] = [
        {"name": "ONE WORLD TRADE", "pos": Vector2(-900, 900), "style": "glass_tower", "type": "office", "size": Vector2(144, 164)},
        {"name": "EMPIRE STATE", "pos": Vector2(-150, 0), "style": "art_deco", "type": "office", "size": Vector2(132, 154)},
        {"name": "CHRYSLER", "pos": Vector2(150, -300), "style": "art_deco", "type": "office", "size": Vector2(112, 142)},
        {"name": "FLATIRON", "pos": Vector2(-1200, 600), "style": "brownstone", "type": "office", "size": Vector2(92, 146)},
        {"name": "WOOLWORTH", "pos": Vector2(-900, 1200), "style": "art_deco", "type": "office", "size": Vector2(108, 132)},
        {"name": "GRAND CENTRAL", "pos": Vector2(0, -600), "style": "store", "type": "station", "size": Vector2(168, 112)},
        {"name": "GUGGENHEIM", "pos": Vector2(600, -900), "style": "modern", "type": "museum", "size": Vector2(128, 116)},
        {"name": "THE MET", "pos": Vector2(600, -600), "style": "modern", "type": "museum", "size": Vector2(164, 116)}
    ]

    # Each city block gets a different mix of rooftops, not one identical building.
    var block_centers: Array[float] = [-1200.0, -900.0, -600.0, -300.0, 0.0, 300.0, 600.0, 900.0, 1200.0]
    for bx in block_centers:
        for by in block_centers:
            # Central Park occupies several full blocks in the east-centre of Manhattan.
            if absf(bx - 300.0) < 1.0 and absf(by) <= 600.0:
                continue
            var landmark_block := false
            for landmark in landmarks:
                if Vector2(bx, by).distance_to(landmark["pos"]) < 145.0:
                    landmark_block = true
                    break
            if landmark_block:
                continue

            var highrise_zone := (bx >= -600.0 and bx <= 300.0 and by >= -450.0 and by <= 450.0)
            var residential_zone := (by < -450.0 or bx < -900.0 or bx > 900.0)
            var count := 2
            if highrise_zone:
                count = 1
            var offsets: Array[Vector2] = [
                Vector2(-54, -42), Vector2(54, -42), Vector2(0, 54)
            ]
            for i in count:
                var b := BUILDING_SCRIPT.new() as ModernBuilding
                var roll := rng.randf()
                if highrise_zone and roll < 0.62:
                    b.building_type = "office"
                    b.building_style = "glass_tower" if roll < 0.34 else "art_deco"
                    b.footprint = Vector2(rng.randi_range(112, 138), rng.randi_range(118, 150))
                    b.building_name = "OFFICE"
                elif residential_zone and roll < 0.72:
                    b.building_type = "apartment"
                    b.building_style = "brownstone" if roll < 0.34 else "brick_apartment"
                    b.footprint = Vector2(rng.randi_range(76, 104), rng.randi_range(88, 116))
                    b.building_name = "APARTMENTS"
                elif roll < 0.20:
                    b.building_type = "market"
                    b.building_style = "store"
                    b.footprint = Vector2(92, 82)
                    b.building_name = "DELI"
                elif roll < 0.42:
                    b.building_type = "cafe"
                    b.building_style = "brownstone"
                    b.footprint = Vector2(82, 94)
                    b.building_name = "CAFE"
                elif roll < 0.68:
                    b.building_type = "apartment"
                    b.building_style = "brick_apartment"
                    b.footprint = Vector2(92, 108)
                    b.building_name = "APARTMENTS"
                else:
                    b.building_type = "office"
                    b.building_style = "modern"
                    b.footprint = Vector2(104, 112)
                    b.building_name = "OFFICE"
                b.position = center + Vector2(bx, by) + offsets[i]
                _world.add_child(b)
                GameState.island.add_dirt_spot(b.position, 72.0)

    # Distinctive landmarks give the skyline a New York identity.
    for landmark in landmarks:
        var b := BUILDING_SCRIPT.new() as ModernBuilding
        b.building_name = landmark["name"]
        b.building_type = landmark["type"]
        b.building_style = landmark["style"]
        b.footprint = landmark["size"]
        b.position = center + landmark["pos"]
        _world.add_child(b)
        GameState.island.add_dirt_spot(b.position, 96.0)

    GameState.island.add_dirt_spot(center, 1840.0)
    return avoid


func _draw_city_roads(parent: Node2D) -> void:
    var extent := 1510.0
    var asphalt := Color("#343b40")
    var sidewalk := Color("#a8a7a0")
    var curb := Color("#d4d0c4")
    var lane_yellow := Color("#e7bd45")
    var lane_white := Color("#e4e1d7")

    # Manhattan-style avenues and cross streets, with sidewalks and broad crossings.
    for x in range(-1350, 1351, 300):
        _add_city_rect(parent, Rect2(Vector2(float(x) - 47, -extent), Vector2(94, extent * 2)), sidewalk)
        _add_city_rect(parent, Rect2(Vector2(float(x) - 36, -extent), Vector2(72, extent * 2)), asphalt)
        _add_city_rect(parent, Rect2(Vector2(float(x) - 1, -extent), Vector2(2, extent * 2)), lane_yellow)
        _add_city_rect(parent, Rect2(Vector2(float(x) - 47, -extent), Vector2(3, extent * 2)), curb)
        _add_city_rect(parent, Rect2(Vector2(float(x) + 44, -extent), Vector2(3, extent * 2)), curb)

    for y in range(-1350, 1351, 300):
        _add_city_rect(parent, Rect2(Vector2(-extent, float(y) - 43), Vector2(extent * 2, 86)), sidewalk)
        _add_city_rect(parent, Rect2(Vector2(-extent, float(y) - 32), Vector2(extent * 2, 64)), asphalt)
        _add_city_rect(parent, Rect2(Vector2(-extent, float(y) - 1), Vector2(extent * 2, 2)), lane_yellow)
        _add_city_rect(parent, Rect2(Vector2(-extent, float(y) - 43), Vector2(extent * 2, 3)), curb)
        _add_city_rect(parent, Rect2(Vector2(-extent, float(y) + 40), Vector2(extent * 2, 3)), curb)

    # Short zebra-crossing bars at intersections.
    for x in range(-1350, 1351, 300):
        for y in range(-1350, 1351, 300):
            for stripe in range(5):
                _add_city_rect(parent, Rect2(Vector2(float(x) - 30 + stripe * 13, float(y) - 30), Vector2(7, 18)), lane_white)
                _add_city_rect(parent, Rect2(Vector2(float(x) - 30 + stripe * 13, float(y) + 12), Vector2(7, 18)), lane_white)


func _draw_broadway(parent: Node2D) -> void:
    # Broadway cuts diagonally across the otherwise regular street grid.
    var a := Vector2(-1450, 1320)
    var b := Vector2(1320, -1450)
    var direction := (b - a).normalized()
    var normal := Vector2(-direction.y, direction.x)
    var road := PackedVector2Array([
        a + normal * 48, b + normal * 48, b - normal * 48, a - normal * 48
    ])
    _add_city_polygon(parent, road, Color("#3b4247"))
    var dash_pos := a.lerp(b, 0.0)
    for i in range(1, 22):
        var t := float(i) / 22.0
        dash_pos = a.lerp(b, t)
        var dash := PackedVector2Array([
            dash_pos + direction * 15 + normal * 2,
            dash_pos + direction * 15 - normal * 2,
            dash_pos - direction * 15 - normal * 2,
            dash_pos - direction * 15 + normal * 2
        ])
        _add_city_polygon(parent, dash, Color("#e5bf4d"))


func _draw_central_park(parent: Node2D) -> void:
    var park := Node2D.new()
    park.name = "CentralPark"
    park.z_index = -1
    parent.add_child(park)
    var outline := PackedVector2Array([
        Vector2(198, -645), Vector2(408, -645), Vector2(426, -590),
        Vector2(416, -390), Vector2(432, -180), Vector2(420, 40),
        Vector2(432, 260), Vector2(410, 480), Vector2(420, 620),
        Vector2(190, 620), Vector2(176, 480), Vector2(190, 250),
        Vector2(178, 20), Vector2(188, -220), Vector2(174, -440)
    ])
    _add_city_polygon(park, outline, Color("#315d3d"))
    var lawn := PackedVector2Array([
        Vector2(210, -610), Vector2(392, -610), Vector2(405, -560),
        Vector2(396, -360), Vector2(410, -170), Vector2(400, 30),
        Vector2(412, 250), Vector2(390, 585), Vector2(210, 585),
        Vector2(198, 420), Vector2(208, 220), Vector2(194, 0),
        Vector2(205, -220), Vector2(192, -430)
    ])
    _add_city_polygon(park, lawn, Color("#527d49"))

    # Winding paths and the reservoir/lakes are deliberately uneven, not a plain rectangle.
    _add_city_strip(park, Vector2(245, -580), Vector2(350, 565), 16, Color("#c3b58f"))
    _add_city_strip(park, Vector2(210, -80), Vector2(400, -35), 12, Color("#c3b58f"))
    _add_city_strip(park, Vector2(225, 270), Vector2(390, 300), 12, Color("#c3b58f"))
    _add_city_ellipse(park, Vector2(320, -320), Vector2(64, 94), Color("#477f99"))
    _add_city_ellipse(park, Vector2(270, 330), Vector2(36, 52), Color("#477f99"))

    # Tree groves in irregular clusters leave lawns and paths visible.
    var rng := RandomNumberGenerator.new()
    rng.seed = GameState.world_seed + 7781
    for i in 88:
        var p := Vector2(rng.randf_range(205, 410), rng.randf_range(-590, 585))
        if absf(p.x - 300.0) < 24.0 or (p.y < -240.0 and p.y > -420.0):
            continue
        _add_city_ellipse(park, p, Vector2(rng.randi_range(10, 16), rng.randi_range(12, 18)), Color("#315c3c"))
        _add_city_ellipse(park, p + Vector2(-3, -4), Vector2(7, 9), Color("#6c9957"))


func _draw_times_square(parent: Node2D) -> void:
    var plaza := Node2D.new()
    plaza.name = "TimesSquare"
    plaza.z_index = -1
    parent.add_child(plaza)
    _add_city_rect(plaza, Rect2(Vector2(-230, -215), Vector2(160, 130)), Color("#5a5550"))
    # Bright rooftop-sign blocks evoke the dense billboards around Times Square.
    var sign_colors: Array[Color] = [
        Color("#d64e45"), Color("#e4b94c"), Color("#4c9fb0"),
        Color("#a45c9d"), Color("#e6e0c8"), Color("#5b9b65")
    ]
    for i in 12:
        var x := -220.0 + float(i % 4) * 37.0
        var y := -205.0 + float(i / 4) * 39.0
        _add_city_rect(plaza, Rect2(Vector2(x, y), Vector2(23, 26)), sign_colors[i % sign_colors.size()])
        _add_city_rect(plaza, Rect2(Vector2(x + 4, y + 5), Vector2(15, 3)), Color("#f5e9ca"))


func _add_city_rect(parent: Node2D, rect: Rect2, color: Color) -> void:
    var polygon := Polygon2D.new()
    polygon.polygon = PackedVector2Array([
        rect.position,
        rect.position + Vector2(rect.size.x, 0.0),
        rect.position + rect.size,
        rect.position + Vector2(0.0, rect.size.y)
    ])
    polygon.color = color
    parent.add_child(polygon)


func _add_city_polygon(parent: Node2D, points: PackedVector2Array, color: Color) -> void:
    var polygon := Polygon2D.new()
    polygon.polygon = points
    polygon.color = color
    parent.add_child(polygon)


func _add_city_strip(parent: Node2D, from: Vector2, to: Vector2, width: float, color: Color) -> void:
    var direction := (to - from).normalized()
    var normal := Vector2(-direction.y, direction.x) * width * 0.5
    _add_city_polygon(parent, PackedVector2Array([
        from + normal, to + normal, to - normal, from - normal
    ]), color)


func _add_city_ellipse(parent: Node2D, center: Vector2, radius: Vector2, color: Color) -> void:
    var points := PackedVector2Array()
    for i in 16:
        var angle := TAU * float(i) / 16.0
        points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
    var shape := Polygon2D.new()
    shape.polygon = points
    shape.color = color
    parent.add_child(shape)


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
    _interior.z_index = -1
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
