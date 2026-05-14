extends GdUnitTestSuite

const AiProviderService = preload("res://scripts/services/ai/ai_provider_service.gd")
const SettingsData = preload("res://scripts/domain/settings_data.gd")


class FakeExecutor:
	var last_url := ""
	var last_headers: PackedStringArray = []
	var last_body := ""

	func execute(url: String, headers: PackedStringArray, body: String) -> Dictionary:
		last_url = url
		last_headers = headers
		last_body = body
		return {
			"http_status": 200,
			"body":
			JSON.stringify(
				{"choices": [{"message": {"content": JSON.stringify({"summary_text": "ok"})}}]}
			),
		}


func test_request_json_builds_openai_compatible_call() -> void:
	var executor := FakeExecutor.new()
	var service: AiProviderService = AiProviderService.new(Callable(executor, "execute"))
	var settings := SettingsData.new()
	settings.ai_base_url = "http://127.0.0.1:8317/v1"
	settings.ai_api_key = "sk-local"
	settings.ai_model = "gpt-5.4-xhigh"

	var result: Dictionary = await service.request_json(
		settings, [{"role": "user", "content": "hello"}], "document_chunk_summary"
	)

	assert_that(result.get("ok", false)).is_true()
	assert_that(executor.last_url).is_equal("http://127.0.0.1:8317/v1/chat/completions")
	assert_that(executor.last_headers[0]).contains("Authorization: Bearer sk-local")
	assert_that(executor.last_body).contains("gpt-5.4-xhigh")
	assert_that(executor.last_body).contains("document_chunk_summary")
