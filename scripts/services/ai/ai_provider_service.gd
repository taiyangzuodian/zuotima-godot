class_name AiProviderService
extends RefCounted

const SettingsData = preload("res://scripts/domain/settings_data.gd")

var _request_executor: Callable


func _init(p_request_executor: Callable = Callable()) -> void:
	_request_executor = p_request_executor


func request_json(
	settings: SettingsData, messages: Array[Dictionary], schema_name: String
) -> Dictionary:
	if (
		settings.ai_base_url.is_empty()
		or settings.ai_api_key.is_empty()
		or settings.ai_model.is_empty()
	):
		return {"ok": false, "error": "AI settings are incomplete"}

	var endpoint := settings.ai_base_url.rstrip("/") + "/chat/completions"
	var headers := PackedStringArray(
		[
			"Authorization: Bearer %s" % settings.ai_api_key,
			"Content-Type: application/json",
		]
	)
	var payload := {
		"model": settings.ai_model,
		"response_format": {"type": "json_object"},
		"messages":
		(
			[
				{
					"role": "system",
					"content": "Return a JSON object for schema_name=%s." % schema_name,
				}
			]
			+ messages
		),
	}

	var response: Dictionary
	if _request_executor.is_valid():
		response = _request_executor.call(endpoint, headers, JSON.stringify(payload))
	else:
		response = await _execute_request(endpoint, headers, JSON.stringify(payload))
	var status := int(response.get("http_status", 0))
	if status < 200 or status >= 300:
		return {"ok": false, "error": "Provider returned HTTP %d" % status}

	var root = JSON.parse_string(str(response.get("body", "")))
	if typeof(root) != TYPE_DICTIONARY:
		return {"ok": false, "error": "Provider returned invalid JSON"}

	var choices = root.get("choices", [])
	if typeof(choices) != TYPE_ARRAY or choices.is_empty():
		return {"ok": false, "error": "Provider response is missing choices"}

	var content := str(choices[0].get("message", {}).get("content", ""))
	var structured = JSON.parse_string(content)
	if typeof(structured) != TYPE_DICTIONARY:
		return {"ok": false, "error": "Provider returned non-structured content"}

	return {"ok": true, "data": structured}


func _execute_request(url: String, headers: PackedStringArray, body: String) -> Dictionary:
	if _request_executor.is_valid():
		return await _request_executor.call(url, headers, body)

	var http := HTTPRequest.new()
	Engine.get_main_loop().root.add_child(http)
	var err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		return {"http_status": 0, "body": "", "error": "request_failed"}

	var result = await http.request_completed
	http.queue_free()

	return {
		"http_status": int(result[1]),
		"body": PackedByteArray(result[3]).get_string_from_utf8(),
	}
