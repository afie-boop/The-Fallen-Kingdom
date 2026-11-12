extends Node
## Save/load (autoload "SaveManager"). One slot, JSON, versioned.
## Writes to a temp file first and keeps a .bak of the previous save.

const SAVE_DIR: String = "user://saves"
const SAVE_FILE: String = "slot1.json"
const TMP_FILE: String = "slot1.json.tmp"
const BAK_FILE: String = "slot1.bak"


func has_save() -> bool:
    return FileAccess.file_exists(SAVE_DIR + "/" + SAVE_FILE) or FileAccess.file_exists(SAVE_DIR + "/" + BAK_FILE)


func save_game(data: Dictionary) -> bool:
    DirAccess.make_dir_recursive_absolute(SAVE_DIR)
    data["version"] = GameConfig.SAVE_VERSION
    data["saved_unix"] = Time.get_unix_time_from_system()
    var tmp_path: String = SAVE_DIR + "/" + TMP_FILE
    var f := FileAccess.open(tmp_path, FileAccess.WRITE)
    if f == null:
        push_error("SaveManager: cannot write %s" % tmp_path)
        return false
    f.store_string(JSON.stringify(data, "  "))
    f.close()
    var dir := DirAccess.open(SAVE_DIR)
    if dir == null:
        return false
    if dir.file_exists(BAK_FILE):
        dir.remove(BAK_FILE)
    if dir.file_exists(SAVE_FILE):
        dir.rename(SAVE_FILE, BAK_FILE)
    var err: int = dir.rename(TMP_FILE, SAVE_FILE)
    if err != OK:
        push_error("SaveManager: rename failed (%d)" % err)
        return false
    return true


## Returns {} if nothing usable could be loaded.
func load_game() -> Dictionary:
    for file_name in [SAVE_FILE, BAK_FILE]:
        var d: Dictionary = _read(SAVE_DIR + "/" + str(file_name))
        if not d.is_empty():
            return d
    return {}


func delete_save() -> void:
    var dir := DirAccess.open(SAVE_DIR)
    if dir == null:
        return
    for file_name in [SAVE_FILE, TMP_FILE, BAK_FILE]:
        if dir.file_exists(str(file_name)):
            dir.remove(str(file_name))


func _read(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        return {}
    var parsed: Variant = JSON.parse_string(f.get_as_text())
    f.close()
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("SaveManager: %s is damaged" % path)
        return {}
    return _validate(parsed)


func _validate(d: Dictionary) -> Dictionary:
    var version: int = 0
    var v: Variant = d.get("version", 0)
    if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
        version = int(v)
    if version < 1 or version > GameConfig.SAVE_VERSION:
        push_warning("SaveManager: unsupported save version %d" % version)
        return {}
    # Future migrations: if version < SAVE_VERSION, upgrade the dictionary here.
    for key in ["player", "kingdom", "time"]:
        if typeof(d.get(key, null)) != TYPE_DICTIONARY:
            push_warning("SaveManager: save is missing section '%s'" % key)
            return {}
    return d
