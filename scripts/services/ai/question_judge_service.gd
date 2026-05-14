class_name QuestionJudgeService
extends RefCounted

const JudgementRequest = preload("res://scripts/domain/judgement_request.gd")
const JudgementResult = preload("res://scripts/domain/judgement_result.gd")
const SettingsData = preload("res://scripts/domain/settings_data.gd")

var _provider_service: Object
var _pending_key := ""


func _init(p_provider_service: Object) -> void:
	_provider_service = p_provider_service


func judge(settings: SettingsData, request: JudgementRequest) -> JudgementResult:
	if _pending_key != "":
		return JudgementResult.new(
			request.run_id,
			request.question_id,
			JudgementResult.VERDICT_ERROR,
			"judgement already pending"
		)

	_pending_key = "%s:%s" % [request.run_id, request.question_id]
	var prompt_template := (
		"Question: %s\n"
		+ "Expected answer hint: %s\n"
		+ "Player answer: %s\n"
		+ "Return JSON with verdict, reason, and canonical_answer. "
		+ "verdict must be correct or incorrect unless judging cannot be completed."
	)
	var messages: Array[Dictionary] = [
		{
			"role": "user",
			"content":
			(
				prompt_template
				% [request.question_prompt, request.expected_answer_hint, request.player_answer]
			),
		}
	]
	var response: Dictionary = await _provider_service.request_json(
		settings, messages, "judgement_result"
	)
	_pending_key = ""

	if not response.get("ok", false):
		return JudgementResult.new(
			request.run_id,
			request.question_id,
			JudgementResult.VERDICT_ERROR,
			str(response.get("error", "judgement failed"))
		)

	var data: Dictionary = response.get("data", {})
	return JudgementResult.new(
		request.run_id,
		request.question_id,
		str(data.get("verdict", JudgementResult.VERDICT_ERROR)),
		str(data.get("reason", "")),
		str(data.get("canonical_answer", ""))
	)
