extends GdUnitTestSuite

const PlaceholderPalette = preload("res://scripts/ui/placeholder_palette.gd")


func test_make_panel_style_uses_shared_panel_tokens() -> void:
	var style := PlaceholderPalette.make_panel_style()

	assert_that(style.bg_color).is_equal(PlaceholderPalette.COLOR_PANEL_BG)
	assert_that(style.border_color).is_equal(PlaceholderPalette.COLOR_PANEL_BORDER)
	assert_that(style.border_width_left).is_equal(2)
	assert_that(style.corner_radius_top_left).is_equal(12)


func test_color_for_state_maps_known_states() -> void:
	assert_that(PlaceholderPalette.color_for_state("safe")).is_equal(PlaceholderPalette.COLOR_SAFE)
	assert_that(PlaceholderPalette.color_for_state("warning")).is_equal(
		PlaceholderPalette.COLOR_WARNING
	)
	assert_that(PlaceholderPalette.color_for_state("danger")).is_equal(
		PlaceholderPalette.COLOR_DANGER
	)
	assert_that(PlaceholderPalette.color_for_state("success")).is_equal(
		PlaceholderPalette.COLOR_SUCCESS
	)
