extends Node
## Sound effects (assets/sfx/*.wav, made by tools/make_sfx.py) and reading questions aloud with the
## phone's text-to-speech voice. Both follow the sound switch in Settings.

const NAMES := ["click", "correct", "wrong", "coin", "win", "fanfare", "tick", "timeup", "start", "buy",
	"pop", "boing", "cheer", "whoosh"]

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var last_played := ""  # for tests
var last_spoken := ""  # for tests


func _ready() -> void:
	for n in NAMES:
		var p := "res://assets/sfx/%s.wav" % n
		if ResourceLoader.exists(p):
			_streams[n] = load(p)
	# A few players so quick sounds (a click then "correct") can overlap.
	for i in 4:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	# Every button in the game gives a soft click.
	get_tree().node_added.connect(func(n: Node):
		if n is BaseButton and not n.pressed.is_connected(click):
			n.pressed.connect(click))


func play(sound: String) -> void:
	last_played = sound
	if not Settings.sound_on() or not _streams.has(sound):
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _streams[sound]
	player.play()


func click() -> void:
	play("click")


## True when the phone has a voice for the language ("ar" or "en").
func can_speak(lang: String) -> bool:
	return _voice(lang) != ""


## Reads the text aloud, stopping whatever was being read. Returns false without a voice.
func speak(text: String, lang: String = "ar") -> bool:
	last_spoken = text
	var voice := _voice(lang)
	if voice == "" or not Settings.sound_on():
		return false
	DisplayServer.tts_stop()
	# A little slower than normal so young kids can follow.
	DisplayServer.tts_speak(text, voice, 100, 1.0, 0.85)
	return true


func stop_speaking() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_stop()


func _voice(lang: String) -> String:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return ""
	var voices := DisplayServer.tts_get_voices_for_language(lang)
	return voices[0] if not voices.is_empty() else ""


## What the speaker button reads: the question, then each choice.
static func question_text(q: Dictionary, lang: String) -> String:
	var ar := lang != "en"
	var parts: Array[String] = [str(q.get("q", ""))]
	match q.get("type", ""):
		"mcq":
			var ordinals := ["الأول", "الثاني", "الثالث", "الرابع", "الخامس", "السادس"]
			for i in q.choices.size():
				if ar:
					parts.append("الخيار %s: %s" % [ordinals[mini(i, ordinals.size() - 1)], q.choices[i]])
				else:
					parts.append("Choice %d: %s" % [i + 1, q.choices[i]])
		"tf":
			parts.append("صح أم خطأ؟" if ar else "True or false?")
		"match":
			for s in q.get("left", []):
				parts.append(str(s))
			parts.append("وصّلها مع:" if ar else "Match them with:")
			for s in q.get("right", []):
				parts.append(str(s))
		"order":
			for s in q.get("shuffled", q.get("items", [])):
				parts.append(str(s))
	return "، ".join(parts) if ar else ". ".join(parts)
