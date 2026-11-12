class_name ZombieSpawner
extends Node
## Spawns zombies at night only, from scattered caves,
## using a fixed-size object pool. At dawn they retreat.

signal zombie_killed(pos: Vector2)

const ZOMBIE_SCENE: PackedScene = preload("res://scenes/zombie.tscn")

var _pool: Array = []
var _caves: Array[Node2D] = []
var _timer: float = 4.0


## Call after all caves exist (they join the "zombie_caves" group).
func setup(entities: Node2D, kingdom_castle: Node2D) -> void:
    for n in get_tree().get_nodes_in_group("zombie_caves"):
        var node := n as Node2D
        if node == null:
            continue
        _caves.append(node)
    var count: int = maxi(GameConfig.zombie_cap_day, GameConfig.zombie_cap_night)
    for i in count:
        var z := ZOMBIE_SCENE.instantiate() as Zombie
        z.kingdom_castle = kingdom_castle
        z.killed.connect(_on_killed)
        entities.add_child(z)
        _pool.append(z)


func retreat_all() -> void:
    for z in _pool:
        z.retreat()


func _process(delta: float) -> void:
    if not GameState.is_night or _caves.is_empty():
        return
    _timer -= delta
    if _timer > 0.0:
        return
    _timer = GameConfig.zombie_spawn_interval_night
    var active_count: int = 0
    var free_z: Zombie = null
    for z in _pool:
        if z.active:
            active_count += 1
        elif free_z == null:
            free_z = z
    if free_z == null or active_count >= GameConfig.zombie_cap_night:
        return
    var cave: Node2D = _caves.pick_random()
    free_z.activate(cave.call("spawn_pos"))


func _on_killed(z: Zombie) -> void:
    zombie_killed.emit(z.global_position)
