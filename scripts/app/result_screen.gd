extends Control

signal retry_requested
signal back_to_start_requested

const PlaceholderPaletteScript = preload("res://scripts/ui/placeholder_palette.gd")

var result_data


func _ready() -> void:
	PlaceholderPaletteScript.apply_page_background($PageBackground)
	PlaceholderPaletteScript.apply_panel(
		$RootMargin/Layout/ResultCard, PlaceholderPaletteScript.COLOR_SUCCESS
	)
	PlaceholderPaletteScript.apply_panel(
		$RootMargin/Layout/StatsCard, PlaceholderPaletteScript.COLOR_PANEL_BORDER
	)
	PlaceholderPaletteScript.apply_panel(
		$RootMargin/Layout/DetailCard, PlaceholderPaletteScript.COLOR_PANEL_BORDER
	)
	PlaceholderPaletteScript.apply_title(
		$RootMargin/Layout/ResultCard/ResultContent/ResultTitleLabel,
		PlaceholderPaletteScript.COLOR_SUCCESS
	)
	PlaceholderPaletteScript.apply_muted_body(
		$RootMargin/Layout/ResultCard/ResultContent/ResultSubtitleLabel
	)
	PlaceholderPaletteScript.apply_body($RootMargin/Layout/StatsCard/StatsContent/AccuracyLabel)
	PlaceholderPaletteScript.apply_body(
		$RootMargin/Layout/StatsCard/StatsContent/QuestionCountLabel
	)
	PlaceholderPaletteScript.apply_body(
		$RootMargin/Layout/DetailCard/DetailScroll/DetailContent/DetailTitleLabel
	)
	PlaceholderPaletteScript.apply_muted_body(
		$RootMargin/Layout/DetailCard/DetailScroll/DetailContent/WrongItemsLabel
	)
	PlaceholderPaletteScript.apply_muted_body(
		$RootMargin/Layout/DetailCard/DetailScroll/DetailContent/TimeoutItemsLabel
	)
	PlaceholderPaletteScript.apply_primary_button($RootMargin/Layout/ActionButtons/RetryButton)
	PlaceholderPaletteScript.apply_secondary_button($RootMargin/Layout/ActionButtons/BackButton)
	$RootMargin/Layout/ActionButtons/RetryButton.pressed.connect(retry_requested.emit)
	$RootMargin/Layout/ActionButtons/BackButton.pressed.connect(back_to_start_requested.emit)
	if result_data == null:
		set_placeholder_result("cleared")
	else:
		show_result(result_data)


func show_result(data) -> void:
	result_data = data
	set_placeholder_result(data.result)
	$RootMargin/Layout/StatsCard/StatsContent/AccuracyLabel.text = (
		"正确率：%d%%" % int(data.accuracy * 100.0)
	)
	$RootMargin/Layout/StatsCard/StatsContent/QuestionCountLabel.text = (
		"题目数：%d" % data.question_count
	)
	var detail_content := $RootMargin/Layout/DetailCard/DetailScroll/DetailContent
	detail_content.get_node("WrongItemsLabel").text = _format_wrong_items(data.wrong_items)
	detail_content.get_node("TimeoutItemsLabel").text = _format_timeout_items(data.timeout_items)


func _format_wrong_items(items: Array[Dictionary]) -> String:
	if items.is_empty():
		return "错题：无"
	var lines := ["错题："]
	for item in items:
		(
			lines
			. append(
				(
					"- %s\n  你的答案：%s\n  标准答案：%s\n  说明：%s"
					% [
						str(item.get("prompt", "")),
						str(item.get("player_answer", "")),
						str(item.get("standard_answer", "")),
						str(item.get("reason", "")),
					]
				)
			)
		)
	return "\n".join(lines)


func _format_timeout_items(items: Array[Dictionary]) -> String:
	if items.is_empty():
		return "超时：无"
	var lines := ["超时："]
	for item in items:
		lines.append(
			"- %s\n  标准答案：%s" % [str(item.get("prompt", "")), str(item.get("standard_answer", ""))]
		)
	return "\n".join(lines)


func set_placeholder_result(result_name: String) -> void:
	if result_name == "failed":
		$RootMargin/Layout/ResultCard/ResultContent/ResultTitleLabel.text = "挑战失败"
		$RootMargin/Layout/ResultCard/ResultContent/ResultSubtitleLabel.text = "本轮占位结果为失败状态。"
		PlaceholderPaletteScript.apply_title(
			$RootMargin/Layout/ResultCard/ResultContent/ResultTitleLabel,
			PlaceholderPaletteScript.COLOR_DANGER
		)
		return

	$RootMargin/Layout/ResultCard/ResultContent/ResultTitleLabel.text = "挑战通关"
	$RootMargin/Layout/ResultCard/ResultContent/ResultSubtitleLabel.text = "本轮占位结果为通关状态。"
	PlaceholderPaletteScript.apply_title(
		$RootMargin/Layout/ResultCard/ResultContent/ResultTitleLabel,
		PlaceholderPaletteScript.COLOR_SUCCESS
	)
