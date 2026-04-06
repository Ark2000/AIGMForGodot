-- SSE line buffer + OpenAI chat.completion.chunk JSON (Godot-agnostic).
package.path = "res://addons/aigm/lua/?.lua;" .. package.path

local json = require("json")
local merge = require("tool_merge")

local M = {}

function M.consume_sse_buffer(buffer, event_data, done_in, did_emit_reset, content, tool_call_map)
  local b = buffer or ""
  local e = event_data or ""
  local d = done_in or false
  local reset = did_emit_reset or false
  local out = content or ""
  local pieces_all = {}
  while true do
    local nl = b:find("\n", 1, true)
    if not nl then break end
    local line = b:sub(1, nl - 1):gsub("\r", "")
    b = b:sub(nl + 1)
    if line:sub(1, 5) == "data:" then
      local p = (line:sub(6):gsub("^%s*(.-)%s*$", "%1"))
      if p == "[DONE]" then
        if e ~= "" then
          local parsed = M.consume_sse_event(e, reset, out, tool_call_map)
          reset = parsed.did_emit_reset
          out = parsed.content
          for _, x in ipairs(parsed.content_pieces or {}) do
            table.insert(pieces_all, x)
          end
        end
        e = ""
        d = true
        break
      end
      if e ~= "" then e = e .. "\n" end
      e = e .. p
    elseif line == "" then
      if e ~= "" then
        local parsed = M.consume_sse_event(e, reset, out, tool_call_map)
        reset = parsed.did_emit_reset
        out = parsed.content
        for _, x in ipairs(parsed.content_pieces or {}) do
          table.insert(pieces_all, x)
        end
        e = ""
      end
    elseif e ~= "" then
      e = e .. "\n" .. line
    end
  end
  return {
    buffer = b,
    event_data = e,
    done = d,
    did_emit_reset = reset,
    content = out,
    content_pieces = pieces_all,
  }
end

function M.consume_sse_event(data, did_emit_reset_ref, content_ref, tool_call_map)
  local did_emit_reset = did_emit_reset_ref
  local content = content_ref
  local content_pieces = {}
  local ok, obj = pcall(json.decode, data)
  if not ok or type(obj) ~= "table" then
    return { did_emit_reset = did_emit_reset, content = content, content_pieces = content_pieces }
  end
  local choices = obj.choices
  if type(choices) ~= "table" or #choices < 1 then
    return { did_emit_reset = did_emit_reset, content = content, content_pieces = content_pieces }
  end
  local choice0 = choices[1]
  if type(choice0) ~= "table" then
    return { did_emit_reset = did_emit_reset, content = content, content_pieces = content_pieces }
  end
  local delta = choice0.delta
  if type(delta) ~= "table" then delta = {} end
  local piece = delta.content or ""
  if piece ~= "" then
    if not did_emit_reset then
      did_emit_reset = true
    end
    content = content .. piece
    table.insert(content_pieces, piece)
  end
  local tool_calls = delta.tool_calls
  if type(tool_calls) == "table" then
    for _, tc in ipairs(tool_calls) do
      if type(tc) == "table" then
        merge.merge_delta(tool_call_map, tc)
      end
    end
  end
  local msg_v = choice0.message
  if type(msg_v) == "table" then
    local msg_tool_calls = msg_v.tool_calls
    if type(msg_tool_calls) == "table" then
      for _, tc2 in ipairs(msg_tool_calls) do
        if type(tc2) == "table" then
          merge.merge_snapshot(tool_call_map, tc2)
        end
      end
    end
    local legacy_msg_fc = msg_v.function_call
    if type(legacy_msg_fc) == "table" then
      merge.merge_legacy_function_call(tool_call_map, legacy_msg_fc)
    end
  end
  local top_tool_calls = choice0.tool_calls
  if type(top_tool_calls) == "table" then
    for _, tc3 in ipairs(top_tool_calls) do
      if type(tc3) == "table" then
        merge.merge_snapshot(tool_call_map, tc3)
      end
    end
  end
  local legacy_fc = choice0.function_call
  if type(legacy_fc) == "table" then
    merge.merge_legacy_function_call(tool_call_map, legacy_fc)
  end
  return {
    did_emit_reset = did_emit_reset,
    content = content,
    content_pieces = content_pieces,
  }
end

return M
