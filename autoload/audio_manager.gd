extends Node
## AudioManager — Null Protocol
## Verwaltet alle Sounds zentral. Andere Systeme senden nur
## EventBus.audio_play_sfx("key") und kümmern sich nicht um Nodes.

const MUSIC_FADE_TIME := 1.2
## Tracks, die nur einmal spielen (Stinger); alle anderen loopen.
const NON_LOOPING_TRACKS: Array[String] = ["gameover"]

var _sfx_players:  Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _sfx_pool_size := 12

var _music_tween:   Tween
var _current_track: String = ""
var _music_request: int = 0   # verwirft veraltete, noch wartende play_music()-Aufrufe

# Laufzeit-Lautstärken (werden aus SaveManager geladen)
var sfx_volume_db:   float = 0.0
var music_volume_db: float = -6.0

# Mapping: sound_key → Ressourcenpfad.
# Füge hier neue Sounds ein, sobald du AudioStream-Assets hast.
# Alle Pfade sind Platzhalter — ersetze sie durch deine .ogg/.wav-Dateien.
const SFX_MAP: Dictionary = {
	"risk_win":      "res://assets/sounds/risk_win.ogg",
	"risk_lose":     "res://assets/sounds/risk_lose.ogg",
	"item_heal":     "res://assets/sounds/item_heal.ogg",
	"item_peek":     "res://assets/sounds/item_peek.ogg",
	"item_force":    "res://assets/sounds/item_force.ogg",
	"item_steal":    "res://assets/sounds/item_steal.ogg",
	"item_generic":  "res://assets/sounds/item_generic.ogg",
	"turn_start":    "res://assets/sounds/turn_start.ogg",
	"player_die":    "res://assets/sounds/player_die.ogg",
	"match_over":    "res://assets/sounds/match_over.ogg",
	"ui_click":      "res://assets/sounds/ui_click.ogg",
	"ui_hover":      "res://assets/sounds/ui_hover.ogg",
}

const MUSIC_MAP: Dictionary = {
	"menu":     "res://assets/sounds/music_menu.ogg",
	"match":    "res://assets/sounds/music_match.ogg",
	"tense":    "res://assets/sounds/music_tense.ogg",
	"gameover": "res://assets/sounds/music_gameover.ogg",
}


func _ready() -> void:
	# SFX-Pool anlegen
	for i in _sfx_pool_size:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)

	# Musik-Player anlegen
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

	# EventBus verdrahten
	EventBus.audio_play_sfx.connect(play_sfx)
	EventBus.audio_play_music.connect(play_music)
	EventBus.audio_stop_music.connect(stop_music)

	# Lautstärken aus SaveManager laden
	sfx_volume_db   = SaveManager.get_setting("sfx_volume",   0.0)
	music_volume_db = SaveManager.get_setting("music_volume", -6.0)
	_apply_volumes()


func play_sfx(sound_key: String) -> void:
	if not SFX_MAP.has(sound_key):
		return
	var path: String = SFX_MAP[sound_key]
	if not ResourceLoader.exists(path):
		return   # Asset noch nicht vorhanden — kein Fehler, nur überspringen
	var stream: AudioStream = load(path)
	var player := _get_free_sfx_player()
	if player == null:
		return
	player.stream          = stream
	player.volume_db       = sfx_volume_db
	player.play()


func play_music(track_key: String) -> void:
	if not MUSIC_MAP.has(track_key):
		return
	# Läuft der Track bereits, nicht neu starten (z. B. wiederholte Phasenwechsel).
	if track_key == _current_track and _music_player.playing:
		return
	var path: String = MUSIC_MAP[track_key]
	if not ResourceLoader.exists(path):
		return
	_music_request += 1
	var request := _music_request
	_current_track = track_key
	_kill_music_tween()
	if _music_player.playing:
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", -80.0, MUSIC_FADE_TIME * 0.5)
		await get_tree().create_timer(MUSIC_FADE_TIME * 0.5).timeout
		if request != _music_request:
			return   # in der Zwischenzeit wurde ein anderer Track angefordert
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = not (track_key in NON_LOOPING_TRACKS)
	_music_player.stream    = stream
	_music_player.volume_db = -80.0
	_music_player.play()
	_kill_music_tween()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", music_volume_db, MUSIC_FADE_TIME * 0.5)


func stop_music() -> void:
	if not _music_player.playing:
		return
	_music_request += 1
	var request := _music_request
	_current_track = ""
	_kill_music_tween()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", -80.0, MUSIC_FADE_TIME)
	await get_tree().create_timer(MUSIC_FADE_TIME).timeout
	if request == _music_request:
		_music_player.stop()


func _kill_music_tween() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()


func set_sfx_volume(db: float) -> void:
	sfx_volume_db = db
	SaveManager.set_setting("sfx_volume", db)
	_apply_volumes()


func set_music_volume(db: float) -> void:
	music_volume_db = db
	_kill_music_tween()   # laufenden Fade nicht gegen den Slider arbeiten lassen
	_music_player.volume_db = db
	SaveManager.set_setting("music_volume", db)


func _apply_volumes() -> void:
	for p in _sfx_players:
		p.volume_db = sfx_volume_db
	_music_player.volume_db = music_volume_db


func _get_free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_players:
		if not p.playing:
			return p
	# Alle belegt → ältesten überschreiben (der erste im Pool)
	_sfx_players[0].stop()
	return _sfx_players[0]
