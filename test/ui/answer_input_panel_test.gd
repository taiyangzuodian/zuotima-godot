extends GdUnitTestSuite

const AnswerInputPanel = preload("res://scripts/ui/answer_input_panel.gd")


func after_test() -> void:
	_reset_submit_action_to_enter()


func test_should_submit_enter_only_when_pressed_and_not_composing() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true

	assert_that(AnswerInputPanel.should_submit_enter(event, false)).is_true()
	assert_that(AnswerInputPanel.should_submit_enter(event, true)).is_false()

	event.pressed = false
	assert_that(AnswerInputPanel.should_submit_enter(event, false)).is_false()

	event.pressed = true
	event.keycode = KEY_SHIFT
	assert_that(AnswerInputPanel.should_submit_enter(event, false)).is_false()


func test_should_submit_enter_accepts_keypad_enter() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_KP_ENTER
	event.pressed = true

	assert_that(AnswerInputPanel.should_submit_enter(event, false)).is_true()


func test_should_submit_enter_respects_submit_answer_action_remap() -> void:
	var enter_event := InputEventKey.new()
	enter_event.keycode = KEY_ENTER
	enter_event.pressed = true
	var space_event := InputEventKey.new()
	space_event.keycode = KEY_SPACE
	space_event.pressed = true
	InputMap.action_erase_events("submit_answer")
	InputMap.action_add_event("submit_answer", space_event)

	assert_that(AnswerInputPanel.should_submit_enter(enter_event, false)).is_false()
	assert_that(AnswerInputPanel.should_submit_enter(space_event, false)).is_true()


func _reset_submit_action_to_enter() -> void:
	var enter_event := InputEventKey.new()
	enter_event.keycode = KEY_ENTER
	var keypad_enter_event := InputEventKey.new()
	keypad_enter_event.keycode = KEY_KP_ENTER
	InputMap.action_erase_events("submit_answer")
	InputMap.action_add_event("submit_answer", enter_event)
	InputMap.action_add_event("submit_answer", keypad_enter_event)
