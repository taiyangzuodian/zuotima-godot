class_name RunDirector
extends RefCounted

const DocumentSource = preload("res://scripts/domain/document_source.gd")
const JudgementResult = preload("res://scripts/domain/judgement_result.gd")
const RunContext = preload("res://scripts/domain/run_context.gd")
const RunResultData = preload("res://scripts/domain/run_result_data.gd")
const SettingsData = preload("res://scripts/domain/settings_data.gd")
const PressureController = preload("res://scripts/run/controllers/pressure_controller.gd")
const QuestionFlowController = preload("res://scripts/run/controllers/question_flow_controller.gd")
const SurvivalController = preload("res://scripts/run/controllers/survival_controller.gd")

var context: RunContext

var _pipeline_service: Object
var _judge_service: Object
var _settings: SettingsData
var _judgement_error_active := false
var _question_flow := QuestionFlowController.new()
var _survival := SurvivalController.new()
var _pressure := PressureController.new()


func _init(p_pipeline_service: Object = null, p_judge_service: Object = null) -> void:
	_pipeline_service = p_pipeline_service
	_judge_service = p_judge_service


func begin_warmup(run_id: String, source: DocumentSource, settings: SettingsData) -> RunContext:
	var source_snapshot := DocumentSource.new(
		source.source_type, source.display_name, source.file_path, source.language_hint
	)
	context = RunContext.new(run_id, source_snapshot)
	_settings = SettingsData.from_dict(settings.to_dict())
	_judgement_error_active = false
	_question_flow = QuestionFlowController.new()
	_survival = SurvivalController.new()
	_survival.reset_for_run()
	_pressure = PressureController.new()
	_sync_context_state()
	return context


func start_run(run_id: String, source: DocumentSource, settings: SettingsData) -> RunContext:
	begin_warmup(run_id, source, settings)
	var preparation: Dictionary = await _pipeline_service.prepare(
		run_id, _settings, context.document_source
	)
	if context == null or str(preparation.get("run_id", "")) != context.run_id:
		return context
	if context.phase != RunContext.PHASE_WARMUP:
		return context
	if not preparation.get("ok", false):
		context.mark_preparation_error(str(preparation.get("error", "preparation failed")))
		return context
	apply_question_pack(preparation.get("pack"))
	return context


func apply_question_pack(pack) -> void:
	if not _is_valid_question_pack(pack):
		context.mark_preparation_error("invalid question pack")
		return
	_judgement_error_active = false
	context.apply_question_pack(pack)
	_question_flow.load_pack(pack)
	_sync_context_state()


func handle_collision() -> void:
	if context == null or not _formal_risk_active():
		return
	_survival.handle_collision(true)
	_sync_context_state()
	if _survival.is_dead():
		_question_flow.cancel_pending_judgement()
		context.mark_failed()
		_sync_context_state()


func submit_answer(answer: String) -> JudgementResult:
	if context == null or _judge_service == null or context.phase != RunContext.PHASE_ACTIVE:
		return JudgementResult.new()
	_judgement_error_active = false
	var request = _question_flow.submit_answer(answer, context.run_id)
	if request == null:
		return JudgementResult.new(
			context.run_id, "", JudgementResult.VERDICT_ERROR, "no question pending"
		)
	context.begin_judging()
	_sync_context_state()
	var result: JudgementResult = await _judge_service.judge(_settings, request)
	if not _can_apply_judgement(request.run_id, request.question_id):
		return JudgementResult.new(
			request.run_id,
			request.question_id,
			JudgementResult.VERDICT_ERROR,
			"ignored stale judgement"
		)
	if not _is_known_verdict(result.verdict):
		result = JudgementResult.new(
			result.run_id, result.question_id, JudgementResult.VERDICT_ERROR, result.reason
		)
	if result.verdict == JudgementResult.VERDICT_ERROR:
		_judgement_error_active = true
		_question_flow.cancel_pending_judgement()
		context.mark_judgement_error(result.reason)
		_sync_context_state()
		return result
	var record := _question_flow.apply_judgement(result)
	if record.get("kind", "") == "ignored":
		return result
	context.apply_judgement_verdict(result.verdict)
	if result.verdict == JudgementResult.VERDICT_CORRECT:
		_survival.restore_shield()
		_pressure.apply_reduced()
	else:
		_pressure.apply_increased()
	_sync_context_state()
	return result


func timeout_current_question() -> Dictionary:
	if context == null or context.phase != RunContext.PHASE_ACTIVE or _judgement_error_active:
		return {"kind": "ignored"}
	var record := _question_flow.timeout_current_question()
	if record.get("kind", "") != "timeout":
		return record
	context.answered_count += 1
	context.current_question_index = _question_flow.current_question_index
	context.phase = RunContext.PHASE_CLEARED
	if not _question_flow.is_complete():
		context.phase = RunContext.PHASE_ACTIVE
	_pressure.apply_increased()
	_sync_context_state()
	return record


func end_after_judgement_error() -> bool:
	if context == null or not _judgement_error_active:
		return false
	_judgement_error_active = false
	_question_flow.cancel_pending_judgement()
	context.mark_failed()
	_sync_context_state()
	return true


func tick(delta: float) -> void:
	_survival.tick(delta)
	_pressure.tick(delta)
	_sync_context_state()


func result_data() -> RunResultData:
	var data := RunResultData.from_context(context)
	data.apply_recorded_results(_question_flow.recorded_results)
	return data


func _can_apply_judgement(run_id: String, question_id: String) -> bool:
	return (
		context != null
		and context.run_id == run_id
		and context.phase == RunContext.PHASE_JUDGING
		and _question_flow.pending_judgement_run_id == run_id
		and _question_flow.pending_judgement_question_id == question_id
	)


func _formal_risk_active() -> bool:
	return (
		(context.phase == RunContext.PHASE_ACTIVE or context.phase == RunContext.PHASE_JUDGING)
		and context.has_current_question()
	)


func _is_known_verdict(verdict: String) -> bool:
	return (
		verdict == JudgementResult.VERDICT_CORRECT or verdict == JudgementResult.VERDICT_INCORRECT
	)


func _is_valid_question_pack(pack) -> bool:
	if pack == null or not (pack is QuestionPack):
		return false
	if _is_blank(pack.summary_title) or _is_blank(pack.summary_text):
		return false
	if _is_blank(pack.source_language):
		return false
	if pack.questions.size() < 3 or pack.questions.size() > 5:
		return false

	var question_ids := {}
	for question in pack.questions:
		if not _is_valid_question(question, question_ids):
			return false
		question_ids[question.question_id] = true
	return true


func _is_valid_question(question: QuestionData, question_ids: Dictionary) -> bool:
	if _is_blank(question.question_id) or question_ids.has(question.question_id):
		return false
	if _is_blank(question.prompt) or _is_blank(question.expected_answer_hint):
		return false
	return question.time_limit_sec > 0.0


func _is_blank(value: String) -> bool:
	return value.strip_edges().is_empty()


func _sync_context_state() -> void:
	if context == null:
		return
	context.shield_state = _survival.shield_state
	context.pressure_state = _pressure.pressure_state
	context.current_question_index = _question_flow.current_question_index
	context.pending_judgement_question_id = _question_flow.pending_judgement_question_id
