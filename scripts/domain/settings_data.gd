class_name SettingsData
extends RefCounted

var ui_language := "zh"
var jump_action_key := KEY_SHIFT
var ai_base_url := ""
var ai_model := ""
var ai_api_key := ""


func to_dict() -> Dictionary:
	return {
		"ui_language": ui_language,
		"jump_action_key": jump_action_key,
		"ai_base_url": ai_base_url,
		"ai_model": ai_model,
		"ai_api_key": ai_api_key,
	}


static func from_dict(data: Dictionary) -> SettingsData:
	var settings := SettingsData.new()
	settings.ui_language = data.get("ui_language", "zh")
	settings.jump_action_key = int(data.get("jump_action_key", KEY_SHIFT))
	settings.ai_base_url = str(data.get("ai_base_url", ""))
	settings.ai_model = str(data.get("ai_model", ""))
	settings.ai_api_key = str(data.get("ai_api_key", ""))
	return settings
