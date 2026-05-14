extends PanelContainer

const PlaceholderPaletteScript = preload("res://scripts/ui/placeholder_palette.gd")


func _ready() -> void:
	set_status("judging")
	PlaceholderPaletteScript.apply_secondary_button($BannerBody/Actions/RetryJudgementButton)
	PlaceholderPaletteScript.apply_secondary_button($BannerBody/Actions/EndRunButton)


func set_status(status_name: String, message: String = "") -> void:
	visible = true
	PlaceholderPaletteScript.apply_body($BannerBody/StatusLabel)

	if status_name == "error":
		PlaceholderPaletteScript.apply_card(self, PlaceholderPaletteScript.COLOR_DANGER)
		$BannerBody/StatusLabel.text = "判题错误：%s" % message if not message.is_empty() else "判题错误"
		$BannerBody/Actions.show()
		return

	PlaceholderPaletteScript.apply_card(self, PlaceholderPaletteScript.COLOR_WARNING)
	$BannerBody/StatusLabel.text = "判题中…"
	$BannerBody/Actions.hide()
