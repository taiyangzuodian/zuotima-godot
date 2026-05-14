extends CanvasLayer

signal answer_submitted(answer_text: String)
signal retry_judgement_requested(answer_text: String)
signal end_run_requested

const RunContext = preload("res://scripts/domain/run_context.gd")

var last_submitted_answer := ""


func _ready() -> void:
	$Root/HudMargin/Layout/TopRow/PhaseBanner/PhaseLabel.text = "预热中"
	$Root/HudMargin/Layout/TopRow/ShieldIndicator/ShieldBody/ShieldValue.text = "有盾"
	PlaceholderPalette.apply_muted_body($Root/HudMargin/Layout/TopRow/PressureHint)
	set_pressure_hint(RunContext.PRESSURE_NORMAL)
	$Root/HudMargin/Layout/BottomStack/JudgementBanner.hide()
	$Root/HudMargin/Layout/BottomStack/QuestionPanel/QuestionBody/PromptLabel.text = "文档提到的核心玩法是什么？"
	$Root/HudMargin/Layout/BottomStack/AnswerInputPanel/AnswerBody/StatusLabel.text = "输入后按 Enter 提交"
	$Root/HudMargin/Layout/BottomStack/AnswerInputPanel.answer_submitted.connect(
		_on_answer_submitted
	)
	(
		$Root/HudMargin/Layout/BottomStack/JudgementBanner/BannerBody/Actions/RetryJudgementButton
		. pressed
		. connect(_on_retry_judgement_pressed)
	)
	(
		$Root/HudMargin/Layout/BottomStack/JudgementBanner/BannerBody/Actions/EndRunButton
		. pressed
		. connect(end_run_requested.emit)
	)


func show_judging() -> void:
	$Root/HudMargin/Layout/BottomStack/JudgementBanner.set_status("judging")


func show_judgement_error(message: String) -> void:
	var bottom_stack := $Root/HudMargin/Layout/BottomStack
	bottom_stack.get_node("JudgementBanner").set_status("error", message)
	bottom_stack.get_node("AnswerInputPanel/AnswerBody/AnswerField").text = last_submitted_answer


func hide_judgement_banner() -> void:
	$Root/HudMargin/Layout/BottomStack/JudgementBanner.hide()


func set_pressure_hint(pressure_state: String) -> void:
	var hint := $Root/HudMargin/Layout/TopRow/PressureHint
	if pressure_state == RunContext.PRESSURE_REDUCED:
		hint.text = "压力降低：危险物放缓"
		return
	if pressure_state == RunContext.PRESSURE_INCREASED:
		hint.text = "压力升高：危险物加快"
		return
	hint.text = "压力正常"


func focus_answer() -> void:
	$Root/HudMargin/Layout/BottomStack/AnswerInputPanel.focus_answer()


func clear_answer() -> void:
	last_submitted_answer = ""
	$Root/HudMargin/Layout/BottomStack/AnswerInputPanel/AnswerBody/AnswerField.clear()


func _on_answer_submitted(answer_text: String) -> void:
	last_submitted_answer = answer_text
	answer_submitted.emit(answer_text)


func _on_retry_judgement_pressed() -> void:
	if last_submitted_answer.strip_edges().is_empty():
		return
	retry_judgement_requested.emit(last_submitted_answer)
