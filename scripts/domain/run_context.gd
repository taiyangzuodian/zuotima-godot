class_name RunContext
extends RefCounted

const DocumentSource = preload("res://scripts/domain/document_source.gd")
const QuestionData = preload("res://scripts/domain/question_data.gd")
const QuestionPack = preload("res://scripts/domain/question_pack.gd")

const JudgementResult = preload("res://scripts/domain/judgement_result.gd")

const PHASE_WARMUP := "WARMUP"
const PHASE_ACTIVE := "ACTIVE"
const PHASE_JUDGING := "JUDGING"
const PHASE_PREPARATION_ERROR := "PREPARATION_ERROR"
const PHASE_FAILED := "FAILED"
const PHASE_CLEARED := "CLEARED"

const SHIELD_SHIELDED := "SHIELDED"
const SHIELD_BROKEN := "BROKEN"
const SHIELD_DEAD := "DEAD"

const PRESSURE_NORMAL := "NORMAL"
const PRESSURE_REDUCED := "REDUCED"
const PRESSURE_INCREASED := "INCREASED"
const PRESSURE_RELIEF := PRESSURE_REDUCED
const PRESSURE_PENALTY := PRESSURE_INCREASED

var run_id := ""
var document_source: DocumentSource
var source_language := ""
var summary_title := ""
var summary_text := ""
var questions: Array[QuestionData] = []
var current_question_index := -1
var pending_judgement_question_id := ""
var phase := PHASE_WARMUP
var shield_state := SHIELD_SHIELDED
var pressure_state := PRESSURE_NORMAL
var last_error_message := ""
var answered_count := 0
var correct_count := 0


func _init(p_run_id: String, p_document_source: DocumentSource) -> void:
	run_id = p_run_id
	document_source = p_document_source


func apply_question_pack(pack: QuestionPack) -> void:
	source_language = pack.source_language
	summary_title = pack.summary_title
	summary_text = pack.summary_text
	questions = pack.questions
	current_question_index = 0
	pending_judgement_question_id = ""
	phase = PHASE_ACTIVE
	last_error_message = ""


func current_question() -> QuestionData:
	if current_question_index < 0 or current_question_index >= questions.size():
		return QuestionData.new()
	return questions[current_question_index]


func has_current_question() -> bool:
	return current_question_index >= 0 and current_question_index < questions.size()


func begin_judging() -> bool:
	if not has_current_question() or pending_judgement_question_id != "":
		return false
	pending_judgement_question_id = current_question().question_id
	phase = PHASE_JUDGING
	last_error_message = ""
	return true


func apply_judgement_verdict(verdict: String) -> void:
	answered_count += 1
	if verdict == JudgementResult.VERDICT_CORRECT:
		correct_count += 1
		shield_state = SHIELD_SHIELDED
		pressure_state = PRESSURE_RELIEF
	else:
		pressure_state = PRESSURE_PENALTY

	pending_judgement_question_id = ""
	current_question_index += 1
	phase = PHASE_CLEARED if current_question_index >= questions.size() else PHASE_ACTIVE


func mark_preparation_error(message: String) -> void:
	pending_judgement_question_id = ""
	phase = PHASE_PREPARATION_ERROR
	last_error_message = message


func mark_judgement_error(message: String) -> void:
	pending_judgement_question_id = ""
	phase = PHASE_ACTIVE
	last_error_message = message


func mark_failed() -> void:
	pending_judgement_question_id = ""
	phase = PHASE_FAILED


func accuracy() -> float:
	if answered_count == 0:
		return 0.0
	return float(correct_count) / float(answered_count)
