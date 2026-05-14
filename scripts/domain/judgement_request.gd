class_name JudgementRequest
extends RefCounted

var run_id := ""
var question_id := ""
var question_prompt := ""
var player_answer := ""
var expected_answer_hint := ""


func _init(
	p_run_id: String = "",
	p_question_id: String = "",
	p_question_prompt: String = "",
	p_player_answer: String = "",
	p_expected_answer_hint: String = ""
) -> void:
	run_id = p_run_id
	question_id = p_question_id
	question_prompt = p_question_prompt
	player_answer = p_player_answer
	expected_answer_hint = p_expected_answer_hint
