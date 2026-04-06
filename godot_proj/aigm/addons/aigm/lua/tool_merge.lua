-- OpenAI-style streamed tool_calls merge (ported from aigm_tool_call_merger.gd).

local M = {}

local function empty_call()
  return { id = "", type = "function", ["function"] = { name = "", arguments = "" } }
end

local function next_index(tool_call_map)
  local max_k = -1
  for k, _ in pairs(tool_call_map) do
    local n = tonumber(k)
    if n and n > max_k then max_k = n end
  end
  return max_k + 1
end

function M.resolve_delta_index(tool_call_map, tc_part)
  if tc_part.index ~= nil then
    return tonumber(tc_part.index) or 0
  end
  local part_id = (tc_part.id or ""):gsub("^%s*(.-)%s*$", "%1")
  if part_id ~= "" then
    for k, existing in pairs(tool_call_map) do
      if type(existing) == "table" and (existing.id or "") == part_id then
        return tonumber(k) or 0
      end
    end
  end
  local pfn = tc_part["function"]
  if type(pfn) == "table" then
    local n = (pfn.name or ""):gsub("^%s*(.-)%s*$", "%1")
    local a = pfn.arguments or ""
    if n == "" and a ~= "" and next(tool_call_map) ~= nil then
      local max_k = -1
      for k, _ in pairs(tool_call_map) do
        local nk = tonumber(k)
        if nk and nk > max_k then max_k = nk end
      end
      return max_k
    end
  end
  return next_index(tool_call_map)
end

function M.merge_delta(tool_call_map, tc_part)
  local idx = M.resolve_delta_index(tool_call_map, tc_part)
  local merged = tool_call_map[idx] or empty_call()
  local part_id = tc_part.id or ""
  if part_id ~= "" then merged.id = part_id end
  local pfn = tc_part["function"]
  if type(pfn) == "table" then
    local fnm = merged["function"] or { name = "", arguments = "" }
    local n = pfn.name or ""
    if n ~= "" then fnm.name = n end
    local a = pfn.arguments or ""
    if a ~= "" then fnm.arguments = (fnm.arguments or "") .. a end
    merged["function"] = fnm
  end
  tool_call_map[idx] = merged
end

function M.merge_snapshot(tool_call_map, tc_full)
  local fn_v0 = tc_full["function"]
  if type(fn_v0) ~= "table" then return end
  local name0 = (fn_v0.name or ""):gsub("^%s*(.-)%s*$", "%1")
  local args0 = (fn_v0.arguments or ""):gsub("^%s*(.-)%s*$", "%1")
  if name0 == "" and args0 == "" then return end
  local idx
  if tc_full.index ~= nil then
    idx = tonumber(tc_full.index) or 0
  else
    idx = next_index(tool_call_map)
  end
  local merged = tool_call_map[idx] or empty_call()
  local cid = tc_full.id or ""
  if cid ~= "" then merged.id = cid end
  local ctype = tc_full.type or ""
  if ctype ~= "" then merged.type = ctype end
  local fn_v = tc_full["function"]
  if type(fn_v) == "table" then
    local out_fn = merged["function"] or { name = "", arguments = "" }
    local n = fn_v.name or ""
    if n ~= "" then out_fn.name = n end
    local a = fn_v.arguments or ""
    if a ~= "" then out_fn.arguments = a end
    merged["function"] = out_fn
  end
  tool_call_map[idx] = merged
end

function M.merge_legacy_function_call(tool_call_map, fc)
  local n0 = (fc.name or ""):gsub("^%s*(.-)%s*$", "%1")
  local a0 = (fc.arguments or ""):gsub("^%s*(.-)%s*$", "%1")
  if n0 == "" and a0 == "" then return end
  local idx = next_index(tool_call_map)
  local merged = tool_call_map[idx] or empty_call()
  local out_fn = merged["function"] or { name = "", arguments = "" }
  local n = fc.name or ""
  if n ~= "" then out_fn.name = n end
  local a = fc.arguments or ""
  if a ~= "" then out_fn.arguments = a end
  merged["function"] = out_fn
  tool_call_map[idx] = merged
end

function M.map_to_sorted_array(tool_call_map)
  local keys = {}
  for k, _ in pairs(tool_call_map) do
    table.insert(keys, tonumber(k) or 0)
  end
  table.sort(keys)
  local out = {}
  for _, k in ipairs(keys) do
    local call = tool_call_map[k]
    if type(call) == "table" then
      if (call.id or "") == "" then
        call.id = "tool_call_" .. tostring(k)
      end
      table.insert(out, call)
    end
  end
  return out
end

return M
