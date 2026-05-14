class_name SettingsService
extends RefCounted

const SettingsData = preload("res://scripts/domain/settings_data.gd")

var _config_path := "user://settings.cfg"


func _init(p_config_path: String = "user://settings.cfg") -> void:
	_config_path = p_config_path


func default_settings() -> SettingsData:
	return SettingsData.new()


func load_or_default() -> SettingsData:
	var config := ConfigFile.new()
	if config.load(_config_path) != OK:
		return default_settings()

	var settings := default_settings()
	settings.ui_language = str(config.get_value("ui", "language", settings.ui_language))
	settings.jump_action_key = int(config.get_value("input", "jump_key", settings.jump_action_key))
	settings.ai_base_url = str(config.get_value("ai", "base_url", settings.ai_base_url))
	settings.ai_api_key = str(config.get_value("ai", "api_key", settings.ai_api_key))
	settings.ai_model = str(config.get_value("ai", "model", settings.ai_model))
	return settings


func save(settings: SettingsData) -> bool:
	var config := ConfigFile.new()
	config.set_value("ui", "language", settings.ui_language)
	config.set_value("input", "jump_key", settings.jump_action_key)
	config.set_value("ai", "base_url", settings.ai_base_url)
	config.set_value("ai", "api_key", settings.ai_api_key)
	config.set_value("ai", "model", settings.ai_model)
	return config.save(_config_path) == OK
