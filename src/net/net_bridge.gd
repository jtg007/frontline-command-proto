class_name NetBridge
extends Node
## The ONLY node with RPCs (lives at /root/Main/Net on server and clients).
## It checks who sent a message and forwards typed arguments as signals.
## Game rules never live here: ServerGame / ClientGame own all decisions.
##
## Channels: 0 reliable ordered (intents, results, roster, orders) ·
##           1 input (unreliable sequenced) · 2 snapshots (unreliable sequenced).

# ---- client -> server --------------------------------------------------------
signal hello_received(peer_id: int, protocol: int, build_id: String, player_name: String, team: int)
signal input_received(peer_id: int, seq: int, move: Vector2, yaw: float, pitch: float, buttons: int)
signal action_received(peer_id: int, request_id: int, action: int, arg: Vector3)
signal debug_tail_requested(peer_id: int, bug_id: String)

# ---- server -> client --------------------------------------------------------
signal welcomed(my_id: int, team: int, server_build: String, map_id: String, tick: int)
signal rejected(reason: String)
signal roster_received(entries: Array)
signal snapshot_received(bytes: PackedByteArray)
signal waypoint_received(team: int, active: bool, pos: Vector3, placed_by: String, serial: int)
signal action_result_received(request_id: int, ok: bool, message: String)
signal notice_received(text: String)
signal debug_tail_received(bug_id: String, lines: PackedStringArray)


# ============================ client-side senders ============================

func send_hello(protocol: int, build_id: String, player_name: String, team: int) -> void:
	_rpc_hello.rpc_id(1, protocol, build_id, player_name, team)


func send_input(seq: int, move: Vector2, yaw: float, pitch: float, buttons: int) -> void:
	_rpc_input.rpc_id(1, seq, move, yaw, pitch, buttons)


func send_action(request_id: int, action: int, arg: Vector3) -> void:
	_rpc_action.rpc_id(1, request_id, action, arg)


func request_debug_tail(bug_id: String) -> void:
	_rpc_debug_tail_request.rpc_id(1, bug_id)


# ============================ server-side senders ============================

func send_welcome(peer_id: int, team: int, server_build: String, map_id: String, tick: int) -> void:
	_rpc_welcome.rpc_id(peer_id, peer_id, team, server_build, map_id, tick)


func send_reject(peer_id: int, reason: String) -> void:
	_rpc_reject.rpc_id(peer_id, reason)


func send_roster(peer_id: int, entries: Array) -> void:
	_rpc_roster.rpc_id(peer_id, entries)


func send_snapshot(peer_id: int, bytes: PackedByteArray) -> void:
	_rpc_snapshot.rpc_id(peer_id, bytes)


func send_waypoint(peer_id: int, team: int, active: bool, pos: Vector3, placed_by: String, serial: int) -> void:
	_rpc_waypoint.rpc_id(peer_id, team, active, pos, placed_by, serial)


func send_action_result(peer_id: int, request_id: int, ok: bool, message: String) -> void:
	_rpc_action_result.rpc_id(peer_id, request_id, ok, message)


func send_notice(peer_id: int, text: String) -> void:
	_rpc_notice.rpc_id(peer_id, text)


func send_debug_tail(peer_id: int, bug_id: String, lines: PackedStringArray) -> void:
	_rpc_debug_tail.rpc_id(peer_id, bug_id, lines)


# ================================ RPC endpoints ==============================
# client -> server

@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_hello(protocol: int, build_id: String, player_name: String, team: int) -> void:
	if multiplayer.is_server():
		hello_received.emit(multiplayer.get_remote_sender_id(), protocol, build_id, player_name, team)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _rpc_input(seq: int, move: Vector2, yaw: float, pitch: float, buttons: int) -> void:
	if multiplayer.is_server():
		input_received.emit(multiplayer.get_remote_sender_id(), seq, move, yaw, pitch, buttons)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_action(request_id: int, action: int, arg: Vector3) -> void:
	if multiplayer.is_server():
		action_received.emit(multiplayer.get_remote_sender_id(), request_id, action, arg)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_debug_tail_request(bug_id: String) -> void:
	if multiplayer.is_server():
		debug_tail_requested.emit(multiplayer.get_remote_sender_id(), bug_id)


# server -> client ("authority" = only the server may call these)

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_welcome(my_id: int, team: int, server_build: String, map_id: String, tick: int) -> void:
	welcomed.emit(my_id, team, server_build, map_id, tick)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_reject(reason: String) -> void:
	rejected.emit(reason)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_roster(entries: Array) -> void:
	roster_received.emit(entries)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _rpc_snapshot(bytes: PackedByteArray) -> void:
	snapshot_received.emit(bytes)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_waypoint(team: int, active: bool, pos: Vector3, placed_by: String, serial: int) -> void:
	waypoint_received.emit(team, active, pos, placed_by, serial)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_action_result(request_id: int, ok: bool, message: String) -> void:
	action_result_received.emit(request_id, ok, message)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_notice(text: String) -> void:
	notice_received.emit(text)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_debug_tail(bug_id: String, lines: PackedStringArray) -> void:
	debug_tail_received.emit(bug_id, lines)
