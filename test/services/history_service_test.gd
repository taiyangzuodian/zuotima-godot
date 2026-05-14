extends GdUnitTestSuite

const HistoryEntry = preload("res://scripts/domain/history_entry.gd")
const HistoryService = preload("res://scripts/services/history/history_service.gd")


func test_history_service_appends_and_loads_entries() -> void:
	var storage_path := "user://history_test.json"
	if FileAccess.file_exists(storage_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(storage_path))

	var service := HistoryService.new(storage_path)
	var entry := HistoryEntry.new()
	entry.completed_at = "2026-04-22T10:05:00Z"
	entry.summary_title = "跑酷与答题"
	entry.result = "cleared"
	entry.accuracy = 1.0
	entry.question_count = 3

	assert_that(service.append_entry(entry)).is_true()

	var entries := service.load_entries()
	assert_that(entries).has_size(1)
	assert_that(entries[0].result).is_equal("cleared")
