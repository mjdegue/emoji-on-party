extends Node

signal connected
signal disconnected
signal session_created(code: String)
signal player_joined(player_id: String, player_name: String)
signal player_rejoined(player_id: String, player_name: String)
signal player_disconnected(player_id: String)
signal message_received(type: String, payload: Dictionary, from: String)

@export var relay_url := "ws://localhost:8080"
const RECONNECT_DELAY := 3.0
const HEARTBEAT_INTERVAL := 25.0

var _socket := WebSocketPeer.new()
var _state := WebSocketPeer.STATE_CLOSED
var _session_code := ""
var _reconnect_timer := 0.0
var _heartbeat_timer := 0.0
var _should_reconnect := false


func connect_to_relay() -> void:
	var err := _socket.connect_to_url(relay_url)
	if err != OK:
		push_error("Failed to connect to relay: %s" % err)
		return
	_should_reconnect = true


func create_session() -> void:
	_send({"type": "host_create_session", "payload": {}})


func send_to_player(player_id: String, type: String, payload: Dictionary) -> void:
	_send({"type": type, "payload": payload, "to": player_id})


func send_to_all(type: String, payload: Dictionary) -> void:
	_send({"type": type, "payload": payload, "to": "all"})


func _process(delta: float) -> void:
	_socket.poll()
	var new_state := _socket.get_ready_state()

	if new_state != _state:
		_state = new_state
		_on_state_changed(new_state)

	match _state:
		WebSocketPeer.STATE_OPEN:
			_heartbeat_timer += delta
			if _heartbeat_timer >= HEARTBEAT_INTERVAL:
				_heartbeat_timer = 0.0
				_send({"type": "ping"})
			while _socket.get_available_packet_count() > 0:
				var raw := _socket.get_packet().get_string_from_utf8()
				_on_message(raw)
		WebSocketPeer.STATE_CLOSED:
			if _should_reconnect:
				_reconnect_timer += delta
				if _reconnect_timer >= RECONNECT_DELAY:
					_reconnect_timer = 0.0
					connect_to_relay()


func _on_state_changed(new_state: int) -> void:
	match new_state:
		WebSocketPeer.STATE_OPEN:
			print("Connected to relay")
			_reconnect_timer = 0.0
			connected.emit()
		WebSocketPeer.STATE_CLOSED:
			print("Disconnected from relay")
			disconnected.emit()


func _on_message(raw: String) -> void:
	var parsed = JSON.parse_string(raw)
	if parsed == null:
		push_warning("Failed to parse message: %s" % raw)
		return

	var msg: Dictionary = parsed
	var type: String = msg.get("type", "")
	var payload: Dictionary = msg.get("payload", {})
	var from: String = str(msg.get("from", ""))

	match type:
		"session_created":
			_session_code = payload.get("code", "")
			print("Session created: %s" % _session_code)
			session_created.emit(_session_code)
		"player_join":
			var player_id: String = payload.get("playerId", "")
			var player_name: String = payload.get("name", "")
			print("Player joined: %s (%s)" % [player_name, player_id])
			player_joined.emit(player_id, player_name)
		"player_rejoin":
			var rejoin_id: String = payload.get("playerId", "")
			var rejoin_name: String = payload.get("name", "")
			print("Player rejoin: %s (%s)" % [rejoin_name, rejoin_id])
			player_rejoined.emit(rejoin_id, rejoin_name)
		"player_disconnected":
			var player_id: String = payload.get("playerId", "")
			print("Player disconnected: %s" % player_id)
			player_disconnected.emit(player_id)
		"pong":
			pass
		"error":
			push_error("Relay error: %s" % payload.get("message", "unknown"))
		_:
			message_received.emit(type, payload, from)


func _send(msg: Dictionary) -> void:
	if _state != WebSocketPeer.STATE_OPEN:
		push_warning("Cannot send, socket not open")
		return
	_socket.send_text(JSON.stringify(msg))


func get_session_code() -> String:
	return _session_code
