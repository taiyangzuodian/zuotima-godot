extends GdUnitTestSuite

const BootScene = preload("res://scenes/app/boot.tscn")
const DocumentSource = preload("res://scripts/domain/document_source.gd")
const HistoryEntry = preload("res://scripts/domain/history_entry.gd")
const JudgementResult = preload("res://scripts/domain/judgement_result.gd")
const LatestSummaryData = preload("res://scripts/domain/latest_summary_data.gd")
const QuestionData = preload("res://scripts/domain/question_data.gd")
const QuestionPack = preload("res://scripts/domain/question_pack.gd")
const RunResultData = preload("res://scripts/domain/run_result_data.gd")
const SettingsData = preload("res://scripts/domain/settings_data.gd")


class FakePipeline:
	var prepare_called := false
	var prepare_count := 0
	var pack: QuestionPack

	func _init(p_pack: QuestionPack = null) -> void:
		pack = p_pack

	func prepare(_run_id: String, _settings: SettingsData, _source: DocumentSource) -> Dictionary:
		prepare_called = true
		prepare_count += 1
		if pack != null:
			return {"ok": true, "run_id": _run_id, "pack": pack}
		return {"ok": false, "run_id": _run_id, "error": "test stop"}


class FakeJudge:
	var result: JudgementResult
	var terminal_target: Node

	func _init(p_result: JudgementResult = null) -> void:
		result = p_result if p_result != null else JudgementResult.new()

	func judge(_settings: SettingsData, _request) -> JudgementResult:
		if terminal_target != null:
			terminal_target.handle_collision()
			terminal_target.director.tick(0.76)
			terminal_target.handle_collision()
		return result


class FakeLatestSummaryService:
	var saved_summary: LatestSummaryData

	func save(summary: LatestSummaryData) -> bool:
		saved_summary = summary
		return true


class FakeHistoryService:
	var entries: Array[HistoryEntry] = []

	func append_entry(entry: HistoryEntry) -> bool:
		entries.append(entry)
		return true


func test_boot_switches_from_start_screen_to_run_screen_on_run_request() -> void:
	var boot: Node = auto_free(BootScene.instantiate())
	boot.pipeline_service = FakePipeline.new()
	boot.judge_service = FakeJudge.new()
	add_child(boot)
	await await_idle_frame()
	boot.call(
		"_start_run", DocumentSource.sample("示例", "res://data/sample_docs/chinese_sample.md", "zh")
	)
	await await_idle_frame()

	assert_that(boot.get_child_count()).is_equal(1)
	assert_that(boot.get_child(0).name).is_equal("RunRoot")


func test_boot_switches_from_run_screen_to_result_screen_on_run_completed() -> void:
	var boot: Node = auto_free(BootScene.instantiate())
	boot.pipeline_service = FakePipeline.new()
	boot.judge_service = FakeJudge.new()
	add_child(boot)
	await await_idle_frame()
	boot.call(
		"_start_run", DocumentSource.sample("示例", "res://data/sample_docs/chinese_sample.md", "zh")
	)
	await await_idle_frame()
	var run_screen: Node = boot.get_child(0)

	run_screen.run_completed.emit(_result_data())
	await await_idle_frame()

	assert_that(boot.get_child_count()).is_equal(1)
	assert_that(boot.get_child(0).name).is_equal("ResultScreen")
	var title_label := boot.get_child(0).get_node(
		"RootMargin/Layout/ResultCard/ResultContent/ResultTitleLabel"
	)
	assert_that(title_label.text).is_equal("挑战失败")


func test_pending_judgement_can_finish_after_boot_replaces_run_screen() -> void:
	var boot: Node = auto_free(BootScene.instantiate())
	var judge := FakeJudge.new(
		JudgementResult.new("run-1", "q1", JudgementResult.VERDICT_CORRECT, "ok", "答案一")
	)
	boot.pipeline_service = FakePipeline.new(_valid_pack())
	boot.judge_service = judge
	add_child(boot)
	await await_idle_frame()
	boot.call(
		"_start_run", DocumentSource.sample("示例", "res://data/sample_docs/chinese_sample.md", "zh")
	)
	await await_idle_frame()
	var run_screen = boot.get_child(0)
	judge.terminal_target = run_screen

	await run_screen.submit_answer("答案一")
	await await_idle_frame()
	await await_idle_frame()

	assert_that(boot.get_child_count()).is_equal(1)
	assert_that(boot.get_child(0).name).is_equal("ResultScreen")


func test_result_back_button_returns_to_start_screen() -> void:
	var boot: Node = auto_free(BootScene.instantiate())
	boot.pipeline_service = FakePipeline.new()
	boot.judge_service = FakeJudge.new()
	add_child(boot)
	await await_idle_frame()
	boot.call("_show_result_screen", _result_data())
	await await_idle_frame()

	(
		(boot.get_child(0).get_node("RootMargin/Layout/ActionButtons/BackButton") as Button)
		. emit_signal("pressed")
	)
	await await_idle_frame()

	assert_that(boot.get_child_count()).is_equal(1)
	assert_that(boot.get_child(0).name).is_equal("StartScreen")


func test_result_retry_button_restarts_last_source() -> void:
	var boot: Node = auto_free(BootScene.instantiate())
	var pipeline := FakePipeline.new(_valid_pack())
	boot.pipeline_service = pipeline
	boot.judge_service = FakeJudge.new()
	add_child(boot)
	await await_idle_frame()
	boot.call(
		"_start_run", DocumentSource.sample("示例", "res://data/sample_docs/chinese_sample.md", "zh")
	)
	await await_idle_frame()
	var run_screen: Node = boot.get_child(0)
	run_screen.run_completed.emit(_result_data())
	await await_idle_frame()

	(
		(boot.get_child(0).get_node("RootMargin/Layout/ActionButtons/RetryButton") as Button)
		. emit_signal("pressed")
	)
	await await_idle_frame()

	assert_that(boot.get_child_count()).is_equal(1)
	assert_that(boot.get_child(0).name).is_equal("RunRoot")
	assert_that(pipeline.prepare_count).is_equal(2)


func test_run_completion_saves_latest_summary_and_history_entry() -> void:
	var boot: Node = auto_free(BootScene.instantiate())
	var latest_summary_service := FakeLatestSummaryService.new()
	var history_service := FakeHistoryService.new()
	boot.latest_summary_service = latest_summary_service
	boot.history_service = history_service
	add_child(boot)
	await await_idle_frame()

	boot.call("_show_result_screen", _cleared_result_data())
	await await_idle_frame()

	assert_that(latest_summary_service.saved_summary).is_not_null()
	assert_that(latest_summary_service.saved_summary.summary_title).is_equal("标题")
	assert_that(latest_summary_service.saved_summary.summary_text).is_equal("摘要")
	assert_that(latest_summary_service.saved_summary.source_language).is_equal("zh")
	assert_that(history_service.entries).has_size(1)
	assert_that(history_service.entries[0].summary_title).is_equal("标题")
	assert_that(history_service.entries[0].result).is_equal("cleared")
	assert_float(history_service.entries[0].accuracy).is_equal(0.5)
	assert_that(history_service.entries[0].question_count).is_equal(4)


func test_failed_run_without_summary_does_not_overwrite_latest_summary() -> void:
	var boot: Node = auto_free(BootScene.instantiate())
	var latest_summary_service := FakeLatestSummaryService.new()
	var history_service := FakeHistoryService.new()
	boot.latest_summary_service = latest_summary_service
	boot.history_service = history_service
	add_child(boot)
	await await_idle_frame()

	boot.call("_show_result_screen", _result_data())
	await await_idle_frame()

	assert_that(latest_summary_service.saved_summary).is_null()
	assert_that(history_service.entries).has_size(1)
	assert_that(history_service.entries[0].result).is_equal("failed")


func _result_data() -> RunResultData:
	var data := RunResultData.new()
	data.result = "failed"
	data.accuracy = 0.25
	data.question_count = 4
	return data


func _cleared_result_data() -> RunResultData:
	var data := RunResultData.new()
	data.result = "cleared"
	data.summary_title = "标题"
	data.summary_text = "摘要"
	data.source_language = "zh"
	data.accuracy = 0.5
	data.question_count = 4
	return data


func _valid_pack() -> QuestionPack:
	return (
		QuestionPack
		. new(
			"pack-1",
			"zh",
			"标题",
			"摘要",
			[
				QuestionData.new("q1", "第一题", "答案一", 20.0),
				QuestionData.new("q2", "第二题", "答案二", 20.0),
				QuestionData.new("q3", "第三题", "答案三", 20.0),
			]
		)
	)
