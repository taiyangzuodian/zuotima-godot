extends PanelContainer

const PlaceholderPaletteScript = preload("res://scripts/ui/placeholder_palette.gd")


func _ready() -> void:
	PlaceholderPaletteScript.apply_card(self, PlaceholderPaletteScript.COLOR_SAFE)
	PlaceholderPaletteScript.apply_title($PhaseLabel, PlaceholderPaletteScript.COLOR_SAFE)
	$PhaseLabel.text = "预热中"
