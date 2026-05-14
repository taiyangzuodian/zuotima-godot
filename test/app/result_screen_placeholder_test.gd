extends GdUnitTestSuite

const RunResultData = preload("res://scripts/domain/run_result_data.gd")


func test_result_screen_contains_placeholder_cards_and_actions() -> void:
	var runner := scene_runner("res://scenes/result/result_screen.tscn")
	await await_idle_frame()

	assert_that(runner.find_child("ResultTitleLabel")).is_not_null()
	assert_that(runner.find_child("StatsCard")).is_not_null()
	assert_that(runner.find_child("RetryButton")).is_not_null()
	assert_that(runner.find_child("BackButton")).is_not_null()


func test_result_screen_can_switch_to_failed_placeholder_state() -> void:
	var runner := scene_runner("res://scenes/result/result_screen.tscn")
	await await_idle_frame()

	var scene := runner.scene()
	scene.set_placeholder_result("failed")
	(
		assert_that(
			scene.get_node("RootMargin/Layout/ResultCard/ResultContent/ResultTitleLabel").text
		)
		. is_equal("挑战失败")
	)


func test_result_screen_displays_wrong_and_timeout_details() -> void:
	var runner := scene_runner("res://scenes/result/result_screen.tscn")
	await await_idle_frame()
	var scene := runner.scene()
	var data := RunResultData.new()
	data.result = "failed"
	data.accuracy = 0.5
	data.question_count = 4
	data.wrong_items = [
		{
			"prompt": "第一题",
			"player_answer": "玩家答案",
			"standard_answer": "标准答案",
			"reason": "AI 解释",
		}
	]
	data.timeout_items = [{"prompt": "第二题", "standard_answer": "答案二"}]

	scene.show_result(data)

	assert_that(runner.find_child("DetailTitleLabel").text).is_equal("答题回顾")
	assert_that(runner.find_child("WrongItemsLabel").text).contains("错题")
	assert_that(runner.find_child("WrongItemsLabel").text).contains("第一题")
	assert_that(runner.find_child("WrongItemsLabel").text).contains("玩家答案")
	assert_that(runner.find_child("WrongItemsLabel").text).contains("标准答案")
	assert_that(runner.find_child("WrongItemsLabel").text).contains("AI 解释")
	assert_that(runner.find_child("TimeoutItemsLabel").text).contains("超时")
	assert_that(runner.find_child("TimeoutItemsLabel").text).contains("第二题")
	assert_that(runner.find_child("TimeoutItemsLabel").text).contains("答案二")
