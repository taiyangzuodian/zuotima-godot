class_name StartRunGate
extends RefCounted

const DocumentSource = preload("res://scripts/domain/document_source.gd")
const SettingsData = preload("res://scripts/domain/settings_data.gd")


class StartRunGateResult:
	extends RefCounted

	var ok := false
	var message_key := ""

	func _init(p_ok := false, p_message_key := "") -> void:
		ok = p_ok
		message_key = p_message_key


var _sample_path := "res://data/sample_docs/chinese_sample.md"


func _init(p_sample_path := "res://data/sample_docs/chinese_sample.md") -> void:
	_sample_path = p_sample_path


func validate(source: DocumentSource, settings: SettingsData) -> StartRunGateResult:
	if _has_missing_ai_config(settings):
		return StartRunGateResult.new(false, "missing_ai_config")

	if source.source_type == DocumentSource.TYPE_SAMPLE:
		return _validate_sample_source(source)

	if source.source_type == DocumentSource.TYPE_LOCAL_FILE:
		return _validate_local_file_source(source)

	return StartRunGateResult.new(false, "unsupported_document_source")


func _has_missing_ai_config(settings: SettingsData) -> bool:
	return (
		_is_blank(settings.ai_base_url)
		or _is_blank(settings.ai_model)
		or _is_blank(settings.ai_api_key)
	)


func _validate_sample_source(source: DocumentSource) -> StartRunGateResult:
	var sample_path := source.file_path if not _is_blank(source.file_path) else _sample_path
	if not ResourceLoader.exists(sample_path) and not FileAccess.file_exists(sample_path):
		return StartRunGateResult.new(false, "missing_sample_resource")
	return StartRunGateResult.new(true, "")


func _validate_local_file_source(source: DocumentSource) -> StartRunGateResult:
	if _is_blank(source.file_path) or not FileAccess.file_exists(source.file_path):
		return StartRunGateResult.new(false, "missing_local_file")
	var extension := source.file_path.get_extension().to_lower()
	if extension != "txt" and extension != "md":
		return StartRunGateResult.new(false, "unsupported_local_file_type")
	var file := FileAccess.open(source.file_path, FileAccess.READ)
	if file == null or file.get_as_text().strip_edges().is_empty():
		return StartRunGateResult.new(false, "empty_local_file")
	return StartRunGateResult.new(true, "")


func _is_blank(value: String) -> bool:
	return value.strip_edges().is_empty()
