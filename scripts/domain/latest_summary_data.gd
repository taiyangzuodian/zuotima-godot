class_name LatestSummaryData
extends RefCounted

var generated_at := ""
var summary_title := ""
var summary_text := ""
var source_language := ""


func to_dict() -> Dictionary:
	return {
		"generated_at": generated_at,
		"summary_title": summary_title,
		"summary_text": summary_text,
		"source_language": source_language,
	}


static func from_dict(data: Dictionary) -> LatestSummaryData:
	var summary := LatestSummaryData.new()
	summary.generated_at = str(data.get("generated_at", ""))
	summary.summary_title = str(data.get("summary_title", ""))
	summary.summary_text = str(data.get("summary_text", ""))
	summary.source_language = str(data.get("source_language", ""))
	return summary
