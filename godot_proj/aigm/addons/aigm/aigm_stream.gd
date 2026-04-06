extends Node

## UI signals + config + tool dispatch; HTTP in `aigm_http_transport.gd`; agent in `lua/api.lua`.

const COMMANDS_SCRIPT := preload("res://addons/aigm/commands.gd")
const AigmLuaHost := preload("res://addons/aigm/aigm_lua_host.gd")
const AigmHttpTransport := preload("res://addons/aigm/aigm_http_transport.gd")
const AigmConfig: Script = preload("res://addons/aigm/aigm_config.gd")
const CONFIG_PATH := "res://addons/aigm/config.json"

signal waiting_changed(value: bool)
signal chat_cleared()
signal chat_line(role: String, text: String)
signal assistant_reply_reset()
signal assistant_reply_piece(piece: String)
signal assistant_reply_finished()
signal ui_set_chat_background_color(color: Color)
signal ui_set_window_title(title: String)
signal request_user_message(text: String)

const SYSTEM_PROMPT_BASE := "You are a helpful assistant."

var _enable_tools := true
var _chat_model := "kimi-k2-turbo-preview"
var _max_tokens := 8192
var _debug_tool_trace := false
var _debug_aigm_trace := false
var base_url := ""
var api_key := ""
var waiting_response := false
var _cancelled := false
var _http: HTTPClient
var _commands: RefCounted
var _lua_core: AigmLuaHost


var messages: Array[Dictionary]:
	get:
		if _lua_core == null or not _lua_core.available:
			return []
		var mj := _lua_core.messages_json()
		var j := JSON.new()
		if j.parse(mj) != OK:
			return []
		var data: Variant = j.data
		return data as Array if data is Array else []


func submit_user_message(text: String) -> void:
	request_user_message.emit(text)


func aigm_bind_http(c: HTTPClient) -> void:
	_http = c


func aigm_is_cancelled() -> bool:
	return _cancelled


func _ready() -> void:
	request_user_message.connect(_on_request_user_message)
	_lua_core = AigmLuaHost.new()
	if not _lua_core.available:
		chat_line.emit("系统", "Lua 核心未加载：需要 lua-gdextension 与 addons/aigm/lua/。")
	_commands = COMMANDS_SCRIPT.new(self)
	_load_config()
	_apply_system_prompt_for_tools()
	call_deferred("_emit_initial_system_line")


func _emit_initial_system_line() -> void:
	var mode_text := "流式对话"
	if _enable_tools:
		mode_text = "流式对话 + 工具调用循环"
	chat_line.emit("系统", "配置已加载。斜杠：/help。当前模式：" + mode_text + "。")


func _apply_system_prompt_for_tools() -> void:
	if _lua_core == null or not _lua_core.available:
		return
	var content := SYSTEM_PROMPT_BASE
	if _enable_tools and _commands != null and _commands.has_method("build_system_prompt_hint"):
		var hint := str(_commands.call("build_system_prompt_hint"))
		if not hint.is_empty():
			content = SYSTEM_PROMPT_BASE + " " + hint
	_lua_core.set_system_prompt(content)


func _on_request_user_message(text: String) -> void:
	if waiting_response:
		return
	_cancelled = false
	_debug_aigm("received user message len=%d" % text.length())
	await _send_user_message(text)


func cancel_current_request() -> void:
	_cancelled = true
	_debug_aigm("cancel_current_request called")
	if _http != null:
		_http.close()
	if waiting_response:
		_set_waiting(false)


func _send_user_message(user_text_in: String) -> void:
	var user_text := user_text_in.strip_edges()
	if user_text.is_empty():
		return
	if user_text.begins_with("/"):
		_handle_slash_command(user_text)
		return
	if base_url.is_empty() or api_key.is_empty():
		chat_line.emit("系统", "配置缺失：请检查 config.json 的 base_url 和 api_key。")
		return
	if _lua_core == null or not _lua_core.available:
		chat_line.emit("系统", "Lua 核心未就绪。")
		return
	_lua_core.append_user(user_text)
	chat_line.emit("你", user_text)
	_debug_aigm("queued user message")
	_set_waiting(true)
	await _request_chat_agent_loop()
	_set_waiting(false)
	_debug_aigm("agent loop finished")


func _request_chat_agent_loop() -> void:
	var round_i := 0
	while true:
		if _cancelled:
			_debug_aigm("agent loop cancelled before round %d" % round_i)
			return
		_debug_aigm("agent loop round=%d start" % round_i)
		var tools_json := "[]"
		if _enable_tools:
			tools_json = JSON.stringify(_build_godot_tool_definitions())
		var prep_raw := _lua_core.prepare_chat_http_json(
			base_url, _chat_model, _max_tokens, true, tools_json, api_key
		)
		var pj := JSON.new()
		if pj.parse(prep_raw) != OK:
			chat_line.emit("系统", "准备请求失败（JSON）。")
			return
		var prep: Variant = pj.data
		if not (prep is Dictionary) or not bool((prep as Dictionary).get("ok", false)):
			var err := ""
			if prep is Dictionary:
				err = str((prep as Dictionary).get("error", "unknown"))
			if err == "tool_rounds_exceeded":
				chat_line.emit("系统", "工具调用轮次过多，已中止。")
			elif err == "bad_base_url":
				chat_line.emit("系统", "base_url 格式不正确（需要 http(s):// 开头）。")
			else:
				chat_line.emit("系统", "准备请求失败：" + err)
			_debug_aigm("prepare failed error=%s" % err)
			return
		var transport := AigmHttpTransport.new(self, _lua_core)
		var res: Dictionary = await transport.request_stream_completion(prep as Dictionary)
		if bool(res.get("cancelled", false)):
			_debug_aigm("round=%d cancelled in request" % round_i)
			return
		if not bool(res.get("ok", false)):
			_debug_aigm("round=%d request failed error=%s" % [round_i, str(res.get("error", "unknown"))])
			chat_line.emit("系统", "请求失败：" + str(res.get("error", "unknown")))
			return
		var commit_raw := _lua_core.commit_assistant_after_stream_json()
		var cj := JSON.new()
		if cj.parse(commit_raw) != OK:
			chat_line.emit("系统", "提交助手消息失败。")
			return
		var commit: Variant = cj.data
		if not (commit is Dictionary) or not bool((commit as Dictionary).get("ok", false)):
			chat_line.emit("系统", "提交助手消息失败。")
			return
		var content := str((commit as Dictionary).get("content", ""))
		var tool_calls: Array = []
		var tcv: Variant = (commit as Dictionary).get("tool_calls", [])
		if tcv is Array:
			tool_calls = tcv as Array
		var continue_loop := bool((commit as Dictionary).get("continue", false))
		_debug_tool(
			"round=%d merged_tool_calls=%d names=%s" % [round_i, tool_calls.size(), _format_tool_names(tool_calls)]
		)
		if not continue_loop:
			_debug_aigm("round=%d no more tool rounds" % round_i)
			if content.strip_edges().is_empty():
				assistant_reply_reset.emit()
				assistant_reply_piece.emit("(空回复)")
				assistant_reply_finished.emit()
			return
		for tc in tool_calls:
			if tc is Dictionary:
				await _append_godot_tool_result(tc as Dictionary)
		_debug_aigm("round=%d executed tool_calls=%d" % [round_i, tool_calls.size()])
		round_i += 1


func _format_tool_names(tool_calls: Array) -> String:
	var names: Array[String] = []
	for tc in tool_calls:
		if tc is Dictionary:
			var fn: Variant = (tc as Dictionary).get("function", {})
			if fn is Dictionary:
				names.append(str((fn as Dictionary).get("name", "")))
	return "[" + ", ".join(names) + "]"


func _append_godot_tool_result(tool_call: Dictionary) -> void:
	var call_id := str(tool_call.get("id", ""))
	var fn: Variant = tool_call.get("function", {})
	if not (fn is Dictionary):
		return
	var fn_d := fn as Dictionary
	var fn_name := str(fn_d.get("name", ""))
	if fn_name.strip_edges().is_empty():
		return
	var arg_str := str(fn_d.get("arguments", "{}"))
	chat_line.emit("工具", "调用: %s(%s)" % [fn_name, arg_str])
	_debug_aigm("tool start id=%s name=%s args=%s" % [call_id, fn_name, arg_str])
	var j := JSON.new()
	var args: Dictionary = {}
	if j.parse(arg_str) == OK and j.data is Dictionary:
		args = j.data
	var result := await _execute_godot_tool_async(fn_name, args)
	_lua_core.append_tool_result(call_id, result)
	chat_line.emit("工具", "结果: " + result)
	_debug_aigm("tool done id=%s name=%s result=%s" % [call_id, fn_name, result])


func _build_godot_tool_definitions() -> Array:
	if _commands == null:
		return []
	if _commands.has_method("build_tool_definitions"):
		return _commands.call("build_tool_definitions")
	if _commands.has_method("build_tool_definition"):
		return [_commands.call("build_tool_definition")]
	return []


func _execute_godot_tool_async(tool_name: String, args: Dictionary) -> String:
	if _commands == null:
		return "Error: commands not initialized"
	if _commands.has_method("execute_tool_async"):
		return str(await _commands.call("execute_tool_async", tool_name, args))
	if _commands.has_method("execute_tool"):
		return str(_commands.call("execute_tool", tool_name, args))
	return "Error: commands execute_tool missing"


func _handle_slash_command(line: String) -> void:
	var body := line.substr(1).strip_edges()
	match body:
		"help":
			chat_line.emit("系统", "/help /clear /reload")
		"clear":
			if _lua_core != null and _lua_core.available:
				_lua_core.reset_session()
			_apply_system_prompt_for_tools()
			chat_cleared.emit()
			chat_line.emit("系统", "对话已清空。")
		"reload":
			_load_config()
			_apply_system_prompt_for_tools()
			chat_line.emit("系统", "配置已重新加载。")
		_:
			chat_line.emit("系统", "未知命令。输入 /help")


func _set_waiting(v: bool) -> void:
	waiting_response = v
	waiting_changed.emit(v)
	_debug_aigm("waiting=%s" % str(v))


func _load_config() -> void:
	var cfg: Dictionary = AigmConfig.load_settings(CONFIG_PATH)
	var err: String = str(cfg.get("load_error", ""))
	if not err.is_empty():
		match err:
			"missing":
				chat_line.emit("系统", "未找到配置文件：%s" % CONFIG_PATH)
			"open_failed":
				chat_line.emit("系统", "配置文件打开失败：%s" % CONFIG_PATH)
			"json_parse":
				chat_line.emit("系统", "配置文件 JSON 格式错误。")
			_:
				pass
		return
	base_url = str(cfg.get("base_url", ""))
	api_key = str(cfg.get("api_key", ""))
	_chat_model = str(cfg.get("chat_model", _chat_model))
	_max_tokens = int(cfg.get("max_tokens", _max_tokens))
	_enable_tools = bool(cfg.get("enable_tools", true))
	_debug_tool_trace = bool(cfg.get("debug_tool_trace", false))
	_debug_aigm_trace = bool(cfg.get("debug_aigm_trace", false))
	if _commands != null:
		if _commands.has_method("set_tools_enabled"):
			_commands.call("set_tools_enabled", _enable_tools)
		elif _commands.has_method("set_lua_tool_enabled"):
			_commands.call("set_lua_tool_enabled", _enable_tools)


func _debug_tool(msg: String) -> void:
	if not _debug_tool_trace:
		return
	print("[AIGM_TOOL_DEBUG] " + msg)


func _debug_aigm(msg: String) -> void:
	if not _debug_aigm_trace:
		return
	print("[AIGM_DEBUG] " + msg)
