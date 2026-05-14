class_name SettingsOverlay
extends PlaceholderModal

const SettingsData = preload("res://scripts/domain/settings_data.gd")

var settings_service: Object


func _ready() -> void:
	super._ready()
	$CenterContainer/ModalPanel/Content/SaveButton.pressed.connect(_save_current_settings)


func load_settings(service: Object) -> void:
	settings_service = service
	var settings: SettingsData = settings_service.load_or_default()
	$CenterContainer/ModalPanel/Content/FieldList/BaseUrlRow/BaseUrlContent/BaseUrlField.text = (
		settings.ai_base_url
	)
	$CenterContainer/ModalPanel/Content/FieldList/ModelRow/ModelContent/ModelField.text = (
		settings.ai_model
	)
	$CenterContainer/ModalPanel/Content/FieldList/ApiKeyRow/ApiKeyContent/ApiKeyField.text = (
		settings.ai_api_key
	)


func _save_current_settings() -> void:
	if settings_service == null:
		return
	var settings: SettingsData = settings_service.load_or_default()
	settings.ai_base_url = (
		$CenterContainer/ModalPanel/Content/FieldList/BaseUrlRow/BaseUrlContent/BaseUrlField
		. text
		. strip_edges()
	)
	settings.ai_model = (
		$CenterContainer/ModalPanel/Content/FieldList/ModelRow/ModelContent/ModelField
		. text
		. strip_edges()
	)
	settings.ai_api_key = (
		$CenterContainer/ModalPanel/Content/FieldList/ApiKeyRow/ApiKeyContent/ApiKeyField
		. text
		. strip_edges()
	)
	settings_service.save(settings)
