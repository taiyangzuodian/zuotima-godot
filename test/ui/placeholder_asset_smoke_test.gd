extends GdUnitTestSuite


func test_placeholder_scenes_load_without_parse_errors() -> void:
	assert_that(load("res://scenes/menu/start_screen.tscn")).is_not_null()
	assert_that(load("res://scenes/menu/overlays/settings_overlay.tscn")).is_not_null()
	assert_that(load("res://scenes/menu/overlays/how_to_play_overlay.tscn")).is_not_null()
	assert_that(load("res://scenes/menu/overlays/latest_summary_overlay.tscn")).is_not_null()
	assert_that(load("res://scenes/menu/overlays/history_overlay.tscn")).is_not_null()
	assert_that(load("res://scenes/run/question_hud.tscn")).is_not_null()
	assert_that(load("res://scenes/run/run_root.tscn")).is_not_null()
	assert_that(load("res://scenes/result/result_screen.tscn")).is_not_null()
