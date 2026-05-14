extends GdUnitTestSuite

const LatestSummaryData = preload("res://scripts/domain/latest_summary_data.gd")
const LatestSummaryService = preload("res://scripts/services/history/latest_summary_service.gd")


func test_latest_summary_service_round_trips_summary_json() -> void:
	var service := LatestSummaryService.new("user://latest_summary_test.json")
	var summary := LatestSummaryData.new()
	summary.generated_at = "2026-04-22T10:00:00Z"
	summary.summary_title = "跑酷与答题"
	summary.summary_text = "玩家需要边躲避边输入答案。"
	summary.source_language = "zh"

	assert_that(service.save(summary)).is_true()

	var loaded := service.load()
	assert_that(loaded.summary_title).is_equal("跑酷与答题")
	assert_that(loaded.source_language).is_equal("zh")
