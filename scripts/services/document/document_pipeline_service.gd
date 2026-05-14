class_name DocumentPipelineService
extends RefCounted

const DocumentSource = preload("res://scripts/domain/document_source.gd")
const QuestionData = preload("res://scripts/domain/question_data.gd")
const QuestionPack = preload("res://scripts/domain/question_pack.gd")
const SettingsData = preload("res://scripts/domain/settings_data.gd")

const CHUNK_MAX_CHARS := 1200

var _provider_service: Object


func _init(p_provider_service: Object) -> void:
	_provider_service = p_provider_service


func prepare(run_id: String, settings: SettingsData, source: DocumentSource) -> Dictionary:
	var raw_text := read_source_text(source)
	if raw_text.is_empty():
		return {"ok": false, "run_id": run_id, "error": "Document is empty"}

	var normalized := normalize_text(raw_text)
	var language := detect_language(normalized, source.language_hint)
	var chunks := split_into_chunks(normalized)
	var chunk_summaries: Array[String] = []

	for chunk in chunks:
		var summary_messages: Array[Dictionary] = [
			{"role": "user", "content": "Summarize this %s chunk:\n%s" % [language, chunk]}
		]
		var summary_response: Dictionary = await _provider_service.request_json(
			settings, summary_messages, "document_chunk_summary"
		)
		if not summary_response.get("ok", false):
			return {
				"ok": false,
				"run_id": run_id,
				"error": summary_response.get("error", "summary failed"),
			}
		chunk_summaries.append(_summary_text_from(summary_response.get("data", {})))

	var merged_title := source.display_name
	var merged_summary := chunk_summaries[0]
	if chunk_summaries.size() > 1:
		var merge_messages: Array[Dictionary] = [
			{
				"role": "user",
				"content":
				"Merge these summaries in %s:\n%s" % [language, "\n".join(chunk_summaries)],
			}
		]
		var merge_response: Dictionary = await _provider_service.request_json(
			settings, merge_messages, "document_summary_merge"
		)
		if not merge_response.get("ok", false):
			return {
				"ok": false,
				"run_id": run_id,
				"error": merge_response.get("error", "merge failed"),
			}
		merged_title = str(merge_response.get("data", {}).get("summary_title", merged_title))
		merged_summary = str(merge_response.get("data", {}).get("summary_text", merged_summary))

	var question_prompt := (
		"Based on this %s summary, generate 3-5 keyword-fill questions as JSON.\n"
		+ "Return summary_title, summary_text, and questions. "
		+ "Each question must include question_id, prompt, expected_answer_hint, and time_limit_sec.\n"
		+ "Title: %s\nSummary: %s"
	)
	var pack_messages: Array[Dictionary] = [
		{
			"role": "user",
			"content": question_prompt % [language, merged_title, merged_summary],
		}
	]
	var pack_response: Dictionary = await _provider_service.request_json(
		settings, pack_messages, "question_pack"
	)
	if not pack_response.get("ok", false):
		return {
			"ok": false,
			"run_id": run_id,
			"error": pack_response.get("error", "question generation failed"),
		}

	var pack_data: Dictionary = pack_response.get("data", {})
	var pack := _build_question_pack(run_id, language, merged_title, merged_summary, pack_data)
	return {"ok": true, "run_id": run_id, "pack": pack}


func read_source_text(source: DocumentSource) -> String:
	if source.file_path.is_empty() or not FileAccess.file_exists(source.file_path):
		return ""
	var file := FileAccess.open(source.file_path, FileAccess.READ)
	return "" if file == null else file.get_as_text()


func normalize_text(text: String) -> String:
	var lines := text.strip_edges().split("\n")
	var normalized: Array[String] = []
	var last_blank := false
	for line in lines:
		var stripped := line.strip_edges()
		if stripped.is_empty():
			if not last_blank:
				normalized.append("")
			last_blank = true
			continue
		normalized.append(stripped)
		last_blank = false
	return "\n".join(normalized).strip_edges()


func detect_language(text: String, hint: String) -> String:
	if not hint.is_empty():
		return hint
	var cjk_regex := RegEx.new()
	cjk_regex.compile("[\\u4e00-\\u9fff]")
	return "zh" if cjk_regex.search(text) != null else "en"


func split_into_chunks(text: String) -> Array[String]:
	if text.length() <= CHUNK_MAX_CHARS:
		return [text]

	var chunks: Array[String] = []
	var current := ""
	for paragraph in text.split("\n\n"):
		var candidate := paragraph.strip_edges()
		if candidate.is_empty():
			continue
		if current.length() > 0 and current.length() + candidate.length() + 2 > CHUNK_MAX_CHARS:
			chunks.append(current)
			current = candidate
		else:
			current = candidate if current.is_empty() else "%s\n\n%s" % [current, candidate]
	if not current.is_empty():
		chunks.append(current)
	return chunks


func _summary_text_from(data: Dictionary) -> String:
	var summary_text := str(data.get("summary_text", ""))
	if not summary_text.strip_edges().is_empty():
		return summary_text
	return str(data.get("summary", ""))


func _build_question_pack(
	run_id: String,
	language: String,
	fallback_title: String,
	fallback_summary: String,
	data: Dictionary
) -> QuestionPack:
	var questions: Array[QuestionData] = []
	for item in data.get("questions", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		questions.append(
			QuestionData.new(
				str(item.get("question_id", "")),
				str(item.get("prompt", "")),
				str(item.get("expected_answer_hint", "")),
				float(item.get("time_limit_sec", 20.0))
			)
		)

	return QuestionPack.new(
		"%s-pack" % run_id,
		language,
		str(data.get("summary_title", fallback_title)),
		str(data.get("summary_text", fallback_summary)),
		questions
	)
