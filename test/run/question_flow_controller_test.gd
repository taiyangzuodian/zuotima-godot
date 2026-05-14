extends GdUnitTestSuite

const JudgementResult = preload("res://scripts/domain/judgement_result.gd")
const QuestionData = preload("res://scripts/domain/question_data.gd")
const QuestionFlowController = preload("res://scripts/run/controllers/question_flow_controller.gd")
const QuestionPack = preload("res://scripts/domain/question_pack.gd")


func test_loading_pack_sets_first_question() -> void:
	var flow := QuestionFlowController.new()
	flow.load_pack(_pack())

	assert_that(flow.current_question_index).is_equal(0)
	assert_that(flow.current_question().question_id).is_equal("q1")
	assert_that(flow.total_questions()).is_equal(3)


func test_submit_answer_enters_pending_judgement() -> void:
	var flow := QuestionFlowController.new()
	flow.load_pack(_pack())
	var request = flow.submit_answer("答案一", "run-1")

	assert_that(request).is_not_null()
	assert_that(request.run_id).is_equal("run-1")
	assert_that(request.question_id).is_equal("q1")
	assert_that(request.player_answer).is_equal("答案一")
	assert_that(request.get("expected_answer_hint")).is_equal("答案一")
	assert_that(flow.is_pending_judgement()).is_true()
	assert_that(flow.pending_judgement_question_id).is_equal("q1")


func test_second_submit_while_pending_returns_null() -> void:
	var flow := QuestionFlowController.new()
	flow.load_pack(_pack())
	flow.submit_answer("答案一", "run-1")

	assert_that(flow.submit_answer("答案二", "run-1")).is_null()


func test_matching_judgement_records_answer_and_advances() -> void:
	var flow := QuestionFlowController.new()
	flow.load_pack(_pack())
	flow.submit_answer("答案一", "run-1")
	var record := flow.apply_judgement(
		JudgementResult.new("run-1", "q1", JudgementResult.VERDICT_CORRECT, "ok", "标准答案一")
	)

	assert_that(record.get("kind", "")).is_equal("judgement")
	assert_that(record.get("verdict", "")).is_equal(JudgementResult.VERDICT_CORRECT)
	assert_that(record.get("prompt", "")).is_equal("第一题")
	assert_that(record.get("player_answer", "")).is_equal("答案一")
	assert_that(record.get("standard_answer", "")).is_equal("标准答案一")
	assert_that(record.get("canonical_answer", "")).is_equal("标准答案一")
	assert_that(flow.is_pending_judgement()).is_false()
	assert_that(flow.current_question().question_id).is_equal("q2")
	assert_that(flow.recorded_results).has_size(1)


func test_stale_judgement_result_is_ignored() -> void:
	var flow := QuestionFlowController.new()
	flow.load_pack(_pack())
	flow.submit_answer("答案一", "run-1")
	var record := flow.apply_judgement(
		JudgementResult.new("run-1", "q2", JudgementResult.VERDICT_CORRECT, "stale", "答案二")
	)

	assert_that(record.get("kind", "")).is_equal("ignored")
	assert_that(flow.current_question().question_id).is_equal("q1")
	assert_that(flow.is_pending_judgement()).is_true()
	assert_that(flow.recorded_results).is_empty()


func test_stale_judgement_from_previous_run_is_ignored() -> void:
	var flow := QuestionFlowController.new()
	flow.load_pack(_pack())
	flow.submit_answer("答案一", "run-1")
	var record := flow.apply_judgement(
		JudgementResult.new("run-2", "q1", JudgementResult.VERDICT_CORRECT, "stale", "答案一")
	)

	assert_that(record.get("kind", "")).is_equal("ignored")
	assert_that(flow.current_question().question_id).is_equal("q1")
	assert_that(flow.is_pending_judgement()).is_true()
	assert_that(flow.recorded_results).is_empty()


func test_timeout_while_pending_judgement_is_ignored() -> void:
	var flow := QuestionFlowController.new()
	flow.load_pack(_pack())
	flow.submit_answer("答案一", "run-1")
	var record := flow.timeout_current_question()

	assert_that(record.get("kind", "")).is_equal("ignored")
	assert_that(flow.current_question().question_id).is_equal("q1")
	assert_that(flow.is_pending_judgement()).is_true()
	assert_that(flow.recorded_results).is_empty()


func test_judgement_without_pending_request_is_ignored() -> void:
	var flow := QuestionFlowController.new()
	flow.load_pack(_pack())
	var record := flow.apply_judgement(
		JudgementResult.new("run-1", "", JudgementResult.VERDICT_CORRECT, "late", "")
	)

	assert_that(record.get("kind", "")).is_equal("ignored")
	assert_that(flow.current_question().question_id).is_equal("q1")
	assert_that(flow.recorded_results).is_empty()


func test_timeout_records_timeout_without_judgement_request() -> void:
	var flow := QuestionFlowController.new()
	flow.load_pack(_pack())
	var record := flow.timeout_current_question()

	assert_that(record.get("kind", "")).is_equal("timeout")
	assert_that(record.get("question_id", "")).is_equal("q1")
	assert_that(record.get("prompt", "")).is_equal("第一题")
	assert_that(record.get("standard_answer", "")).is_equal("答案一")
	assert_that(flow.is_pending_judgement()).is_false()
	assert_that(flow.current_question().question_id).is_equal("q2")
	assert_that(flow.timeout_items).has_size(1)


func test_complete_after_all_questions_recorded() -> void:
	var flow := QuestionFlowController.new()
	flow.load_pack(_pack())
	flow.timeout_current_question()
	flow.submit_answer("答案二", "run-1")
	flow.apply_judgement(
		JudgementResult.new("run-1", "q2", JudgementResult.VERDICT_INCORRECT, "no", "答案二")
	)
	flow.timeout_current_question()

	assert_that(flow.is_complete()).is_true()


func _pack() -> QuestionPack:
	return (
		QuestionPack
		. new(
			"pack-1",
			"zh",
			"标题",
			"摘要",
			[
				QuestionData.new("q1", "第一题", "答案一", 20.0),
				QuestionData.new("q2", "第二题", "答案二", 20.0),
				QuestionData.new("q3", "第三题", "答案三", 20.0),
			]
		)
	)
