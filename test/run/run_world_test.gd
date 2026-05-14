extends GdUnitTestSuite

const RunContext = preload("res://scripts/domain/run_context.gd")
const RunnerPlayer = preload("res://scripts/run/world/runner_player.gd")
const Hazard = preload("res://scripts/run/world/hazard.gd")
const HazardSpawner = preload("res://scripts/run/world/hazard_spawner.gd")


class CollisionCapture:
	var count := 0

	func capture() -> void:
		count += 1


func test_player_starts_grounded() -> void:
	var player: RunnerPlayer = auto_free(RunnerPlayer.new())

	assert_that(player.is_grounded()).is_true()
	assert_float(player.velocity.y).is_equal(0.0)


func test_player_jump_applies_upward_velocity_only_when_grounded() -> void:
	var player: RunnerPlayer = auto_free(RunnerPlayer.new())

	assert_that(player.request_jump()).is_true()
	var first_jump_velocity: float = player.velocity.y
	assert_that(first_jump_velocity).is_less(0.0)

	assert_that(player.request_jump()).is_false()
	assert_float(player.velocity.y).is_equal(first_jump_velocity)


func test_player_jump_clears_visible_hazard_height() -> void:
	var player: RunnerPlayer = auto_free(RunnerPlayer.new())
	var highest_y := player.position.y

	player.request_jump()
	for _index in range(30):
		player.tick(1.0 / 60.0)
		highest_y = minf(highest_y, player.position.y)

	assert_float(player.ground_y - highest_y).is_greater_equal(180.0)


func test_gravity_returns_player_to_ground() -> void:
	var player: RunnerPlayer = auto_free(RunnerPlayer.new())
	player.request_jump()

	for _index in range(60):
		player.tick(0.05)

	assert_that(player.is_grounded()).is_true()
	assert_float(player.position.y).is_equal(player.ground_y)
	assert_float(player.velocity.y).is_equal(0.0)


func test_hazard_moves_left_by_speed_multiplier() -> void:
	var hazard: Hazard = auto_free(Hazard.new())
	hazard.base_speed_px_sec = 100.0
	hazard.position = Vector2(500.0, 0.0)

	hazard.tick(0.5, 1.2)

	assert_float(hazard.position.x).is_equal(440.0)


func test_hazard_default_speed_is_readable_for_manual_play() -> void:
	var hazard: Hazard = auto_free(Hazard.new())

	assert_float(hazard.base_speed_px_sec).is_equal(160.0)


func test_hazard_spawner_does_not_spawn_during_warmup() -> void:
	var spawner: HazardSpawner = auto_free(HazardSpawner.new())
	spawner.set_run_phase(RunContext.PHASE_WARMUP)

	spawner.tick(10.0, 1.0)

	assert_that(spawner.spawned_hazards).is_empty()


func test_hazard_spawner_default_spacing_keeps_bullets_readable() -> void:
	var spawner: HazardSpawner = auto_free(HazardSpawner.new())
	spawner.set_run_phase(RunContext.PHASE_ACTIVE)

	spawner.tick(2.9, 1.0)
	assert_that(spawner.spawned_hazards).is_empty()

	spawner.tick(0.2, 1.0)
	assert_that(spawner.spawned_hazards).has_size(1)


func test_hazard_spawner_interval_respects_pressure_multiplier() -> void:
	var spawner: HazardSpawner = auto_free(HazardSpawner.new())
	spawner.base_interval_sec = 3.0
	spawner.spawn_x = 900.0
	spawner.spawn_y = 560.0
	spawner.set_run_phase(RunContext.PHASE_ACTIVE)

	spawner.tick(2.3, 1.0)
	assert_that(spawner.spawned_hazards).is_empty()

	spawner.tick(0.2, 0.8)
	assert_that(spawner.spawned_hazards).has_size(1)
	assert_float(spawner.spawned_hazards[0].position.x).is_equal(900.0)
	assert_float(spawner.spawned_hazards[0].position.y).is_equal(560.0)


func test_hazard_spawner_creates_visible_art_hazard() -> void:
	var spawner: HazardSpawner = auto_free(HazardSpawner.new())

	var hazard := spawner.spawn_hazard()

	assert_that(hazard.get_child_count()).is_greater(0)
	var sprite := hazard.get_child(0) as Sprite2D
	assert_that(sprite).is_not_null()
	assert_that(sprite.texture).is_not_null()


func test_spawned_hazards_move_when_spawner_ticks() -> void:
	var spawner: HazardSpawner = auto_free(HazardSpawner.new())
	spawner.spawn_x = 900.0
	var hazard := spawner.spawn_hazard()

	spawner.tick(0.5, 1.0)

	assert_float(hazard.position.x).is_equal(820.0)


func test_spawner_collision_is_ignored_during_warmup_and_forwarded_when_active() -> void:
	var spawner: HazardSpawner = auto_free(HazardSpawner.new())
	var capture := CollisionCapture.new()
	spawner.collision_detected.connect(capture.capture)

	spawner.set_run_phase(RunContext.PHASE_WARMUP)
	spawner.notify_player_collision()
	assert_that(capture.count).is_equal(0)

	spawner.set_run_phase(RunContext.PHASE_ACTIVE)
	spawner.notify_player_collision()
	assert_that(capture.count).is_equal(1)
