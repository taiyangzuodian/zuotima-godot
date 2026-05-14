extends GdUnitTestSuite

const RunContext = preload("res://scripts/domain/run_context.gd")
const PressureController = preload("res://scripts/run/controllers/pressure_controller.gd")
const SurvivalController = preload("res://scripts/run/controllers/survival_controller.gd")


func test_warmup_collision_does_not_break_shield() -> void:
	var controller := SurvivalController.new()
	controller.reset_for_run()
	controller.handle_collision(false)

	assert_that(controller.shield_state).is_equal(RunContext.SHIELD_SHIELDED)


func test_active_collision_breaks_shield_and_starts_protection() -> void:
	var controller := SurvivalController.new()
	controller.reset_for_run()

	controller.handle_collision(true)

	assert_that(controller.shield_state).is_equal(RunContext.SHIELD_BROKEN)
	assert_that(controller.is_break_protected()).is_true()


func test_collision_during_break_protection_does_not_kill() -> void:
	var controller := SurvivalController.new()
	controller.reset_for_run()
	controller.handle_collision(true)

	controller.handle_collision(true)

	assert_that(controller.shield_state).is_equal(RunContext.SHIELD_BROKEN)
	assert_that(controller.is_dead()).is_false()


func test_collision_after_break_protection_expires_kills() -> void:
	var controller := SurvivalController.new()
	controller.reset_for_run()
	controller.handle_collision(true)
	controller.tick(0.76)

	controller.handle_collision(true)

	assert_that(controller.shield_state).is_equal(RunContext.SHIELD_DEAD)
	assert_that(controller.is_dead()).is_true()


func test_correct_answer_restores_shield() -> void:
	var controller := SurvivalController.new()
	controller.reset_for_run()
	controller.handle_collision(true)
	controller.restore_shield()

	assert_that(controller.shield_state).is_equal(RunContext.SHIELD_SHIELDED)


func test_increased_pressure_uses_default_duration_and_expires() -> void:
	var pressure := PressureController.new()
	pressure.apply_increased()
	assert_that(pressure.pressure_state).is_equal(RunContext.PRESSURE_INCREASED)
	assert_float(pressure.speed_multiplier).is_equal(1.2)
	assert_float(pressure.spawn_interval_multiplier).is_equal(0.8)

	pressure.tick(3.9)
	assert_that(pressure.pressure_state).is_equal(RunContext.PRESSURE_INCREASED)
	pressure.tick(0.2)
	assert_that(pressure.pressure_state).is_equal(RunContext.PRESSURE_NORMAL)
	assert_float(pressure.speed_multiplier).is_equal(1.0)
	assert_float(pressure.spawn_interval_multiplier).is_equal(1.0)


func test_reduced_pressure_uses_default_duration_and_multipliers() -> void:
	var pressure := PressureController.new()
	pressure.apply_reduced()

	assert_that(pressure.pressure_state).is_equal(RunContext.PRESSURE_REDUCED)
	assert_float(pressure.speed_multiplier).is_equal(0.85)
	assert_float(pressure.spawn_interval_multiplier).is_equal(1.15)

	pressure.tick(2.4)
	assert_that(pressure.pressure_state).is_equal(RunContext.PRESSURE_REDUCED)
	pressure.tick(0.2)
	assert_that(pressure.pressure_state).is_equal(RunContext.PRESSURE_NORMAL)


func test_same_pressure_state_refreshes_duration_without_stacking() -> void:
	var pressure := PressureController.new()
	pressure.apply_increased()
	pressure.tick(3.0)

	pressure.apply_increased()
	pressure.tick(3.0)

	assert_that(pressure.pressure_state).is_equal(RunContext.PRESSURE_INCREASED)
	assert_float(pressure.speed_multiplier).is_equal(1.2)
	assert_float(pressure.spawn_interval_multiplier).is_equal(0.8)


func test_opposite_pressure_state_overwrites_current_state() -> void:
	var pressure := PressureController.new()
	pressure.apply_increased()

	pressure.apply_reduced()

	assert_that(pressure.pressure_state).is_equal(RunContext.PRESSURE_REDUCED)
	assert_float(pressure.speed_multiplier).is_equal(0.85)
	assert_float(pressure.spawn_interval_multiplier).is_equal(1.15)
