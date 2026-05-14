extends GdUnitTestSuite


func test_main_scene_path_is_configured() -> void:
	var project_settings := ProjectSettings
	assert_that(project_settings.get_setting("application/run/main_scene")).is_equal(
		"res://scenes/app/boot.tscn"
	)


func test_windows_export_preset_is_configured() -> void:
	var config := ConfigFile.new()
	assert_that(config.load("res://export_presets.cfg")).is_equal(OK)
	assert_that(config.get_value("preset.0", "name", "")).is_equal("Windows Desktop")
	assert_that(config.get_value("preset.0", "platform", "")).is_equal("Windows Desktop")
	assert_that(config.get_value("preset.0", "export_path", "")).is_equal(
		"build/windows/zuotima.exe"
	)
	assert_that(config.has_section("preset.0.options")).is_true()


func test_core_input_actions_are_configured() -> void:
	assert_that(InputMap.has_action("jump")).is_true()
	assert_that(InputMap.has_action("submit_answer")).is_true()
	assert_that(_action_has_key("jump", KEY_SHIFT)).is_true()
	assert_that(_action_has_key("submit_answer", KEY_ENTER)).is_true()


func _action_has_key(action_name: String, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.keycode == keycode:
			return true
	return false
