extends CanvasLayer

const AIGM_CONTROLLER_SCRIPT := preload("res://addons/aigm/aigm_stream.gd")
const HOTKEY_CODE_TOGGLE := 96
const TYPEWRITER_CPS_BASE := 38.0
const TYPEWRITER_CPS_MAX := 220.0

## Per-tab UI + stream controller binding.
class AgentPageState extends RefCounted:
	var page: RichTextLabel
	var controller: Node
	var body := ""
	var stream_base := ""
	var stream_reply := ""
	var display_reply_len := 0
	var typewriter_accum := 0.0
	var stream_finished := false
	var waiting := false
	var base_title := ""
	var ai_label := ""
	var is_typing := false

	func reset_stream(clear_body: bool) -> void:
		if clear_body:
			body = ""
		stream_base = ""
		stream_reply = ""
		display_reply_len = 0
		typewriter_accum = 0.0
		is_typing = false
		stream_finished = false


@onready var _bg: Panel = $Bg
@onready var _root_vbox: VBoxContainer = $VBoxContainer
@onready var _title_btn: Button = $VBoxContainer/TopBar/Title
@onready var _add_btn: Button = $VBoxContainer/TopBar/Add
@onready var _close_btn: Button = $VBoxContainer/TopBar/Close
@onready var _contents: TabContainer = $VBoxContainer/Contents
@onready var _input_edit: LineEdit = $VBoxContainer/InputArea/LineEdit
@onready var _send_btn: Button = $VBoxContainer/InputArea/Send

var _ui_open := false
var _agent_serial := 1
var _page_states: Dictionary = {} # RichTextLabel -> AgentPageState
var _controllers_host: Node


func _ready() -> void:
	set_process_input(true)
	set_process(false)
	_add_btn.pressed.connect(_on_add_pressed)
	_close_btn.pressed.connect(_on_close_pressed)
	_contents.tab_changed.connect(_on_tab_changed)

	var tab_bar := _contents.get_tab_bar()
	tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ALWAYS
	tab_bar.tab_close_pressed.connect(_on_tab_close_pressed)

	_send_btn.pressed.connect(_on_send_pressed)
	_input_edit.text_submitted.connect(_on_input_submitted)

	for child in _contents.get_children():
		child.queue_free()

	_controllers_host = Node.new()
	_controllers_host.name = "ControllersHost"
	add_child(_controllers_host)

	_spawn_agent_tab(true)
	_set_ui_open(false)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	if k.keycode == HOTKEY_CODE_TOGGLE or k.keycode == KEY_QUOTELEFT:
		_set_ui_open(not _ui_open)
		get_viewport().set_input_as_handled()


func _set_ui_open(open: bool) -> void:
	_ui_open = open
	_bg.visible = open
	_root_vbox.visible = open
	_sync_input_waiting_state()
	if open:
		_input_edit.grab_focus()


func _spawn_agent_tab(make_current: bool) -> void:
	var controller := Node.new()
	controller.set_script(AIGM_CONTROLLER_SCRIPT)
	_controllers_host.add_child(controller)

	var page := RichTextLabel.new()
	page.name = "Agent%d" % _agent_serial
	page.bbcode_enabled = true
	page.scroll_following = true
	page.selection_enabled = true
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_contents.add_child(page)

	var tab_idx := _contents.get_tab_count() - 1
	var tab_title := "Agent %d" % _agent_serial
	_contents.set_tab_title(tab_idx, tab_title)

	var st := AgentPageState.new()
	st.page = page
	st.controller = controller
	st.base_title = tab_title
	_page_states[page] = st

	_bind_controller_signals(controller, page)
	_agent_serial += 1

	if make_current:
		_contents.current_tab = tab_idx
	_sync_title()
	_sync_input_waiting_state()
	_input_edit.grab_focus()


func _state_for_page(page: RichTextLabel) -> AgentPageState:
	return _page_states.get(page, null) as AgentPageState


func _close_tab_by_index(tab_idx: int) -> void:
	if tab_idx < 0 or tab_idx >= _contents.get_tab_count():
		return
	var page := _contents.get_child(tab_idx) as RichTextLabel
	if page == null:
		return
	var st := _state_for_page(page)
	if st != null and st.controller != null and st.controller.has_method("cancel_current_request"):
		st.controller.call("cancel_current_request")

	_page_states.erase(page)
	page.queue_free()
	if st != null and st.controller != null:
		st.controller.queue_free()

	if _contents.get_tab_count() <= 1:
		call_deferred("_ensure_at_least_one_tab")
	else:
		call_deferred("_sync_title")
		call_deferred("_sync_input_waiting_state")
		call_deferred("_focus_input_if_open")


func _ensure_at_least_one_tab() -> void:
	if _contents.get_tab_count() == 0:
		_spawn_agent_tab(true)
	else:
		_sync_title()
		_sync_input_waiting_state()
		_focus_input_if_open()


func _sync_title() -> void:
	_title_btn.text = "Agents (%d Active)" % _contents.get_tab_count()


func _on_add_pressed() -> void:
	_spawn_agent_tab(true)


func _on_close_pressed() -> void:
	_set_ui_open(false)


func _on_tab_close_pressed(tab_idx: int) -> void:
	_close_tab_by_index(tab_idx)


func _on_tab_changed(_tab_idx: int) -> void:
	_focus_input_if_open()
	_sync_input_waiting_state()


func _on_send_pressed() -> void:
	_submit_input_to_current_agent()


func _on_input_submitted(_text: String) -> void:
	_submit_input_to_current_agent()


func _submit_input_to_current_agent() -> void:
	var text := _input_edit.text.strip_edges()
	if text.is_empty():
		return
	var page := _get_current_page()
	if page == null:
		return
	var st := _state_for_page(page)
	if st != null and st.controller != null and st.controller.has_method("submit_user_message"):
		st.controller.call("submit_user_message", text)
	_input_edit.clear()
	_focus_input_if_open()


func _focus_input_if_open() -> void:
	if _ui_open:
		_input_edit.grab_focus()


func _get_current_page() -> RichTextLabel:
	if _contents.get_tab_count() == 0:
		return null
	var idx := _contents.current_tab
	if idx < 0 or idx >= _contents.get_tab_count():
		return null
	return _contents.get_child(idx) as RichTextLabel


func _bind_controller_signals(controller: Node, page: RichTextLabel) -> void:
	if controller.has_signal("chat_line"):
		controller.connect("chat_line", Callable(self, "_on_agent_chat_line").bind(page))
	if controller.has_signal("chat_cleared"):
		controller.connect("chat_cleared", Callable(self, "_on_agent_chat_cleared").bind(page))
	if controller.has_signal("assistant_reply_reset"):
		controller.connect("assistant_reply_reset", Callable(self, "_on_agent_assistant_reset").bind(page))
	if controller.has_signal("assistant_reply_piece"):
		controller.connect("assistant_reply_piece", Callable(self, "_on_agent_assistant_piece").bind(page))
	if controller.has_signal("assistant_reply_finished"):
		controller.connect("assistant_reply_finished", Callable(self, "_on_agent_assistant_finished").bind(page))
	if controller.has_signal("waiting_changed"):
		controller.connect("waiting_changed", Callable(self, "_on_agent_waiting_changed").bind(page))


func _on_agent_chat_line(role: String, text: String, page: RichTextLabel) -> void:
	var st := _state_for_page(page)
	if st == null:
		return
	var role_color := _role_color(role)
	var ts_part := ""
	if role == "你" or role == "工具":
		ts_part = "[color=#94a3b8]%s[/color] " % _ts()
	var line := "%s[color=%s][b][%s][/b][/color] %s\n" % [ts_part, role_color, _esc(role), _esc(text)]
	st.body += line
	if st.is_typing:
		st.stream_base += line
		_render_stream_preview(st)
	else:
		page.text = st.body


func _on_agent_chat_cleared(page: RichTextLabel) -> void:
	var st := _state_for_page(page)
	if st == null:
		return
	st.reset_stream(true)
	st.ai_label = ""
	page.clear()


func _on_agent_assistant_reset(page: RichTextLabel) -> void:
	var st := _state_for_page(page)
	if st == null:
		return
	var saved_body := st.body
	st.reset_stream(false)
	st.stream_base = saved_body
	st.ai_label = _ai_label_with_ts()
	page.text = st.body + st.ai_label


func _on_agent_assistant_piece(piece: String, page: RichTextLabel) -> void:
	var st := _state_for_page(page)
	if st == null:
		return
	st.stream_reply += piece
	st.is_typing = true
	set_process(true)


func _on_agent_assistant_finished(page: RichTextLabel) -> void:
	var st := _state_for_page(page)
	if st == null:
		return
	st.stream_finished = true
	st.is_typing = true
	set_process(true)


func _on_agent_waiting_changed(waiting: bool, page: RichTextLabel) -> void:
	var st := _state_for_page(page)
	if st == null:
		return
	st.waiting = waiting
	_refresh_tab_waiting_badges()
	if page != _get_current_page():
		return
	_sync_input_waiting_state()


func _role_color(role: String) -> String:
	match role:
		"系统":
			return "#94a3b8"
		"你":
			return "#38bdf8"
		"AI":
			return "#c4b5fd"
		"工具":
			return "#86efac"
		_:
			return "#e2e8f0"


func _esc(s: String) -> String:
	return s.replace("[", "\\[").replace("]", "\\]")


func _sync_input_waiting_state() -> void:
	var page := _get_current_page()
	if page == null:
		_send_btn.disabled = false
		_input_edit.editable = true
		_send_btn.text = " Enter "
		return
	var st := _state_for_page(page)
	var waiting := false
	if st != null and st.controller != null:
		waiting = st.controller.get("waiting_response") == true
	_send_btn.disabled = waiting
	_input_edit.editable = not waiting
	_send_btn.text = "[思考中]" if waiting else " Enter "


func _refresh_tab_waiting_badges() -> void:
	for i in range(_contents.get_tab_count()):
		var page := _contents.get_child(i) as RichTextLabel
		if page == null:
			continue
		var st := _state_for_page(page)
		var base_title := st.base_title if st != null else "Agent"
		var waiting := st.waiting if st != null else false
		var shown := base_title + (" [思考中]" if waiting else "")
		_contents.set_tab_title(i, shown)


func _any_page_typing() -> bool:
	for st in _page_states.values():
		if st is AgentPageState and (st as AgentPageState).is_typing:
			return true
	return false


func _process(delta: float) -> void:
	if not _any_page_typing():
		set_process(false)
		return

	for page in _page_states.keys():
		var st := _state_for_page(page)
		if st == null or not st.is_typing:
			continue

		var full_reply: String = st.stream_reply
		var target_len := full_reply.length()
		if target_len <= 0:
			continue

		var display_len: int = st.display_reply_len
		if display_len >= target_len:
			if not st.stream_finished:
				continue
			_finalize_stream_render(st)
			if not _any_page_typing():
				set_process(false)
			continue

		var behind: int = target_len - display_len
		var speed: float = TYPEWRITER_CPS_BASE + minf(float(behind) * 1.8, TYPEWRITER_CPS_MAX - TYPEWRITER_CPS_BASE)
		var accum: float = st.typewriter_accum
		accum += delta * speed
		var inc := int(floor(accum))
		if inc <= 0:
			st.typewriter_accum = accum
			continue
		var new_len: int = min(target_len, display_len + inc)
		accum -= float(new_len - display_len)
		st.typewriter_accum = accum
		st.display_reply_len = new_len
		_render_stream_preview(st, new_len)


func _render_stream_preview(st: AgentPageState, display_len_override: int = -1) -> void:
	var display_len: int = st.display_reply_len
	if display_len_override >= 0:
		display_len = display_len_override
	display_len = min(display_len, st.stream_reply.length())
	var shown_reply: String = st.stream_reply.substr(0, display_len)
	var label := st.ai_label if not st.ai_label.is_empty() else _ai_label_with_ts()
	st.page.text = st.stream_base + label + _esc(shown_reply)


func _finalize_stream_render(st: AgentPageState) -> void:
	var label := st.ai_label if not st.ai_label.is_empty() else _ai_label_with_ts()
	st.body = st.stream_base + label + _esc(st.stream_reply) + "\n"
	st.typewriter_accum = 0.0
	st.is_typing = false
	st.stream_finished = false
	st.page.text = st.body


func _ts() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "[%02d:%02d:%02d]" % [int(d.get("hour", 0)), int(d.get("minute", 0)), int(d.get("second", 0))]


func _ai_label_with_ts() -> String:
	return "[color=#94a3b8]%s[/color] [color=#c4b5fd][b][AI][/b][/color] " % _ts()
