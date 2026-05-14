extends GdUnitTestSuite

const BootScene = preload("res://scenes/app/boot.tscn")
const DocumentSource = preload("res://scripts/domain/document_source.gd")
const JudgementResult = preload("res://scripts/domain/judgement_result.gd")
const QuestionData = preload("res://scripts/domain/question_data.gd")
const QuestionPack = preload("res://scripts/domain/question_pack.gd")
const RunContext = preload("res://scripts/domain/run_context.gd")
const SettingsData = preload("res://scripts/domain/settings_data.gd")


class FakeSettingsService:
	func load_or_default() -> SettingsData:
		var settings := SettingsData.new()
		settings.ai_base_url = "http://127.0.0.1:8317/v1"
		settings.ai_api_key = "sk-test"
		settings.ai_model = "test-model"
		return settings


class FakePipeline:
	signal preparation_released

	var last_source: DocumentSource
	var prepare_count := 0

	func prepare(_run_id: String, _settings: SettingsData, source: DocumentSource) -> Dictionary:
		last_source = source
		prepare_count += 1
		await preparation_released
		return {"ok": true, "run_id": _run_id, "pack": _valid_pack(_run_id)}

	func release_preparation() -> void:
		preparation_released.emit()

	func _valid_pack(run_id: String) -> QuestionPack:
		return (
			QuestionPack
			. new(
				"%s-pack" % run_id,
				"zh",
				"完整流程标题",
				"完整流程摘要",
				[
					QuestionData.new("q1", "第一题", "答案一", 20.0),
					QuestionData.new("q2", "第二题", "答案二", 20.0),
					QuestionData.new("q3", "第三题", "答案三", 20.0),
				]
			)
		)


class FakeJudge:
	var judged_answers: Array[String] = []

	func judge(_settings: SettingsData, request) -> JudgementResult:
		judged_answers.append(request.player_answer)
		return JudgementResult.new(
			request.run_id,
			request.question_id,
			JudgementResult.VERDICT_CORRECT,
			"matched intent",
			request.player_answer
		)


func test_sample_document_flow_reaches_questions_and_result_screen() -> void:
	var boot: Node = auto_free(BootScene.instantiate())
	var pipeline := FakePipeline.new()
	var judge := FakeJudge.new()
	boot.settings_service = FakeSettingsService.new()
	boot.pipeline_service = pipeline
	boot.judge_service = judge
	add_child(boot)
	await await_idle_frame()

	var start_screen := boot.get_child(0)
	(start_screen.find_child("SampleDocumentButton", true, false) as Button).emit_signal("pressed")
	await await_idle_frame()
	await await_idle_frame()

	var run_screen := boot.get_child(0)
	assert_that(run_screen.name).is_equal("RunRoot")
	assert_that(pipeline.prepare_count).is_equal(1)
	assert_that(pipeline.last_source.source_type).is_equal(DocumentSource.TYPE_SAMPLE)
	assert_that(run_screen.director.context.phase).is_equal(RunContext.PHASE_WARMUP)
	assert_that((run_screen.find_child("PhaseLabel", true, false) as Label).text).is_equal("预热中")
	assert_that(run_screen.get_node("BackgroundLayer/WarmupTint").visible).is_true()

	pipeline.release_preparation()
	await await_idle_frame()
	await await_idle_frame()

	assert_that((run_screen.find_child("PhaseLabel", true, false) as Label).text).is_equal("答题中")
	assert_that((run_screen.find_child("PromptLabel", true, false) as Label).text).is_equal("第一题")

	_submit_answer(run_screen, "答案一")
	await await_idle_frame()
	await await_idle_frame()
	assert_that(judge.judged_answers).contains_exactly(["答案一"])
	assert_that((run_screen.find_child("PromptLabel", true, false) as Label).text).is_equal("第二题")

	_submit_answer(run_screen, "答案二")
	await await_idle_frame()
	_submit_answer(run_screen, "答案三")
	await await_idle_frame()
	await await_idle_frame()

	var result_screen := boot.get_child(0)
	assert_that(result_screen.name).is_equal("ResultScreen")
	assert_that((result_screen.find_child("ResultTitleLabel", true, false) as Label).text).is_equal(
		"挑战通关"
	)
	assert_that(judge.judged_answers).contains_exactly(["答案一", "答案二", "答案三"])


func _submit_answer(run_screen: Node, answer: String) -> void:
	var answer_field := run_screen.find_child("AnswerField", true, false) as LineEdit
	answer_field.text = answer
	(run_screen.find_child("SubmitButton", true, false) as Button).emit_signal("pressed")
