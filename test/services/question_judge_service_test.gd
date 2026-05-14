extends GdUnitTestSuite

const JudgementRequest = preload("res://scripts/domain/judgement_request.gd")
const JudgementResult = preload("res://scripts/domain/judgement_result.gd")
const QuestionJudgeService = preload("res://scripts/services/ai/question_judge_service.gd")
const SettingsData = preload("res://scripts/domain/settings_data.gd")


class ImmediateProvider:
	var last_messages: Array[Dictionary] = []

	func request_json(
		_settings: SettingsData, _messages: Array[Dictionary], _schema_name: String
	) -> Dictionary:
		last_messages = _messages
		return {
			"ok": true,
			"data":
			{
				"verdict": "correct",
				"reason": "matched intent",
				"canonical_answer": "跑酷与答题",
			},
		}


class BlockingProvider:
	signal released

	func request_json(
		_settings: SettingsData, _messages: Array[Dictionary], _schema_name: String
	) -> Dictionary:
		await released
		return {
			"ok": true,
			"data":
			{
				"verdict": "correct",
				"reason": "matched intent",
				"canonical_answer": "跑酷与答题",
			},
		}


class JudgeRunner:
	extends RefCounted

	signal completed

	var last_result: JudgementResult
	var _service: QuestionJudgeService
	var _settings: SettingsData
	var _request: JudgementRequest

	func _init(
		p_service: QuestionJudgeService, p_settings: SettingsData, p_request: JudgementRequest
	) -> void:
		_service = p_service
		_settings = p_settings
		_request = p_request

	func run() -> void:
		last_result = await _service.judge(_settings, _request)
		completed.emit()


func test_judge_maps_provider_data_into_judgement_result() -> void:
	var provider := ImmediateProvider.new()
	var service: QuestionJudgeService = QuestionJudgeService.new(provider)
	var settings := SettingsData.new()
	var request := JudgementRequest.new("run-1", "q1", "核心玩法是什么？", "跑酷与答题", "跑酷与答题")

	var result: JudgementResult = await service.judge(settings, request)

	assert_that(result.verdict).is_equal(JudgementResult.VERDICT_CORRECT)
	assert_that(result.canonical_answer).is_equal("跑酷与答题")
	assert_that(str(provider.last_messages[0].get("content", ""))).contains("Expected answer hint")
	assert_that(str(provider.last_messages[0].get("content", ""))).contains("correct")
	assert_that(str(provider.last_messages[0].get("content", ""))).contains("incorrect")


func test_judge_rejects_a_second_pending_request() -> void:
	var provider := BlockingProvider.new()
	var service: QuestionJudgeService = QuestionJudgeService.new(provider)
	var settings := SettingsData.new()

	var runner := JudgeRunner.new(
		service, settings, JudgementRequest.new("run-1", "q1", "题目一", "答案一")
	)
	runner.call_deferred("run")
	await get_tree().process_frame

	var second_result: JudgementResult = await service.judge(
		settings, JudgementRequest.new("run-1", "q2", "题目二", "答案二")
	)

	assert_that(second_result.verdict).is_equal(JudgementResult.VERDICT_ERROR)
	assert_that(second_result.reason).contains("pending")

	provider.call_deferred("emit_signal", "released")
	await runner.completed
	assert_that(runner.last_result.verdict).is_equal(JudgementResult.VERDICT_CORRECT)
