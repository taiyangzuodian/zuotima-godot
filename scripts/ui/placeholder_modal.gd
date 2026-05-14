class_name PlaceholderModal
extends Control

const PlaceholderPaletteScript = preload("res://scripts/ui/placeholder_palette.gd")

@export var accent_state := "warning"


func _ready() -> void:
	hide()
	PlaceholderPaletteScript.apply_panel(
		$CenterContainer/ModalPanel, PlaceholderPaletteScript.color_for_state(accent_state)
	)
	PlaceholderPaletteScript.apply_secondary_button(
		$CenterContainer/ModalPanel/Content/Header/CloseButton
	)
	PlaceholderPaletteScript.apply_title(
		$CenterContainer/ModalPanel/Content/Header/TitleLabel,
		PlaceholderPaletteScript.color_for_state(accent_state)
	)
	$OverlayShade.color = PlaceholderPaletteScript.COLOR_OVERLAY_SHADE
	$CenterContainer/ModalPanel/Content/Header/CloseButton.pressed.connect(hide)

	for node in find_children("*", "Button", true, false):
		var button := node as Button
		if button == null or button.name == "CloseButton":
			continue
		PlaceholderPaletteScript.apply_primary_button(button)

	for node in find_children("*", "LineEdit", true, false):
		var line_edit := node as LineEdit
		if line_edit == null:
			continue
		PlaceholderPaletteScript.apply_input(line_edit)

	for node in find_children("*", "Label", true, false):
		var label := node as Label
		if label == null or label.name == "TitleLabel":
			continue
		PlaceholderPaletteScript.apply_body(label)

	for node in find_children("*", "PanelContainer", true, false):
		var panel := node as PanelContainer
		if panel == null or panel.name == "ModalPanel":
			continue
		PlaceholderPaletteScript.apply_card(panel)
