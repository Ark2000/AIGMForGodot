-- AIGM core: Kimi/OpenAI-compatible chat, SSE, tool merge, session (no Godot).
package.path = "res://addons/aigm/lua/?.lua;" .. package.path

local json = require("json")
local url = require("url")
local sse = require("sse")
local merge = require("tool_merge")

local M = {}

M.CHAT_ENDPOINT = "/chat/completions"
M.SYSTEM_PROMPT_BASE = "You are a helpful assistant."
M.AGENT_TOOL_ROUNDS_MAX = 8

function M.new_session()
  return {
    http_round_count = 0,
    messages = {
      { role = "system", content = M.SYSTEM_PROMPT_BASE },
    },
    sse = {
      buffer = "",
      event_data = "",
      done = false,
      content = "",
      did_emit_reset = false,
      tool_call_map = {},
      reply_reset_emitted = false,
    },
  }
end

function M.session_reset(s)
  s.http_round_count = 0
  s.messages = { { role = "system", content = M.SYSTEM_PROMPT_BASE } }
  M.session_reset_stream(s)
end

function M.session_reset_stream(s)
  local st = s.sse
  st.buffer = ""
  st.event_data = ""
  st.done = false
  st.content = ""
  st.did_emit_reset = false
  st.tool_call_map = {}
  st.reply_reset_emitted = false
end

function M.set_system_prompt_content(s, text)
  if s.messages[1] and type(s.messages[1]) == "table" then
    s.messages[1].content = text
  end
end

function M.append_user(s, text)
  s.http_round_count = 0
  table.insert(s.messages, { role = "user", content = text })
end

function M.append_assistant(s, content, tool_calls)
  local msg = { role = "assistant", content = content or "" }
  if tool_calls and type(tool_calls) == "table" and #tool_calls > 0 then
    msg.tool_calls = tool_calls
  end
  table.insert(s.messages, msg)
end

function M.append_tool_message(s, tool_call_id, content)
  table.insert(s.messages, { role = "tool", tool_call_id = tool_call_id, content = content })
end

function M.build_chat_completions_payload(s, model, max_tokens, stream, tools_array)
  local body = {
    model = model,
    messages = s.messages,
    max_tokens = max_tokens,
    stream = stream,
  }
  if tools_array and type(tools_array) == "table" and #tools_array > 0 then
    body.tools = tools_array
  end
  return json.encode(body)
end

--- tools_json_str: JSON array from host (OpenAI tools), or empty / "[]" to omit.
function M.build_chat_completions_payload_from_tools_json(s, model, max_tokens, stream, tools_json_str)
  local tools = nil
  if tools_json_str and type(tools_json_str) == "string" and tools_json_str ~= "" and tools_json_str ~= "[]" then
    local ok, decoded = pcall(json.decode, tools_json_str)
    if ok and type(decoded) == "table" and #decoded > 0 then
      tools = decoded
    end
  end
  return M.build_chat_completions_payload(s, model, max_tokens, stream, tools)
end

function M.parse_base_url(base_url)
  return url.parse_base_url(base_url)
end

function M.request_path(path_prefix)
  local pp = path_prefix or ""
  if pp:sub(-1) == "/" then pp = pp:sub(1, -2) end
  return pp .. M.CHAT_ENDPOINT
end

--- Process UTF-8 chunk from HTTP body. `pieces` is array of content delta strings.
function M.process_stream_chunk(s, chunk_utf8)
  local st = s.sse
  if chunk_utf8 == nil or chunk_utf8 == "" then
    return { ok = true, pieces = {}, need_reply_reset = false, stream_done = false }
  end
  st.buffer = st.buffer .. chunk_utf8
  local out_pieces = {}
  local parsed = sse.consume_sse_buffer(
    st.buffer,
    st.event_data,
    st.done,
    st.did_emit_reset,
    st.content,
    st.tool_call_map
  )
  st.buffer = parsed.buffer
  st.event_data = parsed.event_data
  st.done = parsed.done
  st.did_emit_reset = parsed.did_emit_reset
  st.content = parsed.content
  for _, p in ipairs(parsed.content_pieces or {}) do
    table.insert(out_pieces, p)
  end
  local need_reset = false
  if #out_pieces > 0 and not st.reply_reset_emitted then
    st.reply_reset_emitted = true
    need_reset = true
  end
  return {
    ok = true,
    pieces = out_pieces,
    need_reply_reset = need_reset,
    stream_done = st.done,
  }
end

function M.finalize_stream_tail(s)
  local st = s.sse
  if st.event_data == "" then
    return { pieces = {}, need_reply_reset = false }
  end
  local parsed = sse.consume_sse_event(st.event_data, st.did_emit_reset, st.content, st.tool_call_map)
  st.did_emit_reset = parsed.did_emit_reset
  st.content = parsed.content
  st.event_data = ""
  local out_pieces = parsed.content_pieces or {}
  local need_reset = false
  if #out_pieces > 0 and not st.reply_reset_emitted then
    st.reply_reset_emitted = true
    need_reset = true
  end
  return {
    pieces = out_pieces,
    need_reply_reset = need_reset,
  }
end

function M.tool_calls_json(s)
  local arr = merge.map_to_sorted_array(s.sse.tool_call_map)
  return json.encode(arr)
end

function M.stream_content(s)
  return s.sse.content or ""
end

-- --- Host bridge (single global session for aigm_lua_host.gd) ---
function M.host_reset_session()
  _G.AIGM_SESSION = M.new_session()
end

function M.host_set_system_prompt(text)
  local s = _G.AIGM_SESSION
  if not s then error("AIGM_SESSION missing") end
  M.set_system_prompt_content(s, text)
end

function M.host_append_user(text)
  M.append_user(_G.AIGM_SESSION, text)
end

function M.host_append_assistant(content, tool_calls_json_str)
  local tc = nil
  if tool_calls_json_str and tool_calls_json_str ~= "" and tool_calls_json_str ~= "null" then
    local ok, decoded = pcall(json.decode, tool_calls_json_str)
    if ok and type(decoded) == "table" then tc = decoded end
  end
  M.append_assistant(_G.AIGM_SESSION, content, tc)
end

function M.host_append_tool(tool_call_id, content)
  M.append_tool_message(_G.AIGM_SESSION, tool_call_id, content)
end

function M.host_build_payload_json(model, max_tokens, stream_bool, tools_json_str)
  return M.build_chat_completions_payload_from_tools_json(
    _G.AIGM_SESSION, model, max_tokens, stream_bool, tools_json_str or "[]"
  )
end

function M.host_process_chunk(chunk_utf8)
  return M.process_stream_chunk(_G.AIGM_SESSION, chunk_utf8)
end

function M.host_finalize_tail()
  return M.finalize_stream_tail(_G.AIGM_SESSION)
end

function M.host_tool_calls_json()
  return M.tool_calls_json(_G.AIGM_SESSION)
end

function M.host_stream_content()
  return M.stream_content(_G.AIGM_SESSION)
end

function M.host_session_reset_stream()
  M.session_reset_stream(_G.AIGM_SESSION)
end

function M.host_messages_json()
  return json.encode(_G.AIGM_SESSION.messages)
end

function M.host_process_chunk_json(chunk_utf8)
  local t = M.process_stream_chunk(_G.AIGM_SESSION, chunk_utf8)
  return json.encode(t)
end

function M.host_finalize_tail_json()
  local t = M.finalize_stream_tail(_G.AIGM_SESSION)
  return json.encode(t)
end


function M.host_parse_url_json(u)
  local p = M.parse_base_url(u)
  if not p then return "{}" end
  return json.encode(p)
end

function M.host_request_path(path_prefix)
  return M.request_path(path_prefix)
end

function M.host_authorization_header(api_key)
  return "Authorization: Bearer " .. (api_key or "")
end

--- One chat/completions HTTP attempt: bump round counter, build body + URL parts for any host (portable core).
function M.host_prepare_chat_http_json(base_url, model, max_tokens, stream_bool, tools_json_str, api_key)
  local s = _G.AIGM_SESSION
  if not s then
    return json.encode({ ok = false, error = "no_session" })
  end
  local parsed = M.parse_base_url(base_url)
  if not parsed then
    return json.encode({ ok = false, error = "bad_base_url" })
  end
  s.http_round_count = (s.http_round_count or 0) + 1
  if s.http_round_count > M.AGENT_TOOL_ROUNDS_MAX then
    return json.encode({ ok = false, error = "tool_rounds_exceeded" })
  end
  local body = M.build_chat_completions_payload_from_tools_json(
    s,
    model,
    max_tokens,
    stream_bool,
    tools_json_str or "[]"
  )
  local path_prefix = parsed.path_prefix or ""
  local path = M.request_path(path_prefix)
  local headers = {
    "Content-Type: application/json",
    M.host_authorization_header(api_key),
    "Accept: text/event-stream",
  }
  return json.encode({
    ok = true,
    host = parsed.host,
    port = parsed.port,
    tls = parsed.tls,
    path = path,
    headers = headers,
    body = body,
  })
end

--- After SSE body is fully read + finalize_stream_tail equivalent run by host, persist assistant + decide tool loop.
function M.host_commit_assistant_after_stream_json()
  local s = _G.AIGM_SESSION
  if not s then
    return json.encode({ ok = false, error = "no_session" })
  end
  local content = M.stream_content(s) or ""
  local tc_str = M.tool_calls_json(s)
  local tc = {}
  if tc_str and tc_str ~= "" and tc_str ~= "[]" then
    local ok, decoded = pcall(json.decode, tc_str)
    if ok and type(decoded) == "table" then
      tc = decoded
    end
  end
  M.append_assistant(s, content, tc)
  local continue_next = #tc > 0
  return json.encode({
    ok = true,
    continue = continue_next,
    content = content,
    tool_calls = tc,
  })
end

return M
