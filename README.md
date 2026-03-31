# AIGM

Pure AIGM branch focused on runtime-native Agent orchestration for Godot.

## Scope of this branch

- Keep only AIGM core docs and minimal runtime integration code.
- Exclude `tests/testsandbox` and unrelated gameplay prototype content.
- Use `tests/llm_talk_cursor/agents_wnd.tscn` as the default run scene.

## Quick start

1. Open `godot_proj/aigm/project.godot` in Godot 4.6+.
2. Copy `godot_proj/aigm/tests/llm_talk_cursor/config.example.json` to `config.json`.
3. Fill your API config and run the project.
