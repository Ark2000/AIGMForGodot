-- OpenAI/Kimi-compatible base URL → host, port, tls, path_prefix (Godot-agnostic).

local M = {}

function M.parse_base_url(url)
  local u = url:match("^%s*(.-)%s*$") or ""
  local use_tls = false
  if u:sub(1, 8) == "https://" then
    use_tls = true
    u = u:sub(9)
  elseif u:sub(1, 7) == "http://" then
    u = u:sub(8)
  else
    return nil
  end
  local slash = u:find("/", 1, true)
  local host_part = slash and u:sub(1, slash - 1) or u
  local path_prefix = slash and u:sub(slash) or ""
  local host = host_part
  local port = use_tls and 443 or 80
  local colon = host_part:find(":", 1, true)
  if colon then
    host = host_part:sub(1, colon - 1)
    port = tonumber(host_part:sub(colon + 1)) or port
  end
  return { host = host, port = port, tls = use_tls, path_prefix = path_prefix }
end

return M
