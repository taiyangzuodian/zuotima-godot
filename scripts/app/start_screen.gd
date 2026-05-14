extends Control

signal start_blocked(message_key: String)
signal run_requested(source: DocumentSource)

const DocumentSource = preload("res://scripts/domain/document_source.gd")
const PlaceholderPaletteScript = preload("res://scripts/ui/placeholder_palette.gd")
const HistoryService = preload("res://scripts/services/history/history_service.gd")
const LatestSummaryService = preload("res://scripts/services/history/latest_summary_service.gd")
const SettingsService = preload("res://scripts/services/settings/settings_service.gd")
const StartRunGate = preload("res://scripts/app/start_run_gate.gd")

var settings_service: Object = SettingsService.new()
var latest_summary_service: Object = LatestSummaryService.new()
var history_service: Object = HistoryService.new()
var start_run_gate := StartRunGate.new()

@onready var settings_overlay: Control = $SettingsOverlay
@onready var how_to_play_overlay: Control = $HowToPlayOverlay
@onready var latest_summary_overlay: Control = $LatestSummaryOverlay
@onready var history_overlay: Control = $HistoryOverlay
@onready var local_file_dialog: FileDialog = $LocalFileDialog
@onready var primary_actions: VBoxContainer = $RootMargin/MainLayout/PrimaryActions
@onready var start_blocked_message: Label = primary_actions.get_node("StartBlockedMessage")


func _ready() -> void:
	PlaceholderPaletteScript.apply_page_background($PageBackground)
	PlaceholderPaletteScript.apply_panel(
		$RootMargin/MainLayout/TitleCard, PlaceholderPaletteScript.COLOR_SAFE
	)
	PlaceholderPaletteScript.apply_title(
		$RootMargin/MainLayout/TitleCard/TitleContent/TitleLabel,
		PlaceholderPaletteScript.COLOR_SAFE
	)
	PlaceholderPaletteScript.apply_muted_body(
		$RootMargin/MainLayout/TitleCard/TitleContent/SubtitleLabel
	)

	PlaceholderPaletteScript.apply_primary_button(
		$RootMargin/MainLayout/PrimaryActions/SampleDocumentButton
	)
	PlaceholderPaletteScript.apply_primary_button(
		$RootMargin/MainLayout/PrimaryActions/LocalFileButton
	)
	PlaceholderPaletteScript.apply_muted_body(start_blocked_message)
	start_blocked_message.add_theme_color_override(
		"font_color", PlaceholderPaletteScript.COLOR_WARNING
	)
	$RootMargin/MainLayout/PrimaryActions/SampleDocumentButton.pressed.connect(_request_sample_run)
	$RootMargin/MainLayout/PrimaryActions/LocalFileButton.pressed.connect(
		func() -> void: local_file_dialog.popup_centered()
	)
	local_file_dialog.file_selected.connect(_request_local_file_run)
	PlaceholderPaletteScript.apply_secondary_button(
		$RootMargin/MainLayout/SecondaryActions/SettingsButton
	)
	PlaceholderPaletteScript.apply_secondary_button(
		$RootMargin/MainLayout/SecondaryActions/HowToPlayButton
	)
	PlaceholderPaletteScript.apply_secondary_button(
		$RootMargin/MainLayout/SecondaryActions/LatestSummaryButton
	)
	PlaceholderPaletteScript.apply_secondary_button(
		$RootMargin/MainLayout/SecondaryActions/HistoryButton
	)

	$RootMargin/MainLayout/SecondaryActions/SettingsButton.pressed.connect(_show_settings_overlay)
	$RootMargin/MainLayout/SecondaryActions/HowToPlayButton.pressed.connect(
		func() -> void: how_to_play_overlay.show()
	)
	$RootMargin/MainLayout/SecondaryActions/LatestSummaryButton.pressed.connect(
		_show_latest_summary_overlay
	)
	$RootMargin/MainLayout/SecondaryActions/HistoryButton.pressed.connect(_show_history_overlay)


func _show_settings_overlay() -> void:
	settings_overlay.call("load_settings", settings_service)
	settings_overlay.show()


func _show_latest_summary_overlay() -> void:
	latest_summary_overlay.call("load_summary", latest_summary_service)
	latest_summary_overlay.show()


func _show_history_overlay() -> void:
	history_overlay.call("load_entries", history_service)
	history_overlay.show()


func _request_sample_run() -> void:
	var source := DocumentSource.sample("做题马示例文档", "res://data/sample_docs/chinese_sample.md", "zh")
	_request_run(source)


func _request_local_file_run(path: String) -> void:
	_request_run(DocumentSource.local_file(path.get_file(), path))


func _request_run(source: DocumentSource) -> void:
	_hide_start_blocked_message()
	var settings = settings_service.load_or_default()
	var validation = start_run_gate.validate(source, settings)
	if not validation.ok:
		_show_start_blocked_message(validation.message_key)
		start_blocked.emit(validation.message_key)
		return
	run_requested.emit(source)


func _show_start_blocked_message(message_key: String) -> void:
	start_blocked_message.text = _blocked_message_text(message_key)
	start_blocked_message.visible = true


func _hide_start_blocked_message() -> void:
	start_blocked_message.visible = false
	start_blocked_message.text = ""


func _blocked_message_text(message_key: String) -> String:
	match message_key:
		"missing_ai_config":
			return "请先在设置里填写 AI Base URL、模型和 API Key，再开始挑战。"
		"missing_sample_resource":
			return "示例文档缺失，无法开始挑战。"
		"missing_local_file":
			return "没有找到选择的本地文档。"
		"unsupported_local_file_type":
			return "当前只支持 txt 或 md 文档。"
		"empty_local_file":
			return "选择的文档为空，请换一个 txt 或 md 文档。"
		_:
			return "当前文档无法开始挑战，请检查设置和文档。"
