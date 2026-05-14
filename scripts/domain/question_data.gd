class_name QuestionData
extends RefCounted

var question_id := ""
var prompt := ""
var expected_answer_hint := ""
var time_limit_sec := 20.0


func _init(
	p_question_id: String = "",
	p_prompt: String = "",
	p_expected_answer_hint: String = "",
	p_time_limit_sec: float = 20.0
) -> void:
	question_id = p_question_id
	prompt = p_prompt
	expected_answer_hint = p_expected_answer_hint
	time_limit_sec = p_time_limit_sec
