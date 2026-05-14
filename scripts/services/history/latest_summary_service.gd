class_name LatestSummaryService
extends RefCounted

const LatestSummaryData = preload("res://scripts/domain/latest_summary_data.gd")

var _file_path := "user://latest_summary.json"


func _init(p_file_path: String = "user://latest_summary.json") -> void:
	_file_path = p_file_path


func save(summary: LatestSummaryData) -> bool:
	var file := FileAccess.open(_file_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(summary.to_dict()))
	return true


func load() -> LatestSummaryData:
	if not FileAccess.file_exists(_file_path):
		return LatestSummaryData.new()
	var file := FileAccess.open(_file_path, FileAccess.READ)
	if file == null:
		return LatestSummaryData.new()
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return LatestSummaryData.new()
	return LatestSummaryData.from_dict(parsed)
