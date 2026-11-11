extends Node
## LocaleManager — Null Protocol
## Einfaches, eigenständiges Lokalisierungssystem.
## Kein Godot-TranslationServer nötig — eigenes Dictionary-basiertes System.
## Neue Sprache: Eintrag in _TRANSLATIONS hinzufügen, fertig.

signal locale_changed(new_locale: String)

const SUPPORTED_LOCALES := ["de", "en", "ru"]
const LOCALE_NAMES       := {"de": "Deutsch", "en": "English", "ru": "Русский"}

var current_locale: String = "de"

# ─────────────────────────────────────────────────────────────────────────────
# Übersetzungstabelle
# key → {de, en, ru}
# ─────────────────────────────────────────────────────────────────────────────
const _T: Dictionary = {
	# ── Hauptmenü ────────────────────────────────────────────────────────────
	"menu.title":           {"de": "NULL PROTOCOL",          "en": "NULL PROTOCOL",        "ru": "NULL ПРОТОКОЛ"},
	"menu.subtitle":        {"de": "Casino Heist",           "en": "Casino Heist",          "ru": "Ограбление казино"},
	"menu.name_hint":       {"de": "Dein Name",              "en": "Your Name",             "ru": "Твоё имя"},
	"menu.difficulty":      {"de": "Schwierigkeit:",         "en": "Difficulty:",           "ru": "Сложность:"},
	"menu.diff_easy":       {"de": "Leicht (Ghost)",         "en": "Easy (Ghost)",          "ru": "Легко (Призрак)"},
	"menu.diff_normal":     {"de": "Normal (Phantom)",       "en": "Normal (Phantom)",      "ru": "Нормально (Фантом)"},
	"menu.diff_hard":       {"de": "Schwer (Cipher)",        "en": "Hard (Cipher)",         "ru": "Сложно (Шифр)"},
	"menu.start_solo":      {"de": "Solo gegen KI",          "en": "Solo vs AI",            "ru": "Соло против ИИ"},
	"menu.multiplayer":     {"de": "Multiplayer",            "en": "Multiplayer",           "ru": "Мультиплеер"},
	"menu.settings":        {"de": "Einstellungen",          "en": "Settings",              "ru": "Настройки"},
	"menu.characters":      {"de": "Charaktere",             "en": "Characters",            "ru": "Персонажи"},
	"menu.quit":            {"de": "Beenden",                "en": "Quit",                  "ru": "Выход"},
	"menu.version":         {"de": "v0.2 — Null Protocol",  "en": "v0.2 — Null Protocol",  "ru": "v0.2 — Null Протокол"},

	# ── Charakter-Galerie (Hauptmenü) ────────────────────────────────────────
	"gallery.title":        {"de": "CHARAKTERE",             "en": "CHARACTERS",            "ru": "ПЕРСОНАЖИ"},
	"gallery.pick":         {"de": "Als Favorit wählen",     "en": "Set as Favorite",       "ru": "Выбрать любимым"},
	"gallery.back":         {"de": "← Zurück",               "en": "← Back",                "ru": "← Назад"},
	"gallery.picked":       {"de": "Favorit: %s",            "en": "Favorite: %s",          "ru": "Любимый: %s"},

	# ── Einstellungen ─────────────────────────────────────────────────────────
	"settings.title":       {"de": "Einstellungen",          "en": "Settings",              "ru": "Настройки"},
	"settings.language":    {"de": "Sprache:",               "en": "Language:",             "ru": "Язык:"},
	"settings.display":     {"de": "Anzeige",                "en": "Display",               "ru": "Дисплей"},
	"settings.monitor":     {"de": "Monitor:",               "en": "Monitor:",              "ru": "Монитор:"},
	"settings.fullscreen":  {"de": "Vollbild:",              "en": "Fullscreen:",           "ru": "Полный экран:"},
	"settings.resolution":  {"de": "Auflösung:",             "en": "Resolution:",           "ru": "Разрешение:"},
	"settings.vsync":       {"de": "V-Sync:",                "en": "V-Sync:",               "ru": "В-синхр.:"},
	"settings.audio":       {"de": "Audio",                  "en": "Audio",                 "ru": "Звук"},
	"settings.sfx_vol":     {"de": "Soundeffekte:",          "en": "Sound Effects:",        "ru": "Звуковые эффекты:"},
	"settings.music_vol":   {"de": "Musik:",                 "en": "Music:",                "ru": "Музыка:"},
	"settings.controls":    {"de": "Steuerung",              "en": "Controls",              "ru": "Управление"},
	"settings.sens":        {"de": "Maus-Sensitivität:",     "en": "Mouse Sensitivity:",    "ru": "Чувствит. мыши:"},
	"settings.apply":       {"de": "Übernehmen",             "en": "Apply",                 "ru": "Применить"},
		"settings.back":        {"de": "← Zurück",               "en": "← Back",                "ru": "← Назад"},
		"settings.restart_req": {"de": "Neustart erforderlich!", "en": "Restart required!",     "ru": "Требуется перезапуск!"},
		"settings.master_vol":  {"de": "Gesamtlautstärke",       "en": "Master Volume",         "ru": "Общая громкость"},
		"settings.window_mode": {"de": "Fenstermodus",            "en": "Window Mode",            "ru": "Режим окна"},
		"settings.brightness":  {"de": "Helligkeit",              "en": "Brightness",             "ru": "Яркость"},
		"settings.ui_scale":    {"de": "UI-Skalierung",           "en": "UI Scale",               "ru": "Масштаб интерфейса"},
		"settings.colorblind":  {"de": "Farbseh-Modus",           "en": "Color-blind Filter",     "ru": "Режим для дальтоников"},
		"settings.subtitles":   {"de": "Untertitel",              "en": "Subtitles",              "ru": "Субтитры"},
		"settings.reduce_motion":{"de": "Bewegung reduzieren",    "en": "Reduce Motion",          "ru": "Уменьшить анимацию"},
		"settings.reset":       {"de": "↺  Standard",             "en": "↺  Reset",               "ru": "↺  Сбросить"},
		"settings.reset_title": {"de": "Auf Standard zurücksetzen","en": "Reset to Defaults",     "ru": "Сбросить настройки"},
		"settings.reset_body":  {"de": "Alle Einstellungen auf die Standardwerte zurücksetzen?", "en": "Reset all settings to their defaults?", "ru": "Сбросить все настройки к значениям по умолчанию?"},
		"settings.reset_bindings_body": {"de": "Tastenbelegung auf Standard zurücksetzen?", "en": "Reset key bindings to defaults?", "ru": "Сбросить назначения клавиш?"},
		"settings.saved":       {"de": "Gespeichert",             "en": "Saved",                  "ru": "Сохранено"},
		"settings.close":       {"de": "✕  Schließen",           "en": "✕  Close",              "ru": "✕  Закрыть"},
		"settings.controls_hint":{"de": "Klicke eine Taste zum Ändern  •  ESC = Schließen", "en": "Click a key to rebind  •  ESC = Close", "ru": "Нажмите клавишу  •  ESC = закрыть"},
		"settings.controls_title":{"de": "STEUERUNG  /  TASTENBELEGUNG", "en": "CONTROLS  /  KEY BINDINGS", "ru": "УПРАВЛЕНИЕ  /  КЛАВИШИ"},
		"settings.unsaved_body":{"de": "Es gibt ungespeicherte Änderungen. Verwerfen und schließen?", "en": "You have unsaved changes. Discard and close?", "ru": "Есть несохранённые изменения. Отменить и закрыть?"},
		"settings.unsaved_indicator":{"de": "●  Nicht gespeicherte Änderungen", "en": "●  Unsaved changes", "ru": "●  Несохранённые изменения"},
		"settings.unsaved_title":{"de": "Ungespeicherte Änderungen", "en": "Unsaved Changes", "ru": "Несохранённые изменения"},

		# ── Lobby ─────────────────────────────────────────────────────────────────
	"lobby.title":          {"de": "LOBBY",                  "en": "LOBBY",                 "ru": "ЛОББИ"},
	"lobby.name_hint":      {"de": "Dein Name",              "en": "Your Name",             "ru": "Твоё имя"},
	"lobby.host":           {"de": "Server hosten",          "en": "Host Server",           "ru": "Создать сервер"},
	"lobby.ip_hint":        {"de": "IP-Adresse des Hosts",   "en": "Host IP Address",       "ru": "IP-адрес хоста"},
	"lobby.join":           {"de": "Beitreten",              "en": "Join",                  "ru": "Подключиться"},
	"lobby.players":        {"de": "Verbundene Spieler:",    "en": "Connected Players:",    "ru": "Подключённые игроки:"},
	"lobby.start":          {"de": "Match starten (Host)",   "en": "Start Match (Host)",    "ru": "Начать матч (Хост)"},
	"lobby.back":           {"de": "← Zurück",               "en": "← Back",                "ru": "← Назад"},
	"lobby.host_tag":       {"de": "[HOST]",                 "en": "[HOST]",                "ru": "[ХОСТ]"},
	"lobby.you_tag":        {"de": "[DU]",                   "en": "[YOU]",                 "ru": "[ТЫ]"},
	"lobby.local_ping":     {"de": "lokal",                  "en": "local",                 "ru": "локально"},
	"lobby.waiting":        {"de": "Warte auf Spieler…",     "en": "Waiting for players…",  "ru": "Ожидание игроков…"},
	"lobby.connecting":     {"de": "Verbinde…",              "en": "Connecting…",           "ru": "Подключение…"},
	"lobby.err_no_ip":      {"de": "Bitte IP eingeben!",     "en": "Please enter IP!",      "ru": "Введите IP!"},
	"lobby.err_host":       {"de": "Host-Fehler: %d",        "en": "Host error: %d",        "ru": "Ошибка хоста: %d"},
	"lobby.connected":      {"de": "Verbunden! ID: %d",      "en": "Connected! ID: %d",     "ru": "Подключено! ID: %d"},
	"lobby.disconnected":   {"de": "Getrennt.",              "en": "Disconnected.",         "ru": "Отключено."},
	"lobby.conn_failed":    {"de": "Verbindung fehl.: %s",   "en": "Connection failed: %s", "ru": "Ошибка подкл.: %s"},

	# ── Charakter-Auswahl ─────────────────────────────────────────────────────
	"char.title":           {"de": "CHARAKTER WÄHLEN",       "en": "SELECT CHARACTER",      "ru": "ВЫБОР ПЕРСОНАЖА"},
	"char.gender":          {"de": "Geschlecht:",            "en": "Gender:",               "ru": "Пол:"},
	"char.male":            {"de": "Männlich",               "en": "Male",                  "ru": "Мужской"},
	"char.female":          {"de": "Weiblich",               "en": "Female",                "ru": "Женский"},
	"char.nonbinary":       {"de": "Divers",                 "en": "Non-binary",            "ru": "Небинарный"},
	"char.appearance":      {"de": "Aussehen",               "en": "Appearance",            "ru": "Внешность"},
	"char.skin":            {"de": "Hautton:",               "en": "Skin Tone:",            "ru": "Тон кожи:"},
	"char.hair":            {"de": "Frisur:",                "en": "Hairstyle:",            "ru": "Причёска:"},
	"char.hair_color":      {"de": "Haarfarbe:",             "en": "Hair Color:",           "ru": "Цвет волос:"},
	"char.outfit":          {"de": "Outfit:",                "en": "Outfit:",               "ru": "Наряд:"},
	"char.accessory":       {"de": "Accessoire:",            "en": "Accessory:",            "ru": "Аксессуар:"},
	"char.smuggle_slots":   {"de": "Schmuggel-Slots: %d",   "en": "Smuggle Slots: %d",     "ru": "Слотов контрабанды: %d"},
	"char.loadout":         {"de": "Ausrüstung wählen",      "en": "Choose Loadout",        "ru": "Выбор снаряжения"},
	"char.confirm":         {"de": "Bestätigen",             "en": "Confirm",               "ru": "Подтвердить"},
	"char.locked":          {"de": "Gesperrt",               "en": "Locked",                "ru": "Заблокировано"},
	"char.stats_health":    {"de": "Leben",                  "en": "Health",                "ru": "Здоровье"},
	"char.stats_suspicion": {"de": "Misstrauen",             "en": "Suspicion",             "ru": "Подозрение"},
	"char.stats_influence": {"de": "Einfluss",               "en": "Influence",             "ru": "Влияние"},
	"char.stats_chips":     {"de": "Chips",                  "en": "Chips",                 "ru": "Фишки"},
		"char.passive":         {"de": "Passiv:",                "en": "Passive:",              "ru": "Пассивный:"},
		"char.active":          {"de": "Aktiv:",                 "en": "Active:",               "ru": "Активный:"},

		# ── Faction-first character onboarding ───────────────────────────────────
		"character.back_to_factions": {"de": "← Fraktionen", "en": "← Factions", "ru": "← Фракции"},
		"character.step_faction": {"de": "SCHRITT 1/2 · FRAKTION WÄHLEN", "en": "STEP 1/2 · CHOOSE FACTION", "ru": "ШАГ 1/2 · ВЫБЕРИТЕ ФРАКЦИЮ"},
		"character.step_role": {"de": "SCHRITT 2/2 · CHARAKTER WÄHLEN", "en": "STEP 2/2 · CHOOSE CHARACTER", "ru": "ШАГ 2/2 · ВЫБЕРИТЕ ПЕРСОНАЖА"},
		"character.choose_faction": {"de": "Wähle eine Fraktion", "en": "Choose a faction", "ru": "Выберите фракцию"},
		"character.faction_hint": {"de": "Wähle zuerst deine Seite. Danach siehst du nur die Rollen dieser Fraktion.", "en": "Choose your side first. You will then see only roles from that faction.", "ru": "Сначала выберите сторону. Затем появятся только роли этой фракции."},
		"character.roles_available": {"de": "Verfügbare Rollen:", "en": "Available roles:", "ru": "Доступные роли:"},
		"character.continue": {"de": "Rollen ansehen", "en": "View roles", "ru": "Показать роли"},
		"character.select_faction_first": {"de": "Bitte zuerst eine Fraktion auswählen.", "en": "Please choose a faction first.", "ru": "Сначала выберите фракцию."},
		"character.confirm_start": {"de": "Bestätigen & Starten", "en": "Confirm & Start", "ru": "Подтвердить и начать"},
		"character.no_roles": {"de": "Für diese Fraktion sind keine Charaktere freigeschaltet.", "en": "No characters are unlocked for this faction.", "ru": "Для этой фракции пока нет открытых персонажей."},
		"character.select_role_first": {"de": "Bitte zuerst einen Charakter wählen.", "en": "Please choose a character first.", "ru": "Сначала выберите персонажа."},
		"character.gender_label": {"de": "Geschlecht:", "en": "Gender:", "ru": "Пол:"},
		"character.gender_m": {"de": "Männlich", "en": "Male", "ru": "Мужской"},
		"character.gender_f": {"de": "Weiblich", "en": "Female", "ru": "Женский"},
		"character.gender_nb": {"de": "Nichtbinär", "en": "Non-binary", "ru": "Небинарный"},
		"character.smuggle_slots": {"de": "Schmuggel-Slots: %d", "en": "Smuggling slots: %d", "ru": "Слотов контрабанды: %d"},
		"character.item_slot": {"de": "+ Item %d wählen", "en": "+ Choose item %d", "ru": "+ Выбрать предмет %d"},
		"character.confirmed_wait": {"de": "Bestätigt — warte auf andere Spieler...", "en": "Confirmed — waiting for other players...", "ru": "Подтверждено — ожидание других игроков..."},
		"character.stats_health": {"de": "❤ Leben", "en": "❤ Health", "ru": "❤ Здоровье"},
		"character.stats_suspicion": {"de": "👁 Misstrauen", "en": "👁 Suspicion", "ru": "👁 Подозрение"},
		"character.stats_influence": {"de": "🎩 Einfluss", "en": "🎩 Influence", "ru": "🎩 Влияние"},
		"character.stats_chips": {"de": "💰 Chips", "en": "💰 Chips", "ru": "💰 Фишки"},
		"character.faction_mafia": {"de": "Mafia", "en": "Mafia", "ru": "Мафия"},
		"character.faction_military": {"de": "Militär", "en": "Military", "ru": "Военные"},
		"character.faction_civilian": {"de": "Zivilisten", "en": "Civilians", "ru": "Мирные жители"},
		"character.faction_assassins": {"de": "Assassinen-Gilde", "en": "Assassins' Guild", "ru": "Гильдия ассасинов"},
		"character.faction_government": {"de": "Regierung", "en": "Government", "ru": "Правительство"},
		"character.faction_law_enforcement": {"de": "Ermittler", "en": "Investigators", "ru": "Следователи"},
		"character.faction_elite": {"de": "Casino-Elite", "en": "Casino Elite", "ru": "Элита казино"},
		"character.faction_independent": {"de": "Unabhängig", "en": "Independent", "ru": "Независимые"},

		# ── Items ─────────────────────────────────────────────────────────────────
	"item.revolver":        {"de": "Revolver",               "en": "Revolver",              "ru": "Револьвер"},
	"item.poison_needle":   {"de": "Giftnadel",              "en": "Poison Needle",         "ru": "Отравленная игла"},
	"item.fake_cards":      {"de": "Präparierte Karten",     "en": "Marked Cards",          "ru": "Крапленые карты"},
	"item.lighter":         {"de": "Feuerzeug",              "en": "Lighter",               "ru": "Зажигалка"},
	"item.ai_lens":         {"de": "KI-Linse",               "en": "AI Lens",               "ru": "ИИ-линза"},
	"item.coin":            {"de": "Falschmünze",            "en": "Fake Coin",             "ru": "Фальшивая монета"},
	"item.glue":            {"de": "Superkleber",            "en": "Super Glue",            "ru": "Суперклей"},
	"item.bulletproof_band":{"de": "Kugelschutzband",        "en": "Bulletproof Band",      "ru": "Бронежилет"},
	"item.fake_id":         {"de": "Gefälschter Ausweis",    "en": "Fake ID",               "ru": "Поддельное удост."},
	"item.listening_bug":   {"de": "Abhörwanze",             "en": "Listening Bug",         "ru": "Жучок"},
	"item.smoke_grenade":   {"de": "Rauchgranate",           "en": "Smoke Grenade",         "ru": "Дымовая граната"},
	"item.vault_key_copy":  {"de": "Vault-Schlüssel",        "en": "Vault Key Copy",        "ru": "Копия ключа хранилища"},

	# ── HUD & Match ───────────────────────────────────────────────────────────
	"hud.round":            {"de": "Runde %d",               "en": "Round %d",              "ru": "Раунд %d"},
	"hud.your_turn":        {"de": "⚡ DEIN ZUG",            "en": "⚡ YOUR TURN",           "ru": "⚡ ТВОЙ ХОД"},
	"hud.waiting_for":      {"de": "Warte auf Sp. %d…",      "en": "Waiting for P. %d…",   "ru": "Ожидание игр. %d…"},
	"hud.phase_item":       {"de": "Phase: Item (1/2)",       "en": "Phase: Item (1/2)",     "ru": "Фаза: Предмет (1/2)"},
	"hud.phase_action":     {"de": "Phase: Aktion (2/2)",     "en": "Phase: Action (2/2)",   "ru": "Фаза: Действие (2/2)"},
	"hud.phase_resolve":    {"de": "Phase: Auflösung…",       "en": "Phase: Resolving…",     "ru": "Фаза: Разрешение…"},
	"hud.zone":             {"de": "📍 Zone: %s",             "en": "📍 Zone: %s",            "ru": "📍 Зона: %s"},
	"hud.suspicion":        {"de": "Misstrauen",              "en": "Suspicion",             "ru": "Подозрение"},
	"hud.heat":             {"de": "Heat",                    "en": "Heat",                  "ru": "Жара"},
	"hud.chips":            {"de": "💰 %d Chips",             "en": "💰 %d Chips",            "ru": "💰 %d Фишки"},
	"hud.end_turn":         {"de": "Zug beenden\n[Enter]",    "en": "End Turn\n[Enter]",     "ru": "Завершить ход\n[Enter]"},
	"hud.game_over":        {"de": "SPIELENDE",               "en": "GAME OVER",             "ru": "ИГРА ОКОНЧЕНА"},
	"hud.you_won":          {"de": "🏆 DU HAST GEWONNEN!",    "en": "🏆 YOU WIN!",            "ru": "🏆 ТЫ ПОБЕДИЛ!"},
	"hud.player_wins":      {"de": "Spieler %d gewinnt.",     "en": "Player %d wins.",       "ru": "Игрок %d побеждает."},
	"hud.draw":             {"de": "Unentschieden",           "en": "Draw",                  "ru": "Ничья"},
	"hud.back_menu":        {"de": "Zurück zum Menü",         "en": "Back to Menu",          "ru": "В главное меню"},
	"hud.zone_entrance":    {"de": "Eingang",                 "en": "Entrance",              "ru": "Вход"},
	"hud.zone_lobby":       {"de": "Lobby",                   "en": "Lobby",                 "ru": "Лобби"},
	"hud.zone_floor":       {"de": "Spielfläche",             "en": "Casino Floor",          "ru": "Игровой зал"},
	"hud.zone_bar":         {"de": "Bar",                     "en": "Bar",                   "ru": "Бар"},
	"hud.zone_vault_corr":  {"de": "Vault-Korridor",          "en": "Vault Corridor",        "ru": "Коридор хранилища"},
	"hud.zone_vault":       {"de": "VAULT 🔐",                "en": "VAULT 🔐",               "ru": "ХРАНИЛИЩЕ 🔐"},
	"hud.zone_boss":        {"de": "Boss-Büro",               "en": "Boss Office",           "ru": "Офис босса"},
	"hud.zone_backroom":    {"de": "Hinterzimmer",            "en": "Backroom",              "ru": "Подсобка"},
	"hud.zone_rooftop":     {"de": "Dach",                    "en": "Rooftop",               "ru": "Крыша"},
	"hud.zone_exit":        {"de": "Ausgang",                 "en": "Exit",                  "ru": "Выход"},

	# ── Phasen-Nachrichten ────────────────────────────────────────────────────
	"phase.char_select":    {"de": "Wähle deinen Charakter!",   "en": "Choose your character!",    "ru": "Выбери персонажа!"},
	"phase.entry":          {"de": "Einlass-Kontrolle…",        "en": "Entry check in progress…",  "ru": "Проверка на входе…"},
	"phase.floor":          {"de": "Du bist drin. Spiel beginnt.", "en": "You're in. Game begins.", "ru": "Ты внутри. Игра начинается."},
	"phase.vault":          {"de": "VAULT GEÖFFNET!",           "en": "VAULT OPENED!",             "ru": "ХРАНИЛИЩЕ ОТКРЫТО!"},
	"phase.boss":           {"de": "BOSS-BEGEGNUNG!",           "en": "BOSS ENCOUNTER!",           "ru": "ВСТРЕЧА С БОССОМ!"},

	# ── Toasts / Feedback ─────────────────────────────────────────────────────
	"toast.not_your_turn":  {"de": "Nicht dein Zug!",           "en": "Not your turn!",            "ru": "Не твой ход!"},
	"toast.no_vault_key":   {"de": "Du brauchst den Vault-Key!","en": "You need the vault key!",   "ru": "Нужен ключ хранилища!"},
	"toast.vault_key_got":  {"de": "🔑 Vault-Key aktiviert!",   "en": "🔑 Vault key activated!",   "ru": "🔑 Ключ активирован!"},
	"toast.stuck":          {"de": "Du kannst dich nicht bewegen!", "en": "You can't move!",       "ru": "Ты не можешь двигаться!"},
	"toast.suspicion_crit": {"de": "⚠ Misstrauen kritisch!",   "en": "⚠ Suspicion critical!",    "ru": "⚠ Подозрение критично!"},
	"toast.settings_soon":  {"de": "Einstellungen kommen bald!", "en": "Settings coming soon!",   "ru": "Настройки скоро!"},
}


func _ready() -> void:
	current_locale = SaveManager.get_setting("locale", "de")
	if not SUPPORTED_LOCALES.has(current_locale):
		current_locale = "de"


## Übersetzt einen Key. Fehlende Keys geben den Key selbst zurück.
func t(key: String, args: Array = []) -> String:
	if not _T.has(key):
		push_warning("[Locale] Fehlender Key: '%s'" % key)
		return key
	var entry: Dictionary = _T[key]
	var text: String = entry.get(current_locale, entry.get("en", key))
	if args.is_empty():
		return text
	return text % args


## Kurzform: L.t("key") → LM.t("key")
func translate(key: String, args: Array = []) -> String:
	return t(key, args)


func set_locale(locale: String) -> void:
	if not SUPPORTED_LOCALES.has(locale):
		return
	current_locale = locale
	SaveManager.set_setting("locale", locale)
	locale_changed.emit(locale)


func get_locale_display_name(locale: String) -> String:
	return LOCALE_NAMES.get(locale, locale)


func get_all_locales() -> Array[String]:
	var result: Array[String] = []
	for l in SUPPORTED_LOCALES:
		result.append(l)
	return result
