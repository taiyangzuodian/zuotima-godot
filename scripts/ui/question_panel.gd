extends PanelContainer

const PlaceholderPaletteScript = preload("res://scripts/ui/placeholder_palette.gd")


func _ready() -> void:
	PlaceholderPaletteScript.apply_card(self, PlaceholderPaletteScript.COLOR_SAFE)
	PlaceholderPaletteScript.apply_muted_body($QuestionBody/QuestionNumberLabel)
	PlaceholderPaletteScript.apply_body($QuestionBody/PromptLabel)
	PlaceholderPaletteScript.apply_muted_body($QuestionBody/TimerLabel)
	$QuestionBody/QuestionNumberLabel.text = "第 1 / 3 题"
	$QuestionBody/PromptLabel.text = "文档提到的核心玩法是什么？"
	$QuestionBody/TimerLabel.text = "剩余 20 秒"
