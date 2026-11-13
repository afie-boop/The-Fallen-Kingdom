class_name KingdomManager
extends Node
## Build / upgrade logic for the shared kingdom and job assignment for citizens.
## Buildings go into fixed slots around the kingdom house (no free placement yet).
## Costs are paid from the acting player's PERSONAL wallet. All numbers live in GameConfig.

const STRUCTURE_SCENE: PackedScene = preload("res://scenes/structure.tscn")
const KINDS: Array[String] = ["castle", "wall"]
const NAMES: Dictionary = {"castle": "Castle", "wall": "Kingdom Fence"}
const JOBS: Dictionary = {}
const MAX_LEVEL: int = 3
const MAX_FENCE_LEVEL: int = 5
const FENCE_SCRIPT: Script = preload("res://scripts/kingdom_fence.gd")

## Slot offsets from the kingdom house position (bottom-anchored buildings).
const SLOTS: Dictionary = {
    "castle": [Vector2(0, -135)],
    "wall": [
        Vector2(-120, -170), Vector2(120, -170),
        Vector2(-230, -70), Vector2(230, -70),
        Vector2(-230, 70), Vector2(230, 70),
        Vector2(-120, 130), Vector2(120, 130),
    ],
}

signal changed

var home: Vector2 = Vector2.ZERO
var _entities: Node2D
var _structures: Array[Structure] = []
var fence: KingdomFence
var fence_level: int = 0


func setup(entities: Node2D, home_pos: Vector2) -> void:
    _entities = entities
    home = home_pos
    for b in GameState.buildings:
        var d: Dictionary = b
        var kind: String = str(d.get("kind", ""))
        var slot: int = int(d.get("slot", 0))
        if kind == "wall":
            fence_level = maxi(fence_level, int(d.get("level", 1)))
        elif SLOTS.has(kind) and slot < (SLOTS[kind] as Array).size():
            _spawn(kind, slot, int(d.get("level", 1)), float(d.get("hp", -1.0)))
    if fence_level > 0:
        _create_fence()


# --- queries -----------------------------------------------------------------

func count(kind: String) -> int:
    if kind == "wall":
        return 1 if fence_level > 0 else 0
    var n: int = 0
    for s in _structures:
        if s.kind == kind:
            n += 1
    return n


func capacity(kind: String) -> int:
    if kind == "wall":
        return 1
    return (SLOTS[kind] as Array).size()


## Lowest level among built structures of a kind (0 if none).
func level_of(kind: String) -> int:
    if kind == "wall":
        return fence_level
    var lowest: int = 99
    for s in _structures:
        if s.kind == kind:
            lowest = mini(lowest, s.level)
    return 0 if lowest == 99 else lowest


func castle_level() -> int:
    return level_of("castle")


func _cost(kind: String, level_index: int) -> int:
    var arr: Array
    match kind:
        "wall":
            arr = GameConfig.cost_wall
        "archer_post":
            arr = GameConfig.cost_archer_post
        _:
            arr = GameConfig.cost_castle
    return int(arr[clampi(level_index, 0, arr.size() - 1)])


func _free_slot(kind: String) -> int:
    if kind == "wall":
        return 0 if fence_level == 0 else -1
    var used: Array[int] = []
    for s in _structures:
        if s.kind == kind:
            used.append(s.slot)
    for i in capacity(kind):
        if not used.has(i):
            return i
    return -1


func info_text() -> String:
    var jobless: int = 0
    var citizens: int = 0
    for c in get_tree().get_nodes_in_group("citizens"):
        citizens += 1
        if (c as Citizen).job == "":
            jobless += 1
    return "Gold: %d   Citizens: %d (jobless %d)   Archers: %d   Builders: %d" % [
        GameState.get_gold(), citizens, jobless,
        _job_count("archer"), _job_count("builder")]


func _workers(kind: String) -> int:
    var n: int = 0
    for s in _structures:
        if s.kind == kind and _worker_for(s) != null:
            n += 1
    return n


func _job_count(job_name: String) -> int:
    var n: int = 0
    for c in get_tree().get_nodes_in_group("citizens"):
        var cz := c as Citizen
        if cz != null and cz.job == job_name:
            n += 1
    return n


func _jobless_count() -> int:
    var n: int = 0
    for c in get_tree().get_nodes_in_group("citizens"):
        var cz := c as Citizen
        if cz != null and cz.job == "":
            n += 1
    return n


# --- menu ----------------------------------------------------------------------

## Rows for the BUILD menu: {title, info, button, enabled, kind, action}.
func menu_rows() -> Array:
    var rows: Array = []
    var gold: int = GameState.get_gold()
    var cl: int = castle_level()
    for kind in KINDS:
        var n: int = count(kind)
        var lvl: int = level_of(kind)
        # build row
        var build_enabled: bool = false
        var build_btn: String = ""
        var build_info: String = ""
        var cost: int = _cost(kind, 0)
        if kind == "castle":
            if n == 0:
                build_btn = "Build  %d coin" % cost
                build_enabled = gold >= cost
                build_info = "A strong castle behind your house. Unlocks level 2 upgrades."
            else:
                build_btn = "Built"
                build_info = "Level %d / %d" % [lvl, MAX_LEVEL]
        else:
            var free: bool = _free_slot(kind) >= 0
            build_btn = "Build  %d coin" % cost if free else "Full"
            build_enabled = free and gold >= cost
            build_info = "%d / %d built" % [n, capacity(kind)]
            if n > 0:
                build_info += ", Lv %d" % lvl
            if JOBS.has(kind):
                build_info += ". Needs a jobless citizen as %s." % JOBS[kind]
        if gold < cost and build_btn.begins_with("Build"):
            build_info += "  (not enough coins)"
        rows.append({"title": "%s" % NAMES[kind], "info": build_info, "button": build_btn, "enabled": build_enabled, "kind": kind, "action": "build"})
        # upgrade row
        if n > 0:
            var target: int = lvl + 1
            var up_btn: String = "Max level"
            var up_enabled: bool = false
            var up_info: String = "Upgrades all %s." % NAMES[kind].to_lower()
            var level_cap: int = MAX_FENCE_LEVEL if kind == "wall" else MAX_LEVEL
            if target <= level_cap:
                var up_cost: int = _cost(kind, target - 1)
                up_btn = "Upgrade Lv %d  %d coin" % [target, up_cost]
                if kind != "castle" and kind != "wall" and target > cl:
                    up_info = "Needs Castle level %d first." % target
                elif gold < up_cost:
                    up_info += "  (not enough coins)"
                else:
                    up_enabled = true
            rows.append({"title": "Upgrade %s" % NAMES[kind], "info": up_info, "button": up_btn, "enabled": up_enabled, "kind": kind, "action": "upgrade"})
    var available_citizens: int = _jobless_count()
    for job_name in ["archer", "builder"]:
        var job_title: String = "Archer" if job_name == "archer" else "Builder"
        var job_cost: int = 1 if job_name == "archer" else 0
        var can_hire: bool = available_citizens > 0 and gold >= job_cost
        var hire_button: String = "Assign 1 citizen" if job_cost == 0 else "Assign 1 citizen  %d coin" % job_cost
        if available_citizens <= 0:
            hire_button = "No jobless citizens"
        elif gold < job_cost:
            hire_button = "Need %d coin" % job_cost
        rows.append({
            "title": job_title,
            "info": "%d bekerja tanpa bangunan khas. Kos: %d Gold Coin setiap pengambilan." % [_job_count(job_name), job_cost],
            "button": hire_button,
            "enabled": can_hire,
            "kind": job_name,
            "action": "hire"
        })
    return rows


## Performs a menu action for a player. Returns a short result message.
func do_action(kind: String, action: String, player_id: int) -> String:
    if kind in ["archer", "builder"] and action == "hire":
        if _jobless_count() <= 0:
            return "No jobless citizens available."
        var hire_cost: int = 1 if kind == "archer" else 0
        if hire_cost > 0 and not GameState.spend_gold(hire_cost, player_id):
            return "Not enough Gold Coins."
        for c in get_tree().get_nodes_in_group("citizens"):
            var cz := c as Citizen
            if cz != null and cz.job == "":
                cz.set_job(kind, null)
                changed.emit()
                return "Citizen assigned as a %s for %d Gold Coin(s)." % [kind, hire_cost]
        return "No jobless citizens available."
    if not SLOTS.has(kind):
        return ""
    if kind == "wall":
        if action == "build":
            if fence_level > 0:
                return "The kingdom fence is already built."
            if not GameState.spend_gold(_cost("wall", 0), player_id):
                return "Not enough Gold Coins."
            fence_level = 1
            _create_fence()
            sync_state()
            changed.emit()
            return "A complete fence now surrounds your kingdom."
        if action == "upgrade":
            if fence_level <= 0:
                return "Build the fence first."
            if fence_level >= MAX_FENCE_LEVEL:
                return "Territory is already at its maximum size."
            var next_level: int = fence_level + 1
            var expansion_cost: int = _cost("wall", next_level - 1)
            if not GameState.spend_gold(expansion_cost, player_id):
                return "Not enough Gold Coins."
            fence_level = next_level
            if is_instance_valid(fence):
                fence.set_level(fence_level)
            sync_state()
            changed.emit()
            return "Kingdom territory expanded. Fence boundary moved outward."
    if action == "build":
        var slot: int = _free_slot(kind)
        if slot < 0 or (kind == "castle" and count("castle") > 0):
            return "Nothing more to build here."
        var cost: int = _cost(kind, 0)
        if not GameState.spend_gold(cost, player_id):
            return "Not enough Gold Coins."
        var lvl: int = maxi(1, level_of(kind)) if kind != "castle" else 1
        _spawn(kind, slot, lvl, -1.0)
        sync_state()
        assign_jobs()
        changed.emit()
        return "%s built." % NAMES[kind]
    if action == "upgrade":
        var n: int = count(kind)
        if n == 0:
            return "Build it first."
        var target: int = level_of(kind) + 1
        if target > MAX_LEVEL:
            return "Already at max level."
        if kind != "castle" and target > castle_level():
            return "Needs Castle level %d first." % target
        var up_cost: int = _cost(kind, target - 1)
        if not GameState.spend_gold(up_cost, player_id):
            return "Not enough Gold Coins."
        for s in _structures:
            if s.kind == kind and s.level < target:
                s.set_level(target)
        sync_state()
        changed.emit()
        return "%s upgraded to level %d." % [NAMES[kind], target]
    return ""


func _create_fence() -> void:
    if is_instance_valid(fence):
        fence.queue_free()
    fence = FENCE_SCRIPT.new() as KingdomFence
    fence.level = fence_level
    fence.position = home
    _entities.add_child(fence)


func _spawn(kind: String, slot: int, level: int, hp: float) -> void:
    var s := STRUCTURE_SCENE.instantiate() as Structure
    s.kind = kind
    s.slot = slot
    s.level = clampi(level, 1, MAX_LEVEL)
    s.hp = hp
    if kind == "wall":
        s.horizontal = absf((SLOTS[kind] as Array)[slot].x) < 200.0   # top/bottom segments are horizontal, side ones vertical
    s.position = home + ((SLOTS[kind] as Array)[slot] as Vector2)
    _entities.add_child(s)
    _structures.append(s)


## Copies the live buildings into GameState so they get saved.
func sync_state() -> void:
    var list: Array = []
    for s in _structures:
        if is_instance_valid(s):
            list.append(s.to_save())
    if fence_level > 0:
        list.append({"kind": "wall", "slot": -1, "level": fence_level, "hp": -1.0})
    GameState.buildings = list


# --- jobs ------------------------------------------------------------------------

func _worker_for(s: Structure) -> Citizen:
    for c in get_tree().get_nodes_in_group("citizens"):
        var cz := c as Citizen
        if cz != null and cz.workplace == s:
            return cz
    return null


## Gives every workplace a worker: first a citizen who had that job when the game was saved,
## otherwise any jobless citizen.
func assign_jobs() -> void:
    for s in _structures:
        if not JOBS.has(s.kind) or _worker_for(s) != null:
            continue
        var job: String = JOBS[s.kind]
        var pick: Citizen = null
        for c in get_tree().get_nodes_in_group("citizens"):
            var cz := c as Citizen
            if cz == null or cz.job != "":
                continue
            if GameState.citizen_jobs.get(cz.citizen_id, "") == job:
                pick = cz
                break
            if pick == null and not GameState.citizen_jobs.has(cz.citizen_id):
                pick = cz
        if pick != null:
            pick.set_job(job, s)
    changed.emit()
