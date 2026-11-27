extends Node

# Небольшой пул голосов для коротких процедурных звуков боя и интерфейса.
# Все PCM-сигналы строятся один раз из data/balance.json, поэтому APK не
# содержит внешних аудиофайлов и не запрашивает доступ к сети.

const PresentationCatalog = preload("res://scripts/ui/presentation_catalog.gd")

var players: Array = []
var clips: Dictionary = {}
var enabled: bool = true
var next_voice: int = 0


func configure(balance: Dictionary, sound_on: bool) -> void:
	enabled = bool(sound_on)
	var config: Dictionary = PresentationCatalog.audio_config(balance)
	var mix_rate: int = int(config.get("mix_rate", 22050))
	if AudioServer.get_bus_count() > 0:
		AudioServer.set_bus_volume_db(0, float(config.get("master_volume_db", -8.0)))
	for _index in range(int(config.get("voice_count", 6))):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		players.append(player)
	var sounds: Dictionary = config.get("sounds", {}) as Dictionary
	for event_id in sounds.keys():
		var spec: Dictionary = sounds[event_id] as Dictionary
		clips[str(event_id)] = {
			"stream": PresentationCatalog.build_stream(spec, mix_rate),
			"volume_db": float(spec.get("volume_db", -12.0)),
		}


func set_enabled(value: bool) -> void:
	enabled = bool(value)
	if not enabled:
		for item in players:
			(item as AudioStreamPlayer).stop()


func play(event_id: String) -> void:
	if not enabled or not clips.has(event_id) or players.is_empty():
		return
	var player: AudioStreamPlayer = players[next_voice] as AudioStreamPlayer
	next_voice = (next_voice + 1) % players.size()
	# При точечном запуске через --script дерево ещё не активно. В игре
	# обработчики вызываются после _ready(), поэтому звук воспроизводится.
	if not player.is_inside_tree():
		return
	var clip: Dictionary = clips[event_id] as Dictionary
	player.stream = clip.get("stream") as AudioStreamWAV
	player.volume_db = float(clip.get("volume_db", -12.0))
	player.play()


func stream_count() -> int:
	return clips.size()


func voice_count() -> int:
	return players.size()
