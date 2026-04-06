extends RefCounted
## Loads addons/aigm/lua (aigm.lua core) via lua-gdextension. No game logic — bridge only.

const _BOOT := "package.path = 'res://addons/aigm/lua/?.lua;' .. package.path\nAIGM = require('aigm')\nAIGM.host_reset_session()\n"

var available: bool = false
var _lua: Object


func _init() -> void:
	if not ClassDB.class_exists("LuaState"):
		return
	_lua = ClassDB.instantiate("LuaState")
	if _lua == null:
		return
	_lua.call("open_libraries", _host_library_mask())
	var boot_result: Variant = _lua.do_string(_BOOT)
	if _is_lua_error(boot_result):
		push_error("AIGM Lua boot: " + str(boot_result))
		return
	available = true


func _host_library_mask() -> int:
	const LUA_BASE := 1 << 0
	const LUA_PACKAGE := 1 << 1
	const LUA_COROUTINE := 1 << 2
	const LUA_STRING := 1 << 3
	const LUA_MATH := 1 << 5
	const LUA_TABLE := 1 << 6
	const LUA_BIT32 := 1 << 8
	const LUA_UTF8 := 1 << 12
	const GODOT_LOCAL_PATHS := 1 << 18
	return (
		LUA_BASE
		| LUA_PACKAGE
		| LUA_COROUTINE
		| LUA_STRING
		| LUA_MATH
		| LUA_TABLE
		| LUA_BIT32
		| LUA_UTF8
		| GODOT_LOCAL_PATHS
	)


func _is_lua_error(v: Variant) -> bool:
	return typeof(v) == TYPE_OBJECT and v != null and str(v.get_class()) == "LuaError"


func reset_session() -> void:
	if not available:
		return
	_lua.do_string("AIGM.host_reset_session()")


func set_system_prompt(text: String) -> void:
	if not available:
		return
	_set_global_string("__aigm_sys", text)
	_lua.do_string("AIGM.host_set_system_prompt(__aigm_sys)")


func append_user(text: String) -> void:
	if not available:
		return
	_set_global_string("__aigm_u", text)
	_lua.do_string("AIGM.host_append_user(__aigm_u)")


func append_assistant(content: String, tool_calls_json: String) -> void:
	if not available:
		return
	_set_global_string("__aigm_c", content)
	_set_global_string("__aigm_tc", tool_calls_json)
	_lua.do_string("AIGM.host_append_assistant(__aigm_c, __aigm_tc)")


func append_tool_result(tool_call_id: String, content: String) -> void:
	if not available:
		return
	_set_global_string("__aigm_id", tool_call_id)
	_set_global_string("__aigm_r", content)
	_lua.do_string("AIGM.host_append_tool(__aigm_id, __aigm_r)")


func build_payload_json(model: String, max_tokens: int, stream: bool, tools_json: String) -> String:
	if not available:
		return "{}"
	_set_global("__aigm_model", model)
	_set_global("__aigm_mx", max_tokens)
	_set_global("__aigm_st", stream)
	_set_global("__aigm_tools", tools_json)
	var r: Variant = _lua.do_string("return AIGM.host_build_payload_json(__aigm_model, __aigm_mx, __aigm_st, __aigm_tools)")
	return str(r)


func parse_url_json(url: String) -> String:
	if not available:
		return "{}"
	_set_global_string("__aigm_url", url)
	var r: Variant = _lua.do_string("return AIGM.host_parse_url_json(__aigm_url)")
	return str(r)


func request_path(path_prefix: String) -> String:
	if not available:
		return "/chat/completions"
	_set_global_string("__aigm_pp", path_prefix)
	var r: Variant = _lua.do_string("return AIGM.host_request_path(__aigm_pp)")
	return str(r)


func authorization_header(api_key: String) -> String:
	if not available:
		return ""
	_set_global_string("__aigm_key", api_key)
	var r: Variant = _lua.do_string("return AIGM.host_authorization_header(__aigm_key)")
	return str(r)


func session_reset_stream() -> void:
	if not available:
		return
	_lua.do_string("AIGM.host_session_reset_stream()")


func process_stream_chunk(chunk_utf8: String) -> Dictionary:
	if not available:
		return {"ok": false}
	_set_global_string("__aigm_chunk", chunk_utf8)
	var r: Variant = _lua.do_string("return AIGM.host_process_chunk_json(__aigm_chunk)")
	if _is_lua_error(r):
		return {"ok": false, "error": str(r)}
	var j := JSON.new()
	if j.parse(str(r)) != OK:
		return {"ok": false}
	var d: Variant = j.data
	if not (d is Dictionary):
		return {"ok": false}
	return d


func finalize_stream_tail() -> Dictionary:
	if not available:
		return {"pieces": [], "need_reply_reset": false}
	var r: Variant = _lua.do_string("return AIGM.host_finalize_tail_json()")
	if _is_lua_error(r):
		return {"pieces": [], "need_reply_reset": false}
	var j := JSON.new()
	if j.parse(str(r)) != OK:
		return {"pieces": [], "need_reply_reset": false}
	var d: Variant = j.data
	if d is Dictionary:
		return d
	return {"pieces": [], "need_reply_reset": false}


func tool_calls_json() -> String:
	if not available:
		return "[]"
	var r: Variant = _lua.do_string("return AIGM.host_tool_calls_json()")
	return str(r)


func stream_content() -> String:
	if not available:
		return ""
	var r: Variant = _lua.do_string("return AIGM.host_stream_content()")
	return str(r)


func messages_json() -> String:
	if not available:
		return "[]"
	var r: Variant = _lua.do_string("return AIGM.host_messages_json()")
	return str(r)


## Portable agent: build one POST /chat/completions envelope (Lua). Host only performs HTTP.
func prepare_chat_http_json(
	base_url: String,
	model: String,
	max_tokens: int,
	stream: bool,
	tools_json: String,
	api_key: String
) -> String:
	if not available:
		return "{\"ok\":false,\"error\":\"lua_unavailable\"}"
	_set_global_string("__aigm_bu", base_url)
	_set_global_string("__aigm_model", model)
	_set_global("__aigm_mx", max_tokens)
	_set_global("__aigm_st", stream)
	_set_global_string("__aigm_tools", tools_json)
	_set_global_string("__aigm_key", api_key)
	var r: Variant = _lua.do_string(
		"return AIGM.host_prepare_chat_http_json(__aigm_bu, __aigm_model, __aigm_mx, __aigm_st, __aigm_tools, __aigm_key)"
	)
	return str(r)


## After stream chunks + finalize_tail on host, append assistant row and return whether more tool rounds needed.
func commit_assistant_after_stream_json() -> String:
	if not available:
		return "{\"ok\":false,\"error\":\"lua_unavailable\"}"
	var r: Variant = _lua.do_string("return AIGM.host_commit_assistant_after_stream_json()")
	return str(r)


func _set_global(name: String, value: Variant) -> void:
	var g: Variant = _lua.get("globals")
	if g != null:
		g[name] = value


func _set_global_string(name: String, value: String) -> void:
	_set_global(name, value)
