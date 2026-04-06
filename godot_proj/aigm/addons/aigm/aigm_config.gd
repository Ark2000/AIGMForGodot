extends RefCounted
## Loads `config.json` into a plain Dictionary (`load_error` key if failed).

const CONFIG_PATH := "res://addons/aigm/config.json"


static func load_settings(path: String) -> Dictionary:
	var out := {
		"load_error": "",
		"base_url": "",
		"api_key": "",
		"chat_model": "kimi-k2-turbo-preview",
		"max_tokens": 8192,
		"enable_tools": true,
		"debug_tool_trace": false,
		"debug_aigm_trace": false,
	}
	if not FileAccess.file_exists(path):
		out["load_error"] = "missing"
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		out["load_error"] = "open_failed"
		return out
	var raw := f.get_as_text()
	f.close()
	var j := JSON.new()
	if j.parse(raw) != OK:
		out["load_error"] = "json_parse"
		return out
	var d: Variant = j.data
	if not (d is Dictionary):
		out["load_error"] = "not_object"
		return out
	var di: Dictionary = d
	out["base_url"] = str(di.get("base_url", "")).strip_edges()
	out["api_key"] = str(di.get("api_key", "")).strip_edges()
	if di.has("model"):
		out["chat_model"] = str(di.get("model", out["chat_model"])).strip_edges()
	if di.has("max_tokens"):
		out["max_tokens"] = int(di.get("max_tokens", out["max_tokens"]))
	if di.has("enable_tools"):
		out["enable_tools"] = bool(di.get("enable_tools"))
	else:
		out["enable_tools"] = bool(di.get("enable_godot_tools", true)) and bool(di.get("enable_lua_tool", true))
	if di.has("debug_tool_trace"):
		out["debug_tool_trace"] = bool(di.get("debug_tool_trace"))
	if di.has("debug_aigm_trace"):
		out["debug_aigm_trace"] = bool(di.get("debug_aigm_trace"))
	if out["debug_tool_trace"]:
		out["debug_aigm_trace"] = true
	return out
