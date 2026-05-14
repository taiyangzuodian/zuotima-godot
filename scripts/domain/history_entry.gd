class_name HistoryEntry
extends RefCounted

var completed_at := ""
var summary_title := ""
var result := "failed"
var accuracy := 0.0
var question_count := 0


func to_dict() -> Dictionary:
	return {
		"completed_at": completed_at,
		"summary_title": summary_title,
		"result": result,
		"accuracy": accuracy,
		"question_count": question_count,
	}


static func from_dict(data: Dictionary) -> HistoryEntry:
	var entry := HistoryEntry.new()
	entry.completed_at = str(data.get("completed_at", ""))
	entry.summary_title = str(data.get("summary_title", ""))
	entry.result = str(data.get("result", "failed"))
	entry.accuracy = float(data.get("accuracy", 0.0))
	entry.question_count = int(data.get("question_count", 0))
	return entry
