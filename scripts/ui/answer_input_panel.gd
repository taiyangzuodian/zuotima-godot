extends PanelContainer

signal answer_submitted(answer_text: String)

const PlaceholderPaletteScript = preload("res://scripts/ui/placeholder_palette.gd")

var ime_composing := false


static func should_submit_enter(event: InputEvent, ime_composing: bool) -> bool:
	if ime_composing:
		return false
	return event.is_action_pressed("submit_answer")


func _ready() -> void:
	PlaceholderPaletteScript.apply_card(self, PlaceholderPaletteScript.COLOR_PANEL_BORDER)
	PlaceholderPaletteScript.apply_input($AnswerBody/AnswerField)
	PlaceholderPaletteScript.apply_primary_button($AnswerBody/SubmitButton)
	PlaceholderPaletteScript.apply_muted_body($AnswerBody/StatusLabel)
	$AnswerBody/AnswerField.placeholder_text = "输入关键词答案"
	$AnswerBody/SubmitButton.text = "提交答案"
	$AnswerBody/StatusLabel.text = "输入后按 Enter 提交"
	$AnswerBody/SubmitButton.pressed.connect(_submit_current_answer)
	$AnswerBody/AnswerField.gui_input.connect(_on_answer_field_gui_input)


func focus_answer() -> void:
	$AnswerBody/AnswerField.grab_focus()


func _on_answer_field_gui_input(event: InputEvent) -> void:
	if should_submit_enter(event, ime_composing):
		_submit_current_answer()
		$AnswerBody/AnswerField.accept_event()


func _submit_current_answer() -> void:
	_submit_answer($AnswerBody/AnswerField.text)


func _submit_answer(answer_text: String) -> void:
	if answer_text.strip_edges().is_empty():
		return
	$AnswerBody/AnswerField.clear()
	answer_submitted.emit(answer_text)
