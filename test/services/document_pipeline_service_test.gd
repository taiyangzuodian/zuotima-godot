extends GdUnitTestSuite

const DocumentPipelineService = preload(
	"res://scripts/services/document/document_pipeline_service.gd"
)
const DocumentSource = preload("res://scripts/domain/document_source.gd")
const SettingsData = preload("res://scripts/domain/settings_data.gd")


class FakeProvider:
	var schemas: Array[String] = []
	var messages_by_schema: Dictionary = {}
	var chunk_summary_data := {"summary_text": "分块摘要"}

	func request_json(
		_settings: SettingsData, _messages: Array[Dictionary], schema_name: String
	) -> Dictionary:
		schemas.append(schema_name)
		messages_by_schema[schema_name] = _messages
		if schema_name == "document_chunk_summary":
			return {"ok": true, "data": chunk_summary_data}
		if schema_name == "document_summary_merge":
			return {
				"ok": true,
				"data": {"summary_title": "合并摘要标题", "summary_text": "合并摘要正文"},
			}
		return {
			"ok": true,
			"data":
			{
				"summary_title": "最终标题",
				"summary_text": "最终摘要",
				"questions":
				[
					{
						"question_id": "q1",
						"prompt": "核心玩法是什么？",
						"expected_answer_hint": "跑酷与答题",
						"time_limit_sec": 20,
					},
					{
						"question_id": "q2",
						"prompt": "玩家需要同时做什么？",
						"expected_answer_hint": "躲避并输入答案",
						"time_limit_sec": 20,
					},
					{
						"question_id": "q3",
						"prompt": "来源文档是什么语言？",
						"expected_answer_hint": "中文",
						"time_limit_sec": 20,
					},
				],
			},
		}


func test_prepare_builds_question_pack_from_sample_document() -> void:
	var provider := FakeProvider.new()
	var service := DocumentPipelineService.new(provider)
	var settings := SettingsData.new()
	var result := await service.prepare(
		"run-1",
		settings,
		DocumentSource.sample("示例文档", "res://data/sample_docs/chinese_sample.md", "zh")
	)

	assert_that(result.get("ok", false)).is_true()
	assert_that(result.get("run_id", "")).is_equal("run-1")
	assert_that(result.get("pack").summary_title).is_equal("最终标题")
	assert_that(result.get("pack").questions).has_size(3)
	var question_pack_message := str(
		provider.messages_by_schema.get("question_pack", [])[0].get("content", "")
	)
	assert_that(question_pack_message).contains("summary_title")
	assert_that(question_pack_message).contains("expected_answer_hint")
	assert_that(question_pack_message).contains("3-5")


func test_prepare_summarizes_multiple_chunks_before_question_generation() -> void:
	var provider := FakeProvider.new()
	var service := DocumentPipelineService.new(provider)
	var settings := SettingsData.new()
	var file := FileAccess.open("user://long_doc_test.md", FileAccess.WRITE)
	file.store_string("段落一\n\n" + ("很长的中文内容".repeat(400)))
	file.close()

	var result := await service.prepare(
		"run-2", settings, DocumentSource.local_file("长文档", "user://long_doc_test.md", "zh")
	)

	assert_that(result.get("ok", false)).is_true()
	assert_that(provider.schemas).contains("document_chunk_summary")
	assert_that(provider.schemas).contains("question_pack")


func test_prepare_accepts_provider_summary_alias_for_chunk_summary() -> void:
	var provider := FakeProvider.new()
	provider.chunk_summary_data = {"summary": "别名摘要"}
	var service := DocumentPipelineService.new(provider)
	var settings := SettingsData.new()

	var result := await service.prepare(
		"run-3",
		settings,
		DocumentSource.sample("示例文档", "res://data/sample_docs/chinese_sample.md", "zh")
	)

	assert_that(result.get("ok", false)).is_true()
	var question_pack_message := str(
		provider.messages_by_schema.get("question_pack", [])[0].get("content", "")
	)
	assert_that(question_pack_message).contains("别名摘要")
