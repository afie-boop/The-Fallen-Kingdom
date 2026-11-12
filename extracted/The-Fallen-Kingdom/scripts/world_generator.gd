class_name WorldGenerator
extends RefCounted
## Deterministic world population on top of the island map. The same seed always
## gives the same trees and ruins, so only the seed and the removed tree ids are saved.

const TREE_SCENE: PackedScene = preload("res://scenes/tree.tscn")
const RUIN_SCENE: PackedScene = preload("res://scenes/ruin.tscn")
const NEST_SCENE: PackedScene = preload("res://scenes/zombie_nest.tscn")
const CAMP_PROP_SCENE: PackedScene = preload("res://scenes/camp_prop.tscn")
const BEGGAR_SCENE: PackedScene = preload("res://scenes/beggar.tscn")


static func _blocked(p: Vector2, avoid: Array) -> bool:
    for a in avoid:
        var ad: Dictionary = a
        if p.distance_to(ad["pos"]) < float(ad["r"]):
            return true
    return false


## avoid: Array of {"pos": Vector2, "r": float}. Trees only grow on the grass (not beach/sea).
static func spawn_trees(parent: Node2D, island: IslandMap, world_seed: int, count: int, avoid: Array, removed: Array) -> int:
    var rng := RandomNumberGenerator.new()
    rng.seed = world_seed
    var placed: Array[Vector2] = []
    var spawned: int = 0
    for i in count * 3:
        if placed.size() >= count:
            break
        # Always consume the same random numbers per index so removals never shift later trees.
        var p: Vector2 = Vector2(
            rng.randf_range(40.0, island.world_size.x - 40.0),
            rng.randf_range(60.0, island.world_size.y - 30.0))
        if island.sample(p) < 0.16 or island.dirt_at(p) > 0.56 or _blocked(p, avoid):
            continue
        var too_close: bool = false
        for q in placed:
            if p.distance_to(q) < 34.0:
                too_close = true
                break
        if too_close:
            continue
        placed.append(p)
        if removed.has(i):
            continue
        var t := TREE_SCENE.instantiate() as ChoppableTree
        t.tree_id = i
        t.position = p
        parent.add_child(t)
        spawned += 1
    return spawned


## Scatters ruined houses on the grass. Returns their positions.
static func spawn_ruins(parent: Node2D, island: IslandMap, world_seed: int, count: int, avoid: Array) -> Array[Vector2]:
    var rng := RandomNumberGenerator.new()
    rng.seed = world_seed + 7919
    var spots: Array[Vector2] = []
    var tries: int = 0
    while spots.size() < count and tries < 400:
        tries += 1
        var p: Vector2 = island.random_land_point(rng, 0.25, 120.0)
        if _blocked(p, avoid):
            continue
        var far_enough: bool = true
        for q in spots:
            if p.distance_to(q) < 260.0:
                far_enough = false
                break
        if not far_enough:
            continue
        spots.append(p)
        var r := RUIN_SCENE.instantiate() as RuinProp
        r.variant = spots.size() - 1
        r.position = p
        parent.add_child(r)
    return spots


## Small zombie nests spread over the island (the big Zombie Castle is placed separately).
static func spawn_nests(parent: Node2D, island: IslandMap, world_seed: int, count: int, avoid: Array) -> Array[Vector2]:
    var rng := RandomNumberGenerator.new()
    rng.seed = world_seed + 4242
    var spots: Array[Vector2] = []
    var tries: int = 0
    while spots.size() < count and tries < 500:
        tries += 1
        var p: Vector2 = island.random_land_point(rng, 0.25, 140.0)
        if _blocked(p, avoid):
            continue
        var ok: bool = true
        for q in spots:
            if p.distance_to(q) < 380.0:
                ok = false
                break
        if not ok:
            continue
        spots.append(p)
        var n := NEST_SCENE.instantiate() as ZombieNest
        n.position = p
        parent.add_child(n)
        island.add_dirt_spot(p + Vector2(0, 8), 60.0)
    return spots


## Poor people's camps: 3-4 camps, each with exactly 2 tents (random positions) and 1-2 beggars.
## Beggar ids are stable (camp * 10 + slot) so recruited ones stay gone after loading.
static func spawn_camps(parent: Node2D, island: IslandMap, world_seed: int, avoid: Array, recruited: Array) -> Array[Vector2]:
    var rng := RandomNumberGenerator.new()
    rng.seed = world_seed + 31337
    var wanted: int = rng.randi_range(5, 6)
    var spots: Array[Vector2] = []
    var tries: int = 0
    var gap: float = 380.0     # minimum distance between camps; relaxed if the island is small
    while spots.size() < wanted and gap >= 160.0:
        tries += 1
        if tries > 600:
            tries = 0
            gap -= 70.0
        var c: Vector2 = island.random_land_point(rng, 0.3, 170.0)
        # Camps are placed deep in the jungle, well away from the kingdom.
        if c.distance_to(island.center_pos) < 760.0:
            continue
        if _blocked(c, avoid):
            continue
        var ok: bool = true
        for q in spots:
            if c.distance_to(q) < gap:
                ok = false
                break
        if not ok:
            continue
        var camp_index: int = spots.size()
        spots.append(c)
        island.add_dirt_spot(c + Vector2(0, 12), 105.0)
        # exactly two tents, randomly placed either side of the fire
        var left := Vector2(rng.randf_range(-84.0, -50.0), rng.randf_range(-26.0, 22.0))
        var right := Vector2(rng.randf_range(50.0, 84.0), rng.randf_range(-26.0, 22.0))
        for off in [left, right]:
            var tent := CAMP_PROP_SCENE.instantiate() as CampProp
            tent.kind = "tent"
            tent.position = c + (off as Vector2)
            parent.add_child(tent)
        var fire := CAMP_PROP_SCENE.instantiate() as CampProp
        fire.kind = "fire"
        fire.position = c + Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(16.0, 34.0))
        parent.add_child(fire)
        var beggar_count: int = rng.randi_range(1, 2)
        for slot in beggar_count:
            var bid: int = camp_index * 10 + slot
            var off2 := Vector2(rng.randf_range(-46.0, 46.0), rng.randf_range(40.0, 70.0))
            if recruited.has(bid):
                continue
            var b := BEGGAR_SCENE.instantiate() as Beggar
            b.beggar_id = bid
            b.variant = (bid * 7 + 3) % PixelArt.BEGGAR_VARIANTS
            b.position = c + off2
            parent.add_child(b)
    return spots


## Four beggars waiting just outside the kingdom (ids 100-103, stable across loads).
static func spawn_kingdom_beggars(parent: Node2D, island: IslandMap, world_seed: int, center: Vector2, recruited: Array) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = world_seed + 9001
    for k in 4:
        var pos: Vector2 = center + Vector2(0, 340)
        for attempt in 30:
            var ang: float = (float(k) + rng.randf_range(0.15, 0.85)) * (TAU / 4.0)
            var cand: Vector2 = center + Vector2.from_angle(ang) * rng.randf_range(310.0, 390.0)
            if island.sample(cand) >= 0.2 and island.dirt_at(cand) < 0.9:
                pos = cand
                break
        var bid: int = 100 + k
        if recruited.has(bid):
            continue
        var b := BEGGAR_SCENE.instantiate() as Beggar
        b.beggar_id = bid
        b.variant = (bid * 7 + 3) % PixelArt.BEGGAR_VARIANTS
        b.position = pos
        parent.add_child(b)


## Dense jungle groves surround the poor people's camps. Separate tree ids keep
## chopped jungle trees stable across saves without colliding with normal trees.
static func spawn_jungle_trees(parent: Node2D, island: IslandMap, world_seed: int, camps: Array[Vector2], removed: Array) -> int:
    var rng := RandomNumberGenerator.new()
    rng.seed = world_seed + 60617
    var spawned: int = 0
    for camp_index in camps.size():
        var camp: Vector2 = camps[camp_index]
        var placed: Array[Vector2] = []
        for slot in 72:
            var tree_id: int = 100000 + camp_index * 100 + slot
            var p := Vector2.ZERO
            var valid: bool = false
            for attempt in 24:
                var angle: float = rng.randf_range(0.0, TAU)
                var radius: float = rng.randf_range(125.0, 350.0)
                var candidate: Vector2 = camp + Vector2.from_angle(angle) * radius
                if island.sample(candidate) < 0.16 or island.dirt_at(candidate) > 0.56:
                    continue
                var close: bool = false
                for q in placed:
                    if candidate.distance_to(q) < 30.0:
                        close = true
                        break
                if close:
                    continue
                p = candidate
                valid = true
                break
            if not valid:
                continue
            placed.append(p)
            if removed.has(tree_id):
                continue
            var tree := TREE_SCENE.instantiate() as ChoppableTree
            tree.tree_id = tree_id
            tree.position = p
            parent.add_child(tree)
            spawned += 1
    return spawned

## Four beggars live beside the level-1 kingdom castle (ids 200-203).
## They remain until recruited; recruited ids are persisted in GameState.
static func spawn_castle_beggars(parent: Node2D, home: Vector2, recruited: Array) -> void:
    var offsets: Array[Vector2] = [
        Vector2(-82.0, -112.0),
        Vector2(82.0, -112.0),
        Vector2(-82.0, -48.0),
        Vector2(82.0, -48.0),
    ]
    for i in 4:
        var bid: int = 200 + i
        if recruited.has(bid):
            continue
        var already_spawned: bool = false
        for existing in parent.get_tree().get_nodes_in_group("beggars"):
            if int(existing.get("beggar_id")) == bid:
                already_spawned = true
                break
        if already_spawned:
            continue
        var tent := CAMP_PROP_SCENE.instantiate() as CampProp
        tent.kind = "tent"
        var tent_offsets: Array[Vector2] = [Vector2(-150.0, -240.0), Vector2(150.0, -240.0), Vector2(-150.0, -165.0), Vector2(150.0, -165.0)]
        tent.position = home + tent_offsets[i]
        parent.add_child(tent)
        var b := BEGGAR_SCENE.instantiate() as Beggar
        b.beggar_id = bid
        b.variant = (bid * 7 + 3) % PixelArt.BEGGAR_VARIANTS
        b.position = home + Vector2(0, -135) + offsets[i]
        parent.add_child(b)
