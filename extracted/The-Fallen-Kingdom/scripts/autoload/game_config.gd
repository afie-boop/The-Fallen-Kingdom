extends Node
## Central tunables (autoload "GameConfig").
## Defaults live here; data/game_config.json can override any variable.
## Anything marked UNDECIDED is a placeholder, not an official rule.

const SAVE_VERSION: int = 1
const GAME_VERSION: String = "0.1.0-stage1"
const OVERRIDE_PATH: String = "res://data/game_config.json"

var world_width: float = 10000.0
var world_height: float = 10000.0
var tree_count: int = 2800
var camera_zoom: float = 2.0
var day_length_seconds: float = 240.0

var player_max_hp: float = 100.0
var player_speed: float = 90.0
var player_attack_damage: float = 12.0
var player_attack_cooldown: float = 0.45
var player_attack_range: float = 38.0
var respawn_delay: float = 2.0

var starting_gold: int = 15   # placeholder so recruiting + building can be tried
var death_penalty_percent: float = 0.0     # UNDECIDED. Own wallet only.
var reward_distribution_mode: String = "pickup"  # UNDECIDED.

var tree_hp: int = 3
var wood_per_tree_min: int = 1
var wood_per_tree_max: int = 2

var zombie_max_hp: float = 30.0
var zombie_speed: float = 38.0
var zombie_damage: float = 8.0
var zombie_attack_cooldown: float = 1.0
var zombie_castle_damage: float = 5.0
var zombie_coin_drop_chance: float = 0.5
var zombie_aggro_day: float = 120.0
var zombie_aggro_night: float = 220.0
var zombie_cap_day: int = 0    # zombies only come out at night
var zombie_cap_night: int = 16
var zombie_spawn_interval_day: float = 12.0
var zombie_spawn_interval_night: float = 3.5

var castle_max_hp: float = 500.0

# Kingdom buildings. Arrays are indexed by level - 1 (index 0 = build / level 1).
# Costs and stats are PLACEHOLDERS (design says exact costs are not decided); change in data/game_config.json.
var cost_castle: Array = [6, 10, 16]
var cost_wall: Array = [10, 10, 20, 30, 40] # one fence build, then progressive territory expansions
var cost_archer_post: Array = [1, 4, 8]
var cost_builder_hut: Array = [1, 4, 8]
var hp_castle: Array = [600, 1000, 1500]
var hp_wall: Array = [120, 240, 400]
var hp_archer_post: Array = [150, 260, 400]
var hp_builder_hut: Array = [100, 180, 300]
var archer_damage: Array = [8, 12, 18]
var archer_range: Array = [240, 280, 320]
var archer_cooldown: float = 1.3
var builder_repair_rate: Array = [15, 25, 40]   # HP per second, free, no materials, daytime only
var autosave_interval: float = 60.0


func _ready() -> void:
    _load_overrides()


func world_size() -> Vector2:
    return Vector2(world_width, world_height)


func _load_overrides() -> void:
    if not FileAccess.file_exists(OVERRIDE_PATH):
        return
    var f := FileAccess.open(OVERRIDE_PATH, FileAccess.READ)
    if f == null:
        push_warning("GameConfig: cannot open %s" % OVERRIDE_PATH)
        return
    var parsed: Variant = JSON.parse_string(f.get_as_text())
    f.close()
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("GameConfig: %s is not a valid JSON object, using defaults" % OVERRIDE_PATH)
        return
    var data: Dictionary = parsed
    for k in data:
        var key: String = str(k)
        if key.begins_with("_") or not (key in self):
            continue
        var cur: Variant = get(key)
        var val: Variant = data[k]
        var cur_num: bool = typeof(cur) == TYPE_INT or typeof(cur) == TYPE_FLOAT
        var val_num: bool = typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT
        if cur_num and val_num:
            if typeof(cur) == TYPE_INT:
                set(key, int(val))
            else:
                set(key, float(val))
        elif typeof(cur) == typeof(val):
            set(key, val)
        else:
            push_warning("GameConfig: ignoring '%s' (wrong type)" % key)
