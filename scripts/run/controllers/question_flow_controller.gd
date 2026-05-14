class_name QuestionFlowController
extends RefCounted

const JudgementRequest = preload("res://scripts/domain/judgement_request.gd")
const JudgementResult = preload("res://scripts/domain/judgement_result.gd")
const QuestionData = preload("res://scripts/domain/question_data.gd")
const QuestionPack = preload("res://scripts/domain/question_pack.gd")

var current_question_index := -1
var pending_judgement_question_id := ""
var pending_judgement_run_id := ""
var recorded_results: Array[Dictionary] = []
var timeout_items: Array[Dictionary] = []
var _questions: Array[QuestionData] = []
var _pending_player_answer := ""


func load_pack(pack: QuestionPack) -> void:
	_questions = pack.questions.duplicate()
	current_question_index = 0 if not _questions.is_empty() else -1
	pending_judgement_question_id = ""
	pending_judgement_run_id = ""
	_pending_player_answer = ""
	recorded_results.clear()
	timeout_items.clear()


func current_question() -> QuestionData:
	if current_question_index < 0 or current_question_index >= _questions.size():
		return QuestionData.new()
	return _questions[current_question_index]


func total_questions() -> int:
	return _questions.size()


func submit_answer(answer: String, run_id: String) -> JudgementRequest:
	if is_pending_judgement() or is_complete():
		return null
	var question := current_question()
	pending_judgement_question_id = question.question_id
	pending_judgement_run_id = run_id
	_pending_player_answer = answer
	return JudgementRequest.new(
		run_id, question.question_id, question.prompt, answer, question.expected_answer_hint
	)


func apply_judgement(result: JudgementResult) -> Dictionary:
	if not is_pending_judgement():
		return {"kind": "ignored", "question_id": result.question_id}
	if (
		result.run_id != pending_judgement_run_id
		or result.question_id != pending_judgement_question_id
	):
		return {"kind": "ignored", "question_id": result.question_id}
	var question := current_question()
	var standard_answer := result.canonical_answer
	if standard_answer.strip_edges().is_empty():
		standard_answer = question.expected_answer_hint
	var record := {
		"kind": "judgement",
		"question_id": result.question_id,
		"prompt": question.prompt,
		"player_answer": _pending_player_answer,
		"standard_answer": standard_answer,
		"verdict": result.verdict,
		"reason": result.reason,
		"canonical_answer": standard_answer,
	}
	recorded_results.append(record)
	pending_judgement_question_id = ""
	pending_judgement_run_id = ""
	_pending_player_answer = ""
	advance_after_recorded_result()
	return record


func cancel_pending_judgement() -> void:
	pending_judgement_question_id = ""
	pending_judgement_run_id = ""
	_pending_player_answer = ""


func timeout_current_question() -> Dictionary:
	if is_pending_judgement() or is_complete():
		return {"kind": "ignored"}
	var question := current_question()
	var record := {
		"kind": "timeout",
		"question_id": question.question_id,
		"prompt": question.prompt,
		"standard_answer": question.expected_answer_hint,
	}
	timeout_items.append(record)
	recorded_results.append(record)
	pending_judgement_question_id = ""
	pending_judgement_run_id = ""
	_pending_player_answer = ""
	advance_after_recorded_result()
	return record


func advance_after_recorded_result() -> void:
	current_question_index += 1


func is_pending_judgement() -> bool:
	return not pending_judgement_question_id.is_empty()


func is_complete() -> bool:
	return current_question_index < 0 or current_question_index >= _questions.size()
