class_name QuestionPack
extends RefCounted

const QuestionData = preload("res://scripts/domain/question_data.gd")

var pack_id := ""
var source_language := ""
var summary_title := ""
var summary_text := ""
var questions: Array[QuestionData] = []


func _init(
	p_pack_id: String = "",
	p_source_language: String = "",
	p_summary_title: String = "",
	p_summary_text: String = "",
	p_questions: Array[QuestionData] = []
) -> void:
	pack_id = p_pack_id
	source_language = p_source_language
	summary_title = p_summary_title
	summary_text = p_summary_text
	questions = p_questions
