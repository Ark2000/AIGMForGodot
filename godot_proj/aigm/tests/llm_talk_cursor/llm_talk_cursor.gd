extends Control

## Godot 4.2+ 支持 #region / #endregion：脚本编辑器里可折叠；minimap 上是否像 VS 那样高亮分区因版本而异（见 godot-proposals）。
#region 常量与成员
const CONFIG_PATH := "res://tests/llm_talk_cursor/config.json"
const CHAT_ENDPOINT := "/chat/completions"

## 聊天区角色颜色（BBCode hex）
const CHAT_TS_COLOR := "#64748b"
const ROLE_COLORS := {"系统": "#94a3b8", "你": "#38bdf8", "AI": "#c4b5fd", "工具": "#86efac"}

## 控制台详细日志：DEBUG 会产生较多输出；发 issue 时可整段复制 Output 面板
const LOG_DEBUG_ENABLED := true
## chat_io 单行过长时截断，避免把 Output 撑爆
const CHAT_IO_LOG_MAX_CHARS := 16384
## 工具返回展示在聊天区时的上限（避免 JSON 过长撑爆界面）
const TOOL_RESULT_CHAT_MAX_CHARS := 6000
## 为 true 时 /run 会执行本机 shell（仅本地调试用，有安全风险）
const SLASH_SHELL_ENABLED := false
## 为 true 时走「工具调用」流程（非流式轮询），模型可调用下方注册的 Godot 函数
var _enable_godot_tools := true
const GODOT_TOOL_ROUNDS_MAX := 8
## 非流式 JSON：服务端排队 + 首 token 慢时，HTTP 可能长时间停留在 REQUESTING（未进入 BODY）
const HTTP_JSON_HEADER_WAIT_MS := 600000
const HTTP_JSON_BODY_READ_MS := 600000
const HTTP_JSON_PROGRESS_LOG_MS := 5000
const HTTP_JSON_CLOSE_POLL_MS := 8000

enum LogLevel { DEBUG, INFO, WARN, ERROR }

@onready var _background_rect: ColorRect = $ColorRect
@onready var chat_log: RichTextLabel = $MarginContainer/VBoxContainer/ChatLog
@onready var input_edit: LineEdit = $MarginContainer/VBoxContainer/InputRow/InputEdit
@onready var send_button: Button = $MarginContainer/VBoxContainer/InputRow/SendButton

var base_url := ""
var api_key := ""
var waiting_response := false
var messages: Array[Dictionary] = [
	{
		"role": "system",
		"content": "You are a helpful assistant."
	}
]

var _http: HTTPClient
var _stream_line_buf := ""
var _assistant_reply := ""
var _log_base_before_ai := ""
var _ai_prefix_bbcode := ""
## RichTextLabel 用 append_text 追加的内容读回 chat_log.text 可能不完整；与 text= 混用会丢行。此处存完整 BBCode 正文。
var _chat_richtext := ""

## 打字机：界面显示长度追赶 SSE 累积的完整文本（按字符逐步露出）
var _typewriter_display_len := 0
var _typewriter_accum := 0.0
const TYPEWRITER_CPS_BASE := 38.0
const TYPEWRITER_CPS_MAX := 220.0

var _sse_chunk_index := 0
var _chat_model := "kimi-k2-turbo-preview"
var _max_tokens := 8192
## Expression 沙箱（仅暴露 expr_*，避免把整棵 Control 交给 Expression）
var _tool_expr_sandbox: RefCounted

#endregion

#region 生命周期
func _ready() -> void:
	set_process(false)
	send_button.pressed.connect(_on_send_pressed)
	input_edit.text_submitted.connect(_on_input_submitted)

	var vi := Engine.get_version_info()
	_log(LogLevel.INFO, "lifecycle", "llm_talk_cursor 场景就绪 (Godot %s.%s.%s)" % [vi.get("major", "?"), vi.get("minor", "?"), vi.get("patch", "?")])
	_load_config()
	_tool_expr_sandbox = ToolExprSandbox.new(self)
	if _enable_godot_tools and messages.size() > 0:
		var m0: Variant = messages[0]
		if m0 is Dictionary and str(m0.get("role", "")) == "system":
			m0["content"] = (
				"You are a helpful assistant. For engine/OS facts or changing this chat UI, call tool godot_eval_expression "
				+ "with a single Godot Expression string (not full GDScript). "
				+ "Use only these sandbox methods on the expression instance: "
				+ "expr_get_engine_version(), expr_get_os_name(), expr_print(\"text\"), "
				+ "expr_set_window_title(\"title\"), expr_set_chat_background_color(\"#RRGGBB\" or \"#RRGGBBAA\"). "
				+ "Use double quotes for strings. You may combine with operators and built-in math functions (sin, cos, etc.)."
			)
	_append_log(
		"系统",
		"配置已加载。斜杠：/help。"
		+ (" 已启用 Godot 本地工具调用（非流式轮询）。" if _enable_godot_tools else " 流式对话。")
	)
	_refocus_input_edit()

#endregion

#region 日志与控制台
func _log(level: LogLevel, category: String, message: String) -> void:
	if level == LogLevel.DEBUG and not LOG_DEBUG_ENABLED:
		return
	var level_name: String
	match level:
		LogLevel.DEBUG:
			level_name = "DEBUG"
		LogLevel.INFO:
			level_name = "INFO"
		LogLevel.WARN:
			level_name = "WARN"
		LogLevel.ERROR:
			level_name = "ERROR"
	var ts_ms := Time.get_ticks_msec()
	var line := "[%d][%s][%s] %s" % [ts_ms, level_name, category, message]
	match level:
		LogLevel.ERROR:
			push_error(line)
		LogLevel.WARN:
			push_warning(line)
		_:
			print(line)


func _log_chat_io(tag: String, body: String) -> void:
	var shown := body
	if shown.length() > CHAT_IO_LOG_MAX_CHARS:
		shown = shown.substr(0, CHAT_IO_LOG_MAX_CHARS) + " ...[truncated total_len=%d]" % body.length()
	_log(LogLevel.INFO, "chat_io", "%s (len=%d): %s" % [tag, body.length(), shown])


func _log_long_to_category(level: LogLevel, category: String, prefix: String, body: String) -> void:
	if body.is_empty():
		return
	var max_chunk := CHAT_IO_LOG_MAX_CHARS
	if body.length() <= max_chunk:
		_log(level, category, "%s%s" % [prefix, body])
		return
	var start: int = 0
	var part: int = 1
	var total_parts: int = int(ceil(float(body.length()) / float(max_chunk)))
	if total_parts < 1:
		total_parts = 1
	while start < body.length():
		var chunk_end: int = start + max_chunk
		if chunk_end > body.length():
			chunk_end = body.length()
		_log(level, category, "%s[part %d/%d]\n%s" % [prefix, part, total_parts, body.substr(start, chunk_end - start)])
		start = chunk_end
		part += 1


func _log_chat_richtext_snapshot(reason: String) -> void:
	var full := _chat_richtext
	_log(LogLevel.INFO, "chat_mirror", "---- snapshot %s bbcode_len=%d ----" % [reason, full.length()])
	_log_long_to_category(LogLevel.INFO, "chat_mirror", "", full)


func _chat_time_str() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "[%02d:%02d:%02d]" % [int(d.hour), int(d.minute), int(d.second)]


func _escape_bbcode(s: String) -> String:
	return s.replace("[", "[lb]").replace("]", "[rb]")


func _format_role_prefix(role: String) -> String:
	var rc: String = str(ROLE_COLORS.get(role, "#e2e8f0"))
	return "[color=%s]%s[/color] [color=%s]%s[/color]: " % [CHAT_TS_COLOR, _chat_time_str(), rc, role]


func _log_secret_hint(label: String, value: String) -> void:
	if value.is_empty():
		_log(LogLevel.INFO, "config", "%s: (empty)" % label)
	else:
		_log(LogLevel.INFO, "config", "%s: len=%d prefix=%s..." % [label, value.length(), value.substr(0, min(4, value.length()))])

#endregion

#region HTTPClient 状态名
func _http_status_label(st: int) -> String:
	match st:
		HTTPClient.STATUS_DISCONNECTED:
			return "DISCONNECTED"
		HTTPClient.STATUS_RESOLVING:
			return "RESOLVING"
		HTTPClient.STATUS_CANT_RESOLVE:
			return "CANT_RESOLVE"
		HTTPClient.STATUS_CONNECTING:
			return "CONNECTING"
		HTTPClient.STATUS_CANT_CONNECT:
			return "CANT_CONNECT"
		HTTPClient.STATUS_CONNECTED:
			return "CONNECTED"
		HTTPClient.STATUS_REQUESTING:
			return "REQUESTING"
		HTTPClient.STATUS_BODY:
			return "BODY"
		HTTPClient.STATUS_CONNECTION_ERROR:
			return "CONNECTION_ERROR"
		HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			return "TLS_HANDSHAKE_ERROR"
		_:
			return "UNKNOWN(%d)" % st

#endregion

#region 帧循环与输入
func _process(delta: float) -> void:
	var target_len: int = _assistant_reply.length()
	if _typewriter_display_len >= target_len:
		return
	# 落后越多略加快，避免一大段 SSE 结束后要等很久才追上
	var behind: int = target_len - _typewriter_display_len
	var speed: float = TYPEWRITER_CPS_BASE + minf(behind * 1.8, TYPEWRITER_CPS_MAX - TYPEWRITER_CPS_BASE)
	_typewriter_accum += delta * speed
	while _typewriter_accum >= 1.0 and _typewriter_display_len < target_len:
		_typewriter_accum -= 1.0
		_typewriter_display_len += 1
	_refresh_ai_line()


func _on_send_pressed() -> void:
	await _send_user_message()


func _on_input_submitted(_text: String) -> void:
	await _send_user_message()


func _send_user_message() -> void:
	if waiting_response:
		_log(LogLevel.DEBUG, "send", "ignored: already waiting_response")
		return

	var user_text := input_edit.text.strip_edges()
	if user_text.is_empty():
		_log(LogLevel.DEBUG, "send", "ignored: empty input")
		return

	if user_text.begins_with("/"):
		input_edit.clear()
		_handle_slash_command(user_text)
		return

	if base_url.is_empty() or api_key.is_empty():
		_log(LogLevel.ERROR, "config", "base_url or api_key missing (base_url empty=%s api_key empty=%s)" % [base_url.is_empty(), api_key.is_empty()])
		_append_log("系统", "配置缺失：请检查 config.json 里的 base_url 和 api_key。")
		_refocus_input_edit()
		return

	_log_chat_io("user_input", user_text)
	_append_log("你", user_text)
	messages.append({"role": "user", "content": user_text})
	input_edit.clear()
	await _request_chat_stream_async()

#endregion

#region 斜杠命令
func _handle_slash_command(line: String) -> void:
	_log_chat_io("slash_command", line)
	_append_log("你", line)
	var trimmed := line.strip_edges()
	var body := trimmed.substr(1).strip_edges()
	if body.is_empty():
		_append_log("系统", "空命令。输入 /help 查看列表。")
		_refocus_input_edit()
		return
	var sp := body.find(" ")
	var head: String = body if sp == -1 else body.substr(0, sp)
	var tail: String = "" if sp == -1 else body.substr(sp + 1).strip_edges()
	var cmd := head.to_lower()
	match cmd:
		"help", "?", "h":
			_slash_print_help()
		"clear":
			_slash_clear_chat()
		"reload":
			_load_config()
			_append_log("系统", "已重新加载 config.json（base_url / api_key 等）。")
		"run", "!":
			if SLASH_SHELL_ENABLED:
				_slash_run_shell(tail)
			else:
				_append_log("系统", "/run 未启用：请在脚本顶部将 SLASH_SHELL_ENABLED 设为 true（仅本机调试，有安全风险）。")
		_:
			_append_log("系统", "未知命令 /%s。输入 /help" % head)
	_refocus_input_edit()


func _slash_print_help() -> void:
	var lines := PackedStringArray([
		"/help — 本帮助",
		"/clear — 清空聊天记录与多轮 messages（保留默认 system）",
		"/reload — 重新加载 config.json",
	])
	if SLASH_SHELL_ENABLED:
		lines.append("/run <命令> — 在本机通过 cmd /c 执行（Windows）")
	_append_log("系统", "\n".join(lines))


func _slash_clear_chat() -> void:
	messages.clear()
	messages.append(
		{
			"role": "system",
			"content": "You are a helpful assistant."
		}
	)
	_chat_richtext = ""
	chat_log.clear()
	_append_log("系统", "对话已清空。")
	_log(LogLevel.INFO, "slash", "chat cleared")
	_log_chat_richtext_snapshot("after_clear")
	_refocus_input_edit()


func _slash_run_shell(command: String) -> void:
	if command.strip_edges().is_empty():
		_append_log("系统", "/run 需要参数，例如：/run echo hello")
		_refocus_input_edit()
		return
	var out_lines: Array = []
	var exit_code: int
	if OS.get_name() == "Windows":
		exit_code = OS.execute("cmd.exe", PackedStringArray(["/c", command]), out_lines)
	else:
		exit_code = OS.execute("/bin/sh", PackedStringArray(["-c", command]), out_lines)
	var combined := ""
	for s in out_lines:
		combined += str(s)
	if combined.length() > CHAT_IO_LOG_MAX_CHARS:
		combined = combined.substr(0, CHAT_IO_LOG_MAX_CHARS) + "\n...[truncated]"
	_log(LogLevel.INFO, "slash", "shell exit=%d len=%d" % [exit_code, combined.length()])
	_append_log("系统", "[exit %d]\n%s" % [exit_code, combined])
	_refocus_input_edit()

#endregion

#region Godot 工具与 HTTP JSON（非流式 tool_calls）
func _http_status_abort_before_body(st: int) -> bool:
	return st == HTTPClient.STATUS_DISCONNECTED or _http_status_is_fatal(st)


func _moonshot_post_json(url_parts: Dictionary, subpath: String, body: Dictionary) -> Dictionary:
	return await _moonshot_http_json(url_parts, HTTPClient.METHOD_POST, subpath, JSON.stringify(body))


func _moonshot_http_json(url_parts: Dictionary, method: int, subpath: String, body_str: String) -> Dictionary:
	var http := HTTPClient.new()
	var tls_opts: TLSOptions = null
	if bool(url_parts["tls"]):
		tls_opts = TLSOptions.client()
	if http.connect_to_host(url_parts["host"], url_parts["port"], tls_opts) != OK:
		_log(LogLevel.ERROR, "http", "json connect_to_host failed")
		return {"ok": false, "error": "connect"}
	var connect_deadline_ms := Time.get_ticks_msec() + 30000
	while http.get_status() != HTTPClient.STATUS_CONNECTED:
		if _http_status_is_fatal(http.get_status()) or Time.get_ticks_msec() > connect_deadline_ms:
			var st := http.get_status()
			_log(
				LogLevel.ERROR,
				"http",
				"json connect aborted fatal=%s st=%d (%s)" % [_http_status_is_fatal(st), st, _http_status_label(st)]
			)
			http.close()
			return {"ok": false, "error": "connect_timeout" if Time.get_ticks_msec() > connect_deadline_ms else "connect_fatal"}
		http.poll()
		await get_tree().process_frame
	var req_path := str(url_parts["path_prefix"]).trim_suffix("/") + subpath
	var headers := PackedStringArray([
		"Authorization: Bearer %s" % api_key,
		"Accept: application/json",
	])
	if method == HTTPClient.METHOD_POST:
		headers.append("Content-Type: application/json")
	_log(LogLevel.DEBUG, "http", "json POST %s (header_wait_ms=%d)" % [req_path, HTTP_JSON_HEADER_WAIT_MS])
	http.request(method, req_path, headers, body_str if method == HTTPClient.METHOD_POST else "")
	var header_deadline_ms := Time.get_ticks_msec() + HTTP_JSON_HEADER_WAIT_MS
	var header_wait_start := Time.get_ticks_msec()
	var last_header_progress := header_wait_start
	while http.get_status() != HTTPClient.STATUS_BODY:
		var stb := http.get_status()
		var now_h := Time.get_ticks_msec()
		if now_h - last_header_progress >= HTTP_JSON_PROGRESS_LOG_MS:
			last_header_progress = now_h
			_log(
				LogLevel.INFO,
				"http",
				"waiting for HTTP response headers (LLM may queue long) elapsed=%dms st=%d (%s)"
				% [now_h - header_wait_start, stb, _http_status_label(stb)]
			)
		if _http_status_abort_before_body(stb) or now_h > header_deadline_ms:
			_log(
				LogLevel.ERROR,
				"http",
				"json no STATUS_BODY (timeout or dropped) st=%d (%s) elapsed=%dms"
				% [stb, _http_status_label(stb), now_h - header_wait_start]
			)
			http.close()
			return {"ok": false, "error": "no_response_body st=%d" % stb}
		http.poll()
		await get_tree().process_frame
	_log(LogLevel.INFO, "http", "response headers received, reading body...")
	var code := http.get_response_code()
	var raw := await _read_http_body_fully(http)
	http.close()
	var close_poll_deadline := Time.get_ticks_msec() + HTTP_JSON_CLOSE_POLL_MS
	while http.get_status() != HTTPClient.STATUS_DISCONNECTED:
		if Time.get_ticks_msec() > close_poll_deadline:
			_log(LogLevel.WARN, "http", "json close() poll DISCONNECTED timeout st=%d; continuing" % http.get_status())
			break
		http.poll()
		await get_tree().process_frame
	if code < 200 or code >= 300:
		_log(LogLevel.WARN, "http", "json code=%d body=%s" % [code, raw.substr(0, min(400, raw.length()))])
		return {"ok": false, "error": "http_%d" % code, "raw": raw}
	var jp := JSON.new()
	if jp.parse(raw) != OK:
		_log(
			LogLevel.ERROR,
			"http",
			"json parse failed err=%s at line=%d body_head=%s"
			% [jp.get_error_message(), jp.get_error_line(), raw.substr(0, min(300, raw.length()))]
		)
		return {"ok": false, "error": "json_parse", "raw": raw}
	_log(LogLevel.DEBUG, "http", "json OK code=%d body_len=%d" % [code, raw.length()])
	return {"ok": true, "code": code, "json": jp.data}


## HTTP/1.1 keep-alive：读完带 Content-Length 的 body 后，连接常回到 CONNECTED 而不是 DISCONNECTED，
## 若只靠「等到 DISCONNECTED」会死循环；必须以声明长度或完整 JSON 作为结束条件。
func _json_payload_looks_complete(s: String) -> bool:
	if s.strip_edges().is_empty():
		return false
	var j := JSON.new()
	return j.parse(s) == OK and (j.data is Dictionary or j.data is Array)


func _read_http_body_fully(http: HTTPClient) -> String:
	var out := PackedByteArray()
	var declared: int = http.get_response_body_length()
	_log(LogLevel.DEBUG, "http", "get_response_body_length()=%d (-1=chunked/unknown)" % declared)
	var body_deadline_ms := Time.get_ticks_msec() + HTTP_JSON_BODY_READ_MS
	var body_wait_start := Time.get_ticks_msec()
	var last_body_progress := body_wait_start
	while http.get_status() != HTTPClient.STATUS_DISCONNECTED:
		var st := http.get_status()
		var now_b := Time.get_ticks_msec()
		if now_b - last_body_progress >= HTTP_JSON_PROGRESS_LOG_MS:
			last_body_progress = now_b
			_log(
				LogLevel.INFO,
				"http",
				"reading response body elapsed=%dms st=%d (%s) bytes=%d declared=%d"
				% [now_b - body_wait_start, st, _http_status_label(st), out.size(), declared]
			)
		if declared == 0:
			_log(LogLevel.INFO, "http", "body complete (declared size 0)")
			break
		if _http_status_is_fatal(st):
			_log(LogLevel.ERROR, "http", "body read fatal st=%d (%s) bytes_so_far=%d" % [st, _http_status_label(st), out.size()])
			break
		if now_b > body_deadline_ms:
			_log(LogLevel.ERROR, "http", "body read timeout st=%d (%s) bytes_so_far=%d" % [st, _http_status_label(st), out.size()])
			break
		http.poll()
		if http.get_status() == HTTPClient.STATUS_BODY:
			out.append_array(http.read_response_body_chunk())
		# 结束条件必须在 poll/read 之后：keep-alive 下读满后常回到 CONNECTED(5)，不会 DISCONNECTED
		if declared > 0 and out.size() >= declared:
			_log(LogLevel.INFO, "http", "body complete (Content-Length %d)" % declared)
			break
		var st_after := http.get_status()
		if (
			declared < 0
			and (st_after == HTTPClient.STATUS_CONNECTED or st_after == HTTPClient.STATUS_BODY)
			and _json_payload_looks_complete(out.get_string_from_utf8())
		):
			_log(LogLevel.INFO, "http", "body complete (JSON ok, declared=-1, st=%s)" % _http_status_label(st_after))
			break
		await get_tree().process_frame
	return out.get_string_from_utf8()


## Moonshot / OpenAI 兼容：assistant 消息里 tool_calls[].index 必须是 JSON 整数；JSON.parse 常得到 float(0.0) 会触发 400。
func _normalize_openai_messages_tool_calls(messages_arr: Array) -> void:
	for m in messages_arr:
		if not (m is Dictionary):
			continue
		if str(m.get("role", "")) != "assistant":
			continue
		if not m.has("tool_calls"):
			continue
		var tc: Variant = m.get("tool_calls", [])
		if not (tc is Array):
			continue
		for item in tc:
			if not (item is Dictionary):
				continue
			var idx: Variant = item.get("index", 0)
			match typeof(idx):
				TYPE_INT:
					pass
				TYPE_FLOAT:
					item["index"] = int(idx)
				_:
					item["index"] = int(str(idx).to_float())


func _build_godot_tool_definitions() -> Array:
	var desc := (
		"Evaluates one Godot Expression (see Godot docs class Expression). "
		+ "Pass a single expression string; execution uses a sandbox object as base instance (not the full UI node). "
		+ "Available methods: expr_get_engine_version() -> String (JSON); expr_get_os_name() -> String; "
		+ "expr_print(message) -> String (prints to Output); expr_set_window_title(title) -> String; "
		+ "expr_set_chat_background_color(color_hex) -> String (#RRGGBB or #RRGGBBAA, # optional). "
		+ "String literals must use double quotes. Example: expr_print(\"hello\") or expr_set_chat_background_color(\"#1a1a2e\")."
	)
	return [
		{
			"type": "function",
			"function": {
				"name": "godot_eval_expression",
				"description": desc,
				"parameters": {
					"type": "object",
					"properties": {
						"expression": {
							"type": "string",
							"description": "Single Expression; call only expr_* sandbox methods."
						}
					},
					"required": ["expression"]
				}
			}
		},
	]


func _parse_color_hex_string(s: String) -> Variant:
	var h := s.strip_edges()
	if h.begins_with("#"):
		h = h.substr(1)
	if h.length() != 6 and h.length() != 8:
		return "Error: color must be #RRGGBB or #RRGGBBAA (or without #)"
	if not h.is_valid_hex_number(false):
		return "Error: invalid hex color"
	var r := h.substr(0, 2).hex_to_int()
	var g := h.substr(2, 2).hex_to_int()
	var b := h.substr(4, 2).hex_to_int()
	var a := 255
	if h.length() == 8:
		a = h.substr(6, 2).hex_to_int()
	return Color(r / 255.0, g / 255.0, b / 255.0, a / 255.0)


func _expr_sandbox_set_chat_background(color_hex: String) -> String:
	var parsed: Variant = _parse_color_hex_string(color_hex)
	if parsed is String:
		return parsed
	if not is_instance_valid(_background_rect):
		return "Error: background ColorRect missing"
	_background_rect.color = parsed
	return "ok, chat background set to %s" % _background_rect.color.to_html(true)


func _execute_godot_tool(tool_name: String, args: Dictionary) -> String:
	match tool_name:
		"godot_eval_expression":
			var expr_s := str(args.get("expression", "")).strip_edges()
			if expr_s.is_empty():
				return "Error: empty expression"
			if _tool_expr_sandbox == null:
				return "Error: expression sandbox not initialized"
			var expr := Expression.new()
			var perr := expr.parse(expr_s, PackedStringArray())
			if perr != OK:
				return "Error: parse: %s" % expr.get_error_text()
			var result: Variant = expr.execute([], _tool_expr_sandbox, true)
			if expr.has_execute_failed():
				return "Error: execute: %s" % expr.get_error_text()
			if result == null:
				return "ok"
			return str(result)
		_:
			return "Error: unknown tool %s" % tool_name


func _append_godot_tool_result(tool_call: Dictionary) -> void:
	var call_id := str(tool_call.get("id", ""))
	var fn: Variant = tool_call.get("function", {})
	if not (fn is Dictionary):
		var err_invalid := "Error: invalid function"
		messages.append({"role": "tool", "tool_call_id": call_id, "content": err_invalid})
		_append_log("系统", "工具调用格式错误（无法解析 function）。")
		return
	var fn_name := str(fn.get("name", ""))
	var arg_str := str(fn.get("arguments", "{}"))
	var j := JSON.new()
	var args: Dictionary = {}
	if j.parse(arg_str) == OK and j.data is Dictionary:
		args = j.data
	_log(LogLevel.INFO, "tools", "invoke %s" % fn_name)
	_append_log("系统", "调用工具 %s" % fn_name)
	var result := _execute_godot_tool(fn_name, args)
	messages.append({"role": "tool", "tool_call_id": call_id, "content": result})
	var shown := result
	if shown.length() > TOOL_RESULT_CHAT_MAX_CHARS:
		shown = shown.substr(0, TOOL_RESULT_CHAT_MAX_CHARS) + "\n…[truncated, total_len=%d]" % result.length()
	_append_log("工具", shown)
	var rlog := result
	if rlog.length() > 2000:
		rlog = rlog.substr(0, 2000) + "…"
	_log(LogLevel.INFO, "tools", "result %s" % rlog)


func _request_chat_with_tools_async(url_parts: Dictionary) -> void:
	_log(LogLevel.INFO, "http", "chat with Godot tools (non-stream)")
	var tools := _build_godot_tool_definitions()
	for round_idx in range(GODOT_TOOL_ROUNDS_MAX):
		_normalize_openai_messages_tool_calls(messages)
		_log(
			LogLevel.INFO,
			"tools",
			"round %d/%d messages=%d (tool_calls normalized for API)" % [round_idx + 1, GODOT_TOOL_ROUNDS_MAX, messages.size()]
		)
		var payload := {
			"model": _chat_model,
			"messages": messages,
			"max_tokens": _max_tokens,
			"stream": false,
			"tools": tools,
		}
		var resp := await _moonshot_post_json(url_parts, CHAT_ENDPOINT, payload)
		if not bool(resp.get("ok", false)):
			var err_s := str(resp.get("error", "unknown"))
			var raw_v: Variant = resp.get("raw", "")
			var raw_s := str(raw_v) if raw_v != null else ""
			var raw_head := raw_s.substr(0, min(400, raw_s.length()))
			_log(
				LogLevel.ERROR,
				"http",
				"chat tools round %d failed err=%s raw_head=%s" % [round_idx + 1, err_s, raw_head]
			)
			_append_log("系统", "请求失败：%s" % err_s + (("\n" + raw_head) if not raw_head.is_empty() else ""))
			return
		var data: Variant = resp.get("json", {})
		if not (data is Dictionary):
			_log(LogLevel.ERROR, "tools", "round %d: JSON root not object" % [round_idx + 1])
			_append_log("系统", "响应解析失败。")
			return
		if data.has("error"):
			var e = data["error"]
			var em := str(e) if not (e is Dictionary) else str(e.get("message", e))
			_log(LogLevel.ERROR, "tools", "round %d API error: %s" % [round_idx + 1, em])
			_append_log("系统", "接口错误：%s" % em)
			return
		var choices: Variant = data.get("choices", [])
		if not (choices is Array) or (choices as Array).is_empty():
			_log(LogLevel.WARN, "tools", "round %d: empty choices" % [round_idx + 1])
			_append_log("系统", "返回无 choices。")
			return
		var choice0: Variant = choices[0]
		if not (choice0 is Dictionary):
			_log(LogLevel.ERROR, "tools", "round %d: choice[0] not object" % [round_idx + 1])
			return
		var msg: Variant = choice0.get("message", {})
		if not (msg is Dictionary):
			_log(LogLevel.ERROR, "tools", "round %d: invalid message" % [round_idx + 1])
			_append_log("系统", "无效 message。")
			return
		var calls: Variant = msg.get("tool_calls", [])
		var has_calls := calls is Array and not (calls as Array).is_empty()
		if has_calls:
			messages.append(msg)
			_log(LogLevel.INFO, "tools", "round %d: model returned %d tool_call(s)" % [round_idx + 1, (calls as Array).size()])
			for tc in calls as Array:
				if tc is Dictionary:
					_append_godot_tool_result(tc)
			_append_log("系统", "已执行工具，继续请求模型…")
			continue
		var text := str(msg.get("content", ""))
		if text.strip_edges().is_empty():
			text = "(空回复)"
		messages.append({"role": "assistant", "content": text})
		await _apply_assistant_reply_ui(text)
		return
	_log(LogLevel.WARN, "tools", "stopped: max rounds %d" % GODOT_TOOL_ROUNDS_MAX)
	_append_log("系统", "工具轮次过多，已中止。")


func _apply_assistant_reply_ui(text: String) -> void:
	_assistant_reply = text
	_typewriter_display_len = 0
	_typewriter_accum = 0.0
	_sse_chunk_index = 0
	_log_base_before_ai = _chat_richtext
	_ai_prefix_bbcode = _format_role_prefix("AI")
	chat_log.text = _log_base_before_ai + _ai_prefix_bbcode
	set_process(true)
	while _typewriter_display_len < _assistant_reply.length():
		await get_tree().process_frame
	_chat_richtext = _log_base_before_ai + _ai_prefix_bbcode + _escape_bbcode(_assistant_reply) + "\n"
	chat_log.text = _chat_richtext
	_scroll_chat_to_end()
	set_process(false)
	_log_chat_io("assistant_output", _assistant_reply)
	_log_chat_richtext_snapshot("after_assistant_reply_tools")

#endregion

#region 流式 Chat Completions（HTTP + SSE）
func _request_chat_stream_async() -> void:
	_set_waiting(true)
	var url_parts := _parse_http_base_url(base_url)
	if url_parts.is_empty():
		_log(LogLevel.ERROR, "http", "base_url parse failed (need http:// or https://)")
		_append_log("系统", "base_url 格式不正确（需要 http(s):// 开头）。")
		_set_waiting(false)
		return

	if _enable_godot_tools:
		await _request_chat_with_tools_async(url_parts)
		_set_waiting(false)
		return

	_log(
		LogLevel.INFO,
		"http",
		"target host=%s port=%d tls=%s path=%s" % [url_parts["host"], url_parts["port"], url_parts["tls"], str(url_parts["path_prefix"]).trim_suffix("/") + CHAT_ENDPOINT]
	)

	var payload := {
		"model": _chat_model,
		"messages": messages,
		"max_tokens": _max_tokens,
		"stream": true,
	}
	var body := JSON.stringify(payload)
	_log(LogLevel.DEBUG, "http", "POST body bytes=%d messages_count=%d" % [body.length(), messages.size()])
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % api_key,
		"Accept: text/event-stream",
	])
	var path: String = str(url_parts["path_prefix"]).trim_suffix("/") + CHAT_ENDPOINT

	_http = HTTPClient.new()
	# Godot 4.4+：第 3 参为 TLSOptions，不再接受 bool
	var tls_opts: TLSOptions = null
	if bool(url_parts["tls"]):
		tls_opts = TLSOptions.client()
	var err := _http.connect_to_host(url_parts["host"], url_parts["port"], tls_opts)
	if err != OK:
		_log(LogLevel.ERROR, "http", "connect_to_host failed err=%d" % err)
		_append_log("系统", "连接失败，错误码：%d" % err)
		_set_waiting(false)
		return

	_log(LogLevel.DEBUG, "http", "connect_to_host OK, polling until CONNECTED...")
	# 必须先 poll：状态会从 RESOLVING → CONNECTING → CONNECTED，不能只判断 CONNECTING
	var connect_deadline_ms := Time.get_ticks_msec() + 30000
	var last_logged_st := -1
	while _http.get_status() != HTTPClient.STATUS_CONNECTED:
		var st := _http.get_status()
		if st != last_logged_st:
			_log(LogLevel.DEBUG, "http", "connect poll status=%d (%s)" % [st, _http_status_label(st)])
			last_logged_st = st
		if _http_status_is_fatal(st):
			_log(LogLevel.ERROR, "http", "fatal status while connecting: %d (%s)" % [st, _http_status_label(st)])
			_append_log("系统", "未能建立连接（状态 %d，参见 HTTPClient.Status）。" % st)
			_http.close()
			_set_waiting(false)
			return
		if Time.get_ticks_msec() > connect_deadline_ms:
			_log(LogLevel.ERROR, "http", "connect timeout status=%d (%s)" % [st, _http_status_label(st)])
			_append_log("系统", "连接超时（当前状态 %d）。" % st)
			_http.close()
			_set_waiting(false)
			return
		_http.poll()
		await get_tree().process_frame

	_log(LogLevel.INFO, "http", "TCP/TLS connected")

	err = _http.request(HTTPClient.METHOD_POST, path, headers, body)
	if err != OK:
		_log(LogLevel.ERROR, "http", "request() failed err=%d" % err)
		_append_log("系统", "请求发起失败，错误码：%d" % err)
		_http.close()
		_set_waiting(false)
		return

	_log(LogLevel.DEBUG, "http", "request() OK, waiting for STATUS_BODY...")
	var header_deadline_ms := Time.get_ticks_msec() + 120000
	last_logged_st = -1
	while _http.get_status() != HTTPClient.STATUS_BODY:
		var st2 := _http.get_status()
		if st2 != last_logged_st:
			_log(LogLevel.DEBUG, "http", "header poll status=%d (%s)" % [st2, _http_status_label(st2)])
			last_logged_st = st2
		if _http_status_is_fatal(st2):
			_log(LogLevel.ERROR, "http", "fatal status before body: %d (%s)" % [st2, _http_status_label(st2)])
			_append_log("系统", "请求失败（状态 %d）。" % st2)
			_http.close()
			_set_waiting(false)
			return
		if Time.get_ticks_msec() > header_deadline_ms:
			_log(LogLevel.ERROR, "http", "response headers timeout status=%d (%s)" % [st2, _http_status_label(st2)])
			_append_log("系统", "等待响应头超时（状态 %d）。" % st2)
			_http.close()
			_set_waiting(false)
			return
		_http.poll()
		await get_tree().process_frame

	var code := _http.get_response_code()
	_log(LogLevel.INFO, "http", "response_code=%d" % code)
	if code < 200 or code >= 300:
		var err_text := await _read_error_body_async()
		var preview := err_text.substr(0, min(500, err_text.length()))
		if err_text.length() > 500:
			preview += "...(truncated)"
		_log(LogLevel.ERROR, "http", "non-2xx body preview: %s" % preview)
		_append_log("系统", "HTTP 错误：%d\n%s" % [code, err_text])
		_http.close()
		_set_waiting(false)
		return

	_stream_line_buf = ""
	_assistant_reply = ""
	_typewriter_display_len = 0
	_typewriter_accum = 0.0
	_sse_chunk_index = 0
	_log_base_before_ai = _chat_richtext
	_ai_prefix_bbcode = _format_role_prefix("AI")
	chat_log.text = _log_base_before_ai + _ai_prefix_bbcode
	set_process(true)
	_log(LogLevel.INFO, "sse", "stream body started, typewriter enabled")

	var stream_done := false
	while _http.get_status() != HTTPClient.STATUS_DISCONNECTED and not stream_done:
		_http.poll()
		if _http.get_status() == HTTPClient.STATUS_BODY:
			var chunk := _http.read_response_body_chunk()
			if chunk.size() > 0:
				stream_done = _consume_sse_chunk(chunk)
		await get_tree().process_frame

	_log(LogLevel.INFO, "sse", "read loop exit stream_done=%s http_status=%d (%s)" % [stream_done, _http.get_status(), _http_status_label(_http.get_status())])

	if _http.get_status() != HTTPClient.STATUS_DISCONNECTED:
		_log(LogLevel.DEBUG, "http", "closing client...")
		_http.close()
		while _http.get_status() != HTTPClient.STATUS_DISCONNECTED:
			_http.poll()
			await get_tree().process_frame

	if _assistant_reply.is_empty():
		_log(LogLevel.WARN, "sse", "assistant_reply empty, substituting placeholder")
		_assistant_reply = "(空回复)"

	# 等打字机把剩余字都露出来（流可能已结束但界面还在追）
	_log(LogLevel.DEBUG, "typewriter", "draining display len=%d target=%d" % [_typewriter_display_len, _assistant_reply.length()])
	while _typewriter_display_len < _assistant_reply.length():
		await get_tree().process_frame

	_chat_richtext = _log_base_before_ai + _ai_prefix_bbcode + _escape_bbcode(_assistant_reply) + "\n"
	chat_log.text = _chat_richtext
	_scroll_chat_to_end()
	set_process(false)
	_log(LogLevel.INFO, "typewriter", "finished reply_len=%d" % _assistant_reply.length())
	_log_chat_io("assistant_output", _assistant_reply)
	_log_chat_richtext_snapshot("after_assistant_reply_sse")

	messages.append({"role": "assistant", "content": _assistant_reply})
	_set_waiting(false)

#endregion

#region 响应体读取与 SSE 解析
func _read_error_body_async() -> String:
	var out := PackedByteArray()
	while _http.get_status() != HTTPClient.STATUS_DISCONNECTED:
		_http.poll()
		if _http.get_status() == HTTPClient.STATUS_BODY:
			var chunk := _http.read_response_body_chunk()
			out.append_array(chunk)
		await get_tree().process_frame
	var s := out.get_string_from_utf8()
	_log(LogLevel.DEBUG, "http", "error body total bytes=%d" % out.size())
	return s


func _consume_sse_chunk(chunk: PackedByteArray) -> bool:
	_sse_chunk_index += 1
	if LOG_DEBUG_ENABLED and (_sse_chunk_index <= 3 or _sse_chunk_index % 40 == 0):
		_log(LogLevel.DEBUG, "sse", "chunk #%d bytes=%d buf_len=%d" % [_sse_chunk_index, chunk.size(), _stream_line_buf.length()])

	_stream_line_buf += chunk.get_string_from_utf8()
	while true:
		var nl := _stream_line_buf.find("\n")
		if nl == -1:
			break
		var line := _stream_line_buf.substr(0, nl).strip_edges()
		_stream_line_buf = _stream_line_buf.substr(nl + 1)
		line = line.replace("\r", "")
		if line.is_empty():
			continue
		if not line.begins_with("data: "):
			if LOG_DEBUG_ENABLED and not line.begins_with(":"):
				_log(LogLevel.DEBUG, "sse", "skip non-data line: %s" % line.substr(0, min(80, line.length())))
			continue
		var data := line.substr(6).strip_edges()
		if data == "[DONE]":
			_log(LogLevel.INFO, "sse", "[DONE] received")
			return true

		var json := JSON.new()
		if json.parse(data) != OK:
			_log(LogLevel.WARN, "sse", "JSON parse failed for data line (len=%d)" % data.length())
			continue
		var obj = json.data
		if not (obj is Dictionary):
			_log(LogLevel.WARN, "sse", "parsed JSON is not object (variant type=%d)" % typeof(obj))
			continue

		if obj.has("error"):
			var e = obj["error"]
			var msg := str(e) if not (e is Dictionary) else str(e.get("message", e))
			_log(LogLevel.ERROR, "api", "stream error object: %s" % msg)
			_append_log("系统", "接口错误：%s" % msg)
			continue

		if not obj.has("choices"):
			continue
		var choices = obj["choices"]
		if choices.is_empty():
			continue
		var delta = choices[0].get("delta", {})
		var piece := str(delta.get("content", ""))
		if piece.is_empty():
			continue

		_assistant_reply += piece

	return false

#endregion

#region 打字机刷新
func _refresh_ai_line() -> void:
	var shown: String = _assistant_reply.substr(0, _typewriter_display_len)
	chat_log.text = _log_base_before_ai + _ai_prefix_bbcode + _escape_bbcode(shown)
	_scroll_chat_to_end()

#endregion

#region URL 与致命状态
func _http_status_is_fatal(st: int) -> bool:
	return (
		st == HTTPClient.STATUS_CANT_RESOLVE
		or st == HTTPClient.STATUS_CANT_CONNECT
		or st == HTTPClient.STATUS_CONNECTION_ERROR
		or st == HTTPClient.STATUS_TLS_HANDSHAKE_ERROR
	)


func _parse_http_base_url(url: String) -> Dictionary:
	var u := url.strip_edges().trim_suffix("/")
	if u.is_empty():
		_log(LogLevel.WARN, "url", "empty after strip")
		return {}
	var use_tls := u.begins_with("https://")
	if u.begins_with("https://"):
		u = u.substr(8)
	elif u.begins_with("http://"):
		u = u.substr(7)
		use_tls = false
	else:
		_log(LogLevel.WARN, "url", "missing scheme")
		return {}

	var slash := u.find("/")
	var host_part := u.substr(0, slash) if slash != -1 else u
	var path_prefix := u.substr(slash) if slash != -1 else "/"
	if path_prefix.is_empty():
		path_prefix = "/"

	var port := 443 if use_tls else 80
	var host := host_part
	if ":" in host_part:
		var hp := host_part.split(":")
		host = hp[0]
		port = int(hp[1])

	_log(LogLevel.DEBUG, "url", "parsed host=%s port=%d tls=%s path_prefix=%s" % [host, port, use_tls, path_prefix])
	return {"host": host, "port": port, "tls": use_tls, "path_prefix": path_prefix}

#endregion

#region 配置文件
func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		_log(LogLevel.ERROR, "config", "file missing: %s" % CONFIG_PATH)
		_append_log("系统", "未找到配置文件：%s" % CONFIG_PATH)
		return

	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		_log(LogLevel.ERROR, "config", "open failed: %s (err=%d)" % [CONFIG_PATH, FileAccess.get_open_error()])
		_append_log("系统", "配置文件打开失败：%s" % CONFIG_PATH)
		return

	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_error := json.parse(content)
	if parse_error != OK:
		_log(LogLevel.ERROR, "config", "JSON parse error line=%d" % json.get_error_line())
		_append_log("系统", "配置文件 JSON 格式错误。")
		return

	var conf = json.data
	if conf is Dictionary:
		base_url = str(conf.get("base_url", "")).strip_edges()
		api_key = str(conf.get("api_key", "")).strip_edges()
		if conf.has("model"):
			_chat_model = str(conf.get("model")).strip_edges()
		if conf.has("max_tokens"):
			_max_tokens = int(conf.get("max_tokens", _max_tokens))
		if conf.has("enable_godot_tools"):
			_enable_godot_tools = bool(conf.get("enable_godot_tools"))
		_log(LogLevel.INFO, "config", "loaded base_url=%s model=%s tools=%s" % [base_url, _chat_model, _enable_godot_tools])
		_log_secret_hint("api_key", api_key)
	else:
		_log(LogLevel.WARN, "config", "root is not object")

#endregion

#region 聊天区与等待态
func _append_log(role: String, text: String) -> void:
	var compact_text := text.strip_edges().replace("\r\n", "\n")
	while compact_text.find("\n\n") != -1:
		compact_text = compact_text.replace("\n\n", "\n")
	_chat_richtext += _format_role_prefix(role) + _escape_bbcode(compact_text) + "\n"
	chat_log.text = _chat_richtext
	_scroll_chat_to_end()
	# 每条聊天行同步到 Output（长文本分块），与 RichTextLabel 中可见内容一致
	_log_long_to_category(LogLevel.INFO, "chat_ui", "[%s] " % role, compact_text)


func _scroll_chat_to_end() -> void:
	var lc := chat_log.get_line_count()
	if lc > 0:
		chat_log.scroll_to_line(lc - 1)


func _set_waiting(value: bool) -> void:
	waiting_response = value
	send_button.disabled = value
	send_button.text = "发送中..." if value else "发送"
	if not value:
		_refocus_input_edit()


func _refocus_input_edit() -> void:
	if not is_instance_valid(input_edit):
		return
	# 协程：等 2 帧再聚焦，避免本帧内 chat_log 滚动/刷新把焦点留在 RichTextLabel 上
	_refocus_input_edit_after_frames()


func _refocus_input_edit_after_frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(input_edit):
		return
	input_edit.grab_focus()
	_log(LogLevel.DEBUG, "ui", "grab_focus LineEdit (focus_owner=%s)" % get_viewport().gui_get_focus_owner())

#endregion


## 仅含 expr_* 方法，供 Expression.execute 的 base_instance 使用；用 WeakRef 避免与 UI 根节点循环引用。
class ToolExprSandbox extends RefCounted:
	var _owner: WeakRef

	func _init(owner: Control) -> void:
		_owner = weakref(owner)

	func expr_get_engine_version() -> String:
		return JSON.stringify(Engine.get_version_info())

	func expr_get_os_name() -> String:
		return OS.get_name()

	func expr_print(message: String) -> String:
		var m := str(message)
		print("[LLM expr] ", m)
		return "ok, printed to Godot Output: %s" % m

	func expr_set_window_title(title: String) -> String:
		var t := str(title)
		var n: Object = _owner.get_ref()
		if n == null:
			return "Error: scene invalid"
		var ctl := n as Control
		if ctl == null:
			return "Error: invalid owner"
		var w: Window = ctl.get_window()
		if w:
			w.title = t
		return "ok, window title updated to %s" % t

	func expr_set_chat_background_color(color_hex: String) -> String:
		var n: Object = _owner.get_ref()
		if n == null:
			return "Error: scene invalid"
		if not n.has_method("_expr_sandbox_set_chat_background"):
			return "Error: host missing sandbox hook"
		return n.call("_expr_sandbox_set_chat_background", color_hex)
