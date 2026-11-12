class_name BuildingData
extends RefCounted
## Building definitions. ALL numbers below are PLACEHOLDERS (few coins, as requested) and are
## not official game rules - tune them here. min_castle_level is the hook for locked progression
## (0 = no requirement): e.g. set tower level 3 to require castle level 2 later.

const ORDER: Array[String] = ["castle", "wall", "tower", "hut"]
const MAX_LEVEL: int = 3

const DATA: Dictionary = {
    "castle": {
        "name": "Castle", "build_cost": 6, "upgrade_costs": [8, 12], "hp": [400.0, 700.0, 1000.0],
        "radius": 70.0, "reach": 84.0, "limit": 1, "footprint": Vector2(84, 22), "worker": "",
        "min_castle_level": [0, 0, 0],
    },
    "wall": {
        "name": "Wall", "build_cost": 1, "upgrade_costs": [2, 4], "hp": [60.0, 120.0, 200.0],
        "radius": 20.0, "reach": 34.0, "limit": 60, "footprint": Vector2(44, 12), "worker": "",
        "min_castle_level": [0, 0, 0],
    },
    "tower": {
        "name": "Archer Tower", "build_cost": 3, "upgrade_costs": [4, 6], "hp": [120.0, 200.0, 300.0],
        "radius": 26.0, "reach": 30.0, "limit": 4, "footprint": Vector2(24, 14), "worker": "archer",
        "min_castle_level": [0, 0, 0],
    },
    "hut": {
        "name": "Builder Hut", "build_cost": 3, "upgrade_costs": [3, 5], "hp": [100.0, 160.0, 240.0],
        "radius": 30.0, "reach": 34.0, "limit": 2, "footprint": Vector2(36, 14), "worker": "builder",
        "min_castle_level": [0, 0, 0],
    },
}


static func info(type: String) -> Dictionary:
    return DATA.get(type, {})


static func max_hp(type: String, level: int) -> float:
    var arr: Array = info(type).get("hp", [100.0])
    return float(arr[clampi(level, 1, arr.size()) - 1])


## Cost to go from `level` to level + 1 (-1 if already max).
static func upgrade_cost(type: String, level: int) -> int:
    var arr: Array = info(type).get("upgrade_costs", [])
    if level < 1 or level > arr.size():
        return -1
    return int(arr[level - 1])


static func tower_stats(level: int) -> Dictionary:
    var i: int = clampi(level, 1, 3) - 1
    return {
        "damage": [8.0, 12.0, 16.0][i],
        "interval": [1.4, 1.1, 0.9][i],
        "range": [200.0, 240.0, 280.0][i],
    }


## Builders repair this many HP per second (free, no materials) - daytime only.
static func repair_rate(level: int) -> float:
    return [10.0, 16.0, 24.0][clampi(level, 1, 3) - 1]
