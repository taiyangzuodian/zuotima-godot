extends PanelContainer

const PlaceholderPaletteScript = preload("res://scripts/ui/placeholder_palette.gd")


func _ready() -> void:
	PlaceholderPaletteScript.apply_card(self, PlaceholderPaletteScript.COLOR_WARNING)
	PlaceholderPaletteScript.apply_title(
		$ShieldBody/ShieldTitle, PlaceholderPaletteScript.COLOR_WARNING
	)
	PlaceholderPaletteScript.apply_body($ShieldBody/ShieldValue)
	$ShieldBody/ShieldTitle.text = "护盾"
	$ShieldBody/ShieldValue.text = "有盾"
