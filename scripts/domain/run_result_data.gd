class_name RunResultData
extends RefCounted

const DocumentSource = preload("res://scripts/domain/document_source.gd")
const JudgementResult = preload("res://scripts/domain/judgement_result.gd")
const RunContext = preload("res://scripts/domain/run_context.gd")

var document_source: DocumentSource
var summary_title := ""
var summary_text := ""
var source_language := ""
var result := "failed"
var accuracy := 0.0
var question_count := 0
var submitted_count := 0
var correct_count := 0
var recorded_results: Array[Dictionary] = []
var wrong_items: Array[Dictionary] = []
var timeout_items: Array[Dictionary] = []


func _init() -> void:
	document_source = DocumentSource.new()


static func from_context(context: RunContext) -> RunResultData:
	var data := RunResultData.new()
	data.document_source = context.document_source
	data.summary_title = context.summary_title
	data.summary_text = context.summary_text
	data.source_language = context.source_language
	data.result = "cleared" if context.phase == RunContext.PHASE_CLEARED else "failed"
	data.accuracy = context.accuracy()
	data.question_count = context.questions.size()
	data.submitted_count = context.answered_count
	data.correct_count = context.correct_count
	return data


func apply_recorded_results(records: Array[Dictionary]) -> void:
	recorded_results = records.duplicate(true)
	wrong_items.clear()
	timeout_items.clear()
	submitted_count = 0
	correct_count = 0
	for record in recorded_results:
		if record.get("kind", "") == "timeout":
			timeout_items.append(_timeout_item_from_record(record))
			continue
		if record.get("kind", "") != "judgement":
			continue
		var verdict := str(record.get("verdict", ""))
		if verdict == JudgementResult.VERDICT_ERROR:
			continue
		submitted_count += 1
		if verdict == JudgementResult.VERDICT_CORRECT:
			correct_count += 1
		elif verdict == JudgementResult.VERDICT_INCORRECT:
			wrong_items.append(_wrong_item_from_record(record))
	accuracy = 0.0 if submitted_count == 0 else float(correct_count) / float(submitted_count)


func _wrong_item_from_record(record: Dictionary) -> Dictionary:
	return {
		"question_id": str(record.get("question_id", "")),
		"prompt": str(record.get("prompt", "")),
		"player_answer": str(record.get("player_answer", "")),
		"standard_answer": str(record.get("standard_answer", record.get("canonical_answer", ""))),
		"reason": str(record.get("reason", "")),
	}


func _timeout_item_from_record(record: Dictionary) -> Dictionary:
	return {
		"question_id": str(record.get("question_id", "")),
		"prompt": str(record.get("prompt", "")),
		"standard_answer": str(record.get("standard_answer", "")),
	}
