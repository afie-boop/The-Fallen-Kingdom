extends Node
## Runtime game data (autoload "GameState").
## Personal data (wallets, inventories) is keyed by player id so the same layout
## works for LAN multiplayer later. Shared kingdom resources are kept separate.

signal wallet_changed(player_id: int, amount: int)
signal inventory_changed(player_id: int)
signal kingdom_changed
signal notice(text: String)                       ## short on-screen message (shown by the HUD)
signal beggar_recruited(beggar_id: int, variant: int, pos: Vector2)

const KINGDOM_RESOURCES: Array[String] = [
    "food", "wood", "stone", "iron_ore", "copper_ore", "clay", "sand", "water",
    "bricks", "cement", "steel",
]

var initialized: bool = false
var loaded_from_save: bool = false
var local_player_id: int = 1
var world_seed: int = 0
var wallets: Dictionary = {}
var inventories: Dictionary = {}
var kingdom_resources: Dictionary = {}
var kingdom_level: int = 1
var castle_hp: float = -1.0
var player_hp: float = -1.0
var player_pos: Vector2 = Vector2.ZERO
var has_player_pos: bool = false
var time_of_day: float = 0.3
var day_count: int = 1
var is_night: bool = false
var kills: int = 0
var removed_trees: Array = []
var recruited_beggars: Array = []   ## ids of beggars who became citizens
var citizen_jobs: Dictionary = {}   ## citizen id -> "archer" | "builder" (missing = jobless)
var buildings: Array = []           ## [{kind, slot, level, hp}] kinds: castle, wall, archer_post, builder_hut
var player_skin: int = 1          ## which character sprite (1..11) the local player uses
var island: IslandMap              ## built by the game scene from world_seed


func reset_new_game() -> void:
    initialized = true
    loaded_from_save = false
    world_seed = randi()
    wallets = {local_player_id: GameConfig.starting_gold}
    inventories = {local_player_id: {}}
    kingdom_resources = {}
    for r in KINGDOM_RESOURCES:
        kingdom_resources[r] = 0
    kingdom_level = 1
    castle_hp = -1.0
    player_hp = -1.0
    has_player_pos = false
    time_of_day = 0.3
    day_count = 1
    is_night = false
    kills = 0
    removed_trees = []
    recruited_beggars = []
    citizen_jobs = {}
    buildings = []


func _pid(pid: int) -> int:
    return local_player_id if pid < 0 else pid


# --- personal wallet -------------------------------------------------------

func get_gold(pid: int = -1) -> int:
    return int(wallets.get(_pid(pid), 0))


func add_gold(amount: int, pid: int = -1) -> void:
    var id: int = _pid(pid)
    wallets[id] = maxi(0, int(wallets.get(id, 0)) + amount)
    wallet_changed.emit(id, int(wallets[id]))


func spend_gold(amount: int, pid: int = -1) -> bool:
    var id: int = _pid(pid)
    if amount < 0 or get_gold(id) < amount:
        return false
    wallets[id] = get_gold(id) - amount
    wallet_changed.emit(id, get_gold(id))
    return true


# --- personal inventory ----------------------------------------------------

func get_item(item: String, pid: int = -1) -> int:
    var inv: Dictionary = inventories.get(_pid(pid), {})
    return int(inv.get(item, 0))


func add_item(item: String, amount: int, pid: int = -1) -> void:
    var id: int = _pid(pid)
    if not inventories.has(id):
        inventories[id] = {}
    var inv: Dictionary = inventories[id]
    inv[item] = maxi(0, int(inv.get(item, 0)) + amount)
    inventory_changed.emit(id)


## Moves a player's carried items into the shared kingdom stock. Returns amount moved.
func deposit_to_kingdom(item: String, pid: int = -1) -> int:
    var n: int = get_item(item, pid)
    if n <= 0:
        return 0
    add_item(item, -n, pid)
    kingdom_resources[item] = int(kingdom_resources.get(item, 0)) + n
    kingdom_changed.emit()
    return n


func _jobs_to_save() -> Dictionary:
    var out: Dictionary = {}
    for k in citizen_jobs:
        out[str(k)] = str(citizen_jobs[k])
    return out


func building_level(kind: String) -> int:
    var lvl: int = 0
    for b in buildings:
        if (b as Dictionary).get("kind", "") == kind:
            lvl = maxi(lvl, int((b as Dictionary).get("level", 1)))
    return lvl


func recruit_beggar(beggar_id: int) -> void:
    if not recruited_beggars.has(beggar_id):
        recruited_beggars.append(beggar_id)
    kingdom_changed.emit()


# --- save / load -------------------------------------------------------------

func to_dict() -> Dictionary:
    var w: Dictionary = {}
    for k in wallets:
        w[str(k)] = int(wallets[k])
    var inv: Dictionary = {}
    for k in inventories:
        inv[str(k)] = (inventories[k] as Dictionary).duplicate()
    return {
        "world_seed": world_seed,
        "player": {
            "id": local_player_id,
            "hp": player_hp,
            "pos": [player_pos.x, player_pos.y],
        },
        "wallets": w,
        "inventories": inv,
        "kingdom": {
            "resources": kingdom_resources.duplicate(),
            "level": kingdom_level,
            "castle_hp": castle_hp,
        },
        "time": {"time_of_day": time_of_day, "day": day_count},
        "world": {"removed_trees": removed_trees.duplicate(), "recruited_beggars": recruited_beggars.duplicate()},
        "kingdom_buildings": buildings.duplicate(true),
        "citizen_jobs": _jobs_to_save(),
        "stats": {"kills": kills},
    }


static func _num(v: Variant, fallback: float) -> float:
    if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
        return float(v)
    return fallback


func from_dict(d: Dictionary) -> void:
    reset_new_game()
    loaded_from_save = true
    world_seed = int(_num(d.get("world_seed", world_seed), world_seed))

    var p: Variant = d.get("player", {})
    if typeof(p) == TYPE_DICTIONARY:
        var pd: Dictionary = p
        local_player_id = int(_num(pd.get("id", 1), 1))
        player_hp = clampf(_num(pd.get("hp", -1.0), -1.0), -1.0, GameConfig.player_max_hp)
        var pos: Variant = pd.get("pos", null)
        if typeof(pos) == TYPE_ARRAY and (pos as Array).size() == 2:
            var pa: Array = pos
            player_pos = Vector2(_num(pa[0], 0.0), _num(pa[1], 0.0))
            player_pos = player_pos.clamp(Vector2.ZERO, GameConfig.world_size())
            has_player_pos = true

    wallets = {}
    var w: Variant = d.get("wallets", {})
    if typeof(w) == TYPE_DICTIONARY:
        for k in (w as Dictionary):
            wallets[int(str(k))] = maxi(0, int(_num((w as Dictionary)[k], 0.0)))
    if not wallets.has(local_player_id):
        wallets[local_player_id] = GameConfig.starting_gold

    inventories = {}
    var inv: Variant = d.get("inventories", {})
    if typeof(inv) == TYPE_DICTIONARY:
        for k in (inv as Dictionary):
            var one: Variant = (inv as Dictionary)[k]
            if typeof(one) != TYPE_DICTIONARY:
                continue
            var clean: Dictionary = {}
            for item in (one as Dictionary):
                clean[str(item)] = maxi(0, int(_num((one as Dictionary)[item], 0.0)))
            inventories[int(str(k))] = clean
    if not inventories.has(local_player_id):
        inventories[local_player_id] = {}

    var kd: Variant = d.get("kingdom", {})
    if typeof(kd) == TYPE_DICTIONARY:
        var kdict: Dictionary = kd
        kingdom_level = maxi(1, int(_num(kdict.get("level", 1), 1.0)))
        castle_hp = clampf(_num(kdict.get("castle_hp", -1.0), -1.0), -1.0, GameConfig.castle_max_hp)
        var res: Variant = kdict.get("resources", {})
        if typeof(res) == TYPE_DICTIONARY:
            for r in (res as Dictionary):
                kingdom_resources[str(r)] = maxi(0, int(_num((res as Dictionary)[r], 0.0)))

    var td: Variant = d.get("time", {})
    if typeof(td) == TYPE_DICTIONARY:
        var tdict: Dictionary = td
        time_of_day = clampf(_num(tdict.get("time_of_day", 0.3), 0.3), 0.0, 0.9999)
        day_count = maxi(1, int(_num(tdict.get("day", 1), 1.0)))

    var wd: Variant = d.get("world", {})
    if typeof(wd) == TYPE_DICTIONARY:
        var rt: Variant = (wd as Dictionary).get("removed_trees", [])
        if typeof(rt) == TYPE_ARRAY:
            for t in (rt as Array):
                removed_trees.append(int(_num(t, -1.0)))
        var rb: Variant = (wd as Dictionary).get("recruited_beggars", [])
        if typeof(rb) == TYPE_ARRAY:
            for b in (rb as Array):
                recruited_beggars.append(int(_num(b, -1.0)))

    var bl: Variant = d.get("kingdom_buildings", [])
    if typeof(bl) == TYPE_ARRAY:
        for e in (bl as Array):
            if typeof(e) != TYPE_DICTIONARY:
                continue
            var ed: Dictionary = e
            var kind: String = str(ed.get("kind", ""))
            if not ["castle", "wall", "archer_post", "builder_hut"].has(kind):
                continue
            buildings.append({
                "kind": kind,
                "slot": maxi(0, int(_num(ed.get("slot", 0), 0.0))),
                "level": clampi(int(_num(ed.get("level", 1), 1.0)), 1, 3),
                "hp": maxf(0.0, _num(ed.get("hp", 1.0), 1.0)),
            })
    var jb: Variant = d.get("citizen_jobs", {})
    if typeof(jb) == TYPE_DICTIONARY:
        for k in (jb as Dictionary):
            var job: String = str((jb as Dictionary)[k])
            if job == "archer" or job == "builder":
                citizen_jobs[int(str(k))] = job

    var sd: Variant = d.get("stats", {})
    if typeof(sd) == TYPE_DICTIONARY:
        kills = maxi(0, int(_num((sd as Dictionary).get("kills", 0), 0.0)))
