class_name HistoryService
extends RefCounted

const HistoryEntry = preload("res://scripts/domain/history_entry.gd")

var _file_path := "user://history.json"


func _init(p_file_path: String = "user://history.json") -> void:
	_file_path = p_file_path


func load_entries() -> Array[HistoryEntry]:
	if not FileAccess.file_exists(_file_path):
		return []
	var file := FileAccess.open(_file_path, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		return []

	var entries: Array[HistoryEntry] = []
	for item in parsed:
		if typeof(item) == TYPE_DICTIONARY:
			entries.append(HistoryEntry.from_dict(item))
	return entries


func append_entry(entry: HistoryEntry) -> bool:
	var rows: Array[Dictionary] = []
	for existing in load_entries():
		rows.append(existing.to_dict())
	rows.push_front(entry.to_dict())

	var file := FileAccess.open(_file_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(rows))
	return true
