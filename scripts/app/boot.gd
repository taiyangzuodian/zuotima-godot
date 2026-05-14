extends Node

const AiProviderService = preload("res://scripts/services/ai/ai_provider_service.gd")
const DocumentPipelineService = preload(
	"res://scripts/services/document/document_pipeline_service.gd"
)
const HistoryEntry = preload("res://scripts/domain/history_entry.gd")
const HistoryService = preload("res://scripts/services/history/history_service.gd")
const LatestSummaryData = preload("res://scripts/domain/latest_summary_data.gd")
const LatestSummaryService = preload("res://scripts/services/history/latest_summary_service.gd")
const QuestionJudgeService = preload("res://scripts/services/ai/question_judge_service.gd")
const SettingsService = preload("res://scripts/services/settings/settings_service.gd")

const START_SCREEN_SCENE := preload("res://scenes/menu/start_screen.tscn")
const RUN_SCENE := preload("res://scenes/run/run_root.tscn")
const RESULT_SCREEN_SCENE := preload("res://scenes/result/result_screen.tscn")

var settings_service: Object = SettingsService.new()
var latest_summary_service: Object = LatestSummaryService.new()
var history_service: Object = HistoryService.new()
var pipeline_service: Object
var judge_service: Object
var _last_source


func _ready() -> void:
	if get_child_count() == 0:
		_show_start_screen()


func _show_start_screen() -> void:
	var start_screen := START_SCREEN_SCENE.instantiate()
	start_screen.settings_service = settings_service
	start_screen.latest_summary_service = latest_summary_service
	start_screen.history_service = history_service
	start_screen.run_requested.connect(_start_run)
	_replace_screen(start_screen)


func _start_run(source) -> void:
	_last_source = source
	var run_screen := RUN_SCENE.instantiate()
	_ensure_run_services()
	run_screen.pipeline_service = pipeline_service
	run_screen.judge_service = judge_service
	run_screen.run_completed.connect(_show_result_screen)
	_replace_screen(run_screen)
	run_screen.start_run(_new_run_id(), source, settings_service.load_or_default())


func _ensure_run_services() -> void:
	if pipeline_service != null and judge_service != null:
		return
	var provider := AiProviderService.new()
	pipeline_service = DocumentPipelineService.new(provider)
	judge_service = QuestionJudgeService.new(provider)


func _show_result_screen(result_data) -> void:
	_persist_run_result(result_data)
	var result_screen := RESULT_SCREEN_SCENE.instantiate()
	result_screen.result_data = result_data
	result_screen.retry_requested.connect(_retry_last_run)
	result_screen.back_to_start_requested.connect(_show_start_screen)
	_replace_screen(result_screen)


func _retry_last_run() -> void:
	if _last_source == null:
		_show_start_screen()
		return
	_start_run(_last_source)


func _persist_run_result(result_data) -> void:
	if result_data == null:
		return
	if not str(result_data.summary_title).strip_edges().is_empty():
		latest_summary_service.save(_latest_summary_from_result(result_data))
	history_service.append_entry(_history_entry_from_result(result_data))


func _latest_summary_from_result(result_data) -> LatestSummaryData:
	var summary := LatestSummaryData.new()
	summary.generated_at = Time.get_datetime_string_from_system(true)
	summary.summary_title = result_data.summary_title
	summary.summary_text = result_data.summary_text
	summary.source_language = result_data.source_language
	return summary


func _history_entry_from_result(result_data) -> HistoryEntry:
	var entry := HistoryEntry.new()
	entry.completed_at = Time.get_datetime_string_from_system(true)
	entry.summary_title = result_data.summary_title
	entry.result = "cleared" if result_data.result == "cleared" else "failed"
	entry.accuracy = result_data.accuracy
	entry.question_count = result_data.question_count
	return entry


func _replace_screen(screen: Node) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_child(screen)


func _new_run_id() -> String:
	return "run-%d" % Time.get_ticks_msec()
