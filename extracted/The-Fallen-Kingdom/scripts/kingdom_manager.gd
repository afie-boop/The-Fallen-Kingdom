class_name KingdomManager
extends Node
## Build / upgrade logic for the shared kingdom and job assignment for citizens.
## Buildings go into fixed slots around the kingdom house (no free placement yet).
## Costs are paid from the acting player's PERSONAL wallet. All numbers live in GameConfig.

const STRUCTURE_SCENE: PackedScene = preload("res://scenes/structure.tscn")
const KINDS: Array[String] = ["castle", "wall"]
const NAMES: Dictionary = {"castle": "Castle", "wall": "Kingdom Fence"}
const EQUIPMENT_SHOP_SCRIPT: Script = preload("res://scripts/equipment_shop.gd")
const MAX_LEVEL: int = 3
const MAX_FENCE_LEVEL: int = 5
const FENCE_SCRIPT: Script = preload("res://scripts/kingdom_fence.gd")
const CONSTRUCTION_SITE_SCRIPT: Script = preload("res://scripts/construction_site.gd")

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
var pending_site: Node2D = null


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
    set_campfire_lit(GameState.campfire_lit)


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
    var builder_count: int = _job_count("builder")
    var construction_text: String = "   Construction in progress" if is_instance_valid(pending_site) else ""
    return "Gold: %d   Citizens: %d (jobless %d)   Archers: %d   Builders: %d%s" % [
        GameState.get_gold(), citizens, jobless,
        _job_count("archer"), builder_count, construction_text]


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
    var has_builder: bool = _job_count("builder") > 0
    var construction_busy: bool = is_instance_valid(pending_site)
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
                build_enabled = gold >= cost and has_builder and not construction_busy
                build_info = "A strong castle behind your house. Unlocks level 2 upgrades."
            else:
                build_btn = "Built"
                build_info = "Level %d / %d" % [lvl, MAX_LEVEL]
        else:
            var free: bool = _free_slot(kind) >= 0
            build_btn = "Build  %d coin" % cost if free else "Full"
            build_enabled = free and gold >= cost and has_builder and not construction_busy
            build_info = "%d / %d built" % [n, capacity(kind)]
            if n > 0:
                build_info += ", Lv %d" % lvl
        if gold < cost and build_btn.begins_with("Build"):
            build_info += "  (not enough coins)"
        rows.append({"title": "%s" % NAMES[kind], "info": build_info, "button": build_btn, "enabled": build_enabled, "kind": kind, "action": "build"})
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
                    up_enabled = has_builder and not construction_busy
            rows.append({"title": "Upgrade %s" % NAMES[kind], "info": up_info, "button": up_btn, "enabled": up_enabled, "kind": kind, "action": "upgrade"})
    # Construction and upgrades require an equipped builder and only one active site at a time.
    if not has_builder:
        for row in rows:
            if str(row.get("button", "")).begins_with("Build") or str(row.get("button", "")).begins_with("Upgrade"):
                row["info"] = str(row.get("info", "")) + "  (requires a Builder)"
    elif construction_busy:
        for row in rows:
            if str(row.get("button", "")).begins_with("Build") or str(row.get("button", "")).begins_with("Upgrade"):
                row["info"] = str(row.get("info", "")) + "  (finish current construction first)"
    # Citizens take equipment from a completed rack automatically; there is no job-assignment menu.
    return rows


## Performs a menu action for a player. Returns a short result message.
func do_action(kind: String, action: String, player_id: int) -> String:
    if not SLOTS.has(kind):
        return ""
    if _job_count("builder") <= 0:
        return "A Builder is required before construction or upgrades."
    if is_instance_valid(pending_site):
        return "A Builder is already working on another construction."

    if kind == "wall":
        if action == "build":
            if fence_level > 0:
                return "The kingdom fence is already built."
            var wall_cost: int = _cost("wall", 0)
            if not GameState.spend_gold(wall_cost, player_id):
                return "Not enough Gold Coins."
            _start_construction("wall", "build", -1, 1, wall_cost)
            return "Fence blueprint placed. A Builder will come to construct it."
        if action == "upgrade":
            if fence_level <= 0:
                return "Build the fence first."
            if fence_level >= MAX_FENCE_LEVEL:
                return "Territory is already at its maximum size."
            var next_level: int = fence_level + 1
            var expansion_cost: int = _cost("wall", next_level - 1)
            if not GameState.spend_gold(expansion_cost, player_id):
                return "Not enough Gold Coins."
            _start_construction("wall", "upgrade", -1, next_level, expansion_cost)
            return "Fence upgrade blueprint placed. A Builder will expand it."
    if action == "build":
        var slot: int = _free_slot(kind)
        if slot < 0 or (kind == "castle" and count("castle") > 0):
            return "Nothing more to build here."
        var cost: int = _cost(kind, 0)
        if not GameState.spend_gold(cost, player_id):
            return "Not enough Gold Coins."
        var lvl: int = maxi(1, level_of(kind)) if kind != "castle" else 1
        _start_construction(kind, "build", slot, lvl, cost)
        return "%s blueprint placed. A Builder will come to construct it." % NAMES[kind]
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
        _start_construction(kind, "upgrade", -1, target, up_cost)
        return "%s upgrade blueprint placed. A Builder will come to upgrade it." % NAMES[kind]
    return ""


func _start_construction(kind: String, action: String, slot: int, target: int, _cost_paid: int) -> void:
    var site := CONSTRUCTION_SITE_SCRIPT.new() as Node2D
    site.set("site_kind", kind)
    site.set("site_action", action)
    site.set("site_slot", slot)
    site.set("target_level", target)
    var duration: float = 7.0 if kind == "wall" else 5.5
    if action == "upgrade":
        duration += 1.5
    site.set("work_required", duration)
    var site_pos: Vector2 = home
    if kind != "wall" and slot >= 0:
        site_pos = home + ((SLOTS[kind] as Array)[slot] as Vector2)
    site.position = site_pos
    var work_pos: Vector2 = site_pos + Vector2(0, 28)
    if kind == "wall":
        var radius: float = 360.0 + float(maxi(1, target) - 1) * 180.0
        work_pos = home + Vector2(0, -radius)
    site.set("work_position", work_pos)
    _entities.add_child(site)
    site.connect("finished", Callable(self, "_on_construction_finished"))
    pending_site = site
    changed.emit()


func _on_construction_finished(site: Node2D) -> void:
    if site != pending_site:
        return
    var kind: String = str(site.get("site_kind"))
    var action: String = str(site.get("site_action"))
    var slot: int = int(site.get("site_slot"))
    var target: int = int(site.get("target_level"))
    if kind == "wall":
        fence_level = target
        _create_fence()
        GameState.notice.emit("Kingdom fence %s complete. Level %d." % ["built" if action == "build" else "upgraded", fence_level])
    elif action == "build":
        _spawn(kind, slot, target, -1.0)
        GameState.notice.emit("%s construction complete." % NAMES.get(kind, kind))
    else:
        for structure in _structures:
            if structure.kind == kind and structure.level < target:
                structure.set_level(target)
        GameState.notice.emit("%s upgrade complete. Level %d." % [NAMES.get(kind, kind), target])
    pending_site = null
    sync_state()
    changed.emit()

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


func set_campfire_lit(lit: bool) -> void:
    if not lit or _entities == null:
        return
    _sync_equipment_shops()


func _sync_equipment_shops() -> void:
    var has_bow := false
    var has_hammer := false
    for node in _entities.get_children():
        if node is EquipmentShop:
            if node.item_kind == "bow":
                has_bow = true
            elif node.item_kind == "hammer":
                has_hammer = true
    if not has_bow:
        var bow_shop := EQUIPMENT_SHOP_SCRIPT.new() as EquipmentShop
        bow_shop.item_kind = "bow"
        bow_shop.position = home + Vector2(150, 18)
        _entities.add_child(bow_shop)
    if not has_hammer:
        var hammer_shop := EQUIPMENT_SHOP_SCRIPT.new() as EquipmentShop
        hammer_shop.item_kind = "hammer"
        hammer_shop.position = home + Vector2(-150, 18)
        _entities.add_child(hammer_shop)

    # Job/equipment pickup stalls get their own small timber frame as soon
    # as the campfire is lit. These frames are decorative and need no Builder.
    _ensure_employment_scaffold(home + Vector2(150, 18))
    _ensure_employment_scaffold(home + Vector2(-150, 18))


func _ensure_employment_scaffold(at: Vector2) -> void:
    for node in get_tree().get_nodes_in_group("employment_scaffolds"):
        if node is Node2D and (node as Node2D).position.distance_to(at + Vector2(0, -18)) < 2.0:
            return
    var frame := CONSTRUCTION_SITE_SCRIPT.new() as Node2D
    frame.set("site_kind", "employment")
    frame.position = at + Vector2(0, -18)
    frame.z_index = 1
    _entities.add_child(frame)


## Compatibility hook: citizens now receive jobs only after collecting tools.
func assign_jobs() -> void:
    pass
