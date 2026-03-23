extends Node

const COMMANDS_SCRIPT := preload("res://tests/llm_talk_cursor/commands.gd")

signal waiting_changed(value: bool)
signal chat_cleared()
signal chat_line(role: String, text: String)
signal assistant_reply_reset()
signal assistant_reply_piece(piece: String)
signal assistant_reply_finished()
signal ui_set_chat_background_color(color: Color)
signal ui_set_window_title(title: String)
signal request_user_message(text: String)

const CONFIG_PATH := "res://tests/llm_talk_cursor/config.json"
const CHAT_ENDPOINT := "/chat/completions"
const GODOT_TOOL_ROUNDS_MAX := 8
const HTTP_CONNECT_DEADLINE_MS := 30000
const HTTP_HEADER_DEADLINE_MS := 120000
const HTTP_STREAM_IDLE_DEADLINE_MS := 180000

var _enable_godot_tools := true
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

var messages: Array[Dictionary] = [{"role": "system", "content": "You are a helpful assistant."}]

func submit_user_message(text: String) -> void:
	request_user_message.emit(text)

func _ready() -> void:
	request_user_message.connect(_on_request_user_message)
	_load_config()
	_commands = COMMANDS_SCRIPT.new(self)
	_apply_system_prompt_for_tools()
	call_deferred("_emit_initial_system_line")

func _emit_initial_system_line() -> void:
	var mode_text := "流式对话"
	if _enable_godot_tools:
		mode_text = "流式对话 + 工具调用循环"
	chat_line.emit("系统", "配置已加载。斜杠：/help。当前模式：" + mode_text + "。")

func _apply_system_prompt_for_tools() -> void:
	if messages.is_empty():
		return
	var m0: Variant = messages[0]
	if not (m0 is Dictionary):
		return
	if _enable_godot_tools:
		var hint := ""
		if _commands != null and _commands.has_method("build_system_prompt_hint"):
			hint = str(_commands.call("build_system_prompt_hint"))
		m0["content"] = "You are a helpful assistant. " + hint
	else:
		m0["content"] = "You are a helpful assistant."

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
	messages.append({"role": "user", "content": user_text})
	chat_line.emit("你", user_text)
	_debug_aigm("queued user message, messages=%d" % messages.size())
	_set_waiting(true)
	await _request_chat_agent_loop()
	_set_waiting(false)
	_debug_aigm("agent loop finished")

func _request_chat_agent_loop() -> void:
	var url_parts := _parse_http_base_url(base_url)
	if url_parts.is_empty():
		chat_line.emit("系统", "base_url 格式不正确（需要 http(s):// 开头）。")
		return
	for _i in range(GODOT_TOOL_ROUNDS_MAX):
		if _cancelled:
			_debug_aigm("agent loop cancelled before round %d" % _i)
			return
		_debug_aigm("agent loop round=%d start" % _i)
		var res := await _request_stream_completion(url_parts)
		if bool(res.get("cancelled", false)):
			_debug_aigm("round=%d cancelled in request" % _i)
			return
		if not bool(res.get("ok", false)):
			_debug_aigm("round=%d request failed error=%s" % [_i, str(res.get("error", "unknown"))])
			chat_line.emit("系统", "请求失败：" + str(res.get("error", "unknown")))
			return
		var content := str(res.get("content", ""))
		var tool_calls: Array = res.get("tool_calls", [])
		_debug_tool("round=%d merged_tool_calls=%d names=%s" % [_i, tool_calls.size(), _tool_call_names_for_debug(tool_calls)])
		var assistant_msg: Dictionary = {"role": "assistant", "content": content}
		if not tool_calls.is_empty():
			assistant_msg["tool_calls"] = tool_calls
		messages.append(assistant_msg)
		if tool_calls.is_empty():
			_debug_aigm("round=%d no tool calls; finalize" % _i)
			if content.strip_edges().is_empty():
				assistant_reply_reset.emit()
				assistant_reply_piece.emit("(空回复)")
				assistant_reply_finished.emit()
			return
		for tc in tool_calls:
			if tc is Dictionary:
				await _append_godot_tool_result(tc)
		_debug_aigm("round=%d executed tool_calls=%d" % [_i, tool_calls.size()])
	chat_line.emit("系统", "工具调用轮次过多，已中止。")
	_debug_aigm("agent loop exceeded max rounds")

func _request_stream_completion(url_parts: Dictionary) -> Dictionary:
	var payload := {"model": _chat_model, "messages": messages, "max_tokens": _max_tokens, "stream": true}
	if _enable_godot_tools:
		payload["tools"] = _build_godot_tool_definitions()
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer %s" % api_key, "Accept: text/event-stream"])
	var path: String = str(url_parts["path_prefix"]).trim_suffix("/") + CHAT_ENDPOINT
	_http = HTTPClient.new()
	var tls_opts: TLSOptions = null
	if bool(url_parts["tls"]):
		tls_opts = TLSOptions.client()
	var err := _http.connect_to_host(url_parts["host"], url_parts["port"], tls_opts)
	if err != OK:
		_debug_aigm("connect_to_host failed err=%d" % err)
		return {"ok": false, "error": "connect_%d" % err}
	var connect_deadline := Time.get_ticks_msec() + HTTP_CONNECT_DEADLINE_MS
	while _http.get_status() != HTTPClient.STATUS_CONNECTED:
		if _cancelled:
			_http.close()
			return {"ok": false, "cancelled": true}
		if _http_status_is_fatal(_http.get_status()) or Time.get_ticks_msec() > connect_deadline:
			_http.close()
			return {"ok": false, "error": "connect_timeout"}
		_http.poll()
		await get_tree().process_frame
	err = _http.request(HTTPClient.METHOD_POST, path, headers, JSON.stringify(payload))
	if err != OK:
		_http.close()
		_debug_aigm("http request failed err=%d" % err)
		return {"ok": false, "error": "request_%d" % err}
	var header_deadline := Time.get_ticks_msec() + HTTP_HEADER_DEADLINE_MS
	while _http.get_status() != HTTPClient.STATUS_BODY:
		if _cancelled:
			_http.close()
			return {"ok": false, "cancelled": true}
		if _http_status_is_fatal(_http.get_status()) or Time.get_ticks_msec() > header_deadline:
			_http.close()
			return {"ok": false, "error": "header_timeout"}
		_http.poll()
		await get_tree().process_frame
	return await _consume_stream_body()

func _consume_stream_body() -> Dictionary:
	var content := ""
	var did_emit_reset := false
	var buffer := ""
	var event_data := ""
	var done := false
	var idle_deadline := Time.get_ticks_msec() + HTTP_STREAM_IDLE_DEADLINE_MS
	var tool_call_map := {}
	while _http.get_status() != HTTPClient.STATUS_DISCONNECTED and not done:
		if _cancelled:
			_http.close()
			return {"ok": false, "cancelled": true}
		_http.poll()
		if _http.get_status() == HTTPClient.STATUS_BODY:
			var chunk := _http.read_response_body_chunk()
			if chunk.size() > 0:
				idle_deadline = Time.get_ticks_msec() + HTTP_STREAM_IDLE_DEADLINE_MS
				buffer += chunk.get_string_from_utf8()
				var parsed := _consume_sse_buffer(buffer, event_data, done, did_emit_reset, content, tool_call_map)
				buffer = str(parsed.get("buffer", buffer))
				event_data = str(parsed.get("event_data", event_data))
				done = bool(parsed.get("done", done))
				did_emit_reset = bool(parsed.get("did_emit_reset", did_emit_reset))
				content = str(parsed.get("content", content))
		if Time.get_ticks_msec() > idle_deadline:
			break
		await get_tree().process_frame
	if _http.get_status() != HTTPClient.STATUS_DISCONNECTED:
		_http.close()
	if not event_data.is_empty():
		var parsed_tail := _consume_sse_event(event_data, did_emit_reset, content, tool_call_map)
		did_emit_reset = bool(parsed_tail.get("did_emit_reset", did_emit_reset))
		content = str(parsed_tail.get("content", content))
	if did_emit_reset:
		assistant_reply_finished.emit()
	return {"ok": true, "content": content, "tool_calls": _tool_call_map_to_array(tool_call_map)}

func _consume_sse_buffer(buffer: String, event_data: String, done: bool, did_emit_reset: bool, content: String, tool_call_map: Dictionary) -> Dictionary:
	var b := buffer
	var e := event_data
	var d := done
	var reset := did_emit_reset
	var out := content
	while true:
		var nl := b.find("\n")
		if nl == -1:
			break
		var line := b.substr(0, nl).replace("\r", "")
		b = b.substr(nl + 1)
		if line.begins_with("data:"):
			var p := line.substr(5).strip_edges()
			if p == "[DONE]":
				if not e.is_empty():
					var parsed_before_done := _consume_sse_event(e, reset, out, tool_call_map)
					reset = bool(parsed_before_done.get("did_emit_reset", reset))
					out = str(parsed_before_done.get("content", out))
					e = ""
				d = true
				break
			if not e.is_empty():
				e += "\n"
			e += p
		elif line.is_empty():
			if not e.is_empty():
				var parsed := _consume_sse_event(e, reset, out, tool_call_map)
				reset = bool(parsed.get("did_emit_reset", reset))
				out = str(parsed.get("content", out))
				e = ""
		elif not e.is_empty():
			e += "\n" + line
	return {"buffer": b, "event_data": e, "done": d, "did_emit_reset": reset, "content": out}

func _consume_sse_event(data: String, did_emit_reset_ref: bool, content_ref: String, tool_call_map: Dictionary) -> Dictionary:
	var did_emit_reset := did_emit_reset_ref
	var content := content_ref
	var j := JSON.new()
	if j.parse(data) != OK:
		return {"did_emit_reset": did_emit_reset, "content": content}
	var obj: Variant = j.data
	if not (obj is Dictionary):
		return {"did_emit_reset": did_emit_reset, "content": content}
	var choices: Variant = obj.get("choices", [])
	if not (choices is Array) or (choices as Array).is_empty():
		return {"did_emit_reset": did_emit_reset, "content": content}
	var choice0: Variant = (choices as Array)[0]
	if not (choice0 is Dictionary):
		return {"did_emit_reset": did_emit_reset, "content": content}
	_debug_tool("sse_event keys=%s" % JSON.stringify((choice0 as Dictionary).keys()))
	var delta: Variant = choice0.get("delta", {})
	if not (delta is Dictionary):
		delta = {}
	var piece := str((delta as Dictionary).get("content", ""))
	if not piece.is_empty():
		if not did_emit_reset:
			assistant_reply_reset.emit()
			did_emit_reset = true
		content += piece
		assistant_reply_piece.emit(piece)
	var tool_calls: Variant = (delta as Dictionary).get("tool_calls", [])
	if tool_calls is Array:
		_debug_tool("delta.tool_calls count=%d" % (tool_calls as Array).size())
		for tc in tool_calls as Array:
			if tc is Dictionary:
				_debug_tool("delta.tool_call part=%s" % JSON.stringify(tc))
				_merge_tool_call_delta(tool_call_map, tc)
	# Some providers send tool calls outside delta in streamed chunks.
	var msg_v: Variant = choice0.get("message", {})
	if msg_v is Dictionary:
		var msg_d := msg_v as Dictionary
		var msg_tool_calls: Variant = msg_d.get("tool_calls", [])
		if msg_tool_calls is Array:
			_debug_tool("message.tool_calls count=%d" % (msg_tool_calls as Array).size())
			for tc2 in msg_tool_calls as Array:
				if tc2 is Dictionary:
					_debug_tool("message.tool_call=%s" % JSON.stringify(tc2))
					_merge_tool_call_snapshot(tool_call_map, tc2)
		var legacy_msg_fc: Variant = msg_d.get("function_call", {})
		if legacy_msg_fc is Dictionary:
			_merge_legacy_function_call(tool_call_map, legacy_msg_fc as Dictionary)
	var top_tool_calls: Variant = choice0.get("tool_calls", [])
	if top_tool_calls is Array:
		_debug_tool("choice.tool_calls count=%d" % (top_tool_calls as Array).size())
		for tc3 in top_tool_calls as Array:
			if tc3 is Dictionary:
				_debug_tool("choice.tool_call=%s" % JSON.stringify(tc3))
				_merge_tool_call_snapshot(tool_call_map, tc3)
	var legacy_fc: Variant = choice0.get("function_call", {})
	if legacy_fc is Dictionary:
		_debug_tool("choice.function_call=%s" % JSON.stringify(legacy_fc))
		_merge_legacy_function_call(tool_call_map, legacy_fc as Dictionary)
	_debug_tool("tool_map_now=%s" % _tool_call_map_debug(tool_call_map))
	return {"did_emit_reset": did_emit_reset, "content": content}

func _merge_tool_call_delta(tool_call_map: Dictionary, tc_part: Dictionary) -> void:
	var idx := _resolve_tool_call_delta_index(tool_call_map, tc_part)
	var merged: Dictionary = tool_call_map.get(idx, {"id": "", "type": "function", "function": {"name": "", "arguments": ""}})
	var part_id := str(tc_part.get("id", ""))
	if not part_id.is_empty():
		merged["id"] = part_id
	var pfn: Variant = tc_part.get("function", {})
	if pfn is Dictionary:
		var fnm: Dictionary = merged.get("function", {"name": "", "arguments": ""})
		var pfn_d := pfn as Dictionary
		var n := str(pfn_d.get("name", ""))
		if not n.is_empty():
			fnm["name"] = n
		var a := str(pfn_d.get("arguments", ""))
		if not a.is_empty():
			fnm["arguments"] = str(fnm.get("arguments", "")) + a
		merged["function"] = fnm
	tool_call_map[idx] = merged


func _merge_tool_call_snapshot(tool_call_map: Dictionary, tc_full: Dictionary) -> void:
	var fn_v0: Variant = tc_full.get("function", {})
	if not (fn_v0 is Dictionary):
		return
	var fn_d0 := fn_v0 as Dictionary
	var name0 := str(fn_d0.get("name", "")).strip_edges()
	var args0 := str(fn_d0.get("arguments", "")).strip_edges()
	if name0.is_empty() and args0.is_empty():
		return
	var idx: int
	if tc_full.has("index"):
		idx = int(tc_full.get("index", 0))
	else:
		idx = _next_tool_call_index(tool_call_map)
	var merged: Dictionary = tool_call_map.get(idx, {"id": "", "type": "function", "function": {"name": "", "arguments": ""}})
	var cid := str(tc_full.get("id", ""))
	if not cid.is_empty():
		merged["id"] = cid
	var ctype := str(tc_full.get("type", ""))
	if not ctype.is_empty():
		merged["type"] = ctype
	var fn_v: Variant = tc_full.get("function", {})
	if fn_v is Dictionary:
		var fn_d := fn_v as Dictionary
		var out_fn: Dictionary = merged.get("function", {"name": "", "arguments": ""})
		var n := str(fn_d.get("name", ""))
		if not n.is_empty():
			out_fn["name"] = n
		var a := str(fn_d.get("arguments", ""))
		if not a.is_empty():
			out_fn["arguments"] = a
		merged["function"] = out_fn
	tool_call_map[idx] = merged


func _merge_legacy_function_call(tool_call_map: Dictionary, fc: Dictionary) -> void:
	var n0 := str(fc.get("name", "")).strip_edges()
	var a0 := str(fc.get("arguments", "")).strip_edges()
	if n0.is_empty() and a0.is_empty():
		return
	var idx := _next_tool_call_index(tool_call_map)
	var merged: Dictionary = tool_call_map.get(idx, {"id": "", "type": "function", "function": {"name": "", "arguments": ""}})
	var out_fn: Dictionary = merged.get("function", {"name": "", "arguments": ""})
	var n := str(fc.get("name", ""))
	if not n.is_empty():
		out_fn["name"] = n
	var a := str(fc.get("arguments", ""))
	if not a.is_empty():
		out_fn["arguments"] = a
	merged["function"] = out_fn
	tool_call_map[idx] = merged


func _resolve_tool_call_delta_index(tool_call_map: Dictionary, tc_part: Dictionary) -> int:
	if tc_part.has("index"):
		return int(tc_part.get("index", 0))
	var part_id := str(tc_part.get("id", "")).strip_edges()
	if not part_id.is_empty():
		for k in tool_call_map.keys():
			var existing: Variant = tool_call_map.get(k, {})
			if existing is Dictionary and str((existing as Dictionary).get("id", "")) == part_id:
				return int(k)
	var pfn: Variant = tc_part.get("function", {})
	if pfn is Dictionary:
		var pfn_d := pfn as Dictionary
		var n := str(pfn_d.get("name", "")).strip_edges()
		var a := str(pfn_d.get("arguments", ""))
		# If this chunk only carries argument continuation, append to latest call.
		if n.is_empty() and not a.is_empty() and not tool_call_map.is_empty():
			var keys := tool_call_map.keys()
			keys.sort()
			return int(keys[keys.size() - 1])
	return _next_tool_call_index(tool_call_map)


func _next_tool_call_index(tool_call_map: Dictionary) -> int:
	if tool_call_map.is_empty():
		return 0
	var keys := tool_call_map.keys()
	keys.sort()
	return int(keys[keys.size() - 1]) + 1

func _tool_call_map_to_array(tool_call_map: Dictionary) -> Array:
	var keys := tool_call_map.keys()
	keys.sort()
	var out: Array = []
	for k in keys:
		var call: Dictionary = tool_call_map[k]
		if str(call.get("id", "")).is_empty():
			call["id"] = "tool_call_%s" % str(k)
		out.append(call)
	return out

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
	messages.append({"role": "tool", "tool_call_id": call_id, "content": result})
	chat_line.emit("工具", "结果: " + result)
	_debug_aigm("tool done id=%s name=%s result=%s" % [call_id, fn_name, result])

func _build_godot_tool_definitions() -> Array:
	if _commands != null and _commands.has_method("build_tool_definition"):
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
			messages = [{"role": "system", "content": "You are a helpful assistant."}]
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

func _parse_http_base_url(url: String) -> Dictionary:
	var u := url.strip_edges()
	var use_tls := false
	if u.begins_with("https://"):
		use_tls = true
		u = u.substr(8)
	elif u.begins_with("http://"):
		u = u.substr(7)
	else:
		return {}
	var slash := u.find("/")
	var host_part := u if slash == -1 else u.substr(0, slash)
	var path_prefix := "" if slash == -1 else u.substr(slash)
	var host := host_part
	var port := 443 if use_tls else 80
	if ":" in host_part:
		var hp := host_part.split(":")
		host = hp[0]
		port = int(hp[1])
	return {"host": host, "port": port, "tls": use_tls, "path_prefix": path_prefix}

func _http_status_is_fatal(st: int) -> bool:
	return st == HTTPClient.STATUS_CANT_RESOLVE or st == HTTPClient.STATUS_CANT_CONNECT or st == HTTPClient.STATUS_CONNECTION_ERROR or st == HTTPClient.STATUS_TLS_HANDSHAKE_ERROR

func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		chat_line.emit("系统", "未找到配置文件：%s" % CONFIG_PATH)
		return
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		chat_line.emit("系统", "配置文件打开失败：%s" % CONFIG_PATH)
		return
	var raw := f.get_as_text()
	f.close()
	var j := JSON.new()
	if j.parse(raw) != OK:
		chat_line.emit("系统", "配置文件 JSON 格式错误。")
		return
	var d: Variant = j.data
	if not (d is Dictionary):
		return
	base_url = str(d.get("base_url", "")).strip_edges()
	api_key = str(d.get("api_key", "")).strip_edges()
	if d.has("model"):
		_chat_model = str(d.get("model", _chat_model)).strip_edges()
	if d.has("max_tokens"):
		_max_tokens = int(d.get("max_tokens", _max_tokens))
	if d.has("enable_godot_tools"):
		_enable_godot_tools = bool(d.get("enable_godot_tools"))
	if d.has("debug_tool_trace"):
		_debug_tool_trace = bool(d.get("debug_tool_trace"))
	if d.has("debug_aigm_trace"):
		_debug_aigm_trace = bool(d.get("debug_aigm_trace"))
	if _debug_tool_trace:
		_debug_aigm_trace = true


func _debug_tool(msg: String) -> void:
	if not _debug_tool_trace:
		return
	print("[AIGM_TOOL_DEBUG] " + msg)


func _debug_aigm(msg: String) -> void:
	if not _debug_aigm_trace:
		return
	print("[AIGM_DEBUG] " + msg)


func _tool_call_map_debug(tool_call_map: Dictionary) -> String:
	var keys := tool_call_map.keys()
	keys.sort()
	var parts: Array[String] = []
	for k in keys:
		var call: Variant = tool_call_map.get(k, {})
		if not (call is Dictionary):
			continue
		var fn: Variant = (call as Dictionary).get("function", {})
		var fn_name := ""
		if fn is Dictionary:
			fn_name = str((fn as Dictionary).get("name", ""))
		parts.append("%s:%s" % [str(k), fn_name])
	return "[" + ", ".join(parts) + "]"


func _tool_call_names_for_debug(tool_calls: Array) -> String:
	var out: Array[String] = []
	for tc in tool_calls:
		if tc is Dictionary:
			var fn: Variant = (tc as Dictionary).get("function", {})
			if fn is Dictionary:
				out.append(str((fn as Dictionary).get("name", "")))
	return "[" + ", ".join(out) + "]"


