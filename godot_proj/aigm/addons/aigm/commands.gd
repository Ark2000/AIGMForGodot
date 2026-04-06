extends RefCounted

## Agent tool: run **standard Lua 5.x** only (no Godot APIs in the sandbox).
## Host GDScript uses lua-gdextension only to create LuaState and call open_libraries with a Lua-only mask.

const TOOL_LUA := "aigm_lua_run"
const MAX_DELAY_SECONDS := 300.0
const MAX_LUA_SOURCE_CHARS := 200000
## lua-gdextension LuaState.Library: LUA_* only (must stay in sync with upstream enum bits).
const _PURE_LUA_OPEN_LIBS := (1 << 0) | (1 << 2) | (1 << 3) | (1 << 5) | (1 << 6) | (1 << 8) | (1 << 12)

var _owner_wr: WeakRef
var _tools_enabled := true


func _init(owner: Node) -> void:
	_owner_wr = weakref(owner)


func set_tools_enabled(enabled: bool) -> void:
	_tools_enabled = enabled


## Backward compat with older config / stream code.
func set_lua_tool_enabled(enabled: bool) -> void:
	set_tools_enabled(enabled)


func build_system_prompt_hint() -> String:
	if not _tools_enabled or not _lua_runtime_available():
		return ""
	return (
		"To run short Lua snippets (standard library only, no game engine), call tool %s with a `lua` string. "
		+ "Optional delay_seconds defers execution on the scene tree (max %.0fs). "
		+ "Return a value from the chunk to report it; errors are returned as text."
	) % [TOOL_LUA, MAX_DELAY_SECONDS]


func build_tool_definition() -> Dictionary:
	return _build_lua_tool_definition()


func build_tool_definitions() -> Array:
	if not _tools_enabled or not _lua_runtime_available():
		return []
	return [_build_lua_tool_definition()]


func _build_lua_tool_definition() -> Dictionary:
	return {
		"type": "function",
		"function": {
			"name": TOOL_LUA,
			"description": (
				"Execute a Lua 5.x snippet with standard libraries only (math, string, table, utf8, coroutine, etc.). "
				+ "No engine or host APIs. Use `return` to pass a value back as the tool result. "
				+ "Optional delay_seconds (0–%.0f) defers execution on the scene tree."
			) % MAX_DELAY_SECONDS,
			"parameters": {
				"type": "object",
				"properties": {
					"lua": {
						"type": "string",
						"description": "Lua source (chunk); last return value becomes the tool result string.",
					},
					"delay_seconds": {
						"type": "number",
						"description": (
							"Wait this many seconds before running Lua. Omit or 0 for immediate. Max %.0f."
						) % MAX_DELAY_SECONDS,
					},
				},
				"required": ["lua"]
			}
		}
	}


func execute_tool(tool_name: String, args: Dictionary) -> String:
	return await execute_tool_async(tool_name, args)


func execute_tool_async(tool_name: String, args: Dictionary) -> String:
	if tool_name != TOOL_LUA:
		return "Error: unknown tool " + tool_name
	return await _execute_lua_async(args)


func _execute_lua_async(args: Dictionary) -> String:
	if not _lua_runtime_available():
		return "Error: Lua GDExtension not loaded (install lua-gdextension build/; see tools/fetch_lua_gdextension_build.ps1)"
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
	var src := str(args.get("lua", "")).strip_edges()
	if src.is_empty():
		return "Error: empty lua"
	if src.length() > MAX_LUA_SOURCE_CHARS:
		return "Error: lua source too long (max %d chars)" % MAX_LUA_SOURCE_CHARS
	var lua: Object = ClassDB.instantiate("LuaState")
	if lua == null:
		return "Error: could not create LuaState"
	lua.call("open_libraries", _PURE_LUA_OPEN_LIBS)
	var result: Variant = lua.call("do_string", src)
	if typeof(result) == TYPE_OBJECT and result != null and String(result.get_class()) == "LuaError":
		var msg: Variant = result.get("message")
		return "Error: " + (str(msg) if msg != null else str(result))
	return "ok" if result == null else str(result)


func _lua_runtime_available() -> bool:
	return ClassDB.class_exists("LuaState")


func _owner() -> Node:
	return _owner_wr.get_ref()
