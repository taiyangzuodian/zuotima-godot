class_name DocumentFileReader
extends RefCounted

const DocumentSource = preload("res://scripts/domain/document_source.gd")

var _sample_path := "res://data/sample_docs/chinese_sample.md"


func _init(p_sample_path := "res://data/sample_docs/chinese_sample.md") -> void:
	_sample_path = p_sample_path


func read_text(source: DocumentSource) -> String:
	var path := source.file_path
	if source.source_type == DocumentSource.TYPE_SAMPLE and path.strip_edges().is_empty():
		path = _sample_path
	if path.strip_edges().is_empty() or not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()
