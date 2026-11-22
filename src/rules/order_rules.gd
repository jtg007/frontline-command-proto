class_name OrderRules
extends RefCounted
## Pure validation rules for seats and Commander orders. Each check returns "" when the
## intent is allowed, otherwise a plain-English reason that is shown to the player as-is.

const ENTER_VEHICLE_RANGE: float = 4.5
const COMMAND_POST_RANGE: float = 6.0
const WAYPOINT_REACHED_RADIUS: float = 8.0
const MAX_NAME_LENGTH: int = 20


static func check_place_waypoint(is_commander: bool, pos: Vector3, bounds: AABB) -> String:
	if not is_commander:
		return "Only the Commander can place waypoints. Walk to your Command Vehicle and press C."
	if not (is_finite(pos.x) and is_finite(pos.y) and is_finite(pos.z)):
		return "Invalid waypoint position."
	if pos.x < bounds.position.x or pos.x > bounds.end.x or pos.z < bounds.position.z or pos.z > bounds.end.z:
		return "That spot is outside the map."
	return ""


## Waypoints are private team information: only peers on `team` receive them.
static func waypoint_recipients(team: int, peer_teams: Dictionary[int, int]) -> PackedInt32Array:
	var out := PackedInt32Array()
	for peer_id: int in peer_teams:
		if peer_teams[peer_id] == team:
			out.append(peer_id)
	return out


static func check_enter_vehicle(alive: bool, is_commander: bool, same_team: bool, distance: float, driver_name: String) -> String:
	if not alive:
		return "You can't do that while dead."
	if is_commander:
		return "Leave the Commander seat first (press C)."
	if distance > ENTER_VEHICLE_RANGE:
		if is_inf(distance):
			return "There is no tank nearby."
		return "Too far from the tank (%d m). Walk closer." % roundi(distance)
	if not same_team:
		return "That tank belongs to the enemy team."
	if driver_name != "":
		return "The driver seat is taken by %s." % driver_name
	return ""


static func check_take_command(alive: bool, in_vehicle: bool, distance: float, commander_name: String) -> String:
	if not alive:
		return "You can't do that while dead."
	if in_vehicle:
		return "Leave the vehicle first (press E)."
	if commander_name != "":
		return "%s is already your Commander." % commander_name
	if distance > COMMAND_POST_RANGE:
		return "Too far from your Command Vehicle (%d m). Walk up to it." % roundi(distance)
	return ""


static func sanitize_name(raw: String, fallback: String) -> String:
	var out: String = ""
	for i: int in range(raw.length()):
		var c: int = raw.unicode_at(i)
		if c >= 32 and c != 127 and "[]{}<>\\".find(char(c)) < 0:
			out += char(c)
	out = out.strip_edges().substr(0, MAX_NAME_LENGTH).strip_edges()
	return out if out != "" else fallback
