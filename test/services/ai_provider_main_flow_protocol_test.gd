extends GdUnitTestSuite

const AiProviderService = preload("res://scripts/services/ai/ai_provider_service.gd")
const DocumentPipelineService = preload(
	"res://scripts/services/document/document_pipeline_service.gd"
)
const DocumentSource = preload("res://scripts/domain/document_source.gd")
const JudgementRequest = preload("res://scripts/domain/judgement_request.gd")
const JudgementResult = preload("res://scripts/domain/judgement_result.gd")
const QuestionJudgeService = preload("res://scripts/services/ai/question_judge_service.gd")
const SettingsData = preload("res://scripts/domain/settings_data.gd")


class ScriptedOpenAiExecutor:
	var mode := "happy"
	var calls: Array[Dictionary] = []

	func execute(url: String, headers: PackedStringArray, body: String) -> Dictionary:
		calls.append({"url": url, "headers": headers, "body": body})
		var response := _response_for_mode(body)
		return response

	func _response_for_mode(body: String) -> Dictionary:
		var response: Dictionary
		if mode == "http_error":
			response = {"http_status": 503, "body": "{}"}
		elif mode == "invalid_root_json":
			response = {"http_status": 200, "body": "not-json"}
		elif mode == "non_structured_content":
			response = _openai_content("not-json")
		else:
			response = _response_for_schema(body)
		return response

	func _response_for_schema(body: String) -> Dictionary:
		var schema_message := _schema_message_from_body(body)
		var data: Dictionary = {"summary_text": "unknown schema"}
		if schema_message.contains("document_chunk_summary"):
			data = {"summary_text": "分块摘要"}
		elif schema_message.contains("question_pack"):
			data = {
				"summary_title": "协议验证标题",
				"summary_text": "协议验证摘要",
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
						"prompt": "玩家需要输入什么？",
						"expected_answer_hint": "答案",
						"time_limit_sec": 20,
					},
					{
						"question_id": "q3",
						"prompt": "判题方式是什么？",
						"expected_answer_hint": "语义判题",
						"time_limit_sec": 20,
					},
				],
			}
		elif schema_message.contains("judgement_result"):
			data = {
				"verdict": JudgementResult.VERDICT_CORRECT,
				"reason": "matched intent",
				"canonical_answer": "跑酷与答题",
			}
		return _openai_json(data)

	func _schema_message_from_body(body: String) -> String:
		var payload = JSON.parse_string(body)
		var messages: Array = []
		if typeof(payload) == TYPE_DICTIONARY:
			messages = payload.get("messages", [])
		var schema_message := "" if messages.is_empty() else str(messages[0].get("content", ""))
		return schema_message

	func _openai_json(data: Dictionary) -> Dictionary:
		return _openai_content(JSON.stringify(data))

	func _openai_content(content: String) -> Dictionary:
		return {
			"http_status": 200,
			"body": JSON.stringify({"choices": [{"message": {"content": content}}]}),
		}


func test_document_pipeline_and_judge_use_openai_compatible_http_json_protocol() -> void:
	var executor := ScriptedOpenAiExecutor.new()
	var provider := AiProviderService.new(Callable(executor, "execute"))
	var pipeline := DocumentPipelineService.new(provider)
	var judge := QuestionJudgeService.new(provider)
	var settings := _settings()
	var source := _document_source("user://protocol_happy.md")

	var prepared: Dictionary = await pipeline.prepare("run-protocol", settings, source)
	var pack = prepared.get("pack")
	var judgement: JudgementResult = await judge.judge(
		settings, JudgementRequest.new("run-protocol", "q1", "核心玩法是什么？", "跑酷与答题")
	)

	assert_that(prepared.get("ok", false)).is_true()
	assert_that(pack.summary_title).is_equal("协议验证标题")
	assert_that(pack.questions).has_size(3)
	assert_that(judgement.verdict).is_equal(JudgementResult.VERDICT_CORRECT)
	assert_that(judgement.canonical_answer).is_equal("跑酷与答题")
	assert_that(executor.calls).has_size(3)
	for call in executor.calls:
		_assert_protocol_call(call)


func test_provider_http_failure_enters_preparation_failure_path() -> void:
	var executor := ScriptedOpenAiExecutor.new()
	executor.mode = "http_error"
	var provider := AiProviderService.new(Callable(executor, "execute"))
	var pipeline := DocumentPipelineService.new(provider)

	var prepared: Dictionary = await pipeline.prepare(
		"run-http-error", _settings(), _document_source("user://protocol_http_error.md")
	)

	assert_that(prepared.get("ok", true)).is_false()
	assert_that(str(prepared.get("error", ""))).contains("HTTP 503")


func test_provider_invalid_json_enters_preparation_failure_path() -> void:
	var executor := ScriptedOpenAiExecutor.new()
	executor.mode = "invalid_root_json"
	var provider := AiProviderService.new(Callable(executor, "execute"))
	var pipeline := DocumentPipelineService.new(provider)

	var prepared: Dictionary = await pipeline.prepare(
		"run-invalid-json", _settings(), _document_source("user://protocol_invalid_json.md")
	)

	assert_that(prepared.get("ok", true)).is_false()
	assert_that(str(prepared.get("error", ""))).contains("invalid JSON")


func test_provider_structured_parse_failure_enters_judgement_error_path() -> void:
	var executor := ScriptedOpenAiExecutor.new()
	executor.mode = "non_structured_content"
	var provider := AiProviderService.new(Callable(executor, "execute"))
	var judge := QuestionJudgeService.new(provider)

	var result: JudgementResult = await judge.judge(
		_settings(), JudgementRequest.new("run-parse-error", "q1", "题目", "答案")
	)

	assert_that(result.verdict).is_equal(JudgementResult.VERDICT_ERROR)
	assert_that(result.reason).contains("non-structured")


func _assert_protocol_call(call: Dictionary) -> void:
	assert_that(str(call.get("url", ""))).is_equal("http://127.0.0.1:8317/v1/chat/completions")
	var headers := Array(call.get("headers", PackedStringArray()))
	assert_that(headers).contains("Authorization: Bearer sk-test")
	assert_that(headers).contains("Content-Type: application/json")

	var body = JSON.parse_string(str(call.get("body", "")))
	assert_that(typeof(body)).is_equal(TYPE_DICTIONARY)
	assert_that(str(body.get("model", ""))).is_equal("test-model")
	assert_that(body.get("response_format", {}).get("type", "")).is_equal("json_object")

	var roles: Array[String] = []
	for message in body.get("messages", []):
		roles.append(str(message.get("role", "")))
	assert_that(roles).contains("system")
	assert_that(roles).contains("user")


func _settings() -> SettingsData:
	var settings := SettingsData.new()
	settings.ai_base_url = "http://127.0.0.1:8317/v1"
	settings.ai_api_key = "sk-test"
	settings.ai_model = "test-model"
	return settings


func _document_source(path: String) -> DocumentSource:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("做题马把跑酷躲避和中文答题结合在同一个实时挑战中。")
	file.close()
	return DocumentSource.local_file(path.get_file(), path, "zh")
