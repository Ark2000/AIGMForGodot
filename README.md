# AIGM

Pure AIGM branch focused on runtime-native Agent orchestration for Godot.

## Scope of this branch

- Keep only AIGM core docs and minimal runtime integration code.
- Exclude `tests/testsandbox` and unrelated gameplay prototype content.
- Use `addons/aigm/agents_wnd.tscn` as the default run scene.

## Architecture (short)

- **Lua core** (`godot_proj/aigm/addons/aigm/lua/`): OpenAI-compatible chat payloads, SSE parsing, tool-call merging, URL parsing — no Godot APIs.
- **GDScript host** (`aigm_lua_host.gd`, `aigm_stream.gd`): HTTP/TLS, UI signals, loading Lua via [lua-gdextension](https://github.com/gilzoide/lua-gdextension), agent tool execution (`commands.gd`).
- **Lua GDExtension**: add `addons/lua-gdextension/` with prebuilt `build/` (see `godot_proj/aigm/tools/fetch_lua_gdextension_build.ps1` if `build/` is missing after clone).

## Quick start

1. Open `godot_proj/aigm/project.godot` in Godot 4.6+.
2. Ensure `addons/lua-gdextension/build/` exists (run `fetch_lua_gdextension_build.ps1` from repo root if needed).
3. Copy `godot_proj/aigm/addons/aigm/config.example.json` to `config.json`.
4. Fill API config and run the project.

More detail: `godot_proj/aigm/addons/aigm/README.md`.
