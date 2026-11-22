class_name BotBrain
extends Node
## Scripted headless test clients for the Step A–C release gates. Bots play through the
## exact same client code paths and server validation as humans (inputs + numbered intents).
##
##   commander (Blue): takes command, tries an invalid + a duplicated waypoint request,
##                     then watches the tank ride to the order and saves an F8 bundle.
##   driver    (Blue): sees others, disconnects + reconnects, receives the order on rejoin,
##                     walks to the tank, drives to the waypoint, gets out.
##   spy       (Red):  must NEVER receive Blue's waypoint; is refused when it tries to order.
##
## Results are written as JSON to --test-out; process exit code 0 = all checks passed.

const ARRIVE_RADIUS: float = 6.0

var game: ClientGame
var role: String = ""
var checks: Dictionary = {}
var notes: PackedStringArray = PackedStringArray()

var _args: LaunchArgs
var _step: String = "join"
var _step_started: float = 0.0
var _started: float = 0.0
var _results: Dictionary[int, Array] = {}
var _notices: PackedStringArray = PackedStringArray()
var _bug_path: String = ""
var _reconnected: bool = false
var _path_index: int = 0
var _shot_index: int = 0
var _mid_drive_shot: bool = false
var _wp_request: int = 0
var _invalid_request: int = 0
var _vehicle_start: Vector3 = Vector3.INF
var _vehicle_max_travel: float = 0.0
var _max_tilt: float = 0.0
var _saw_driver_ride: bool = false
var _done: bool = false


func setup(client: ClientGame, launch_args: LaunchArgs) -> void:
	game = client
	_args = launch_args
	role = launch_args.bot
	game.bot_controlled = true
	game.action_result.connect(func(id: int, ok: bool, msg: String) -> void: _results[id] = [ok, msg])
	game.notice.connect(func(text: String) -> void: _notices.append(text))
	game.bug_report_written.connect(func(path: String) -> void: _bug_path = path)
	_started = _now()
	_step_started = _started
	if not role in ["commander", "driver", "spy"]:
		_fail("unknown bot role '%s'" % role)


func _physics_process(_delta: float) -> void:
	if _done:
		return
	if _args.test_timeout > 0.0 and _now() - _started > _args.test_timeout:
		_fail("timeout in step '%s'" % _step)
		return
	game.bot_move = Vector2.ZERO
	game.bot_buttons = 0
	if game.state != ClientGame.State.IN_GAME and _step != "reconnect":
		return
	match role:
		"commander":
			_commander()
		"driver":
			_driver()
		"spy":
			_spy()


# ================================ commander =================================

func _commander() -> void:
	match _step:
		"join":
			if _sees_players(3):
				_check("A_sees_other_clients", true)
				_go("walk_to_post")
		"walk_to_post":
			if _walk_to(game.map.command_posts[game.my_team], 5.0):
				_request(NetProtocol.Action.TOGGLE_COMMAND)
				_go("wait_command")
		"wait_command":
			if game.mode == ClientGame.Mode.COMMANDER:
				_check("B_took_command", true)
				_invalid_request = game.request_action(NetProtocol.Action.PLACE_WAYPOINT, Vector3(500.0, 0.0, 500.0))
				_go("invalid_waypoint")
			elif _elapsed() > 5.0:
				_fail("never became Commander")
		"invalid_waypoint":
			if _results.has(_invalid_request):
				var r: Array = _results[_invalid_request]
				var accepted: bool = r[0]
				_check("B_out_of_map_waypoint_refused", not accepted)
				notes.append("refusal message: %s" % r[1])
				# Same request id twice: the server must execute it exactly once.
				var target: Vector3 = game.map.test_waypoint
				_wp_request = game.request_action(NetProtocol.Action.PLACE_WAYPOINT, target)
				game.resend_action(_wp_request, NetProtocol.Action.PLACE_WAYPOINT, target)
				_go("wait_waypoint")
		"wait_waypoint":
			if _elapsed() > 1.5:
				var serials: int = 0
				for entry: PackedInt32Array in game.waypoint_log:
					if entry[1] == 1:
						serials += 1
				_check("B_waypoint_received_by_own_team", game.waypoint_active)
				_check("B_duplicate_request_executed_once", serials == 1 and game.waypoint_serial == 1)
				_go("observe")
		"observe":
			var v: SnapshotCodec.VehicleSnap = game.own_team_vehicle()
			if v == null:
				return
			if _vehicle_start == Vector3.INF:
				_vehicle_start = v.pos
			_vehicle_max_travel = maxf(_vehicle_max_travel, _vehicle_start.distance_to(v.pos))
			if v.driver != 0:
				_saw_driver_ride = true
			var reached: bool = false
			for n: String in _notices:
				if n.begins_with("Waypoint reached"):
					reached = true
			if reached and _flat(v.pos, game.waypoint_pos) <= OrderRules.WAYPOINT_REACHED_RADIUS + 2.0:
				_check("C_commander_watched_ride", _saw_driver_ride and _vehicle_max_travel > 30.0)
				_check("C_arrival_notice_received", true)
				notes.append("tank travelled %.1f m as seen by the Commander" % _vehicle_max_travel)
				game.request_bug_report()
				_go("bug_report")
		"bug_report":
			if _bug_path != "":
				_check("A_f8_bundle_valid", _verify_bundle(_bug_path))
				_finish()
			elif _elapsed() > 4.0:
				_fail("F8 bundle was never written")


# ================================= driver ===================================

func _driver() -> void:
	match _step:
		"join":
			if _sees_players(3):
				_check("A_sees_others_before_reconnect", true)
				game.disconnect_from_server("test reconnect")
				_go("reconnect")
		"reconnect":
			if game.state == ClientGame.State.MENU and _elapsed() > 1.0 and not _reconnected:
				_reconnected = true
				game.connect_to(_args.connect_address, _args.player_name, _args.team)
			elif game.state == ClientGame.State.IN_GAME:
				_go("rejoined")
		"rejoined":
			if _sees_players(3):
				var names: Array = game.roster_names.values()
				var unique: Dictionary = {}
				for n: Variant in names:
					unique[n] = true
				_check("A_sees_others_after_reconnect", true)
				_check("A_no_ghost_players_after_reconnect", names.size() == 3 and unique.size() == 3)
				_go("wait_order")
			elif _elapsed() > 6.0:
				_fail("did not see the other clients again after reconnecting")
		"wait_order":
			if game.waypoint_active:
				_check("B_order_received_after_rejoin", true)
				_go("walk_to_tank")
			elif _elapsed() > 20.0:
				_fail("never received the Commander's waypoint")
		"walk_to_tank":
			var v: SnapshotCodec.VehicleSnap = game.own_team_vehicle()
			if v == null:
				return
			# Walk around the factory wall and enter through the open front.
			var fwd: Vector3 = PlayerMotor.forward(v.yaw)
			var left: Vector3 = -PlayerMotor.right(v.yaw)
			var path: Array[Vector3] = [v.pos + fwd * 14.0 + left * 9.0, v.pos + fwd * 6.0]
			if _path_index < path.size():
				if _walk_to(path[_path_index], 1.5):
					_path_index += 1
			elif _walk_to(v.pos, 3.2):
				_request(NetProtocol.Action.USE_VEHICLE)
				_go("wait_seat")
		"wait_seat":
			if game.mode == ClientGame.Mode.DRIVER:
				_check("C_entered_driver_seat", true)
				_go("drive")
			elif _elapsed() > 3.0:
				_go("walk_to_tank")  # Retry: maybe we stopped just out of range.
		"drive":
			var v: SnapshotCodec.VehicleSnap = game.my_vehicle()
			if v == null:
				return
			_max_tilt = maxf(_max_tilt, absf(v.pitch))
			if _elapsed() > 4.0 and _shot_index < 20 and not _mid_drive_shot:
				_mid_drive_shot = true
				_screenshot("driving")
			var to_target: Vector3 = game.waypoint_pos - v.pos
			var dist: float = Vector2(to_target.x, to_target.z).length()
			var err: float = wrapf(PlayerMotor.yaw_towards(to_target) - v.yaw, -PI, PI)
			var steer: float = clampf(-err * 2.0, -1.0, 1.0)
			var throttle: float = 1.0 if absf(err) < 0.5 else 0.35
			if dist < 16.0:
				throttle = minf(throttle, 0.45)
			if dist < ARRIVE_RADIUS:
				throttle = -0.6 if v.speed > 0.5 else 0.0
				steer = 0.0
				if absf(v.speed) < 0.6:
					_check("C_drove_tank_to_waypoint", true)
					_check("C_suspension_tilted_on_ramp", _max_tilt > deg_to_rad(5.0))
					notes.append("max hull pitch %.1f°" % rad_to_deg(_max_tilt))
					_request(NetProtocol.Action.USE_VEHICLE)
					_go("wait_exit")
			game.bot_move = Vector2(steer, throttle)
			if _elapsed() > 45.0:
				_fail("drive took too long (%.0f m left)" % dist)
		"wait_exit":
			if game.mode == ClientGame.Mode.INFANTRY:
				_check("C_exited_vehicle", true)
				_finish()
			elif _elapsed() > 3.0:
				_fail("could not exit the tank")


# ================================== spy =====================================

func _spy() -> void:
	match _step:
		"join":
			if _sees_players(3):
				_check("A_sees_other_clients", true)
				_invalid_request = game.request_action(NetProtocol.Action.PLACE_WAYPOINT, Vector3.ZERO)
				_go("try_order")
		"try_order":
			if _results.has(_invalid_request):
				var r: Array = _results[_invalid_request]
				var accepted: bool = r[0]
				_check("B_non_commander_order_refused", not accepted)
				_go("watch")
		"watch":
			# Stay connected until Blue's Commander has finished (left the server).
			var commander_present: bool = false
			for id: int in game.roster_names:
				if game.roster_names[id] == "BotCommander":
					commander_present = true
			if not commander_present and _elapsed() > 2.0:
				var leaked: int = 0
				for entry: PackedInt32Array in game.waypoint_log:
					if entry[0] != game.my_team or entry[1] == 1:
						leaked += 1
				_check("B_enemy_never_received_private_waypoint", leaked == 0)
				_finish()


# ================================ helpers ===================================

func _sees_players(n: int) -> bool:
	return game.view.players.size() >= n and game.roster_names.size() >= n


## Walks toward `target`; returns true once within `radius` (flat distance).
func _walk_to(target: Vector3, radius: float) -> bool:
	var me: SnapshotCodec.PlayerSnap = game.my_snap()
	if me == null:
		return false
	var d: Vector3 = target - me.pos
	if Vector2(d.x, d.z).length() <= radius:
		return true
	game.look_yaw = PlayerMotor.yaw_towards(d)
	game.bot_move = Vector2(0.0, 1.0)
	return false


func _request(action: int) -> void:
	game.request_action(action)


func _verify_bundle(path: String) -> bool:
	var zip := ZIPReader.new()
	if zip.open(path) != OK:
		notes.append("bundle could not be opened: %s" % path)
		return false
	var files: PackedStringArray = zip.get_files()
	var ok: bool = files.has("info.json") and files.has("client_events.log") and files.has("server_events.log")
	if ok:
		var info: Variant = JSON.parse_string(zip.read_file("info.json").get_string_from_utf8())
		ok = info is Dictionary and (info as Dictionary).has("build_id") and (info as Dictionary).has("frame_stats")
		var server_log: String = zip.read_file("server_events.log").get_string_from_utf8()
		ok = ok and server_log.contains("ORDER")
	zip.close()
	notes.append("bundle %s: %s" % [path, "valid" if ok else "INVALID"])
	return ok


func _go(step: String) -> void:
	_screenshot(_step)
	_step = step
	_step_started = _now()


func _screenshot(label: String) -> void:
	if _args.screenshot_dir == "" or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(_args.screenshot_dir)
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s_%02d_%s.png" % [_args.screenshot_dir, role, _shot_index, label])
	_shot_index += 1


func _elapsed() -> float:
	return _now() - _step_started


func _check(check_name: String, passed: bool) -> void:
	checks[check_name] = passed
	print("[bot %s] %s %s" % [role, "PASS" if passed else "FAIL", check_name])


func _fail(reason: String) -> void:
	checks["no_errors"] = false
	notes.append(reason)
	print("[bot %s] FAIL %s" % [role, reason])
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	var passed: bool = not checks.is_empty()
	for k: String in checks:
		if checks[k] != true:
			passed = false
	var out: Dictionary = {
		"role": role,
		"passed": passed,
		"checks": checks,
		"notes": Array(notes),
		"duration_sec": snappedf(_now() - _started, 0.1),
		"client_events": Array(game.events.tail()),
	}
	if _args.test_out != "":
		var f := FileAccess.open(_args.test_out, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(out, "  "))
			f.close()
	print("[bot %s] finished: %s" % [role, "PASSED" if passed else "FAILED"])
	game.disconnect_from_server("test finished")
	get_tree().create_timer(0.3).timeout.connect(get_tree().quit.bind(0 if passed else 1))


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
