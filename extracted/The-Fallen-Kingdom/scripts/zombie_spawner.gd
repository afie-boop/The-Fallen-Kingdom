class_name ZombieSpawner
extends Node
## Spawns zombies at night only, from the nests (small nests + the big Zombie Castle),
## using a fixed-size object pool. At dawn they retreat.

signal zombie_killed(pos: Vector2)

const ZOMBIE_SCENE: PackedScene = preload("res://scenes/zombie.tscn")
const CASTLE_WEIGHT: int = 3   ## the Zombie Castle spawns this many times more often than a nest

var _pool: Array = []
var _nests: Array[Node2D] = []
var _timer: float = 4.0


## Call after all nests exist (they join the "nests" group).
func setup(entities: Node2D, kingdom_castle: Node2D) -> void:
    for n in get_tree().get_nodes_in_group("nests"):
        var node := n as Node2D
        if node == null:
            continue
        var times: int = CASTLE_WEIGHT if node is EnemyCastle else 1
        for i in times:
            _nests.append(node)
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
    if not GameState.is_night or _nests.is_empty():
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
    var nest: Node2D = _nests.pick_random()
    free_z.activate(nest.call("spawn_pos"))


func _on_killed(z: Zombie) -> void:
    zombie_killed.emit(z.global_position)
