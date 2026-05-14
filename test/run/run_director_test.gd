extends GdUnitTestSuite

const DocumentSource = preload("res://scripts/domain/document_source.gd")
const JudgementResult = preload("res://scripts/domain/judgement_result.gd")
const QuestionData = preload("res://scripts/domain/question_data.gd")
const QuestionPack = preload("res://scripts/domain/question_pack.gd")
const RunContext = preload("res://scripts/domain/run_context.gd")
const RunDirector = preload("res://scripts/run/run_director.gd")
const SettingsData = preload("res://scripts/domain/settings_data.gd")


class FakePipeline:
	var result: Dictionary
	var requested_run_id := ""

	func _init(p_result: Dictionary) -> void:
		result = p_result

	func prepare(run_id: String, _settings: SettingsData, _source: DocumentSource) -> Dictionary:
		requested_run_id = run_id
		return result


class BlockingPipeline:
	signal released

	var result: Dictionary
	var requested_model := ""
	var requested_display_name := ""

	func _init(p_result: Dictionary) -> void:
		result = p_result

	func prepare(_run_id: String, settings: SettingsData, source: DocumentSource) -> Dictionary:
		await released
		requested_model = settings.ai_model
		requested_display_name = source.display_name
		return result


class FakeJudge:
	var result: JudgementResult
	var judged_answer := ""
	var settings_model := ""

	func _init(p_result: JudgementResult) -> void:
		result = p_result

	func judge(_settings: SettingsData, request) -> JudgementResult:
		judged_answer = request.player_answer
		settings_model = _settings.ai_model
		return result


class BlockingJudge:
	signal released

	var result: JudgementResult
	var judged_answer := ""

	func _init(p_result: JudgementResult) -> void:
		result = p_result

	func judge(_settings: SettingsData, request) -> JudgementResult:
		judged_answer = request.player_answer
		await released
		return result


class SubmitRunner:
	extends RefCounted

	signal completed

	var result: JudgementResult
	var _director: RunDirector
	var _answer := ""

	func _init(p_director: RunDirector, p_answer: String) -> void:
		_director = p_director
		_answer = p_answer

	func run() -> void:
		result = await _director.submit_answer(_answer)
		completed.emit()


class StartRunner:
	extends RefCounted

	signal completed

	var context: RunContext
	var _director: RunDirector
	var _run_id := ""
	var _source: DocumentSource
	var _settings: SettingsData

	func _init(
		p_director: RunDirector,
		p_run_id: String,
		p_source: DocumentSource,
		p_settings: SettingsData
	) -> void:
		_director = p_director
		_run_id = p_run_id
		_source = p_source
		_settings = p_settings

	func run() -> void:
		context = await _director.start_run(_run_id, _source, _settings)
		completed.emit()


func test_start_enters_warmup_then_applies_prepared_question_pack() -> void:
	var pack := _valid_pack()
	var pipeline := FakePipeline.new({"ok": true, "run_id": "run-1", "pack": pack})
	var director := RunDirector.new(pipeline, FakeJudge.new(JudgementResult.new()))

	var context: RunContext = await director.start_run("run-1", _source(), SettingsData.new())

	assert_that(context.run_id).is_equal("run-1")
	assert_that(context.phase).is_equal(RunContext.PHASE_ACTIVE)
	assert_that(context.summary_title).is_equal("标题")
	assert_that(context.current_question().question_id).is_equal("q1")
	assert_that(pipeline.requested_run_id).is_equal("run-1")


func test_preparation_result_without_matching_run_id_is_ignored() -> void:
	var pipeline := FakePipeline.new({"ok": true, "pack": _valid_pack()})
	var director := RunDirector.new(pipeline, FakeJudge.new(JudgementResult.new()))

	var context: RunContext = await director.start_run("run-1", _source(), SettingsData.new())

	assert_that(context.phase).is_equal(RunContext.PHASE_WARMUP)
	assert_that(context.questions).is_empty()


func test_invalid_question_pack_enters_preparation_error() -> void:
	var pipeline := FakePipeline.new({"ok": true, "run_id": "run-1", "pack": _pack([])})
	var director := RunDirector.new(pipeline, FakeJudge.new(JudgementResult.new()))

	var context: RunContext = await director.start_run("run-1", _source(), SettingsData.new())

	assert_that(context.phase).is_equal(RunContext.PHASE_PREPARATION_ERROR)
	assert_that(context.last_error_message).contains("question pack")


func test_question_pack_missing_answer_hint_enters_preparation_error() -> void:
	var invalid_pack := _pack(
		[
			QuestionData.new("q1", "第一题", "", 20.0),
			QuestionData.new("q2", "第二题", "答案二", 20.0),
			QuestionData.new("q3", "第三题", "答案三", 20.0),
		]
	)
	var pipeline := FakePipeline.new({"ok": true, "run_id": "run-1", "pack": invalid_pack})
	var director := RunDirector.new(pipeline, FakeJudge.new(JudgementResult.new()))

	var context: RunContext = await director.start_run("run-1", _source(), SettingsData.new())

	assert_that(context.phase).is_equal(RunContext.PHASE_PREPARATION_ERROR)
	assert_that(context.questions).is_empty()


func test_collision_is_safe_in_warmup_and_fails_after_break_protection_expires() -> void:
	var director := RunDirector.new(FakePipeline.new({}), FakeJudge.new(JudgementResult.new()))
	director.begin_warmup("run-1", _source(), SettingsData.new())

	director.handle_collision()
	assert_that(director.context.shield_state).is_equal(RunContext.SHIELD_SHIELDED)

	director.apply_question_pack(_valid_pack())
	director.handle_collision()
	assert_that(director.context.shield_state).is_equal(RunContext.SHIELD_BROKEN)
	assert_that(director.context.phase).is_equal(RunContext.PHASE_ACTIVE)

	director.handle_collision()
	assert_that(director.context.phase).is_equal(RunContext.PHASE_ACTIVE)
	assert_that(director.context.shield_state).is_equal(RunContext.SHIELD_BROKEN)

	director.tick(0.76)
	director.handle_collision()
	assert_that(director.context.phase).is_equal(RunContext.PHASE_FAILED)
	assert_that(director.context.pending_judgement_question_id).is_equal("")


func test_collision_during_preparation_error_does_not_break_shield() -> void:
	var pipeline := FakePipeline.new({"ok": false, "run_id": "run-1", "error": "provider failed"})
	var director := RunDirector.new(pipeline, FakeJudge.new(JudgementResult.new()))
	await director.start_run("run-1", _source(), SettingsData.new())

	director.handle_collision()
	director.tick(0.76)
	director.handle_collision()

	assert_that(director.context.phase).is_equal(RunContext.PHASE_PREPARATION_ERROR)
	assert_that(director.context.shield_state).is_equal(RunContext.SHIELD_SHIELDED)


func test_correct_answer_restores_shield_applies_relief_and_advances() -> void:
	var judge := FakeJudge.new(
		JudgementResult.new("run-1", "q1", JudgementResult.VERDICT_CORRECT, "ok", "答案一")
	)
	var director := RunDirector.new(FakePipeline.new({}), judge)
	director.begin_warmup("run-1", _source(), SettingsData.new())
	director.apply_question_pack(_valid_pack())
	director.handle_collision()

	var result: JudgementResult = await director.submit_answer("答案一")

	assert_that(result.verdict).is_equal(JudgementResult.VERDICT_CORRECT)
	assert_that(judge.judged_answer).is_equal("答案一")
	assert_that(director.context.phase).is_equal(RunContext.PHASE_ACTIVE)
	assert_that(director.context.current_question().question_id).is_equal("q2")
	assert_that(director.context.shield_state).is_equal(RunContext.SHIELD_SHIELDED)
	assert_that(director.context.pressure_state).is_equal(RunContext.PRESSURE_REDUCED)


func test_incorrect_answer_records_verdict_and_applies_pressure_without_shield_damage() -> void:
	var judge := FakeJudge.new(
		JudgementResult.new("run-1", "q1", JudgementResult.VERDICT_INCORRECT, "miss", "答案一")
	)
	var director := RunDirector.new(FakePipeline.new({}), judge)
	director.begin_warmup("run-1", _source(), SettingsData.new())
	director.apply_question_pack(_valid_pack())

	var result: JudgementResult = await director.submit_answer("错误答案")

	assert_that(result.verdict).is_equal(JudgementResult.VERDICT_INCORRECT)
	assert_that(director.context.answered_count).is_equal(1)
	assert_that(director.context.correct_count).is_equal(0)
	assert_that(director.context.current_question().question_id).is_equal("q2")
	assert_that(director.context.shield_state).is_equal(RunContext.SHIELD_SHIELDED)
	assert_that(director.context.pressure_state).is_equal(RunContext.PRESSURE_INCREASED)
	var result_data := director.result_data()
	assert_that(result_data.recorded_results[0].get("verdict", "")).is_equal(
		JudgementResult.VERDICT_INCORRECT
	)
	assert_that(result_data.submitted_count).is_equal(1)
	assert_that(result_data.correct_count).is_equal(0)
	assert_that(result_data.wrong_items).has_size(1)
	assert_that(result_data.wrong_items[0].get("prompt", "")).is_equal("第一题")
	assert_that(result_data.wrong_items[0].get("player_answer", "")).is_equal("错误答案")
	assert_that(result_data.wrong_items[0].get("standard_answer", "")).is_equal("答案一")


func test_last_answer_clears_run() -> void:
	var judge := FakeJudge.new(
		JudgementResult.new("run-1", "q3", JudgementResult.VERDICT_CORRECT, "ok", "答案三")
	)
	var director := RunDirector.new(FakePipeline.new({}), judge)
	director.begin_warmup("run-1", _source(), SettingsData.new())
	director.apply_question_pack(_valid_pack())
	director.timeout_current_question()
	director.timeout_current_question()

	await director.submit_answer("答案三")

	assert_that(director.context.phase).is_equal(RunContext.PHASE_CLEARED)
	assert_that(director.result_data().result).is_equal("cleared")


func test_timeout_records_distinct_outcome_and_applies_penalty() -> void:
	var director := RunDirector.new(FakePipeline.new({}), FakeJudge.new(JudgementResult.new()))
	director.begin_warmup("run-1", _source(), SettingsData.new())
	director.apply_question_pack(_valid_pack())

	var record := director.timeout_current_question()

	assert_that(record.get("kind", "")).is_equal("timeout")
	assert_that(director.context.answered_count).is_equal(1)
	assert_that(director.context.pressure_state).is_equal(RunContext.PRESSURE_INCREASED)
	var result_data := director.result_data()
	assert_that(result_data.recorded_results[0].get("kind", "")).is_equal("timeout")
	assert_that(result_data.submitted_count).is_equal(0)
	assert_that(result_data.timeout_items).has_size(1)
	assert_that(result_data.timeout_items[0].get("prompt", "")).is_equal("第一题")
	assert_that(result_data.timeout_items[0].get("standard_answer", "")).is_equal("答案一")


func test_timeout_after_failure_is_ignored() -> void:
	var director := RunDirector.new(FakePipeline.new({}), FakeJudge.new(JudgementResult.new()))
	director.begin_warmup("run-1", _source(), SettingsData.new())
	director.apply_question_pack(_valid_pack())
	director.handle_collision()
	director.tick(0.76)
	director.handle_collision()

	var record := director.timeout_current_question()

	assert_that(record.get("kind", "")).is_equal("ignored")
	assert_that(director.context.phase).is_equal(RunContext.PHASE_FAILED)
	assert_that(director.context.answered_count).is_equal(0)


func test_judgement_error_keeps_question_available_for_retry() -> void:
	var judge := FakeJudge.new(
		JudgementResult.new("run-1", "q1", JudgementResult.VERDICT_ERROR, "provider error", "")
	)
	var director := RunDirector.new(FakePipeline.new({}), judge)
	director.begin_warmup("run-1", _source(), SettingsData.new())
	director.apply_question_pack(_valid_pack())

	await director.submit_answer("答案一")

	assert_that(director.context.phase).is_equal(RunContext.PHASE_ACTIVE)
	assert_that(director.context.current_question().question_id).is_equal("q1")
	assert_that(director.context.last_error_message).is_equal("provider error")

	judge.result = JudgementResult.new("run-1", "q1", JudgementResult.VERDICT_CORRECT, "ok", "答案一")
	await director.submit_answer("答案一")

	assert_that(director.context.phase).is_equal(RunContext.PHASE_ACTIVE)
	assert_that(director.context.current_question().question_id).is_equal("q2")


func test_timeout_after_judgement_error_is_ignored() -> void:
	var judge := FakeJudge.new(
		JudgementResult.new("run-1", "q1", JudgementResult.VERDICT_ERROR, "provider error", "")
	)
	var director := RunDirector.new(FakePipeline.new({}), judge)
	director.begin_warmup("run-1", _source(), SettingsData.new())
	director.apply_question_pack(_valid_pack())
	await director.submit_answer("答案一")

	var record := director.timeout_current_question()

	assert_that(record.get("kind", "")).is_equal("ignored")
	assert_that(director.context.current_question().question_id).is_equal("q1")
	assert_that(director.context.answered_count).is_equal(0)
	assert_that(director.context.pressure_state).is_equal(RunContext.PRESSURE_NORMAL)
	assert_that(director.result_data().recorded_results).is_empty()


func test_end_after_judgement_error_marks_run_failed_only_from_error_state() -> void:
	var judge := FakeJudge.new(
		JudgementResult.new("run-1", "q1", JudgementResult.VERDICT_ERROR, "provider error", "")
	)
	var director := RunDirector.new(FakePipeline.new({}), judge)
	director.begin_warmup("run-1", _source(), SettingsData.new())
	director.apply_question_pack(_valid_pack())

	assert_that(director.end_after_judgement_error()).is_false()
	assert_that(director.context.phase).is_equal(RunContext.PHASE_ACTIVE)

	await director.submit_answer("答案一")

	assert_that(director.end_after_judgement_error()).is_true()
	assert_that(director.context.phase).is_equal(RunContext.PHASE_FAILED)


func test_invalid_judgement_verdict_keeps_question_available_for_retry() -> void:
	var judge := FakeJudge.new(JudgementResult.new("run-1", "q1", "maybe", "bad schema", ""))
	var director := RunDirector.new(FakePipeline.new({}), judge)
	director.begin_warmup("run-1", _source(), SettingsData.new())
	director.apply_question_pack(_valid_pack())

	var result: JudgementResult = await director.submit_answer("答案一")

	assert_that(result.verdict).is_equal(JudgementResult.VERDICT_ERROR)
	assert_that(director.context.phase).is_equal(RunContext.PHASE_ACTIVE)
	assert_that(director.context.current_question().question_id).is_equal("q1")
	assert_that(director.context.answered_count).is_equal(0)
	assert_that(director.result_data().recorded_results).is_empty()


func test_run_uses_start_snapshot_for_source_and_settings() -> void:
	var settings := SettingsData.new()
	settings.ai_model = "model-at-start"
	var source := _source()
	var pipeline := BlockingPipeline.new({"ok": true, "run_id": "run-1", "pack": _valid_pack()})
	var judge := FakeJudge.new(
		JudgementResult.new("run-1", "q1", JudgementResult.VERDICT_CORRECT, "ok", "答案一")
	)
	var director := RunDirector.new(pipeline, judge)
	var runner := StartRunner.new(director, "run-1", source, settings)
	runner.call_deferred("run")
	await get_tree().process_frame

	settings.ai_model = "mutated-model"
	source.display_name = "mutated-source"
	pipeline.call_deferred("emit_signal", "released")
	await runner.completed
	await director.submit_answer("答案一")

	assert_that(pipeline.requested_model).is_equal("model-at-start")
	assert_that(pipeline.requested_display_name).is_equal("示例")
	assert_that(judge.settings_model).is_equal("model-at-start")
	assert_that(director.context.document_source.display_name).is_equal("示例")


func test_late_judgement_after_failure_does_not_return_applied_result() -> void:
	var judge := BlockingJudge.new(
		JudgementResult.new("run-1", "q1", JudgementResult.VERDICT_CORRECT, "ok", "答案一")
	)
	var director := RunDirector.new(FakePipeline.new({}), judge)
	director.begin_warmup("run-1", _source(), SettingsData.new())
	director.apply_question_pack(_valid_pack())
	var runner := SubmitRunner.new(director, "答案一")
	runner.call_deferred("run")
	await get_tree().process_frame

	director.handle_collision()
	director.tick(0.76)
	director.handle_collision()
	judge.call_deferred("emit_signal", "released")
	await runner.completed

	assert_that(runner.result.verdict).is_equal(JudgementResult.VERDICT_ERROR)
	assert_that(runner.result.reason).contains("ignored")


func test_late_judgement_after_failure_does_not_clear_run() -> void:
	var judge := BlockingJudge.new(
		JudgementResult.new("run-1", "q1", JudgementResult.VERDICT_CORRECT, "ok", "答案一")
	)
	var director := RunDirector.new(FakePipeline.new({}), judge)
	director.begin_warmup("run-1", _source(), SettingsData.new())
	director.apply_question_pack(_valid_pack())
	var runner := SubmitRunner.new(director, "答案一")
	runner.call_deferred("run")
	await get_tree().process_frame

	director.handle_collision()
	director.tick(0.76)
	director.handle_collision()
	judge.call_deferred("emit_signal", "released")
	await runner.completed

	assert_that(director.context.phase).is_equal(RunContext.PHASE_FAILED)
	assert_that(director.result_data().result).is_equal("failed")


func test_late_judgement_from_previous_run_is_ignored_after_restart() -> void:
	var judge := BlockingJudge.new(
		JudgementResult.new("run-1", "q1", JudgementResult.VERDICT_ERROR, "old error", "")
	)
	var director := RunDirector.new(FakePipeline.new({}), judge)
	director.begin_warmup("run-1", _source(), SettingsData.new())
	director.apply_question_pack(_valid_pack())
	var runner := SubmitRunner.new(director, "答案一")
	runner.call_deferred("run")
	await get_tree().process_frame

	director.begin_warmup("run-2", _source(), SettingsData.new())
	director.apply_question_pack(_valid_pack())
	judge.call_deferred("emit_signal", "released")
	await runner.completed

	assert_that(director.context.run_id).is_equal("run-2")
	assert_that(director.context.phase).is_equal(RunContext.PHASE_ACTIVE)
	assert_that(director.context.last_error_message).is_equal("")


func test_prepare_failure_stays_in_run_error_state() -> void:
	var pipeline := FakePipeline.new({"ok": false, "run_id": "run-1", "error": "provider failed"})
	var director := RunDirector.new(pipeline, FakeJudge.new(JudgementResult.new()))

	var context: RunContext = await director.start_run("run-1", _source(), SettingsData.new())

	assert_that(context.phase).is_equal(RunContext.PHASE_PREPARATION_ERROR)
	assert_that(context.last_error_message).is_equal("provider failed")


func _valid_pack() -> QuestionPack:
	return _pack(
		[
			QuestionData.new("q1", "第一题", "答案一", 20.0),
			QuestionData.new("q2", "第二题", "答案二", 20.0),
			QuestionData.new("q3", "第三题", "答案三", 20.0),
		]
	)


func _pack(questions: Array[QuestionData]) -> QuestionPack:
	return QuestionPack.new("pack-1", "zh", "标题", "摘要", questions)


func _source() -> DocumentSource:
	return DocumentSource.sample("示例", "res://data/sample_docs/chinese_sample.md", "zh")
