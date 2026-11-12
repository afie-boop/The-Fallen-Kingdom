class_name Wildlife
extends Node2D
## Passive deer and rabbits. Archers can claim and hunt them during daylight.

signal killed

var animal_type: String = "deer"
var hp: float = 18.0
var coin_value: int = 2
var hunter: Node2D = null
var _target: Vector2 = Vector2.ZERO
var _wait: float = 0.0
var _t: float = 0.0
var _sprite: AnimatedSprite2D

const BUNNY_SHEET := "res://Sprite karakter/Sprite karakter bunny.jpg"
const DEER_SHEET := "res://Sprite karakter/Sprite karakter deer.jpg"

func _ready() -> void:
    add_to_group("wildlife")
    _sprite = AnimatedSprite2D.new()
    var sprite_height: float = 30.0 if animal_type == "deer" else 15.0
    var sheet_path: String = DEER_SHEET if animal_type == "deer" else BUNNY_SHEET
    var frames := _build_sprite_frames(sheet_path)
    if frames != null:
        _sprite.sprite_frames = frames
        _sprite.position.y = -sprite_height * 0.5
        _sprite.play("walk")
        _sprite.scale = Vector2.ONE * (sprite_height / float(_frame_source_height(sheet_path, frames)))
        _sprite.material = _black_background_material()
    else:
        var fallback := Sprite2D.new()
        fallback.texture = _make_texture(animal_type)
        fallback.centered = false
        var source_height: float = float(maxi(fallback.texture.get_width(), fallback.texture.get_height()))
        fallback.scale = Vector2.ONE * (sprite_height / source_height)
        fallback.offset = Vector2(-fallback.texture.get_width() / 2.0, -fallback.texture.get_height())
        add_child(fallback)
        _sprite.queue_free()
        _target = global_position
        return
    add_child(_sprite)
    _target = global_position

func configure(kind: String) -> void:
    animal_type = kind
    hp = 24.0 if kind == "deer" else 12.0
    coin_value = 3 if kind == "deer" else 1

func _process(delta: float) -> void:
    _t += delta
    if hunter != null and is_instance_valid(hunter):
        return
    _wait -= delta
    if global_position.distance_to(_target) < 4.0 or _wait <= 0.0:
        _wait = randf_range(1.5, 4.0)
        for attempt in 8:
            var candidate: Vector2 = global_position + Vector2(randf_range(-65.0, 65.0), randf_range(-65.0, 65.0))
            if GameState.island == null or GameState.island.is_walkable(candidate):
                _target = candidate
                break
    var before: Vector2 = global_position
    var direction: Vector2 = _target - global_position
    if direction.length() > 3.0:
        global_position += direction.normalized() * (22.0 if animal_type == "deer" else 30.0) * delta
        if GameState.island != null:
            global_position = GameState.island.constrain(before, global_position)
        # The rabbit source sprite faces left; deer artwork faces right.
        _sprite.flip_h = direction.x > 0.0 if animal_type == "rabbit" else direction.x < 0.0
        _sprite.position.y = -absf(sin(_t * 8.0)) * 1.5

func claim(by: Node2D) -> bool:
    if hunter != null and is_instance_valid(hunter) and hunter != by:
        return false
    hunter = by
    return true

func release(by: Node2D) -> void:
    if hunter == by:
        hunter = null

func take_damage(amount: float, _from: Vector2 = Vector2.ZERO) -> bool:
    hp -= amount
    if hp <= 0.0:
        var dropped := HuntingCoin.new()
        dropped.value = coin_value
        dropped.global_position = global_position
        get_parent().add_child(dropped)
        killed.emit()
        queue_free()
        return true
    return false

func _build_sprite_frames(path: String) -> SpriteFrames:
    var source := load(path) as Texture2D
    if source == null:
        push_warning("Wildlife sprite sheet missing: " + path)
        return null
    var image := source.get_image()
    if image == null or image.is_empty():
        return null

    var width := image.get_width()
    var height := image.get_height()
    var visited := PackedByteArray()
    visited.resize(width * height)
    var rects: Array[Rect2i] = []
    var queue := PackedInt32Array()

    # Split each pose from the black-backed sheet by connected non-black pixels.
    for y in height:
        for x in width:
            var start := y * width + x
            if visited[start] != 0:
                continue
            var color := image.get_pixel(x, y)
            if maxf(color.r, maxf(color.g, color.b)) < 0.18:
                visited[start] = 1
                continue

            queue.clear()
            queue.append(start)
            visited[start] = 1
            var head := 0
            var min_x := x
            var max_x := x
            var min_y := y
            var max_y := y
            var pixel_count := 0

            while head < queue.size():
                var index: int = queue[head]
                head += 1
                pixel_count += 1
                var px := index % width
                var py := index / width
                min_x = mini(min_x, px)
                max_x = maxi(max_x, px)
                min_y = mini(min_y, py)
                max_y = maxi(max_y, py)

                var neighbors := PackedInt32Array()
                if px > 0:
                    neighbors.append(index - 1)
                if px + 1 < width:
                    neighbors.append(index + 1)
                if py > 0:
                    neighbors.append(index - width)
                if py + 1 < height:
                    neighbors.append(index + width)

                for next_index in neighbors:
                    if visited[next_index] != 0:
                        continue
                    visited[next_index] = 1
                    var nx := next_index % width
                    var ny := next_index / width
                    var next_color := image.get_pixel(nx, ny)
                    if maxf(next_color.r, maxf(next_color.g, next_color.b)) >= 0.18:
                        queue.append(next_index)

            if pixel_count >= 80:
                rects.append(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))

    if rects.size() < 2:
        push_warning("Could not detect animation frames in: " + path)
        return null

    rects.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
        if abs(a.position.y - b.position.y) > 24:
            return a.position.y < b.position.y
        return a.position.x < b.position.x
    )

    var result := SpriteFrames.new()
    result.add_animation("walk")
    result.set_animation_speed("walk", 7.0)
    result.set_animation_loop("walk", true)
    result.add_animation("idle")
    result.set_animation_speed("idle", 1.0)
    result.set_animation_loop("idle", true)

    for rect in rects:
        var atlas := AtlasTexture.new()
        atlas.atlas = source
        atlas.region = Rect2(rect)
        result.add_frame("walk", atlas)
    result.add_frame("idle", result.get_frame_texture("walk", 0))
    return result

func _frame_source_height(path: String, _frames: SpriteFrames) -> float:
    var source := load(path) as Texture2D
    return float(source.get_height()) if source != null else 1.0

func _black_background_material() -> ShaderMaterial:
    var shader := Shader.new()
    shader.code = """
shader_type canvas_item;
void fragment() {
    vec4 pixel = texture(TEXTURE, UV);
    if (pixel.r < 0.12 && pixel.g < 0.12 && pixel.b < 0.12) {
        discard;
    }
    COLOR = pixel;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    return material

static func _make_texture(kind: String) -> Texture2D:
    if kind == "deer":
        return PixelArt.file_tex("res://assets/animals/deer.png")
    return PixelArt.file_tex("res://assets/animals/rabbit.png")
