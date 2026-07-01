extends Node
## SaveManager — Null Protocol
## Liest/schreibt Einstellungen und Statistiken nach user://save.cfg

const SAVE_PATH := "user://save.cfg"

var _cfg := ConfigFile.new()


func _ready() -> void:
	_cfg.load(SAVE_PATH)   # Fehler ignorieren falls Datei noch nicht existiert


func get_setting(key: String, default_value: Variant = null) -> Variant:
	return _cfg.get_value("settings", key, default_value)


func set_setting(key: String, value: Variant) -> void:
	_cfg.set_value("settings", key, value)
	_cfg.save(SAVE_PATH)


func get_stat(key: String, default_value: Variant = 0) -> Variant:
	return _cfg.get_value("stats", key, default_value)


func increment_stat(key: String, amount: int = 1) -> void:
	var cur: int = get_stat(key, 0)
	_cfg.set_value("stats", key, cur + amount)
	_cfg.save(SAVE_PATH)


func get_last_character() -> StringName:
	return StringName(_cfg.get_value("meta", "last_character", "mafia_boss"))


func set_last_character(char_id: StringName) -> void:
	_cfg.set_value("meta", "last_character", str(char_id))
	_cfg.save(SAVE_PATH)


func get_unlocked_characters() -> Array:
	return _cfg.get_value("unlock", "characters", ["mafia_boss", "citizen"])


func unlock_character(char_id: StringName) -> void:
	var arr: Array = get_unlocked_characters()
	if not arr.has(str(char_id)):
		arr.append(str(char_id))
		_cfg.set_value("unlock", "characters", arr)
		_cfg.save(SAVE_PATH)


func reset_all() -> void:
	_cfg.clear()
	_cfg.save(SAVE_PATH)
