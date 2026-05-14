extends Node2D

signal run_completed(result_data)

const RunDirector = preload("res://scripts/run/run_director.gd")
const RunContext = preload("res://scripts/domain/run_context.gd")
const JudgementResult = preload("res://scripts/domain/judgement_result.gd")
const PressureController = preload("res://scripts/run/controllers/pressure_controller.gd")
const PlaceholderPaletteScript = preload("res://scripts/ui/placeholder_palette.gd")

const HAZARD_OVERLAP_RADIUS := 72.0

var pipeline_service: Object
var judge_service: Object
var director: RunDirector
var _completion_emitted := false
var _world_pressure := PressureController.new()


func _ready() -> void:
	$BackgroundLayer/WorldBackground.color = PlaceholderPaletteScript.COLOR_PAGE_BG
	$BackgroundLayer/WarmupTint.color = Color(0.08, 0.72, 0.65, 0.12)
	$BackgroundLayer/ActiveTint.color = PlaceholderPaletteScript.COLOR_ACTIVE_TINT
	$BackgroundLayer/FailureOverlay.color = PlaceholderPaletteScript.COLOR_OVERLAY_SHADE
	$BackgroundLayer/DamageFlash.color = PlaceholderPaletteScript.COLOR_DAMAGE_FLASH
	$WorldLayer/PlayerPlaceholder.modulate = Color.WHITE
	$WorldLayer/HazardPlaceholder.modulate = Color.WHITE
	$WorldLayer/GroundStrip.modulate = Color(1.0, 1.0, 1.0, 0.92)
	$WorldLayer/HazardSpawner.collision_detected.connect(handle_collision)
	$QuestionHud.answer_submitted.connect(submit_answer)
	$QuestionHud.retry_judgement_requested.connect(submit_answer)
	$QuestionHud.end_run_requested.connect(end_run_after_judgement_error)
	set_placeholder_phase("WARMUP")


func _process(delta: float) -> void:
	var speed_multiplier := _world_pressure.speed_multiplier
	var spawn_interval_multiplier := _world_pressure.spawn_interval_multiplier
	if director != null and director.context != null:
		director.tick(delta)
		_world_pressure.pressure_state = director.context.pressure_state
		_world_pressure.speed_multiplier = _pressure_speed_multiplier(
			director.context.pressure_state
		)
		_world_pressure.spawn_interval_multiplier = _pressure_spawn_interval_multiplier(
			director.context.pressure_state
		)
		speed_multiplier = _world_pressure.speed_multiplier
		spawn_interval_multiplier = _world_pressure.spawn_interval_multiplier
		$WorldLayer/HazardSpawner.set_run_phase(director.context.phase)
		_sync_from_context()
	tick_world(delta, speed_multiplier, spawn_interval_multiplier)


func _unhandled_input(event: InputEvent) -> void:
	handle_jump_input(event)


func handle_jump_input(event: InputEvent) -> bool:
	if not _is_jump_event(event):
		return false
	$WorldLayer/PlayerPlaceholder.request_jump()
	_focus_answer_input()
	return true


func tick_world(
	delta: float, speed_multiplier: float = 1.0, spawn_interval_multiplier: float = 1.0
) -> void:
	$WorldLayer/PlayerPlaceholder.tick(delta)
	$WorldLayer/HazardSpawner.tick(delta, spawn_interval_multiplier)
	if not _hazards_should_run():
		return
	$WorldLayer/HazardPlaceholder.tick(delta, speed_multiplier)
	_damage_on_world_overlap()


func start_run(run_id: String, source, settings) -> RunContext:
	_completion_emitted = false
	director = RunDirector.new(pipeline_service, judge_service)
	var context: RunContext = await director.start_run(run_id, source, settings)
	if not _can_sync_scene():
		return context
	_sync_from_context()
	_emit_completion_if_terminal()
	return context


func handle_collision() -> void:
	if director == null:
		return
	director.handle_collision()
	_sync_from_context()
	_focus_answer_input()
	_emit_completion_if_terminal()


func submit_answer(answer: String):
	if director == null:
		return null
	var result = await director.submit_answer(answer)
	if not _can_sync_scene():
		return result
	_sync_from_context()
	if result.verdict != JudgementResult.VERDICT_ERROR:
		$QuestionHud.clear_answer()
		_focus_answer_input()
	_emit_completion_if_terminal()
	return result


func end_run_after_judgement_error() -> bool:
	if director == null:
		return false
	var ended := director.end_after_judgement_error()
	_sync_from_context()
	_emit_completion_if_terminal()
	return ended


func timeout_current_question() -> Dictionary:
	if director == null:
		return {"kind": "ignored"}
	var record := director.timeout_current_question()
	_sync_from_context()
	_focus_answer_input()
	_emit_completion_if_terminal()
	return record


func _damage_on_world_overlap() -> void:
	var player := $WorldLayer/PlayerPlaceholder as Node2D
	if _nodes_overlap(player, $WorldLayer/HazardPlaceholder):
		handle_collision()
		return
	for hazard in $WorldLayer/HazardSpawner.spawned_hazards:
		if _nodes_overlap(player, hazard):
			handle_collision()
			return


func _nodes_overlap(left: Node2D, right: Node2D) -> bool:
	return left.global_position.distance_to(right.global_position) <= HAZARD_OVERLAP_RADIUS


func set_placeholder_phase(phase: String) -> void:
	var hazards_visible := phase == RunContext.PHASE_ACTIVE or phase == RunContext.PHASE_JUDGING
	$BackgroundLayer/WarmupTint.visible = phase == RunContext.PHASE_WARMUP
	$BackgroundLayer/ActiveTint.visible = hazards_visible
	$BackgroundLayer/FailureOverlay.visible = (
		phase == RunContext.PHASE_FAILED or phase == RunContext.PHASE_PREPARATION_ERROR
	)
	$WorldLayer/HazardPlaceholder.visible = hazards_visible
	$WorldLayer/HazardSpawner.set_run_phase(phase)
	$BackgroundLayer/DamageFlash.visible = false


func _hazards_should_run() -> bool:
	return $WorldLayer/HazardPlaceholder.visible


func set_pressure_hint(pressure_state: String) -> void:
	$QuestionHud.set_pressure_hint(pressure_state)


func flash_damage() -> void:
	$BackgroundLayer/DamageFlash.visible = true


func _can_sync_scene() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func _focus_answer_input() -> void:
	if _can_sync_scene():
		$QuestionHud.focus_answer()


func _sync_from_context() -> void:
	if director == null or director.context == null or not _can_sync_scene():
		return
	var context := director.context
	set_placeholder_phase(context.phase)
	set_pressure_hint(context.pressure_state)
	$WorldLayer/HazardSpawner.set_run_phase(context.phase)
	_sync_hud(context)


func _emit_completion_if_terminal() -> void:
	if _completion_emitted or director == null or director.context == null:
		return
	var phase := director.context.phase
	if phase != RunContext.PHASE_FAILED and phase != RunContext.PHASE_CLEARED:
		return
	_completion_emitted = true
	run_completed.emit(director.result_data())


func _sync_hud(context: RunContext) -> void:
	var hud := $QuestionHud
	var top_row := hud.get_node("Root/HudMargin/Layout/TopRow")
	var question_body := hud.get_node(
		"Root/HudMargin/Layout/BottomStack/QuestionPanel/QuestionBody"
	)
	top_row.get_node("PhaseBanner/PhaseLabel").text = _phase_text(context.phase)
	top_row.get_node("ShieldIndicator/ShieldBody/ShieldValue").text = _shield_text(
		context.shield_state
	)
	if context.phase == RunContext.PHASE_JUDGING:
		hud.show_judging()
	elif not context.last_error_message.is_empty() and context.phase == RunContext.PHASE_ACTIVE:
		hud.show_judgement_error(context.last_error_message)
	else:
		hud.hide_judgement_banner()
	if context.has_current_question():
		var question := context.current_question()
		question_body.get_node("PromptLabel").text = question.prompt
		question_body.get_node("QuestionNumberLabel").text = (
			"第 %d / %d 题" % [context.current_question_index + 1, context.questions.size()]
		)
		question_body.get_node("TimerLabel").text = "剩余 %d 秒" % int(question.time_limit_sec)
	elif context.phase == RunContext.PHASE_PREPARATION_ERROR:
		question_body.get_node("PromptLabel").text = "准备失败：%s" % context.last_error_message
		question_body.get_node("QuestionNumberLabel").text = "准备失败"
		question_body.get_node("TimerLabel").text = "请检查 AI 服务后重新开始"


func _phase_text(phase: String) -> String:
	if phase == RunContext.PHASE_ACTIVE:
		return "答题中"
	if phase == RunContext.PHASE_JUDGING:
		return "判题中"
	if phase == RunContext.PHASE_FAILED:
		return "挑战失败"
	if phase == RunContext.PHASE_CLEARED:
		return "挑战通关"
	if phase == RunContext.PHASE_PREPARATION_ERROR:
		return "准备失败"
	return "预热中"


func _shield_text(shield_state: String) -> String:
	if shield_state == RunContext.SHIELD_BROKEN:
		return "破盾"
	if shield_state == RunContext.SHIELD_DEAD:
		return "失败"
	return "有盾"


func _is_jump_event(event: InputEvent) -> bool:
	return event.is_action_pressed("jump")


func _pressure_speed_multiplier(pressure_state: String) -> float:
	if pressure_state == RunContext.PRESSURE_REDUCED:
		return 0.85
	if pressure_state == RunContext.PRESSURE_INCREASED:
		return 1.2
	return 1.0


func _pressure_spawn_interval_multiplier(pressure_state: String) -> float:
	if pressure_state == RunContext.PRESSURE_REDUCED:
		return 1.15
	if pressure_state == RunContext.PRESSURE_INCREASED:
		return 0.8
	return 1.0
