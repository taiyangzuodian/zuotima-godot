extends GdUnitTestSuite

const SettingsService = preload("res://scripts/services/settings/settings_service.gd")


func test_default_settings_do_not_include_ai_credentials() -> void:
	var service := SettingsService.new("user://settings_test.cfg")
	var settings = service.load_or_default()

	assert_that(settings.ai_base_url).is_equal("")
	assert_that(settings.ai_api_key).is_equal("")
	assert_that(settings.ai_model).is_equal("")


func test_environment_variables_do_not_bypass_saved_ai_settings() -> void:
	OS.set_environment("ZUOTIMA_AI_BASE_URL", "https://example.test/v1")
	OS.set_environment("ZUOTIMA_AI_API_KEY", "key-a")
	OS.set_environment("ZUOTIMA_AI_MODEL", "model-a")
	var service := SettingsService.new("user://env_settings_test.cfg")
	var settings = service.load_or_default()
	OS.unset_environment("ZUOTIMA_AI_BASE_URL")
	OS.unset_environment("ZUOTIMA_AI_API_KEY")
	OS.unset_environment("ZUOTIMA_AI_MODEL")

	assert_that(settings.ai_base_url).is_equal("")
	assert_that(settings.ai_api_key).is_equal("")
	assert_that(settings.ai_model).is_equal("")
