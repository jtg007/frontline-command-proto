class_name EventLog
extends RefCounted
## Fixed-size ring buffer of the last 200 state events (connections, orders, seat changes...).
## Exported by the F8 bug bundle. Events tagged with a team are only shown to that team,
## so a bug report can never leak the enemy's private orders.

const CAPACITY: int = 200
const ALL_TEAMS: int = -2

var current_tick: int = 0
var echo_to_stdout: bool = false

var _lines: PackedStringArray = PackedStringArray()
var _teams: PackedInt32Array = PackedInt32Array()
var _next: int = 0
var _count: int = 0


func _init(echo: bool = false) -> void:
	echo_to_stdout = echo
	_lines.resize(CAPACITY)
	_teams.resize(CAPACITY)


func add(category: String, text: String, team: int = Teams.NONE) -> void:
	var line: String = "[%9.3fs tick %6d] %-8s %s" % [Time.get_ticks_msec() / 1000.0, current_tick, category, text]
	_lines[_next] = line
	_teams[_next] = team
	_next = (_next + 1) % CAPACITY
	_count = mini(_count + 1, CAPACITY)
	if echo_to_stdout:
		print(line)


func size() -> int:
	return _count


## Oldest first. `team_filter` = ALL_TEAMS returns everything; otherwise only
## untagged events and events of that team.
func tail(team_filter: int = ALL_TEAMS) -> PackedStringArray:
	var out := PackedStringArray()
	var start: int = (_next - _count + CAPACITY) % CAPACITY
	for i: int in range(_count):
		var idx: int = (start + i) % CAPACITY
		var team: int = _teams[idx]
		if team_filter == ALL_TEAMS or team == Teams.NONE or team == team_filter:
			out.append(_lines[idx])
	return out
