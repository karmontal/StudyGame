class_name ToddlerVoice
extends RefCounted
## What the toddler games say. A recorded clip res://assets/toddler/voice/<key>.ogg (or .mp3/.wav) wins
## when it exists (a parent's voice is nicer than the phone's); otherwise the phone's text-to-speech reads
## the text. To add a recording, save it under the key from PHRASES below; docs/aya_voice.md lists them
## (regenerate it with `python3 tools/aya_voice_list.py` after changing PHRASES).

const DIR := "res://assets/toddler/voice/"

const PHRASES := {
	"hello": "أهلاً آية! شو بدك تلعبي؟",
	"bravo": "برافو آية!",
	"try": "حاولي كمان!",
	"w_cat": "وين القطة؟",
	"w_cow": "وين البقرة؟",
	"w_sheep": "وين الخاروف؟",
	"w_chicken": "وين الجاجة؟",
	"w_duck": "وين البطة؟",
	"w_dog": "وين الكلب؟",
	"w_lion": "وين الأسد؟",
	"w_banana": "وين الموزة؟",
	"w_apple": "وين التفاحة؟",
	"wc_red": "وين الطابة الحمرا؟",
	"wc_yellow": "وين الطابة الصفرا؟",
	"wc_blue": "وين الطابة الزرقا؟",
	"wc_green": "وين الطابة الخضرا؟",
	"rest": "يلا نرتاح شوي",
	"game_color": "يلا نلوّن!",
	"game_draw": "يلا نرسم!",
	"game_sort": "حطّي كل طابة بالسلّة اللي بلونها",
	"game_shapes": "حطّي كل شكل بمكانه",
	"game_puzzle": "يلا نركّب الصورة",
	"game_animals": "مين هاد؟ دوسي عليه!",
	"game_balloons": "يلا نفقع البالونات!",
	"c_red": "أحمر",
	"c_yellow": "أصفر",
	"c_blue": "أزرق",
	"c_green": "أخضر",
	"c_orange": "برتقالي",
	"c_pink": "زهري",
	"c_purple": "بنفسجي",
	"c_brown": "بني",
	"s_circle": "دائرة",
	"s_square": "مربع",
	"s_triangle": "مثلث",
	"s_star": "نجمة",
	"s_heart": "قلب",
	"a_cat": "قطة! مياو",
	"a_cow": "بقرة! مووو",
	"a_sheep": "خروف! ماااع",
	"a_chicken": "جاجة! كاك كاك",
	"a_duck": "بطة! كواك كواك",
	"a_dog": "كلب! هاو هاو",
	"a_lion": "أسد! غرررر",
	"a_banana": "موزة! يمّ يمّ",
	"a_apple": "تفاحة! يمّ يمّ",
	"p_sun": "شمس",
	"p_apple": "تفاحة",
	"p_fish": "سمكة",
	"p_house": "بيت",
	"p_flower": "وردة",
	"p_cat": "قطة",
	"p_cow": "بقرة",
	"p_duck": "بطة",
	"p_lion": "أسد",
}

static var last_key := ""  # for tests
static var last_text := ""
static var last_was_clip := false
static var _player: AudioStreamPlayer


const CLIP_TYPES := ["ogg", "mp3", "wav"]


## The recorded clip for a phrase (<key>.ogg, .mp3 or .wav in DIR), or "" when there is none.
static func clip_path(key: String) -> String:
	for ext in CLIP_TYPES:
		var p: String = DIR + key + "." + ext
		if ResourceLoader.exists(p):
			return p
	return ""


static func has_clip(key: String) -> bool:
	return clip_path(key) != ""


## Says a phrase: the recorded clip when there is one, else the phone's voice. `text` defaults to
## PHRASES[key]. Returns true when something is playing.
static func say(key: String, text: String = "") -> bool:
	if text == "":
		text = PHRASES.get(key, "")
	last_key = key
	last_text = text
	last_was_clip = false
	if not Settings.sound_on():
		return false
	if has_clip(key):
		var stream: AudioStream = load(clip_path(key))
		if stream != null:
			Sfx.stop_speaking()
			var p := _get_player()
			p.stream = stream
			p.play()
			last_was_clip = true
			return true
	if _player != null and is_instance_valid(_player):
		_player.stop()
	return Sfx.speak(text, "ar")


static func colour_key(color_id: String) -> String:
	return "c_" + color_id


static func _get_player() -> AudioStreamPlayer:
	if _player == null or not is_instance_valid(_player):
		_player = AudioStreamPlayer.new()
		_player.name = "ToddlerVoice"
		Sfx.add_child(_player)
	return _player
