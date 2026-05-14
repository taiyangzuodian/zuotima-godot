extends GdUnitTestSuite

const DocumentSource = preload("res://scripts/domain/document_source.gd")
const JudgementResult = preload("res://scripts/domain/judgement_result.gd")
const QuestionData = preload("res://scripts/domain/question_data.gd")
const QuestionPack = preload("res://scripts/domain/question_pack.gd")
const RunContext = preload("res://scripts/domain/run_context.gd")
const RunResultData = preload("res://scripts/domain/run_result_data.gd")


func test_from_context_copies_counts_and_base_summary_fields() -> void:
	var context := _context_with_pack()
	context.apply_judgement_verdict(JudgementResult.VERDICT_CORRECT)
	context.apply_judgement_verdict(JudgementResult.VERDICT_INCORRECT)
	context.phase = RunContext.PHASE_FAILED

	var data := RunResultData.from_context(context)

	assert_that(data.result).is_equal("failed")
	assert_that(data.summary_title).is_equal("标题")
	assert_that(data.summary_text).is_equal("摘要")
	assert_that(data.source_language).is_equal("zh")
	assert_that(data.question_count).is_equal(3)
	assert_that(data.submitted_count).is_equal(2)
	assert_that(data.correct_count).is_equal(1)
	assert_float(data.accuracy).is_equal(0.5)


func test_apply_recorded_results_builds_wrong_and_timeout_items() -> void:
	var data := RunResultData.from_context(_context_with_pack())
	(
		data
		. apply_recorded_results(
			[
				{
					"kind": "judgement",
					"question_id": "q1",
					"prompt": "第一题",
					"player_answer": "玩家答案一",
					"standard_answer": "标准答案一",
					"canonical_answer": "标准答案一",
					"verdict": JudgementResult.VERDICT_INCORRECT,
					"reason": "不够准确",
				},
				{
					"kind": "timeout",
					"question_id": "q2",
					"prompt": "第二题",
					"standard_answer": "答案二",
				},
				{
					"kind": "judgement",
					"question_id": "q3",
					"prompt": "第三题",
					"player_answer": "答案三",
					"standard_answer": "答案三",
					"canonical_answer": "答案三",
					"verdict": JudgementResult.VERDICT_CORRECT,
					"reason": "ok",
				},
			]
		)
	)

	assert_that(data.recorded_results).has_size(3)
	assert_that(data.submitted_count).is_equal(2)
	assert_that(data.correct_count).is_equal(1)
	assert_that(data.wrong_items).has_size(1)
	assert_that(data.wrong_items[0].get("prompt", "")).is_equal("第一题")
	assert_that(data.wrong_items[0].get("player_answer", "")).is_equal("玩家答案一")
	assert_that(data.wrong_items[0].get("standard_answer", "")).is_equal("标准答案一")
	assert_that(data.wrong_items[0].get("reason", "")).is_equal("不够准确")
	assert_that(data.timeout_items).has_size(1)
	assert_that(data.timeout_items[0].get("prompt", "")).is_equal("第二题")
	assert_that(data.timeout_items[0].get("standard_answer", "")).is_equal("答案二")


func test_apply_recorded_results_excludes_infrastructure_errors_from_review_items() -> void:
	var data := RunResultData.from_context(_context_with_pack())
	(
		data
		. apply_recorded_results(
			[
				{
					"kind": "judgement",
					"question_id": "q1",
					"prompt": "第一题",
					"player_answer": "答案一",
					"standard_answer": "答案一",
					"verdict": JudgementResult.VERDICT_ERROR,
					"reason": "provider failed",
				}
			]
		)
	)

	assert_that(data.submitted_count).is_equal(0)
	assert_that(data.correct_count).is_equal(0)
	assert_that(data.wrong_items).is_empty()
	assert_that(data.timeout_items).is_empty()


func _context_with_pack() -> RunContext:
	var context := RunContext.new(
		"run-1", DocumentSource.sample("示例", "res://data/sample_docs/chinese_sample.md", "zh")
	)
	(
		context
		. apply_question_pack(
			(
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
		)
	)
	return context
