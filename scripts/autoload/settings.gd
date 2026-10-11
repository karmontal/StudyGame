extends Node
## Device settings that are not per kid: sound on/off and the parent dashboard connection.
## Saved to user://settings.cfg.

var path := "user://settings.cfg"
var _cfg := ConfigFile.new()


func _ready() -> void:
	_cfg.load(path)


func get_value(key: String, default: Variant = null) -> Variant:
	return _cfg.get_value("app", key, default)


func set_value(key: String, value: Variant) -> void:
	_cfg.set_value("app", key, value)
	_cfg.save(path)


func sound_on() -> bool:
	return bool(get_value("sound", true))


## A random id for this phone, made once, so the dashboard can tell devices apart.
func device_id() -> String:
	var id := str(get_value("device_id", ""))
	if id == "":
		id = "dev-%08x%08x" % [randi(), randi()]
		set_value("device_id", id)
	return id


## Clears everything (tests).
func reset() -> void:
	_cfg = ConfigFile.new()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
