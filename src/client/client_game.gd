class_name ClientGame
extends Node
## Game client (Stage-1 netcode): sends inputs + numbered intents, renders interpolated
## server snapshots. The client never decides gameplay outcomes — it only shows them.
##
## Modes come from the server snapshot: Infantry (first person), Driver (third-person
## orbit), Commander (top-down RTS camera), Dead.

signal joined()
signal disconnected(reason: String)
signal action_result(request_id: int, ok: bool, message: String)
signal notice(text: String)
signal waypoint_changed()
signal bug_report_written(path: String)

enum State { MENU, CONNECTING, IN_GAME }
enum Mode { INFANTRY, DRIVER, COMMANDER, DEAD }

const CMD_MIN_HEIGHT: float = 25.0
const CMD_MAX_HEIGHT: float = 140.0
const CMD_PAN_SPEED: float = 1.1  # × height per second
const CMD_ROTATE_SPEED: float = 1.6
const DRIVER_CAM_DISTANCE: float = 9.0
const BUG_REPLY_TIMEOUT_SEC: float = 1.5
const OK_COLOR: Color = Color(0.6, 1.0, 0.65)

var args: LaunchArgs
var net: NetBridge
var map: MapInfo
var events: EventLog = EventLog.new(false)
var frame_stats: FrameStats = FrameStats.new()
var buffer: SnapshotBuffer = SnapshotBuffer.new()
var view: WorldView

var state: State = State.MENU
var mode: Mode = Mode.INFANTRY
var my_id: int = 0
var my_team: int = Teams.NONE
var server_build: String = ""
var server_address: String = ""
var roster_names: Dictionary[int, String] = {}
var roster_teams: Dictionary[int, int] = {}
var commander_of_team: PackedInt32Array = PackedInt32Array([0, 0])

var waypoint_active: bool = false
var waypoint_pos: Vector3 = Vector3.ZERO
var waypoint_by: String = ""
var waypoint_serial: int = 0
## Every waypoint message received this session: [team, active, serial] (used by tests).
var waypoint_log: Array[PackedInt32Array] = []

var look_yaw: float = 0.0
var look_pitch: float = 0.0
## Automated test clients drive the game through these instead of the keyboard.
var bot_controlled: bool = false
var bot_move: Vector2 = Vector2.ZERO
var bot_buttons: int = 0

var _player_name: String = ""
var _preferred_team: int = Teams.NONE
var _reject_reason: String = ""
var _input_seq: int = 0
var _request_id: int = 0
var _pending_actions: Dictionary[int, int] = {}
var _connect_started: float = 0.0
var _last_snapshot_tick: int = -1
var _bad_snapshots: int = 0
var _orbit_yaw: float = 0.0
var _orbit_pitch: float = -0.25
var _cmd_focus: Vector3 = Vector3.ZERO
var _cmd_height: float = 70.0
var _cmd_yaw: float = 0.0
var _menu_orbit: float = 0.0
var _perf_timer: float = 0.0
var _bug_id: String = ""
var _bug_server_lines: PackedStringArray = PackedStringArray()
var _local_server_pid: int = -1
var _camera: Camera3D
var _ui: CanvasLayer
var _hud: Hud
var _menu: JoinMenu
var _cam_ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()


func setup(launch_args: LaunchArgs, bridge: NetBridge, world: Node3D) -> void:
	args = launch_args
	net = bridge
	ClientInput.ensure_actions()
	map = MapInfo.load_into(world)
	view = WorldView.new()
	view.name = "View"
	world.add_child(view)
	_camera = Camera3D.new()
	_camera.fov = 80.0
	_camera.far = 600.0
	world.add_child(_camera)
	_camera.make_current()
	_cam_ray.collision_mask = BodyFactory.LAYER_WORLD

	_ui = CanvasLayer.new()
	add_child(_ui)
	_hud = Hud.new()
	_ui.add_child(_hud)
	_hud.visible = false
	_hud.resume_pressed.connect(_set_menu_open.bind(false))
	_hud.disconnect_pressed.connect(func() -> void: disconnect_from_server("You left the server."))
	_hud.quit_pressed.connect(_quit)
	_menu = JoinMenu.new()
	_ui.add_child(_menu)
	_menu.join_requested.connect(connect_to)
	_menu.host_local_requested.connect(_host_local)
	_menu.quit_requested.connect(_quit)

	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	net.welcomed.connect(_on_welcomed)
	net.rejected.connect(_on_rejected)
	net.roster_received.connect(_on_roster)
	net.snapshot_received.connect(_on_snapshot)
	net.waypoint_received.connect(_on_waypoint)
	net.action_result_received.connect(_on_action_result)
	net.notice_received.connect(_on_notice)
	net.debug_tail_received.connect(_on_debug_tail)

	if args.bot != "":
		var bot := BotBrain.new()
		bot.name = "Bot"
		add_child(bot)
		bot.setup(self, args)
	if args.connect_address != "":
		_menu.visible = false
		connect_to(args.connect_address, args.player_name, args.team)


# ============================== connection ==================================

func connect_to(address: String, player_name: String, team: int) -> void:
	if state != State.MENU:
		return
	server_address = address
	_player_name = player_name
	_preferred_team = team
	_reject_reason = ""
	var host: String = NetProtocol.parse_host(address)
	var port: int = NetProtocol.parse_port(address)
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(host, port, NetProtocol.ENET_CHANNELS)
	if err != OK:
		_menu.set_status("Could not start a connection to %s (%s). Check the address." % [address, error_string(err)], true)
		events.add("NET", "create_client(%s:%d) failed: %s" % [host, port, error_string(err)])
		return
	multiplayer.multiplayer_peer = peer
	state = State.CONNECTING
	_connect_started = _now()
	_menu.set_busy(true)
	_menu.set_status("Connecting to %s:%d …" % [host, port])
	events.add("NET", "connecting to %s:%d" % [host, port])


func disconnect_from_server(reason: String) -> void:
	if state == State.MENU:
		return
	events.add("NET", "disconnect: %s" % reason)
	# Replacing the peer lets SceneMultiplayer clean up its caches before the old peer closes.
	var old_peer: MultiplayerPeer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if old_peer != null:
		old_peer.close()
	state = State.MENU
	my_id = 0
	my_team = Teams.NONE
	buffer.clear()
	view.clear()
	roster_names.clear()
	roster_teams.clear()
	commander_of_team = PackedInt32Array([0, 0])
	waypoint_active = false
	_pending_actions.clear()
	_last_snapshot_tick = -1
	_set_mode(Mode.INFANTRY)
	_hud.visible = false
	_hud.set_menu_open(false)
	_menu.visible = not bot_controlled
	_menu.set_busy(false)
	_menu.set_status(reason, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	disconnected.emit(reason)


func _on_connected() -> void:
	events.add("NET", "connected, sending hello (build %s)" % BuildInfo.build_id())
	net.send_hello(NetProtocol.PROTOCOL_VERSION, BuildInfo.build_id(), _player_name, _preferred_team)


func _on_connection_failed() -> void:
	disconnect_from_server("Could not reach the server at %s. Check the address, or ask the host whether the server is running." % server_address)


func _on_server_disconnected() -> void:
	disconnect_from_server(_reject_reason if _reject_reason != "" else "Lost connection to the server.")


func _on_rejected(reason: String) -> void:
	_reject_reason = reason
	events.add("NET", "rejected: %s" % reason)


func _on_welcomed(id: int, team: int, build: String, map_id: String, server_tick: int) -> void:
	my_id = id
	my_team = team
	server_build = build
	state = State.IN_GAME
	view.hide_player_id = my_id
	_menu.visible = false
	_menu.set_busy(false)
	_hud.visible = true
	events.add("JOIN", "welcome: id %d, team %s, server build %s, map %s, tick %d" % [id, Teams.name_of(team), build, map_id, server_tick])
	if map_id != map.map_id:
		_hud.toast("Server map '%s' differs from local map '%s' — update your build." % [map_id, map.map_id], Hud.WARN_COLOR)
	if build != BuildInfo.build_id():
		_hud.toast("Server build %s differs from yours (%s)." % [build, BuildInfo.build_id()], Hud.WARN_COLOR)
	_hud.toast("Joined %s team. F8 saves a bug report." % Teams.name_of(team), Teams.color_of(team).lightened(0.3))
	_set_mode(Mode.INFANTRY)
	joined.emit()


func _on_roster(entries: Array) -> void:
	roster_names.clear()
	roster_teams.clear()
	commander_of_team = PackedInt32Array([0, 0])
	for e: Variant in entries:
		if not (e is Array):
			continue
		var row: Array = e
		if row.size() < 4 or not (row[0] is int and row[1] is String and row[2] is int and row[3] is bool):
			continue
		var id: int = row[0]
		var team: int = row[2]
		var is_cmd: bool = row[3]
		roster_names[id] = row[1]
		roster_teams[id] = team
		if is_cmd and Teams.is_valid(team):
			commander_of_team[team] = id
		if id == my_id and team != my_team and Teams.is_valid(team):
			my_team = team
			_hud.toast("You are now on %s team." % Teams.name_of(team), Teams.color_of(team).lightened(0.3))
	events.add("ROSTER", "%d players: %s" % [roster_names.size(), ", ".join(PackedStringArray(roster_names.values()))])


func _on_snapshot(bytes: PackedByteArray) -> void:
	if state != State.IN_GAME:
		return
	var snap: SnapshotCodec.Snapshot = SnapshotCodec.decode(bytes)
	if snap == null:
		_bad_snapshots += 1
		if _bad_snapshots <= 3:
			events.add("NET", "malformed snapshot (%d bytes) dropped" % bytes.size())
		return
	if _last_snapshot_tick >= 0 and snap.tick - _last_snapshot_tick > NetProtocol.SNAPSHOT_INTERVAL_TICKS * 6:
		events.add("NET", "snapshot gap: %d ticks without data" % (snap.tick - _last_snapshot_tick))
	if buffer.push(snap):
		_last_snapshot_tick = snap.tick


func _on_waypoint(team: int, active: bool, pos: Vector3, placed_by: String, serial: int) -> void:
	waypoint_log.append(PackedInt32Array([team, 1 if active else 0, serial]))
	if team != my_team:
		events.add("ERROR", "received a waypoint for team %d while on team %d" % [team, my_team])
		return
	var is_new: bool = active and serial != waypoint_serial
	waypoint_active = active
	waypoint_pos = pos
	waypoint_by = placed_by
	waypoint_serial = serial
	view.set_waypoint(active, pos)
	events.add("ORDER", "waypoint #%d %s at (%.1f, %.1f, %.1f) by %s" % [serial, "active" if active else "inactive", pos.x, pos.y, pos.z, placed_by], team)
	if is_new and mode != Mode.COMMANDER:
		_hud.toast("New order from %s: move to the waypoint." % placed_by, VisualFactory.ORDER_COLOR)
	waypoint_changed.emit()


func _on_action_result(request_id: int, ok: bool, message: String) -> void:
	var action: int = _pending_actions.get(request_id, 0)
	_pending_actions.erase(request_id)
	events.add("RESULT", "#%d %s: %s" % [request_id, "ok" if ok else "refused", message if message != "" else "-"])
	if not ok:
		_hud.toast(message, Hud.WARN_COLOR)
	elif action == NetProtocol.Action.PLACE_WAYPOINT:
		_hud.toast("Waypoint placed — your team can see it.", OK_COLOR)
	action_result.emit(request_id, ok, message)


func _on_notice(text: String) -> void:
	events.add("NOTICE", text)
	_hud.toast(text)
	notice.emit(text)


# ================================ intents ===================================

## Sends a numbered intent. Returns the request id (0 if not connected).
func request_action(action: int, arg: Vector3 = Vector3.ZERO) -> int:
	if state != State.IN_GAME:
		return 0
	_request_id += 1
	_pending_actions[_request_id] = action
	net.send_action(_request_id, action, arg)
	events.add("ACTION", "-> #%d %s" % [_request_id, NetProtocol.Action.find_key(action)])
	return _request_id


## Re-sends an already used request id (only used by tests to prove idempotency).
func resend_action(request_id: int, action: int, arg: Vector3) -> void:
	net.send_action(request_id, action, arg)
	events.add("ACTION", "-> #%d %s (resend)" % [request_id, NetProtocol.Action.find_key(action)])


func my_snap() -> SnapshotCodec.PlayerSnap:
	return view.players.get(my_id)


func own_team_vehicle() -> SnapshotCodec.VehicleSnap:
	var me: SnapshotCodec.PlayerSnap = my_snap()
	var best: SnapshotCodec.VehicleSnap = null
	var best_d: float = INF
	for id: int in view.vehicles:
		var v: SnapshotCodec.VehicleSnap = view.vehicles[id]
		if v.team != my_team:
			continue
		var d: float = me.pos.distance_to(v.pos) if me != null else 0.0
		if d < best_d:
			best = v
			best_d = d
	return best


func my_vehicle() -> SnapshotCodec.VehicleSnap:
	for id: int in view.vehicles:
		var v: SnapshotCodec.VehicleSnap = view.vehicles[id]
		if v.driver == my_id:
			return v
	return null


# ================================ frame =====================================

func _process(delta: float) -> void:
	frame_stats.add_frame(delta)
	match state:
		State.MENU:
			_menu_orbit += delta * 0.05
			_camera.position = Vector3(sin(_menu_orbit) * 110.0, 45.0, cos(_menu_orbit) * 110.0)
			_camera.look_at(Vector3.ZERO)
		State.CONNECTING:
			if _now() - _connect_started > NetProtocol.CONNECT_TIMEOUT_SEC:
				_on_connection_failed()
		State.IN_GAME:
			buffer.advance(delta)
			var frame: SnapshotBuffer.Frame = buffer.frame_at(buffer.render_time())
			if frame != null:
				view.apply(frame, my_id, my_team, roster_names)
				_update_mode()
				_update_camera(delta)
				_update_hud()
			else:
				_hud.set_center("Waiting for the first snapshot …")
	_perf_timer -= delta
	if _perf_timer <= 0.0 and state == State.IN_GAME:
		_perf_timer = 0.25
		var stats: Dictionary = frame_stats.summary()
		_hud.set_perf("FPS %d · p95 %.1f ms · ping %d ms · loss %d%%" % [Engine.get_frames_per_second(), stats.get("p95_ms", 0.0), roundi(ping_ms()), roundi(packet_loss() * 100.0)])


func _physics_process(_delta: float) -> void:
	if state != State.IN_GAME:
		return
	var move: Vector2 = Vector2.ZERO
	var buttons: int = 0
	if bot_controlled:
		move = bot_move
		buttons = bot_buttons
	elif not _hud.is_menu_open() and mode != Mode.COMMANDER:
		move = Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_back", "move_forward"))
		if Input.is_action_pressed("jump"):
			buttons |= NetProtocol.BUTTON_JUMP
	_input_seq += 1
	net.send_input(_input_seq, move, look_yaw, look_pitch, buttons)


func _update_mode() -> void:
	var me: SnapshotCodec.PlayerSnap = my_snap()
	if me == null:
		return
	var m: Mode = Mode.INFANTRY
	if not me.is_alive():
		m = Mode.DEAD
	elif me.is_commander():
		m = Mode.COMMANDER
	elif me.in_vehicle():
		m = Mode.DRIVER
	if m != mode:
		_set_mode(m)


func _set_mode(m: Mode) -> void:
	var old: Mode = mode
	mode = m
	if state != State.IN_GAME:
		return
	events.add("MODE", "%s -> %s" % [Mode.find_key(old), Mode.find_key(m)])
	view.hide_player_id = my_id if m == Mode.INFANTRY else 0
	_hud.set_crosshair_visible(m == Mode.INFANTRY)
	match m:
		Mode.DRIVER:
			var v: SnapshotCodec.VehicleSnap = my_vehicle()
			_orbit_yaw = v.yaw if v != null else look_yaw
			_orbit_pitch = -0.25
			_hud.toast("You are driving. W/S throttle · A/D steer · E to get out.", OK_COLOR)
		Mode.COMMANDER:
			var me: SnapshotCodec.PlayerSnap = my_snap()
			_cmd_focus = me.pos if me != null else map.command_posts[maxi(my_team, 0)]
			_cmd_yaw = 0.0 if my_team != Teams.RED else PI
			_hud.toast("You are the Commander. Right-click the ground to place a waypoint.", OK_COLOR)
		Mode.INFANTRY:
			if old == Mode.DRIVER:
				look_yaw = _orbit_yaw
		Mode.DEAD:
			_hud.toast("You died — respawning in 3 s.", Hud.WARN_COLOR)
	_apply_mouse_mode()


func _apply_mouse_mode() -> void:
	if bot_controlled or DisplayServer.get_name() == "headless":
		return
	var captured: bool = state == State.IN_GAME and not _hud.is_menu_open() and mode != Mode.COMMANDER
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func _update_camera(delta: float) -> void:
	var me: SnapshotCodec.PlayerSnap = my_snap()
	match mode:
		Mode.INFANTRY:
			if me != null:
				_camera.position = me.pos + Vector3.UP * PlayerMotor.EYE_HEIGHT
			_camera.rotation = Vector3(look_pitch, look_yaw, 0.0)
		Mode.DRIVER:
			var v: SnapshotCodec.VehicleSnap = my_vehicle()
			if v == null:
				return
			var target: Vector3 = v.pos + Vector3.UP * 2.6
			var offset: Vector3 = Basis(Vector3.UP, _orbit_yaw) * Basis(Vector3.RIGHT, _orbit_pitch) * Vector3(0.0, 0.0, DRIVER_CAM_DISTANCE)
			var desired: Vector3 = target + offset
			_cam_ray.from = target
			_cam_ray.to = desired
			var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(_cam_ray)
			if not hit.is_empty():
				var hp: Vector3 = hit["position"]
				desired = hp + (target - hp).normalized() * 0.4
			_camera.position = desired
			_camera.look_at(target)
		Mode.COMMANDER:
			if not bot_controlled and not _hud.is_menu_open():
				var pan := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_back", "move_forward"))
				var b := Basis(Vector3.UP, _cmd_yaw)
				var world_pan: Vector3 = b * Vector3(pan.x, 0.0, -pan.y)
				_cmd_focus += world_pan * _cmd_height * CMD_PAN_SPEED * delta
				_cmd_yaw += Input.get_axis("cmd_rotate_right", "cmd_rotate_left") * CMD_ROTATE_SPEED * delta
			_cmd_focus.x = clampf(_cmd_focus.x, map.bounds.position.x, map.bounds.end.x)
			_cmd_focus.z = clampf(_cmd_focus.z, map.bounds.position.z, map.bounds.end.z)
			var back: Vector3 = Basis(Vector3.UP, _cmd_yaw) * Vector3(0.0, 0.0, _cmd_height * 0.55)
			_camera.position = _cmd_focus + Vector3.UP * _cmd_height + back
			_camera.look_at(_cmd_focus)
		Mode.DEAD:
			_camera.position += Vector3.UP * delta * 1.5
			_camera.rotation.x = lerpf(_camera.rotation.x, -0.9, delta)


func _update_hud() -> void:
	_hud.set_center("")
	var me: SnapshotCodec.PlayerSnap = my_snap()
	var role: String = ["Infantry", "Driver", "Commander", "Dead"][mode]
	var cmd_id: int = commander_of_team[my_team] if Teams.is_valid(my_team) else 0
	var cmd_name: String = roster_names.get(cmd_id, "") if cmd_id != 0 else ""
	_hud.set_status("%s · %s · %s\nCommander: %s" % [Teams.name_of(my_team).to_upper(), role, roster_names.get(my_id, _player_name), cmd_name if cmd_name != "" else "none"], Teams.color_of(my_team).lightened(0.35))

	var hint: String = ""
	match mode:
		Mode.INFANTRY:
			_hud.set_help("WASD move · Space jump · Mouse look · E tank · C command (at Command Vehicle) · K respawn · F2 switch team · F8 bug report · Esc menu")
			var v: SnapshotCodec.VehicleSnap = own_team_vehicle()
			if me != null and v != null and _flat(me.pos, v.pos) <= OrderRules.ENTER_VEHICLE_RANGE:
				hint = "[E] Drive the tank" if v.driver == 0 else "Tank driver: %s" % roster_names.get(v.driver, "?")
			elif me != null and Teams.is_valid(my_team) and _flat(me.pos, map.command_posts[my_team]) <= OrderRules.COMMAND_POST_RANGE:
				hint = "[C] Take command" if cmd_id == 0 else "%s is your Commander" % cmd_name
		Mode.DRIVER:
			_hud.set_help("W/S throttle · A/D steer · Mouse look around · E get out · F8 bug report · Esc menu")
			var v: SnapshotCodec.VehicleSnap = my_vehicle()
			if v != null:
				hint = "%d km/h" % roundi(absf(v.speed) * 3.6)
		Mode.COMMANDER:
			_hud.set_help("Right-click ground: place waypoint · WASD pan · Q/E rotate · Wheel zoom · C leave command · F8 bug report")
			hint = "COMMANDER VIEW"
		Mode.DEAD:
			_hud.set_help("")
			hint = "Respawning …"
	_hud.set_hint(hint)

	if waypoint_active:
		var from: Vector3 = _focus_point()
		var dist: float = _flat(from, waypoint_pos)
		view.update_waypoint_text(dist, waypoint_by)
		var target: Vector3 = waypoint_pos + Vector3.UP * 3.0
		_hud.set_waypoint_indicator(true, _camera.unproject_position(target), _camera.is_position_behind(target), "%d m" % roundi(dist))
	else:
		_hud.set_waypoint_indicator(false, Vector2.ZERO, false, "")


func _focus_point() -> Vector3:
	match mode:
		Mode.DRIVER:
			var v: SnapshotCodec.VehicleSnap = my_vehicle()
			if v != null:
				return v.pos
		Mode.COMMANDER:
			return _cmd_focus
	var me: SnapshotCodec.PlayerSnap = my_snap()
	return me.pos if me != null else _camera.global_position


# ================================ input =====================================

func _unhandled_input(event: InputEvent) -> void:
	if state != State.IN_GAME or bot_controlled:
		return
	if event.is_action_pressed("menu"):
		_set_menu_open(not _hud.is_menu_open())
		return
	if event.is_action_pressed("bug_report"):
		request_bug_report()
		return
	if _hud.is_menu_open():
		return
	var motion := event as InputEventMouseMotion
	if motion != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rel: Vector2 = motion.relative * ClientInput.MOUSE_SENSITIVITY
		if mode == Mode.DRIVER:
			_orbit_yaw = wrapf(_orbit_yaw - rel.x, -PI, PI)
			_orbit_pitch = clampf(_orbit_pitch - rel.y, -1.1, 0.35)
		else:
			look_yaw = wrapf(look_yaw - rel.x, -PI, PI)
			look_pitch = clampf(look_pitch - rel.y, -1.45, 1.45)
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and mode == Mode.COMMANDER:
		match click.button_index:
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				_place_waypoint_at_screen(click.position)
			MOUSE_BUTTON_WHEEL_UP:
				_cmd_height = clampf(_cmd_height * 0.9, CMD_MIN_HEIGHT, CMD_MAX_HEIGHT)
			MOUSE_BUTTON_WHEEL_DOWN:
				_cmd_height = clampf(_cmd_height * 1.1, CMD_MIN_HEIGHT, CMD_MAX_HEIGHT)
		return
	if event.is_action_pressed("use") and mode != Mode.COMMANDER:
		request_action(NetProtocol.Action.USE_VEHICLE)
	elif event.is_action_pressed("command"):
		request_action(NetProtocol.Action.TOGGLE_COMMAND)
	elif event.is_action_pressed("respawn"):
		request_action(NetProtocol.Action.RESPAWN)
	elif event.is_action_pressed("switch_team"):
		request_action(NetProtocol.Action.SWITCH_TEAM)


func _place_waypoint_at_screen(screen_pos: Vector2) -> void:
	var from: Vector3 = _camera.project_ray_origin(screen_pos)
	_cam_ray.from = from
	_cam_ray.to = from + _camera.project_ray_normal(screen_pos) * 1000.0
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(_cam_ray)
	if hit.is_empty():
		_hud.toast("Click on the ground to place a waypoint.", Hud.WARN_COLOR)
		return
	var p: Vector3 = hit["position"]
	request_action(NetProtocol.Action.PLACE_WAYPOINT, p)


func _set_menu_open(open: bool) -> void:
	_hud.set_menu_open(open)
	_apply_mouse_mode()


# ============================== diagnostics =================================

func ping_ms() -> float:
	var mp := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if mp == null or state != State.IN_GAME:
		return 0.0
	var server: ENetPacketPeer = mp.get_peer(1)
	return server.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME) if server != null else 0.0


func packet_loss() -> float:
	var mp := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if mp == null or state != State.IN_GAME:
		return 0.0
	var server: ENetPacketPeer = mp.get_peer(1)
	return server.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) / ENetPacketPeer.PACKET_LOSS_SCALE if server != null else 0.0


## F8: asks the server for its (team-filtered) event tail, then writes the zip.
func request_bug_report() -> void:
	if _bug_id != "":
		return  # One at a time.
	_bug_id = BugReporter.make_bug_id()
	_bug_server_lines = PackedStringArray()
	events.add("BUG", "bug report %s requested" % _bug_id)
	if state == State.IN_GAME:
		net.request_debug_tail(_bug_id)
		get_tree().create_timer(BUG_REPLY_TIMEOUT_SEC).timeout.connect(_finish_bug_report.bind(_bug_id))
	else:
		_finish_bug_report(_bug_id)


func _on_debug_tail(bug_id: String, lines: PackedStringArray) -> void:
	if bug_id == _bug_id:
		_bug_server_lines = lines
		_finish_bug_report(bug_id)


func _finish_bug_report(bug_id: String) -> void:
	if bug_id != _bug_id:
		return
	_bug_id = ""
	var me: SnapshotCodec.PlayerSnap = my_snap()
	var latest: SnapshotCodec.Snapshot = buffer.latest()
	var info: Dictionary = {
		"bug_id": bug_id,
		"build_id": BuildInfo.build_id(),
		"commit": BuildInfo.commit(),
		"built_at": BuildInfo.built_at(),
		"protocol": NetProtocol.PROTOCOL_VERSION,
		"server_build": server_build,
		"server_address": server_address,
		"time_utc": Time.get_datetime_string_from_system(true),
		"system": BugReporter.system_info(),
		"frame_stats": frame_stats.summary(),
		"ping_ms": snappedf(ping_ms(), 0.1),
		"packet_loss": snappedf(packet_loss(), 0.001),
		"state": State.find_key(state),
		"mode": Mode.find_key(mode),
		"player_id": my_id,
		"team": Teams.name_of(my_team),
		"position": str(me.pos) if me != null else "",
		"last_server_tick": latest.tick if latest != null else -1,
		"waypoint": {"active": waypoint_active, "serial": waypoint_serial, "pos": str(waypoint_pos)},
	}
	var path: String = BugReporter.write_bundle(bug_id, info, events.tail(), _bug_server_lines)
	if path == "":
		_hud.toast("Could not write the bug report file.", Hud.WARN_COLOR)
	else:
		_hud.toast("Bug report saved: %s — attach it to your report." % path, OK_COLOR)
		if DisplayServer.get_name() != "headless":
			DisplayServer.clipboard_set(path)
	events.add("BUG", "bug report written: %s" % path)
	bug_report_written.emit(path)


# ================================ misc ======================================

func _host_local(player_name: String, team: int) -> void:
	var exe: String = OS.get_executable_path()
	var pargs := PackedStringArray()
	if not OS.has_feature("template"):
		pargs.append_array(["--path", ProjectSettings.globalize_path("res://")])
	pargs.append_array(["--headless", "--", "--server", "--port=%d" % NetProtocol.DEFAULT_PORT])
	_local_server_pid = OS.create_process(exe, pargs)
	if _local_server_pid <= 0:
		_menu.set_status("Could not start a local server process.", true)
		return
	events.add("NET", "started local server pid %d" % _local_server_pid)
	_menu.set_status("Starting local server …")
	_menu.set_busy(true)
	await get_tree().create_timer(1.5).timeout
	_menu.set_busy(false)
	connect_to("127.0.0.1:%d" % NetProtocol.DEFAULT_PORT, player_name, team)


func _quit() -> void:
	_stop_local_server()
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_stop_local_server()


func _stop_local_server() -> void:
	if _local_server_pid > 0:
		OS.kill(_local_server_pid)
		_local_server_pid = -1


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
