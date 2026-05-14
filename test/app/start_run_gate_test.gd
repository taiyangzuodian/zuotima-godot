extends GdUnitTestSuite

const DocumentFileReader = preload("res://scripts/services/document/document_file_reader.gd")
const DocumentSource = preload("res://scripts/domain/document_source.gd")
const SettingsData = preload("res://scripts/domain/settings_data.gd")
const StartRunGate = preload("res://scripts/app/start_run_gate.gd")


func test_missing_ai_config_blocks_start() -> void:
	var settings := SettingsData.new()
	var gate := StartRunGate.new("res://data/sample_docs/chinese_sample.md")
	var result = gate.validate(
		DocumentSource.sample("示例", "res://data/sample_docs/chinese_sample.md", "zh"), settings
	)

	assert_that(result.ok).is_false()
	assert_that(result.message_key).is_equal("missing_ai_config")


func test_existing_sample_with_ai_config_passes() -> void:
	var gate := StartRunGate.new("res://data/sample_docs/chinese_sample.md")
	var result = gate.validate(
		DocumentSource.sample("示例", "res://data/sample_docs/chinese_sample.md", "zh"),
		_usable_settings()
	)

	assert_that(result.ok).is_true()
	assert_that(result.message_key).is_equal("")


func test_empty_local_file_blocks_start() -> void:
	var path := "user://empty_local.md"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("")
	file.close()
	var gate := StartRunGate.new("res://data/sample_docs/chinese_sample.md")
	var result = gate.validate(
		DocumentSource.local_file("empty_local.md", path, "zh"), _usable_settings()
	)

	assert_that(result.ok).is_false()
	assert_that(result.message_key).is_equal("empty_local_file")


func test_unsupported_local_file_type_blocks_start() -> void:
	var path := "user://unsupported_local.pdf"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("本地文档内容")
	file.close()
	var gate := StartRunGate.new("res://data/sample_docs/chinese_sample.md")
	var result = gate.validate(
		DocumentSource.local_file("unsupported_local.pdf", path, "zh"), _usable_settings()
	)

	assert_that(result.ok).is_false()
	assert_that(result.message_key).is_equal("unsupported_local_file_type")


func test_document_file_reader_reads_sample_and_local_text() -> void:
	var reader := DocumentFileReader.new("res://data/sample_docs/chinese_sample.md")
	var sample_text := reader.read_text(
		DocumentSource.sample("示例", "res://data/sample_docs/chinese_sample.md", "zh")
	)
	assert_that(sample_text).contains("做题马")

	var path := "user://local_reader.md"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("本地文档内容")
	file.close()

	var local_text := reader.read_text(DocumentSource.local_file("local_reader.md", path, "zh"))
	assert_that(local_text).is_equal("本地文档内容")


func _usable_settings() -> SettingsData:
	var settings := SettingsData.new()
	settings.ai_base_url = "https://example.test/v1"
	settings.ai_model = "model-a"
	settings.ai_api_key = "key-a"
	return settings
