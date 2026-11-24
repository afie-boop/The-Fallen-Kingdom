extends Node2D
## Minimal world viewer: preserve the island map, forest and passive wildlife only.

var _world_rect: Rect2
var _terrain_chunks: Array[Sprite2D] = []
const CHUNK_SIZE := 1024.0

func _ready() -> void:
    if not GameState.initialized:
        GameState.reset_new_game()
    _world_rect = Rect2(Vector2.ZERO, GameConfig.world_size())

    GameState.island = IslandMap.new()
    await GameState.island.build(GameState.world_seed, _world_rect.size)
    _place_small_lake()
    _build_ground()

    var world := Node2D.new()
    world.name = "World"
    world.y_sort_enabled = true
    add_child(world)

    # Trees are part of the natural map; no buildings, characters or enemies.
    await WorldGenerator.spawn_trees(
        world, GameState.island, GameState.world_seed,
        GameConfig.tree_count, [], [], Callable()
    )
    GameState.island.refresh_texture()

    # Passive deer and rabbits only.
    WorldGenerator.spawn_wildlife(
        world, GameState.island, GameState.world_seed, 24,
        GameState.island.center_pos, Callable()
    )

    var camera := Camera2D.new()
    camera.position = GameState.island.center_pos
    camera.zoom = Vector2(0.8, 0.8)
    camera.enabled = true
    add_child(camera)
    camera.make_current()

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
