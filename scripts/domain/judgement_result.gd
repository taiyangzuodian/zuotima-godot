class_name JudgementResult
extends RefCounted

const VERDICT_CORRECT := "correct"
const VERDICT_INCORRECT := "incorrect"
const VERDICT_ERROR := "error"

var run_id := ""
var question_id := ""
var verdict := VERDICT_ERROR
var reason := ""
var canonical_answer := ""


func _init(
	p_run_id: String = "",
	p_question_id: String = "",
	p_verdict: String = VERDICT_ERROR,
	p_reason: String = "",
	p_canonical_answer: String = ""
) -> void:
	run_id = p_run_id
	question_id = p_question_id
	verdict = p_verdict
	reason = p_reason
	canonical_answer = p_canonical_answer
