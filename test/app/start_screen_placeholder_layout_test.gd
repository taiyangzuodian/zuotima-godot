extends GdUnitTestSuite

const DocumentSource = preload("res://scripts/domain/document_source.gd")
const HistoryEntry = preload("res://scripts/domain/history_entry.gd")
const LatestSummaryData = preload("res://scripts/domain/latest_summary_data.gd")
const SettingsData = preload("res://scripts/domain/settings_data.gd")
const StartRunGate = preload("res://scripts/app/start_run_gate.gd")


class SignalCapture:
	extends RefCounted

	var message_key := ""

	func capture(p_message_key: String) -> void:
		message_key = p_message_key


class RunRequestCapture:
	extends RefCounted

	var source: DocumentSource
	var count := 0

	func capture(p_source: DocumentSource) -> void:
		source = p_source
		count += 1


class FakeLatestSummaryService:
	var summary := LatestSummaryData.new()

	func load() -> LatestSummaryData:
		return summary


class FakeHistoryService:
	var entries: Array[HistoryEntry] = []
	var load_count := 0

	func load_entries() -> Array[HistoryEntry]:
		load_count += 1
		return entries


class EmptySettingsService:
	func load_or_default() -> SettingsData:
		return SettingsData.new()


class UsableSettingsService:
	var saved_settings: SettingsData

	func load_or_default() -> SettingsData:
		var settings := SettingsData.new()
		settings.ai_base_url = "https://example.test/v1"
		settings.ai_model = "model-a"
		settings.ai_api_key = "key-a"
		return settings

	func save(settings: SettingsData) -> bool:
		saved_settings = settings
		return true


func test_start_screen_contains_primary_and_secondary_placeholder_actions() -> void:
	var runner := scene_runner("res://scenes/menu/start_screen.tscn")
	await await_idle_frame()

	assert_that(runner.find_child("SampleDocumentButton")).is_not_null()
	assert_that(runner.find_child("LocalFileButton")).is_not_null()
	assert_that(runner.find_child("SettingsButton")).is_not_null()
	assert_that(runner.find_child("HowToPlayButton")).is_not_null()
	assert_that(runner.find_child("LatestSummaryButton")).is_not_null()
	assert_that(runner.find_child("HistoryButton")).is_not_null()


func test_secondary_buttons_open_placeholder_overlays() -> void:
	var runner := scene_runner("res://scenes/menu/start_screen.tscn")
	await await_idle_frame()

	var settings_button := runner.find_child("SettingsButton") as Button
	var settings_overlay := runner.find_child("SettingsOverlay") as Control
	settings_button.emit_signal("pressed")
	await runner.await_input_processed()
	assert_that(settings_overlay.visible).is_true()

	var history_button := runner.find_child("HistoryButton") as Button
	var history_overlay := runner.find_child("HistoryOverlay") as Control
	history_button.emit_signal("pressed")
	await runner.await_input_processed()
	assert_that(history_overlay.visible).is_true()


func test_settings_overlay_loads_and_saves_ai_settings() -> void:
	var runner := scene_runner("res://scenes/menu/start_screen.tscn")
	await await_idle_frame()
	var screen = runner.scene()
	var settings_service := UsableSettingsService.new()
	screen.settings_service = settings_service
	var settings_overlay := runner.find_child("SettingsOverlay")

	settings_overlay.call("load_settings", screen.settings_service)
	assert_that((runner.find_child("BaseUrlField") as LineEdit).text).is_equal(
		"https://example.test/v1"
	)
	assert_that((runner.find_child("ModelField") as LineEdit).text).is_equal("model-a")
	assert_that((runner.find_child("ApiKeyField") as LineEdit).text).is_equal("key-a")

	(runner.find_child("BaseUrlField") as LineEdit).text = "https://new.example/v1"
	(runner.find_child("ModelField") as LineEdit).text = "model-b"
	(runner.find_child("ApiKeyField") as LineEdit).text = "key-b"
	(runner.find_child("SaveButton") as Button).emit_signal("pressed")
	await runner.await_input_processed()

	assert_that(settings_service.saved_settings.ai_base_url).is_equal("https://new.example/v1")
	assert_that(settings_service.saved_settings.ai_model).is_equal("model-b")
	assert_that(settings_service.saved_settings.ai_api_key).is_equal("key-b")


func test_latest_summary_overlay_loads_saved_summary() -> void:
	var runner := scene_runner("res://scenes/menu/start_screen.tscn")
	await await_idle_frame()
	var screen = runner.scene()
	var latest_service := FakeLatestSummaryService.new()
	latest_service.summary.summary_title = "生成标题"
	latest_service.summary.summary_text = "这是最近一次摘要。"
	latest_service.summary.source_language = "zh"
	screen.latest_summary_service = latest_service

	(runner.find_child("LatestSummaryButton") as Button).emit_signal("pressed")
	await runner.await_input_processed()

	assert_that((runner.find_child("SummaryTitle") as Label).text).is_equal("生成标题")
	assert_that((runner.find_child("SummaryBody") as Label).text).contains("这是最近一次摘要。")
	assert_that((runner.find_child("SummaryMeta") as Label).text).contains("zh")


func test_latest_summary_overlay_shows_empty_state_without_summary() -> void:
	var runner := scene_runner("res://scenes/menu/start_screen.tscn")
	await await_idle_frame()
	var screen = runner.scene()
	screen.latest_summary_service = FakeLatestSummaryService.new()

	(runner.find_child("LatestSummaryButton") as Button).emit_signal("pressed")
	await runner.await_input_processed()

	assert_that((runner.find_child("SummaryTitle") as Label).text).contains("暂无摘要")
	assert_that((runner.find_child("SummaryBody") as Label).text).contains("完成一次挑战")


func test_history_overlay_loads_saved_entries_when_opened() -> void:
	var runner := scene_runner("res://scenes/menu/start_screen.tscn")
	await await_idle_frame()
	var screen = runner.scene()
	var history_service := FakeHistoryService.new()
	var entry := HistoryEntry.new()
	entry.summary_title = "跑酷与答题"
	entry.completed_at = "2026-04-28T10:30:00Z"
	entry.result = "cleared"
	entry.accuracy = 0.75
	entry.question_count = 4
	history_service.entries.append(entry)
	screen.history_service = history_service

	assert_that(history_service.load_count).is_equal(0)
	(runner.find_child("HistoryButton") as Button).emit_signal("pressed")
	await runner.await_input_processed()

	var history_list := runner.find_child("HistoryList") as VBoxContainer
	var first_item := history_list.get_child(0)
	assert_that(history_service.load_count).is_equal(1)
	assert_that((first_item.find_child("HistoryItemTitle") as Label).text).is_equal("跑酷与答题")
	assert_that((first_item.find_child("HistoryItemMeta") as Label).text).contains(
		"2026-04-28T10:30:00Z"
	)
	assert_that((first_item.find_child("HistoryItemMeta") as Label).text).contains("cleared")
	assert_that((first_item.find_child("HistoryItemMeta") as Label).text).contains("75%")
	assert_that((first_item.find_child("HistoryItemMeta") as Label).text).contains("4 题")
	assert_that((runner.find_child("EmptyStateCard") as Control).visible).is_false()


func test_history_overlay_shows_empty_state_without_entries() -> void:
	var runner := scene_runner("res://scenes/menu/start_screen.tscn")
	await await_idle_frame()
	var screen = runner.scene()
	var history_service := FakeHistoryService.new()
	screen.history_service = history_service

	assert_that(history_service.load_count).is_equal(0)
	(runner.find_child("HistoryButton") as Button).emit_signal("pressed")
	await runner.await_input_processed()

	assert_that(history_service.load_count).is_equal(1)
	assert_that((runner.find_child("HistoryList") as Control).visible).is_false()
	assert_that((runner.find_child("EmptyStateCard") as Control).visible).is_true()
	assert_that((runner.find_child("EmptyStateLabel") as Label).text).contains("完成一次挑战")


func test_sample_button_blocks_without_ai_settings() -> void:
	var runner := scene_runner("res://scenes/menu/start_screen.tscn")
	await await_idle_frame()
	var screen = runner.scene()
	screen.settings_service = EmptySettingsService.new()
	screen.start_run_gate = StartRunGate.new("res://data/sample_docs/chinese_sample.md")
	var capture := SignalCapture.new()
	screen.start_blocked.connect(capture.capture)

	var sample_button := runner.find_child("SampleDocumentButton") as Button
	sample_button.emit_signal("pressed")
	await runner.await_input_processed()

	var blocked_message := runner.find_child("StartBlockedMessage") as Label
	assert_that(capture.message_key).is_equal("missing_ai_config")
	assert_that(blocked_message.visible).is_true()
	assert_that(blocked_message.text).contains("AI")
	assert_that(blocked_message.text).contains("设置")


func test_local_file_selection_requests_run_for_markdown_file() -> void:
	var runner := scene_runner("res://scenes/menu/start_screen.tscn")
	await await_idle_frame()
	var screen = runner.scene()
	screen.settings_service = UsableSettingsService.new()
	var capture := RunRequestCapture.new()
	screen.run_requested.connect(capture.capture)
	var path := "user://local_start.md"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("本地文档内容")
	file.close()

	(runner.find_child("LocalFileDialog") as FileDialog).file_selected.emit(path)

	assert_that(capture.source).is_not_null()
	assert_that(capture.source.source_type).is_equal(DocumentSource.TYPE_LOCAL_FILE)
	assert_that(capture.source.display_name).is_equal("local_start.md")
	assert_that(capture.source.file_path).is_equal(path)
	assert_that(capture.source.language_hint).is_equal("")


func test_local_file_selection_blocks_without_ai_settings() -> void:
	var runner := scene_runner("res://scenes/menu/start_screen.tscn")
	await await_idle_frame()
	var screen = runner.scene()
	screen.settings_service = EmptySettingsService.new()
	var blocked_capture := SignalCapture.new()
	var run_capture := RunRequestCapture.new()
	screen.start_blocked.connect(blocked_capture.capture)
	screen.run_requested.connect(run_capture.capture)
	var path := "user://local_without_settings.md"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("本地文档内容")
	file.close()

	screen.call("_request_local_file_run", path)

	assert_that(blocked_capture.message_key).is_equal("missing_ai_config")
	assert_that(run_capture.count).is_equal(0)


func test_local_file_selection_blocks_unsupported_extension() -> void:
	var runner := scene_runner("res://scenes/menu/start_screen.tscn")
	await await_idle_frame()
	var screen = runner.scene()
	screen.settings_service = UsableSettingsService.new()
	var capture := SignalCapture.new()
	screen.start_blocked.connect(capture.capture)
	var path := "user://local_start.pdf"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("本地文档内容")
	file.close()

	screen.call("_request_local_file_run", path)

	assert_that(capture.message_key).is_equal("unsupported_local_file_type")
