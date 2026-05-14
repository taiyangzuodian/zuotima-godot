class_name LatestSummaryOverlay
extends PlaceholderModal

const LatestSummaryData = preload("res://scripts/domain/latest_summary_data.gd")


func load_summary(service: Object) -> void:
	var summary: LatestSummaryData = service.load()
	if (
		summary.summary_title.strip_edges().is_empty()
		and summary.summary_text.strip_edges().is_empty()
	):
		_show_empty_state()
		return
	$CenterContainer/ModalPanel/Content/SummaryCard/SummaryContent/SummaryTitle.text = (
		summary.summary_title
	)
	$CenterContainer/ModalPanel/Content/SummaryCard/SummaryContent/SummaryMeta.text = _summary_meta(
		summary
	)
	$CenterContainer/ModalPanel/Content/SummaryCard/SummaryContent/SummaryBody.text = (
		summary.summary_text
	)


func _show_empty_state() -> void:
	var summary_content := $CenterContainer/ModalPanel/Content/SummaryCard/SummaryContent
	summary_content.get_node("SummaryTitle").text = "暂无摘要"
	summary_content.get_node("SummaryMeta").text = ""
	summary_content.get_node("SummaryBody").text = "完成一次挑战后，这里会显示最近一次成功生成的摘要。"


func _summary_meta(summary: LatestSummaryData) -> String:
	var parts: Array[String] = []
	if not summary.source_language.strip_edges().is_empty():
		parts.append(summary.source_language)
	if not summary.generated_at.strip_edges().is_empty():
		parts.append(summary.generated_at)
	return " · ".join(parts)
