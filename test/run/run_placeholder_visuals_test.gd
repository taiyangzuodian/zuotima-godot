extends GdUnitTestSuite


func after_test() -> void:
	_reset_jump_action_to_shift()


func _reset_jump_action_to_shift() -> void:
	var shift_event := InputEventKey.new()
	shift_event.keycode = KEY_SHIFT
	InputMap.action_erase_events("jump")
	InputMap.action_add_event("jump", shift_event)


func test_run_root_contains_world_and_hud_placeholder_layers() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()

	assert_that(runner.find_child("PlayerPlaceholder")).is_not_null()
	assert_that(runner.find_child("HazardPlaceholder")).is_not_null()
	assert_that(runner.find_child("HazardSpawner")).is_not_null()
	assert_that(runner.find_child("GroundStrip")).is_not_null()
	assert_that(runner.find_child("QuestionHud")).is_not_null()
	assert_that(runner.find_child("PhaseBanner")).is_not_null()
	assert_that(runner.find_child("PressureHint")).is_not_null()
	assert_that(runner.find_child("JudgementBanner")).is_not_null()
	assert_that(runner.find_child("QuestionPanel")).is_not_null()
	assert_that(runner.find_child("AnswerInputPanel")).is_not_null()


func test_run_root_renders_world_between_background_and_hud() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()

	var background_layer := runner.find_child("BackgroundLayer") as CanvasLayer
	var hud := runner.find_child("QuestionHud") as CanvasLayer

	assert_that(background_layer.layer).is_less(0)
	assert_that(hud.layer).is_greater(background_layer.layer)


func test_run_world_activity_band_sits_above_answer_area() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()

	var bottom_stack := runner.find_child("BottomStack") as Control
	var player := runner.find_child("PlayerPlaceholder") as Node2D
	var hazard := runner.find_child("HazardPlaceholder") as Node2D
	var spawner := runner.find_child("HazardSpawner")
	var ground := runner.find_child("GroundStrip") as Sprite2D
	var activity_bottom_limit := minf(bottom_stack.global_position.y - 32.0, 480.0)

	assert_that(player.position.y).is_less(activity_bottom_limit)
	assert_that(hazard.position.y).is_less(activity_bottom_limit)
	assert_that(float(spawner.get("spawn_y"))).is_less(activity_bottom_limit)
	assert_that(_sprite_bottom_y(ground)).is_less(activity_bottom_limit)


func test_run_world_hazards_start_from_right_edge() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()

	var hazard := runner.find_child("HazardPlaceholder") as Node2D
	var spawner := runner.find_child("HazardSpawner")

	assert_that(hazard.position.x).is_greater_equal(1280.0)
	assert_that(float(spawner.get("spawn_x"))).is_greater_equal(1280.0)


func test_run_world_hides_hazards_during_warmup() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()
	var scene := runner.scene()
	var hazard := runner.find_child("HazardPlaceholder") as Node2D

	scene.set_placeholder_phase("WARMUP")
	assert_that(hazard.visible).is_false()

	scene.set_placeholder_phase("ACTIVE")
	assert_that(hazard.visible).is_true()


func _sprite_bottom_y(node: Sprite2D) -> float:
	var height := 0.0
	if node.region_enabled:
		height = node.region_rect.size.y
	elif node.texture != null:
		height = node.texture.get_height()
	return node.global_position.y + height * absf(node.scale.y) * 0.5


func test_run_root_world_nodes_are_scripted_and_can_move() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()
	var scene := runner.scene()
	var player := runner.find_child("PlayerPlaceholder")
	var hazard := runner.find_child("HazardPlaceholder")
	var start_x: float = hazard.position.x

	scene.set_placeholder_phase("ACTIVE")
	assert_that(player.call("request_jump")).is_true()
	scene.tick_world(0.1, 1.2, 1.0)

	assert_that(player.position.y).is_less(player.ground_y)
	assert_that(hazard.position.x).is_less(start_x)


func test_run_root_handles_jump_action_without_stealing_answer_focus() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()
	var scene := runner.scene()
	var answer_field := runner.find_child("AnswerField") as LineEdit
	answer_field.grab_focus()
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.pressed = true

	assert_that(scene.handle_jump_input(event)).is_true()

	assert_that(runner.find_child("PlayerPlaceholder").velocity.y).is_less(0.0)
	assert_that(answer_field.has_focus()).is_true()


func test_run_root_ignores_unmapped_shift_when_jump_action_is_remapped() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()
	var scene := runner.scene()
	var shift_event := InputEventKey.new()
	shift_event.keycode = KEY_SHIFT
	shift_event.pressed = true
	var space_event := InputEventKey.new()
	space_event.keycode = KEY_SPACE
	space_event.pressed = true
	InputMap.action_erase_events("jump")
	InputMap.action_add_event("jump", space_event)

	assert_that(scene.handle_jump_input(shift_event)).is_false()
	assert_that(scene.handle_jump_input(space_event)).is_true()


func test_run_root_can_switch_pressure_hint() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()
	var scene := runner.scene()
	var pressure_hint := runner.find_child("PressureHint") as Label

	scene.set_pressure_hint("REDUCED")
	assert_that(pressure_hint.text).contains("压力降低")

	scene.set_pressure_hint("INCREASED")
	assert_that(pressure_hint.text).contains("压力升高")

	scene.set_pressure_hint("NORMAL")
	assert_that(pressure_hint.text).contains("压力正常")


func test_run_root_can_switch_placeholder_phase_and_damage_flash() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()

	var scene := runner.scene()
	scene.set_placeholder_phase("WARMUP")
	assert_that(scene.get_node("BackgroundLayer/WarmupTint").visible).is_true()
	assert_that(scene.get_node("BackgroundLayer/ActiveTint").visible).is_false()
	assert_that(scene.get_node("BackgroundLayer/FailureOverlay").visible).is_false()

	scene.set_placeholder_phase("ACTIVE")
	assert_that(scene.get_node("BackgroundLayer/WarmupTint").visible).is_false()
	assert_that(scene.get_node("BackgroundLayer/ActiveTint").visible).is_true()
	assert_that(scene.get_node("BackgroundLayer/FailureOverlay").visible).is_false()

	scene.set_placeholder_phase("FAILED")
	assert_that(scene.get_node("BackgroundLayer/WarmupTint").visible).is_false()
	assert_that(scene.get_node("BackgroundLayer/FailureOverlay").visible).is_true()

	scene.flash_damage()
	assert_that(scene.get_node("BackgroundLayer/DamageFlash").visible).is_true()


func test_judgement_banner_can_switch_to_error_state() -> void:
	var runner := scene_runner("res://scenes/run/run_root.tscn")
	await await_idle_frame()

	var banner := runner.find_child("JudgementBanner")
	banner.call("set_status", "error", "provider failed")
	assert_that(banner.visible).is_true()
	assert_that(banner.get_node("BannerBody/StatusLabel").text).contains("判题错误")
	assert_that(banner.get_node("BannerBody/StatusLabel").text).contains("provider failed")
	assert_that(runner.find_child("RetryJudgementButton")).is_not_null()
	assert_that(runner.find_child("EndRunButton")).is_not_null()
