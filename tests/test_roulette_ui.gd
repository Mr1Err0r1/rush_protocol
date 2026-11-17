extends Node
## Verifies roulette HUD localization and that private magnifier results are local-only.

var _checks := 0
var _fails: Array[String] = []


func _ready() -> void:
	var previous_locale := LocaleManager.current_locale
	var world: Node = (load("res://scenes/world/match_world.tscn") as PackedScene).instantiate()
	add_child(world)
	await get_tree().process_frame
	var hud: MatchHUD = world.get_node("UILayer/MatchHUD") as MatchHUD
	if hud == null:
		check(false, "MatchHUD exists in match_world")
	else:
		hud._local_player_id = 1
		var cases := [
			{"locale": "en", "name": "Magnifier", "live": "next shell is live", "loaded": "Chamber loaded: 2 live", "shot": "Player 2 loses 1 health"},
			{"locale": "de", "name": "Lupe", "live": "nächste Patrone ist scharf", "loaded": "Magazin geladen: 2 scharf", "shot": "Spieler 2 verliert 1 Leben"},
			{"locale": "ru", "name": "Лупа", "live": "следующий патрон боевой", "loaded": "Магазин заряжен: 2 боевых", "shot": "игрок 2 теряет 1 ед. здоровья"},
		]
		var start: int
		for entry in cases:
			LocaleManager.current_locale = entry["locale"]
			start = hud.toast_container.get_child_count()
			hud._on_item_used(1, &"magnifier", -1, {
				"success": true,
				"is_private": true,
				"revealed": {"shell": "live"},
			})
			var messages := _new_toasts(hud, start)
			check(messages.size() == 2, "%s: generic item + private result toasts" % entry["locale"])
			check(messages.any(func(text: String) -> bool: return text.contains(entry["name"])), "%s: localized item name" % entry["locale"])
			check(messages.any(func(text: String) -> bool: return text.to_lower().contains(entry["live"].to_lower())), "%s: private live-shell result" % entry["locale"])

			start = hud.toast_container.get_child_count()
			hud._on_roulette_reloaded(2, 2, 4)
			messages = _new_toasts(hud, start)
			check(messages.any(func(text: String) -> bool: return text.contains(entry["loaded"])), "%s: localized reload message" % entry["locale"])

			start = hud.toast_container.get_child_count()
			hud._on_roulette_shot(1, 2, true, 1)
			messages = _new_toasts(hud, start)
			check(messages.any(func(text: String) -> bool: return text.contains(entry["shot"])), "%s: localized shot message" % entry["locale"])

		LocaleManager.current_locale = "en"
		start = hud.toast_container.get_child_count()
		hud._on_item_used(2, &"magnifier", -1, {
			"success": true,
			"is_private": true,
			"revealed": {"shell": "live"},
		})
		var remote_messages := _new_toasts(hud, start)
		check(not remote_messages.any(func(text: String) -> bool: return text.contains("next shell is live")), "private result is not shown for a non-local player")

	LocaleManager.current_locale = previous_locale
	world.free()
	_finish()


func _new_toasts(hud: MatchHUD, start: int) -> Array[String]:
	var result: Array[String] = []
	for i in range(start, hud.toast_container.get_child_count()):
		var label := hud.toast_container.get_child(i) as Label
		if label != null:
			result.append(label.text)
	return result


func check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_fails.append(message)


func _finish() -> void:
	if _fails.is_empty():
		print("PASS %d checks" % _checks)
		get_tree().quit(0)
	else:
		for failure in _fails:
			push_error("FAIL: " + failure)
		print("FAIL %d of %d checks" % [_fails.size(), _checks])
		get_tree().quit(1)
