extends GdUnitTestSuite

const DocumentSource = preload("res://scripts/domain/document_source.gd")
const QuestionData = preload("res://scripts/domain/question_data.gd")
const QuestionPack = preload("res://scripts/domain/question_pack.gd")
const RunContext = preload("res://scripts/domain/run_context.gd")


func test_run_context_starts_in_safe_warmup_state() -> void:
	var source := DocumentSource.sample("示例文档", "res://data/sample_docs/chinese_sample.md", "zh")
	var context := RunContext.new("run-1", source)

	assert_that(context.run_id).is_equal("run-1")
	assert_that(context.phase).is_equal(RunContext.PHASE_WARMUP)
	assert_that(context.pending_judgement_question_id).is_equal("")
	assert_that(context.questions).is_empty()


func test_apply_question_pack_switches_context_to_active() -> void:
	var source := DocumentSource.sample("示例文档", "res://data/sample_docs/chinese_sample.md", "zh")
	var context := RunContext.new("run-2", source)
	var questions: Array[QuestionData] = [QuestionData.new("q1", "核心玩法是什么？", "跑酷答题", 20.0)]
	var pack := QuestionPack.new("pack-1", "zh", "跑酷与答题", "摘要正文", questions)

	context.apply_question_pack(pack)

	assert_that(context.phase).is_equal(RunContext.PHASE_ACTIVE)
	assert_that(context.source_language).is_equal("zh")
	assert_that(context.current_question().question_id).is_equal("q1")


func test_mark_preparation_error_keeps_run_inside_current_context() -> void:
	var source := DocumentSource.sample("示例文档", "res://data/sample_docs/chinese_sample.md", "zh")
	var context := RunContext.new("run-3", source)

	context.mark_preparation_error("provider timeout")

	assert_that(context.phase).is_equal(RunContext.PHASE_PREPARATION_ERROR)
	assert_that(context.last_error_message).is_equal("provider timeout")
