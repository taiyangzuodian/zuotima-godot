class_name DocumentSource
extends RefCounted

const TYPE_SAMPLE := "sample"
const TYPE_LOCAL_FILE := "local_file"

var source_type := TYPE_SAMPLE
var display_name := ""
var file_path := ""
var language_hint := ""


func _init(
	p_source_type: String = TYPE_SAMPLE,
	p_display_name: String = "",
	p_file_path: String = "",
	p_language_hint: String = ""
) -> void:
	source_type = p_source_type
	display_name = p_display_name
	file_path = p_file_path
	language_hint = p_language_hint


static func sample(
	p_display_name: String, p_file_path: String, p_language_hint: String = ""
) -> DocumentSource:
	return new(TYPE_SAMPLE, p_display_name, p_file_path, p_language_hint)


static func local_file(
	p_display_name: String, p_file_path: String, p_language_hint: String = ""
) -> DocumentSource:
	return new(TYPE_LOCAL_FILE, p_display_name, p_file_path, p_language_hint)
