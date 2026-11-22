class_name ServerGame
extends Node
## Authoritative dedicated server (Stage-1 netcode).
##
## Owns ALL gameplay state: players, vehicles, seats, Commander, waypoints.
## Clients only send inputs (30 Hz) and numbered intents; the server answers with
## snapshots (15 Hz), team-private orders and plain-English intent results.
##
## CPU rule: one fixed tick here steps every body from flat collections —
## bodies carry no scripts and there is no per-entity _physics_process.

const KILL_Y: float = -25.0
const RESPAWN_DELAY_TICKS: int = NetProtocol.TICK_RATE * 3
const WAYPOINT_CHECK_INTERVAL_TICKS: int = 5
const VEHICLE_GRAVITY: float = 20.0
const DRIVER_SEAT_OFFSET: Vector3 = Vector3(0.0, 1.4, 0.0)


class ServerPlayer:
	var peer_id: int = 0
	var name: String = ""
	var team: int = Teams.BLUE
	var body: CharacterBody3D
	var alive: bool = true
	var respawn_at_tick: int = -1
	var vehicle_id: int = 0
	var is_commander: bool = false
	var input_seq: int = -1
	var move: Vector2 = Vector2.ZERO
	var yaw: float = 0.0
	var pitch: float = 0.0
	var buttons: int = 0


class ServerVehicle:
	var id: int = 0
	var team: int = Teams.BLUE
	var body: CharacterBody3D
	var driver: int = 0
	var speed: float = 0.0
	var yaw: float = 0.0
	var pitch: float = 0.0
	var roll: float = 0.0
	var hull_y: float = 0.0
	var spawn: Transform3D = Transform3D.IDENTITY


class TeamWaypoint:
	var active: bool = false
	var pos: Vector3 = Vector3.ZERO
	var placed_by: String = ""
	var serial: int = 0
	var reached: bool = false


var events: EventLog = EventLog.new(true)
var tick: int = 0
var map: MapInfo
var players: Dictionary[int, ServerPlayer] = {}
var vehicles: Array[ServerVehicle] = []
var commanders: PackedInt32Array = PackedInt32Array([0, 0])
var waypoints: Array[TeamWaypoint] = [TeamWaypoint.new(), TeamWaypoint.new()]
## Diagnostics / CI: how many waypoint messages each peer received, split by waypoint team.
var waypoint_sends: Dictionary[int, PackedInt32Array] = {}

var _net: NetBridge
var _world: Node3D
var _args: LaunchArgs
var _pending: Dictionary[int, float] = {}
var _ledger: RequestLedger = RequestLedger.new()
var _action_limiter: RateLimiter = RateLimiter.new(8.0, 4.0)
var _waypoint_limiter: RateLimiter = RateLimiter.new(6.0, 3.0)
var _debug_limiter: RateLimiter = RateLimiter.new(2.0, 0.2)
var _ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _had_players: bool = false
var _start_msec: int = 0


func start(args: LaunchArgs, net: NetBridge, world: Node3D) -> Error:
	_args = args
	_net = net
	_world = world
	_start_msec = Time.get_ticks_msec()
	map = MapInfo.load_into(world)
	if map == null:
		return ERR_FILE_NOT_FOUND
	for i: int in range(map.vehicle_spawns.size()):
		_spawn_vehicle(i + 1, map.vehicle_spawn_teams[i], map.vehicle_spawns[i])

	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(args.port, args.max_players, NetProtocol.ENET_CHANNELS)
	if err != OK:
		events.add("ERROR", "Could not listen on UDP port %d (%s). Is another server running?" % [args.port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	net.hello_received.connect(_on_hello)
	net.input_received.connect(_on_input)
	net.action_received.connect(_on_action)
	net.debug_tail_requested.connect(_on_debug_tail_requested)

	_ray.collision_mask = BodyFactory.LAYER_WORLD
	events.add("SERVER", "%s on UDP port %d, map %s, max %d players" % [BuildInfo.watermark(), args.port, map.map_id, args.max_players])
	print("SERVER_READY port=%d" % args.port)
	return OK


# =============================== connection =================================

func _on_peer_connected(peer_id: int) -> void:
	_pending[peer_id] = _now()
	events.add("NET", "peer %d connected, waiting for hello" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	_pending.erase(peer_id)
	_ledger.forget(peer_id)
	_action_limiter.forget(peer_id)
	_waypoint_limiter.forget(peer_id)
	_debug_limiter.forget(peer_id)
	if not players.has(peer_id):
		return
	var p: ServerPlayer = players[peer_id]
	players.erase(peer_id)  # First, so seat broadcasts below never target the departed peer.
	_leave_seats(p)
	p.body.queue_free()
	events.add("LEAVE", "%s (peer %d) left %s" % [p.name, peer_id, Teams.name_of(p.team)])
	_broadcast_roster()
	_broadcast_notice("%s left the game." % p.name)


func _on_hello(peer_id: int, protocol: int, build_id: String, player_name: String, team: int) -> void:
	if not _pending.has(peer_id):
		return  # Already joined (or unknown peer): ignore repeated hellos.
	_pending.erase(peer_id)
	if protocol != NetProtocol.PROTOCOL_VERSION:
		var reason: String = "Version mismatch: server runs protocol %d (build %s), you have protocol %d (build %s). Download the latest build." % [NetProtocol.PROTOCOL_VERSION, BuildInfo.build_id(), protocol, build_id]
		events.add("REJECT", "peer %d: %s" % [peer_id, reason])
		_net.send_reject(peer_id, reason)
		get_tree().create_timer(0.5).timeout.connect(_kick.bind(peer_id))
		return
	var p := ServerPlayer.new()
	p.peer_id = peer_id
	p.name = _unique_name(OrderRules.sanitize_name(player_name, "Player%d" % (peer_id % 1000)))
	p.team = team if Teams.is_valid(team) else Teams.auto_assign(_team_counts())
	p.body = BodyFactory.make_player_body()
	p.body.name = "Player_%d" % peer_id
	_world.add_child(p.body)
	players[peer_id] = p
	_had_players = true
	_respawn(p)
	if build_id != BuildInfo.build_id():
		events.add("WARN", "%s joined with build %s (server %s)" % [p.name, build_id, BuildInfo.build_id()])
	events.add("JOIN", "%s (peer %d) joined %s" % [p.name, peer_id, Teams.name_of(p.team)])
	_net.send_welcome(peer_id, p.team, BuildInfo.build_id(), map.map_id, tick)
	_send_waypoint_to(peer_id, p.team)
	_broadcast_roster()
	_broadcast_notice("%s joined %s." % [p.name, Teams.name_of(p.team)])


func _kick(peer_id: int) -> void:
	var mp := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if mp != null and mp.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		mp.disconnect_peer(peer_id)


# ================================ inputs ====================================

func _on_input(peer_id: int, seq: int, move: Vector2, yaw: float, pitch: float, buttons: int) -> void:
	if not players.has(peer_id):
		return
	var p: ServerPlayer = players[peer_id]
	if seq <= p.input_seq:
		return
	if not (is_finite(move.x) and is_finite(move.y) and is_finite(yaw) and is_finite(pitch)):
		return
	p.input_seq = seq
	p.move = move.limit_length(1.0)
	p.yaw = wrapf(yaw, -PI, PI)
	p.pitch = clampf(pitch, -1.5, 1.5)
	p.buttons = buttons


func _on_action(peer_id: int, request_id: int, action: int, arg: Vector3) -> void:
	if not players.has(peer_id):
		return
	match _ledger.classify(peer_id, request_id):
		RequestLedger.Verdict.DUPLICATE:
			events.add("DUP", "peer %d repeated request %d — not executed again" % [peer_id, request_id], players[peer_id].team)
			_net.send_action_result(peer_id, request_id, _ledger.cached_ok(peer_id), _ledger.cached_message(peer_id))
			return
		RequestLedger.Verdict.STALE:
			return
	var limiter: RateLimiter = _waypoint_limiter if action == NetProtocol.Action.PLACE_WAYPOINT else _action_limiter
	if not limiter.allow(peer_id, _now()):
		_finish(peer_id, request_id, false, "Slow down — too many requests.")
		return
	var p: ServerPlayer = players[peer_id]
	var reason: String
	match action:
		NetProtocol.Action.USE_VEHICLE:
			reason = _do_use_vehicle(p)
		NetProtocol.Action.TOGGLE_COMMAND:
			reason = _do_toggle_command(p)
		NetProtocol.Action.PLACE_WAYPOINT:
			reason = _do_place_waypoint(p, arg)
		NetProtocol.Action.RESPAWN:
			reason = _do_respawn_request(p)
		NetProtocol.Action.SWITCH_TEAM:
			reason = _do_switch_team(p)
		_:
			reason = "Unknown action."
	_finish(peer_id, request_id, reason == "", reason)


func _finish(peer_id: int, request_id: int, ok: bool, message: String) -> void:
	_ledger.remember(peer_id, request_id, ok, message)
	_net.send_action_result(peer_id, request_id, ok, message)


# ================================ intents ===================================

func _do_use_vehicle(p: ServerPlayer) -> String:
	if p.vehicle_id != 0:
		_exit_vehicle(p)
		return ""
	var best: ServerVehicle = null
	var best_dist: float = INF
	for v: ServerVehicle in vehicles:
		var d: float = _flat_distance(p.body.global_position, v.body.global_position)
		if d < best_dist:
			best = v
			best_dist = d
	var driver_name: String = ""
	if best != null and best.driver != 0 and players.has(best.driver):
		driver_name = players[best.driver].name
	var same_team: bool = best != null and best.team == p.team
	var reason: String = OrderRules.check_enter_vehicle(p.alive, p.is_commander, same_team, best_dist, driver_name)
	if reason != "":
		return reason
	best.driver = p.peer_id
	p.vehicle_id = best.id
	BodyFactory.set_player_collision(p.body, false)
	p.body.velocity = Vector3.ZERO
	events.add("SEAT", "%s entered tank %d as driver" % [p.name, best.id], p.team)
	return ""


func _do_toggle_command(p: ServerPlayer) -> String:
	if p.is_commander:
		_leave_command(p)
		return ""
	var current: int = commanders[p.team]
	var commander_name: String = players[current].name if current != 0 and players.has(current) else ""
	var dist: float = _flat_distance(p.body.global_position, map.command_posts[p.team])
	var reason: String = OrderRules.check_take_command(p.alive, p.vehicle_id != 0, dist, commander_name)
	if reason != "":
		return reason
	commanders[p.team] = p.peer_id
	p.is_commander = true
	p.body.velocity = Vector3.ZERO
	BodyFactory.set_player_collision(p.body, false)
	events.add("COMMAND", "%s took command of %s" % [p.name, Teams.name_of(p.team)], p.team)
	_broadcast_roster()
	_broadcast_team_notice(p.team, "%s is now your Commander." % p.name)
	return ""


func _do_place_waypoint(p: ServerPlayer, pos: Vector3) -> String:
	var reason: String = OrderRules.check_place_waypoint(p.is_commander, pos, map.bounds)
	if reason != "":
		return reason
	var w: TeamWaypoint = waypoints[p.team]
	w.active = true
	w.pos = _ground_point(pos)
	w.placed_by = p.name
	w.serial += 1
	w.reached = false
	events.add("ORDER", "%s placed waypoint #%d at (%.1f, %.1f, %.1f)" % [p.name, w.serial, w.pos.x, w.pos.y, w.pos.z], p.team)
	for peer_id: int in _peers_of_team(p.team):
		_send_waypoint_to(peer_id, p.team)
	return ""


func _do_respawn_request(p: ServerPlayer) -> String:
	if p.is_commander:
		return "Leave the Commander seat first (press C)."
	_kill(p, "respawn requested")
	return ""


func _do_switch_team(p: ServerPlayer) -> String:
	_leave_seats(p)
	p.team = Teams.other(p.team)
	_respawn(p)
	events.add("TEAM", "%s switched to %s" % [p.name, Teams.name_of(p.team)])
	_send_waypoint_to(p.peer_id, p.team)
	_broadcast_roster()
	_broadcast_notice("%s switched to %s." % [p.name, Teams.name_of(p.team)])
	return ""


# ============================== seat helpers ================================

func _leave_seats(p: ServerPlayer) -> void:
	if p.vehicle_id != 0:
		_exit_vehicle(p)
	if p.is_commander:
		_leave_command(p)


func _leave_command(p: ServerPlayer) -> void:
	p.is_commander = false
	if commanders[p.team] == p.peer_id:
		commanders[p.team] = 0
	if p.alive:
		BodyFactory.set_player_collision(p.body, true)
	events.add("COMMAND", "%s left the Commander seat" % p.name, p.team)
	_broadcast_roster()


func _exit_vehicle(p: ServerPlayer) -> void:
	var v: ServerVehicle = _vehicle_by_id(p.vehicle_id)
	p.vehicle_id = 0
	if v == null:
		return
	v.driver = 0
	p.body.global_position = _find_exit_spot(v)
	p.body.velocity = Vector3.ZERO
	BodyFactory.set_player_collision(p.body, true)
	events.add("SEAT", "%s left tank %d" % [p.name, v.id], p.team)


## Left side, right side, rear, front — first spot with room for a standing player.
func _find_exit_spot(v: ServerVehicle) -> Vector3:
	var shape := CapsuleShape3D.new()
	shape.radius = BodyFactory.PLAYER_RADIUS
	shape.height = BodyFactory.PLAYER_HEIGHT
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = BodyFactory.LAYER_WORLD | BodyFactory.LAYER_VEHICLES | BodyFactory.LAYER_PLAYERS
	var space: PhysicsDirectSpaceState3D = v.body.get_world_3d().direct_space_state
	var b := Basis(Vector3.UP, v.yaw)
	var offsets: Array[Vector3] = [Vector3(-3.0, 0, 0), Vector3(3.0, 0, 0), Vector3(0, 0, 4.5), Vector3(0, 0, -4.5)]
	for off: Vector3 in offsets:
		var spot: Vector3 = _ground_point(v.body.global_position + b * off + Vector3.UP * 0.5)
		q.transform = Transform3D(Basis(), spot + Vector3.UP * (BodyFactory.PLAYER_HEIGHT * 0.5 + 0.05))
		if space.intersect_shape(q, 1).is_empty():
			return spot
	return v.body.global_position + Vector3.UP * 3.0


# ================================ tick ======================================

func _physics_process(delta: float) -> void:
	if map == null:
		return
	tick += 1
	events.current_tick = tick
	_step_players(delta)
	_step_vehicles(delta)
	_step_respawns()
	if tick % WAYPOINT_CHECK_INTERVAL_TICKS == 0:
		_check_waypoints_reached()
	if tick % NetProtocol.SNAPSHOT_INTERVAL_TICKS == 0:
		_broadcast_snapshots()
	_drop_silent_peers()
	_check_test_exit()


func _step_players(delta: float) -> void:
	for peer_id: int in players:
		var p: ServerPlayer = players[peer_id]
		if not p.alive or p.is_commander or p.vehicle_id != 0:
			continue
		var b: CharacterBody3D = p.body
		b.velocity = PlayerMotor.compute_velocity(b.velocity, p.move, p.yaw, b.is_on_floor(), (p.buttons & NetProtocol.BUTTON_JUMP) != 0, delta)
		b.move_and_slide()
		if b.global_position.y < KILL_Y:
			_kill(p, "fell out of the world")


func _step_vehicles(delta: float) -> void:
	for v: ServerVehicle in vehicles:
		var throttle: float = 0.0
		var steer: float = 0.0
		if v.driver != 0 and players.has(v.driver):
			var d: ServerPlayer = players[v.driver]
			throttle = d.move.y
			steer = d.move.x
		v.speed = TankDriveModel.step_speed(v.speed, throttle, delta)
		v.yaw = wrapf(v.yaw + TankDriveModel.yaw_rate(steer, v.speed) * delta, -PI, PI)
		var b: CharacterBody3D = v.body
		b.rotation = Vector3(0.0, v.yaw, 0.0)
		var fwd: Vector3 = PlayerMotor.forward(v.yaw)
		var vy: float = 0.0 if b.is_on_floor() else b.velocity.y - VEHICLE_GRAVITY * delta
		b.velocity = fwd * v.speed + Vector3.UP * vy
		b.move_and_slide()
		# Hitting a wall bleeds speed instead of silently storing it.
		var real_fwd: float = b.get_real_velocity().dot(fwd)
		if absf(real_fwd) < absf(v.speed) - 0.5:
			v.speed = real_fwd
		_update_suspension(v)
		if b.global_position.y < KILL_Y:
			_reset_vehicle(v)
		if v.driver != 0 and players.has(v.driver):
			players[v.driver].body.global_position = b.global_position + DRIVER_SEAT_OFFSET


## Four corner rays -> hull pitch/roll and hull height (the "raycast" in raycast vehicle).
func _update_suspension(v: ServerVehicle) -> void:
	var space: PhysicsDirectSpaceState3D = v.body.get_world_3d().direct_space_state
	var b := Basis(Vector3.UP, v.yaw)
	var origin: Vector3 = v.body.global_position
	var heights: PackedFloat32Array = PackedFloat32Array()
	var sum: float = 0.0
	for off: Vector3 in TankSuspension.corner_offsets():
		var p: Vector3 = origin + b * off
		_ray.from = p + Vector3.UP * TankSuspension.RAY_UP
		_ray.to = p - Vector3.UP * TankSuspension.RAY_DOWN
		var hit: Dictionary = space.intersect_ray(_ray)
		var h: float = origin.y
		if not hit.is_empty():
			var hp: Vector3 = hit["position"]
			h = hp.y
		heights.append(h)
		sum += h
	var tilt: Vector2 = TankSuspension.tilt_from_heights(heights[0], heights[1], heights[2], heights[3])
	v.pitch = lerpf(v.pitch, tilt.x, TankSuspension.SMOOTHING)
	v.roll = lerpf(v.roll, tilt.y, TankSuspension.SMOOTHING)
	v.hull_y = lerpf(v.hull_y, maxf(sum / 4.0, origin.y), 0.5)


func _step_respawns() -> void:
	for peer_id: int in players:
		var p: ServerPlayer = players[peer_id]
		if not p.alive and p.respawn_at_tick >= 0 and tick >= p.respawn_at_tick:
			_respawn(p)


func _check_waypoints_reached() -> void:
	for team: int in range(Teams.COUNT):
		var w: TeamWaypoint = waypoints[team]
		if not w.active or w.reached:
			continue
		for peer_id: int in players:
			var p: ServerPlayer = players[peer_id]
			if p.team != team or not p.alive or p.is_commander:
				continue
			if _flat_distance(p.body.global_position, w.pos) <= OrderRules.WAYPOINT_REACHED_RADIUS:
				w.reached = true
				var how: String = "in the tank" if p.vehicle_id != 0 else "on foot"
				events.add("ORDER", "waypoint #%d reached by %s %s" % [w.serial, p.name, how], team)
				_broadcast_team_notice(team, "Waypoint reached by %s (%s)." % [p.name, how])
				break


func _broadcast_snapshots() -> void:
	if players.is_empty():
		return
	var plist: Array[SnapshotCodec.PlayerSnap] = []
	for peer_id: int in players:
		var p: ServerPlayer = players[peer_id]
		var s := SnapshotCodec.PlayerSnap.new()
		s.id = peer_id
		s.team = p.team
		s.flags = (SnapshotCodec.FLAG_ALIVE if p.alive else 0) \
			| (SnapshotCodec.FLAG_IN_VEHICLE if p.vehicle_id != 0 else 0) \
			| (SnapshotCodec.FLAG_COMMANDER if p.is_commander else 0)
		s.pos = p.body.global_position
		s.yaw = p.yaw
		s.pitch = p.pitch
		plist.append(s)
	var vlist: Array[SnapshotCodec.VehicleSnap] = []
	for v: ServerVehicle in vehicles:
		var s := SnapshotCodec.VehicleSnap.new()
		s.id = v.id
		s.team = v.team
		s.driver = v.driver
		s.pos = Vector3(v.body.global_position.x, v.hull_y, v.body.global_position.z)
		s.yaw = v.yaw
		s.pitch = v.pitch
		s.roll = v.roll
		s.speed = v.speed
		vlist.append(s)
	var body: PackedByteArray = SnapshotCodec.encode_body(plist, vlist)
	for peer_id: int in players:
		_net.send_snapshot(peer_id, SnapshotCodec.encode(tick, players[peer_id].input_seq, body))


func _drop_silent_peers() -> void:
	if _pending.is_empty():
		return
	var now: float = _now()
	for peer_id: int in _pending.keys():
		if now - _pending[peer_id] > NetProtocol.HELLO_TIMEOUT_SEC:
			events.add("NET", "peer %d never sent hello — disconnecting" % peer_id)
			_pending.erase(peer_id)
			_kick(peer_id)


func _check_test_exit() -> void:
	var elapsed: float = (Time.get_ticks_msec() - _start_msec) / 1000.0
	var timed_out: bool = _args.test_timeout > 0.0 and elapsed > _args.test_timeout
	var empty_done: bool = _args.exit_when_empty and _had_players and players.is_empty() and _pending.is_empty()
	if timed_out or empty_done:
		events.add("SERVER", "test exit (%s)" % ("timeout" if timed_out else "all players left"))
		_write_test_output(not timed_out)
		set_physics_process(false)
		get_tree().quit(0 if not timed_out else 2)


func _write_test_output(ok: bool) -> void:
	if _args.test_out == "":
		return
	var sends: Dictionary = {}
	for peer_id: int in waypoint_sends:
		sends[str(peer_id)] = Array(waypoint_sends[peer_id])
	var out: Dictionary = {
		"role": "server",
		"passed": ok,
		"build_id": BuildInfo.build_id(),
		"waypoint_sends_by_peer": sends,
		"events": Array(events.tail()),
	}
	var f := FileAccess.open(_args.test_out, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "  "))


# ============================== debug (F8) ==================================

func _on_debug_tail_requested(peer_id: int, bug_id: String) -> void:
	if not players.has(peer_id) or not _debug_limiter.allow(peer_id, _now()):
		return
	var p: ServerPlayer = players[peer_id]
	var safe_id: String = _safe_file_id(bug_id)
	var lines: PackedStringArray = events.tail(p.team)
	events.add("BUG", "%s saved a bug report (%s)" % [p.name, safe_id])
	_net.send_debug_tail(peer_id, bug_id, lines)
	# Keep a server-side copy (all teams) for the host.
	DirAccess.make_dir_recursive_absolute("user://bug_reports")
	var f := FileAccess.open("user://bug_reports/server_%s.log" % safe_id, FileAccess.WRITE)
	if f != null:
		f.store_string("%s\nreported by %s (peer %d)\n\n%s\n" % [BuildInfo.watermark(), p.name, peer_id, "\n".join(events.tail())])


static func _safe_file_id(raw: String) -> String:
	var out: String = ""
	for i: int in range(mini(raw.length(), 64)):
		var c: String = raw[i]
		if c.is_valid_identifier() or c.is_valid_int() or c == "-":
			out += c
	return out if out != "" else "unnamed"


# ================================ helpers ===================================

func _spawn_vehicle(id: int, team: int, spawn: Transform3D) -> void:
	var v := ServerVehicle.new()
	v.id = id
	v.team = team
	v.spawn = spawn
	v.body = BodyFactory.make_tank_body()
	v.body.name = "Vehicle_%d" % id
	_world.add_child(v.body)
	vehicles.append(v)
	_reset_vehicle(v)


func _reset_vehicle(v: ServerVehicle) -> void:
	v.body.global_position = v.spawn.origin
	v.yaw = v.spawn.basis.get_euler().y
	v.body.rotation = Vector3(0.0, v.yaw, 0.0)
	v.body.velocity = Vector3.ZERO
	v.speed = 0.0
	v.pitch = 0.0
	v.roll = 0.0
	v.hull_y = v.spawn.origin.y


func _respawn(p: ServerPlayer) -> void:
	p.alive = true
	p.respawn_at_tick = -1
	var a: float = float(p.peer_id % 8) * TAU / 8.0
	var spot: Vector3 = map.spawns[p.team] + Vector3(cos(a), 0.0, sin(a)) * 2.5 + Vector3.UP * 0.2
	p.body.global_position = spot
	p.body.velocity = Vector3.ZERO
	p.yaw = PlayerMotor.yaw_towards(-spot)  # face the map centre
	BodyFactory.set_player_collision(p.body, true)


func _kill(p: ServerPlayer, why: String) -> void:
	_leave_seats(p)
	p.alive = false
	p.respawn_at_tick = tick + RESPAWN_DELAY_TICKS
	BodyFactory.set_player_collision(p.body, false)
	p.body.velocity = Vector3.ZERO
	events.add("DEATH", "%s died (%s)" % [p.name, why], p.team)


func _send_waypoint_to(peer_id: int, team: int) -> void:
	var w: TeamWaypoint = waypoints[team]
	_net.send_waypoint(peer_id, team, w.active, w.pos, w.placed_by, w.serial)
	var counts: PackedInt32Array = waypoint_sends.get(peer_id, PackedInt32Array([0, 0]))
	counts[team] += 1
	waypoint_sends[peer_id] = counts


func _broadcast_roster() -> void:
	var entries: Array = []
	for peer_id: int in players:
		var p: ServerPlayer = players[peer_id]
		entries.append([peer_id, p.name, p.team, p.is_commander])
	for peer_id: int in players:
		_net.send_roster(peer_id, entries)


func _broadcast_notice(text: String) -> void:
	for peer_id: int in players:
		_net.send_notice(peer_id, text)


func _broadcast_team_notice(team: int, text: String) -> void:
	for peer_id: int in _peers_of_team(team):
		_net.send_notice(peer_id, text)


func _peers_of_team(team: int) -> PackedInt32Array:
	var teams: Dictionary[int, int] = {}
	for peer_id: int in players:
		teams[peer_id] = players[peer_id].team
	return OrderRules.waypoint_recipients(team, teams)


func _team_counts() -> PackedInt32Array:
	var counts := PackedInt32Array([0, 0])
	for peer_id: int in players:
		counts[players[peer_id].team] += 1
	return counts


func _unique_name(base: String) -> String:
	var taken: Dictionary[String, bool] = {}
	for peer_id: int in players:
		taken[players[peer_id].name] = true
	if not taken.has(base):
		return base
	for i: int in range(2, 100):
		var candidate: String = "%s(%d)" % [base, i]
		if not taken.has(candidate):
			return candidate
	return "%s(%d)" % [base, randi() % 10000]


func _vehicle_by_id(id: int) -> ServerVehicle:
	for v: ServerVehicle in vehicles:
		if v.id == id:
			return v
	return null


## Drops `pos` onto the first surface below a point slightly above it (so a spot inside the
## factory snaps to its floor, not its roof).
func _ground_point(pos: Vector3, search_up: float = 2.0) -> Vector3:
	_ray.from = Vector3(pos.x, pos.y + search_up, pos.z)
	_ray.to = Vector3(pos.x, pos.y - 40.0, pos.z)
	var hit: Dictionary = _world.get_world_3d().direct_space_state.intersect_ray(_ray)
	if hit.is_empty():
		return pos
	return hit["position"]


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
