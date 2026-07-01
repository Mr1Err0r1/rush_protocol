extends Node
## ItemDatabase — Null Protocol
## Lädt beim Start alle ItemDefinition-.tres-Dateien aus resources/items/
## und macht sie über item_id abrufbar. Neue Items: einfach .tres anlegen.

const ITEMS_PATH := "res://resources/items/"

var _db: Dictionary = {}   # StringName → ItemDefinition


func _ready() -> void:
	_scan_folder(ITEMS_PATH)
	print("[ItemDB] %d Items geladen." % _db.size())


func get_item(item_id: StringName) -> Resource:   # gibt ItemDefinition zurück
	if not _db.has(item_id):
		push_warning("[ItemDB] Unbekannte item_id: '%s'" % item_id)
		return null
	return _db[item_id]


func has_item(item_id: StringName) -> bool:
	return _db.has(item_id)


func get_all_ids() -> Array:
	return _db.keys()


func get_items_by_category(category: String) -> Array:
	var result: Array = []
	for item in _db.values():
		if item.category == category:
			result.append(item)
	return result


func get_smuggleable_items() -> Array:
	var result: Array = []
	for item in _db.values():
		if item.can_be_smuggled:
			result.append(item)
	return result


func _scan_folder(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		var full := path + fname
		if dir.current_is_dir() and not fname.begins_with("."):
			_scan_folder(full + "/")
		elif fname.ends_with(".tres"):
			var res := load(full)
			if res != null and res.get("item_id") != null and res.item_id != &"":
				_db[res.item_id] = res
		fname = dir.get_next()
	dir.list_dir_end()
