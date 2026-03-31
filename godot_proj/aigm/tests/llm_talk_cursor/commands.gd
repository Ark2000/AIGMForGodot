extends RefCounted

const TOOL_NAME := "godot_eval_expression"
const MAX_DELAY_SECONDS := 300.0
const METHOD_SPECS := [
	{"signature": "expr_get_engine_version()", "description": "Return Engine version info JSON string."},
	{"signature": "expr_get_os_name()", "description": "Return OS name string."},
	{"signature": "expr_print(\"text\")", "description": "Print text to Godot Output and return ok."},
	{"signature": "expr_set_window_title(\"title\")", "description": "Set chat window title."},
	{
		"signature": "expr_set_chat_background_color(\"#RRGGBB\" or \"#RRGGBBAA\")",
		"description": "Set chat background color.",
	},
	{
		"signature": "expr_npc_talk(\"text\")",
		"description": "Speech bubble on the character the spectator camera is following; empty string hides it.",
	},
]

var _owner_wr: WeakRef


func _init(owner: Node) -> void:
	_owner_wr = weakref(owner)


func build_system_prompt_hint() -> String:
	return (
		"For Godot/engine/UI operations, call tool %s with one expression string. "
		+ "Optional delay_seconds defers evaluation on the scene tree (max %.0fs). "
		+ "Available expression methods are documented in the tool description. "
		+ "Use double-quoted strings. Do not call unknown methods."
	) % [TOOL_NAME, MAX_DELAY_SECONDS]


func build_tool_definition() -> Dictionary:
	return {
		"type": "function",
		"function": {
			"name": TOOL_NAME,
			"description": (
				"Execute one Godot Expression in sandbox. "
				+ "Optional delay_seconds waits on the scene tree before parse/execute (0–%.0f). "
				+ "Allowed methods: %s"
			) % [MAX_DELAY_SECONDS, _method_doc_list()],
			"parameters": {
				"type": "object",
				"properties": {
					"expression": {"type": "string"},
					"delay_seconds": {
						"type": "number",
						"description": (
							"Wait this many seconds before evaluating the expression. "
							+ "Omit or 0 for immediate. Fractional seconds allowed. Max %.0f."
						) % MAX_DELAY_SECONDS,
					},
				},
				"required": ["expression"]
			}
		}
	}


func execute_tool(tool_name: String, args: Dictionary) -> String:
	return await execute_tool_async(tool_name, args)


func execute_tool_async(tool_name: String, args: Dictionary) -> String:
	if tool_name != TOOL_NAME:
		return "Error: unknown tool " + tool_name
	var delay_s := 0.0
	if args.has("delay_seconds"):
		delay_s = float(args["delay_seconds"])
	if delay_s < 0:
		return "Error: delay_seconds must be >= 0"
	if delay_s > MAX_DELAY_SECONDS:
		return "Error: delay_seconds must be <= %.0f" % MAX_DELAY_SECONDS
	if delay_s > 0.0:
		var owner_for_timer := _owner()
		if owner_for_timer == null:
			return "Error: owner unavailable (cannot delay)"
		await owner_for_timer.get_tree().create_timer(delay_s).timeout
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


func expr_npc_talk(message: String) -> String:
	var owner := _owner()
	if owner == null:
		return "Error: owner unavailable"
	if not owner.is_inside_tree():
		return "Error: owner not in tree"
	var cam: Node = owner.get_tree().get_first_node_in_group("spectator_camera")
	if cam == null:
		return "Error: spectator_camera group empty (run testsandbox world with SpectatorCamera)"
	if not cam.has_method("get_current_follow_target"):
		return "Error: camera missing get_current_follow_target"
	var walker: Variant = cam.call("get_current_follow_target")
	if walker == null:
		return "Error: no camera follow target (FREE mode or no trackable characters)"
	if not walker.has_method("talk"):
		return "Error: follow target has no talk()"
	walker.call("talk", str(message))
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
