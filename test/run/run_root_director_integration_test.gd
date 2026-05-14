extends GdUnitTestSuite

const DocumentSource = preload("res://scripts/domain/document_source.gd")
const JudgementResult = preload("res://scripts/domain/judgement_result.gd")
const QuestionData = preload("res://scripts/domain/question_data.gd")
const QuestionPack = preload("res://scripts/domain/question_pack.gd")
const RunContext = preload("res://scripts/domain/run_context.gd")
const SettingsData = preload("res://scripts/domain/settings_data.gd")


class FakePipeline:
	var pack: QuestionPack
	var error := ""

	func _init(p_pack: QuestionPack = null, p_error := "") -> void:
		pack = p_pack
		error = p_error

	func prepare(run_id: String, _settings: SettingsData, _source: DocumentSource) -> Dictionary:
		if not error.is_empty():
			return {"ok": false, "run_id": run_id, "error": error}
		return {"ok": true, "run_id": run_id, "pack": pack}


class FakeJudge:
	var result: JudgementResult
	var judged_answers: Array[String] = []

	func _init(p_result: JudgementResult = null) -> void:
		result = p_result if p_result != null else JudgementResult.new()

	func judge(_settings: SettingsData, _request) -> JudgementResult:
		judged_answers.append(_request.player_answer)
		return result


class ResultCapture:
	var data

	func capture(p_data) -> void:
		data = p_data


func test_run_root_starts_director_and_syncs_active_hud() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()
	var scene = runner.scene()
	scene.pipeline_service = FakePipeline.new(_valid_pack())
	scene.judge_service = FakeJudge.new()

	var context: RunContext = await scene.start_run("run-1", _source(), SettingsData.new())

	assert_that(context.phase).is_equal(RunContext.PHASE_ACTIVE)
	assert_that(scene.director.context).is_equal(context)
	assert_that(scene.get_node("BackgroundLayer/WarmupTint").visible).is_false()
	assert_that(scene.get_node("BackgroundLayer/ActiveTint").visible).is_true()
	assert_that(runner.find_child("PhaseLabel").text).is_equal("答题中")
	assert_that(runner.find_child("ShieldValue").text).is_equal("有盾")
	assert_that(runner.find_child("PromptLabel").text).is_equal("第一题")


func test_run_root_emits_failed_result_after_deadly_collision() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()
	var scene = runner.scene()
	scene.pipeline_service = FakePipeline.new(_valid_pack())
	scene.judge_service = FakeJudge.new()
	var capture := ResultCapture.new()
	scene.run_completed.connect(capture.capture)
	await scene.start_run("run-1", _source(), SettingsData.new())

	scene.handle_collision()
	scene.director.tick(0.76)
	scene.handle_collision()

	assert_that(capture.data.result).is_equal("failed")
	assert_that(scene.get_node("BackgroundLayer/FailureOverlay").visible).is_true()


func test_run_root_emits_cleared_result_after_last_answer() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()
	var scene = runner.scene()
	scene.pipeline_service = FakePipeline.new(_valid_pack())
	scene.judge_service = FakeJudge.new(
		JudgementResult.new("run-1", "q3", JudgementResult.VERDICT_CORRECT, "ok", "答案三")
	)
	var capture := ResultCapture.new()
	scene.run_completed.connect(capture.capture)
	await scene.start_run("run-1", _source(), SettingsData.new())
	scene.timeout_current_question()
	scene.timeout_current_question()

	await scene.submit_answer("答案三")

	assert_that(capture.data.result).is_equal("cleared")
	assert_that(runner.find_child("PhaseLabel").text).is_equal("挑战通关")


func test_hud_submit_button_submits_answer_to_run_director() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()
	var scene = runner.scene()
	scene.pipeline_service = FakePipeline.new(_valid_pack())
	scene.judge_service = FakeJudge.new(
		JudgementResult.new("run-1", "q3", JudgementResult.VERDICT_CORRECT, "ok", "答案三")
	)
	var capture := ResultCapture.new()
	scene.run_completed.connect(capture.capture)
	await scene.start_run("run-1", _source(), SettingsData.new())
	scene.timeout_current_question()
	scene.timeout_current_question()
	var answer_field := runner.find_child("AnswerField") as LineEdit
	answer_field.text = "答案三"

	(runner.find_child("SubmitButton") as Button).emit_signal("pressed")
	await runner.await_input_processed()
	await await_idle_frame()

	assert_that(capture.data.result).is_equal("cleared")
	assert_that(answer_field.text).is_empty()


func test_incorrect_answer_advances_to_next_question() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()
	var scene = runner.scene()
	scene.pipeline_service = FakePipeline.new(_valid_pack())
	scene.judge_service = FakeJudge.new(
		JudgementResult.new("run-1", "q1", JudgementResult.VERDICT_INCORRECT, "miss", "答案一")
	)
	await scene.start_run("run-1", _source(), SettingsData.new())
	var answer_field := runner.find_child("AnswerField") as LineEdit
	answer_field.text = "错了"

	(runner.find_child("SubmitButton") as Button).emit_signal("pressed")
	await runner.await_input_processed()
	await await_idle_frame()

	assert_that(scene.director.context.current_question().question_id).is_equal("q2")
	assert_that((runner.find_child("PromptLabel") as Label).text).is_equal("第二题")
	assert_that((runner.find_child("PressureHint") as Label).text).contains("压力升高")
	assert_that(answer_field.text).is_empty()


func test_run_root_shows_preparation_error_without_completion() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()
	var scene = runner.scene()
	scene.pipeline_service = FakePipeline.new(null, "provider failed")
	scene.judge_service = FakeJudge.new()
	var capture := ResultCapture.new()
	scene.run_completed.connect(capture.capture)

	var context: RunContext = await scene.start_run("run-1", _source(), SettingsData.new())

	assert_that(context.phase).is_equal(RunContext.PHASE_PREPARATION_ERROR)
	assert_that(capture.data).is_null()
	assert_that(scene.get_node("BackgroundLayer/FailureOverlay").visible).is_true()
	assert_that(runner.find_child("PhaseLabel").text).is_equal("准备失败")
	assert_that((runner.find_child("PromptLabel") as Label).text).contains("provider failed")


func test_run_root_process_expires_pressure_windows() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()
	var scene = runner.scene()
	scene.pipeline_service = FakePipeline.new(_valid_pack())
	scene.judge_service = FakeJudge.new()
	await scene.start_run("run-1", _source(), SettingsData.new())

	scene.timeout_current_question()
	scene._process(4.1)

	assert_that(scene.director.context.pressure_state).is_equal(RunContext.PRESSURE_NORMAL)


func test_run_root_keeps_answer_focus_when_pressure_changes() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()
	var scene = runner.scene()
	var answer_field := runner.find_child("AnswerField") as LineEdit
	answer_field.grab_focus()
	scene.pipeline_service = FakePipeline.new(_valid_pack())
	scene.judge_service = FakeJudge.new()
	await scene.start_run("run-1", _source(), SettingsData.new())

	scene.timeout_current_question()

	assert_that(answer_field.has_focus()).is_true()
	assert_that(runner.find_child("PressureHint").text).contains("压力升高")


func test_world_collision_forwarding_is_safe_in_warmup_and_active_in_formal_run() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()
	var scene = runner.scene()
	scene.pipeline_service = FakePipeline.new(_valid_pack())
	scene.judge_service = FakeJudge.new()

	scene.get_node("WorldLayer/HazardSpawner").notify_player_collision()
	assert_that(scene.director).is_null()

	await scene.start_run("run-1", _source(), SettingsData.new())
	var answer_field := runner.find_child("AnswerField") as LineEdit
	answer_field.grab_focus()
	scene.get_node("WorldLayer/HazardSpawner").notify_player_collision()

	assert_that(scene.director.context.shield_state).is_equal(RunContext.SHIELD_BROKEN)
	assert_that(answer_field.has_focus()).is_true()


func test_world_overlap_with_hazard_damages_player_during_active_run() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()
	var scene = runner.scene()
	scene.pipeline_service = FakePipeline.new(_valid_pack())
	scene.judge_service = FakeJudge.new()
	await scene.start_run("run-1", _source(), SettingsData.new())
	var player := runner.find_child("PlayerPlaceholder") as Node2D
	var hazard = scene.get_node("WorldLayer/HazardSpawner").spawn_hazard()
	hazard.position = player.position

	scene.tick_world(0.01)

	assert_that(scene.director.context.shield_state).is_equal(RunContext.SHIELD_BROKEN)


func test_visual_edge_overlap_with_hazard_damages_player() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()
	var scene = runner.scene()
	scene.pipeline_service = FakePipeline.new(_valid_pack())
	scene.judge_service = FakeJudge.new()
	await scene.start_run("run-1", _source(), SettingsData.new())
	var player := runner.find_child("PlayerPlaceholder") as Node2D
	var hazard = scene.get_node("WorldLayer/HazardSpawner").spawn_hazard()
	hazard.position = player.position + Vector2(64.0, 0.0)

	scene.tick_world(0.01)

	assert_that(scene.director.context.shield_state).is_equal(RunContext.SHIELD_BROKEN)


func test_second_world_overlap_after_shield_break_fails_run() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()
	var scene = runner.scene()
	scene.pipeline_service = FakePipeline.new(_valid_pack())
	scene.judge_service = FakeJudge.new()
	var capture := ResultCapture.new()
	scene.run_completed.connect(capture.capture)
	await scene.start_run("run-1", _source(), SettingsData.new())
	var player := runner.find_child("PlayerPlaceholder") as Node2D
	var spawner = scene.get_node("WorldLayer/HazardSpawner")
	var first_hazard = spawner.spawn_hazard()
	first_hazard.position = player.position
	scene.tick_world(0.01)
	scene.director.tick(0.76)
	var second_hazard = spawner.spawn_hazard()
	second_hazard.position = player.position

	scene.tick_world(0.01)

	assert_that(capture.data.result).is_equal("failed")
	assert_that(scene.director.context.phase).is_equal(RunContext.PHASE_FAILED)


func test_judgement_error_shows_retry_actions_and_preserves_answer() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()
	var scene = runner.scene()
	var judge := FakeJudge.new(
		JudgementResult.new("run-1", "q1", JudgementResult.VERDICT_ERROR, "provider failed", "")
	)
	scene.pipeline_service = FakePipeline.new(_valid_pack())
	scene.judge_service = judge
	await scene.start_run("run-1", _source(), SettingsData.new())
	var answer_field := runner.find_child("AnswerField") as LineEdit
	answer_field.text = "答案一"

	(runner.find_child("SubmitButton") as Button).emit_signal("pressed")
	await runner.await_input_processed()
	await await_idle_frame()

	assert_that(runner.find_child("JudgementBanner").visible).is_true()
	assert_that(runner.find_child("StatusLabel").text).contains("provider failed")
	assert_that(runner.find_child("RetryJudgementButton")).is_not_null()
	assert_that(runner.find_child("EndRunButton")).is_not_null()
	assert_that(answer_field.text).is_equal("答案一")
	assert_that(judge.judged_answers).contains_exactly(["答案一"])

	judge.result = JudgementResult.new("run-1", "q1", JudgementResult.VERDICT_CORRECT, "ok", "答案一")
	(runner.find_child("RetryJudgementButton") as Button).emit_signal("pressed")
	await runner.await_input_processed()
	await await_idle_frame()

	assert_that(judge.judged_answers).contains_exactly(["答案一", "答案一"])
	assert_that(scene.director.context.current_question().question_id).is_equal("q2")
	assert_that(answer_field.text).is_empty()


func test_end_run_from_judgement_error_emits_failed_result() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()
	var scene = runner.scene()
	var judge := FakeJudge.new(
		JudgementResult.new("run-1", "q1", JudgementResult.VERDICT_ERROR, "provider failed", "")
	)
	scene.pipeline_service = FakePipeline.new(_valid_pack())
	scene.judge_service = judge
	var capture := ResultCapture.new()
	scene.run_completed.connect(capture.capture)
	await scene.start_run("run-1", _source(), SettingsData.new())
	await scene.submit_answer("答案一")

	(runner.find_child("EndRunButton") as Button).emit_signal("pressed")
	await runner.await_input_processed()
	await await_idle_frame()

	assert_that(capture.data.result).is_equal("failed")
	assert_that(runner.find_child("PhaseLabel").text).is_equal("挑战失败")


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


func _source() -> DocumentSource:
	return DocumentSource.sample("示例", "res://data/sample_docs/chinese_sample.md", "zh")
