extends RefCounted

const TOOL_NAME := "godot_eval_expression"
const METHOD_SPECS := [
	{"signature": "expr_get_engine_version()", "description": "Return Engine version info JSON string."},
	{"signature": "expr_get_os_name()", "description": "Return OS name string."},
	{"signature": "expr_print(\"text\")", "description": "Print text to Godot Output and return ok."},
	{"signature": "expr_set_window_title(\"title\")", "description": "Set chat window title."},
	{
		"signature": "expr_set_chat_background_color(\"#RRGGBB\" or \"#RRGGBBAA\")",
		"description": "Set chat background color.",
	},
]

var _owner_wr: WeakRef


func _init(owner: Node) -> void:
	_owner_wr = weakref(owner)


func build_system_prompt_hint() -> String:
	return (
		"For Godot/engine/UI operations, call tool %s with one expression string. "
		+ "Available expression methods are documented in the tool description. "
		+ "Use double-quoted strings. Do not call unknown methods."
	) % TOOL_NAME


func build_tool_definition() -> Dictionary:
	return {
		"type": "function",
		"function": {
			"name": TOOL_NAME,
			"description": (
				"Execute one Godot Expression in sandbox. "
				+ "Allowed methods: %s"
			) % _method_doc_list(),
			"parameters": {
				"type": "object",
				"properties": {"expression": {"type": "string"}},
				"required": ["expression"]
			}
		}
	}


func execute_tool(tool_name: String, args: Dictionary) -> String:
	return await execute_tool_async(tool_name, args)


func execute_tool_async(tool_name: String, args: Dictionary) -> String:
	if tool_name != TOOL_NAME:
		return "Error: unknown tool " + tool_name
	var expr_s := str(args.get("expression", "")).strip_edges()
	if expr_s.is_empty():
		return "Error: empty expression"
	var expr := Expression.new()
	if expr.parse(expr_s, PackedStringArray()) != OK:
		return "Error: parse: " + expr.get_error_text()
	var result: Variant = expr.execute([], self, true)
	if expr.has_execute_failed():
		return "Error: execute: " + expr.get_error_text()
	return "ok" if result == null else str(result)


func expr_get_engine_version() -> String:
	return JSON.stringify(Engine.get_version_info())


func expr_get_os_name() -> String:
	return OS.get_name()


func expr_print(message: String) -> String:
	print(str(message))
	return "ok"


func expr_set_window_title(title: String) -> String:
	var owner := _owner()
	if owner == null:
		return "Error: owner unavailable"
	owner.ui_set_window_title.emit(str(title))
	return "ok"


func expr_set_chat_background_color(color_hex: String) -> String:
	var owner := _owner()
	if owner == null:
		return "Error: owner unavailable"
	var parsed: Variant = _parse_color_hex_string(color_hex)
	if parsed is String:
		return parsed
	owner.ui_set_chat_background_color.emit(parsed as Color)
	return "ok"


func _owner() -> Node:
	return _owner_wr.get_ref()


func _method_doc_list() -> String:
	var arr: Array[String] = []
	for spec in METHOD_SPECS:
		var sig := str(spec.get("signature", ""))
		var desc := str(spec.get("description", ""))
		arr.append("%s - %s" % [sig, desc])
	return ", ".join(arr)


func _parse_color_hex_string(s: String) -> Variant:
	var h := s.strip_edges()
	if h.begins_with("#"):
		h = h.substr(1)
	if h.length() != 6 and h.length() != 8:
		return "Error: color must be #RRGGBB or #RRGGBBAA"
	if not h.is_valid_hex_number(false):
		return "Error: invalid hex color"
	var r := h.substr(0, 2).hex_to_int()
	var g := h.substr(2, 2).hex_to_int()
	var b := h.substr(4, 2).hex_to_int()
	var a := 255
	if h.length() == 8:
		a = h.substr(6, 2).hex_to_int()
	return Color8(r, g, b, a)
