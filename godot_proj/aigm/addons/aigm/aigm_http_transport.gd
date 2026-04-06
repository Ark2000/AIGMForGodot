extends RefCounted
class_name AigmHttpTransport
## One-shot POST + SSE body read via HTTPClient only. No agent policy.

const AigmLuaHost := preload("res://addons/aigm/aigm_lua_host.gd")

const HTTP_CONNECT_DEADLINE_MS := 30000
const HTTP_HEADER_DEADLINE_MS := 120000
const HTTP_STREAM_IDLE_DEADLINE_MS := 180000

var _stream: Node
var _lua: AigmLuaHost


func _init(stream: Node, lua_host: AigmLuaHost) -> void:
	_stream = stream
	_lua = lua_host


func request_stream_completion(prep: Dictionary) -> Dictionary:
	var body := str(prep.get("body", ""))
	var path := str(prep.get("path", "/chat/completions"))
	var headers := PackedStringArray()
	var hv: Variant = prep.get("headers", [])
	if hv is Array:
		for h in hv as Array:
			headers.append(str(h))
	if headers.is_empty():
		headers = PackedStringArray(
			["Content-Type: application/json", "Authorization: Bearer ", "Accept: text/event-stream"]
		)
	var http := HTTPClient.new()
	if _stream.has_method("aigm_bind_http"):
		_stream.call("aigm_bind_http", http)
	var tls_opts: TLSOptions = null
	if bool(prep.get("tls", false)):
		tls_opts = TLSOptions.client()
	var host := str(prep.get("host", ""))
	var port := int(prep.get("port", 443))
	var err := http.connect_to_host(host, port, tls_opts)
	if err != OK:
		return {"ok": false, "error": "connect_%d" % err}
	var connect_ready := await _wait_http_until_status(http, HTTPClient.STATUS_CONNECTED, HTTP_CONNECT_DEADLINE_MS, "connect_timeout")
	if not bool(connect_ready.get("ok", false)):
		return connect_ready
	err = http.request(HTTPClient.METHOD_POST, path, headers, body)
	if err != OK:
		http.close()
		return {"ok": false, "error": "request_%d" % err}
	var header_ready := await _wait_http_until_status(http, HTTPClient.STATUS_BODY, HTTP_HEADER_DEADLINE_MS, "header_timeout")
	if not bool(header_ready.get("ok", false)):
		return header_ready
	return await _consume_stream_body(http)


func _http_status_is_fatal(st: int) -> bool:
	return (
		st == HTTPClient.STATUS_CANT_RESOLVE
		or st == HTTPClient.STATUS_CANT_CONNECT
		or st == HTTPClient.STATUS_CONNECTION_ERROR
		or st == HTTPClient.STATUS_TLS_HANDSHAKE_ERROR
	)


func _wait_http_until_status(http: HTTPClient, target_status: int, timeout_ms: int, timeout_error: String) -> Dictionary:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while http.get_status() != target_status:
		if bool(_stream.call("aigm_is_cancelled")):
			http.close()
			return {"ok": false, "cancelled": true}
		if _http_status_is_fatal(http.get_status()) or Time.get_ticks_msec() > deadline:
			http.close()
			return {"ok": false, "error": timeout_error}
		http.poll()
		await _stream.get_tree().process_frame
	return {"ok": true}


func _consume_stream_body(http: HTTPClient) -> Dictionary:
	var did_emit_reset := false
	var idle_deadline := Time.get_ticks_msec() + HTTP_STREAM_IDLE_DEADLINE_MS
	_lua.session_reset_stream()
	while http.get_status() != HTTPClient.STATUS_DISCONNECTED:
		if bool(_stream.call("aigm_is_cancelled")):
			http.close()
			return {"ok": false, "cancelled": true}
		http.poll()
		if http.get_status() == HTTPClient.STATUS_BODY:
			var chunk := http.read_response_body_chunk()
			if chunk.size() > 0:
				idle_deadline = Time.get_ticks_msec() + HTTP_STREAM_IDLE_DEADLINE_MS
				var chunk_s := chunk.get_string_from_utf8()
				var pr: Dictionary = _lua.process_stream_chunk(chunk_s)
				if not bool(pr.get("ok", false)):
					http.close()
					return {"ok": false, "error": "sse_parse"}
				var pieces: Variant = pr.get("pieces", [])
				if bool(pr.get("need_reply_reset", false)) and not did_emit_reset:
					_stream.assistant_reply_reset.emit()
					did_emit_reset = true
				if pieces is Array:
					for p in pieces as Array:
						var piece := str(p)
						if not piece.is_empty():
							_stream.assistant_reply_piece.emit(piece)
				if bool(pr.get("stream_done", false)):
					break
		if Time.get_ticks_msec() > idle_deadline:
			break
		await _stream.get_tree().process_frame
	if http.get_status() != HTTPClient.STATUS_DISCONNECTED:
		http.close()
	var ft: Dictionary = _lua.finalize_stream_tail()
	if bool(ft.get("need_reply_reset", false)) and not did_emit_reset:
		_stream.assistant_reply_reset.emit()
		did_emit_reset = true
	var tail_pieces: Variant = ft.get("pieces", [])
	if tail_pieces is Array:
		for p in tail_pieces as Array:
			var piece := str(p)
			if not piece.is_empty():
				_stream.assistant_reply_piece.emit(piece)
	if did_emit_reset:
		_stream.assistant_reply_finished.emit()
	return {"ok": true}
