class_name LaunchArgs
extends RefCounted
## Command-line options (everything after `--` on the Godot command line).
##
##   --server                 run as headless dedicated server
##   --port=27515             server listen port
##   --max-players=32
##   --connect=host:port      client: join this server directly (skips the menu)
##   --name=Alice             client: player name
##   --team=blue|red|auto     client: preferred team
##   --bot=commander|driver|spy   automated test client (see src/client/bot_brain.gd)
##   --test-out=path.json     write automated test results here
##   --test-timeout=90        abort automated test after N seconds
##   --exit-when-empty        server: quit when the last player leaves (CI)
##   --screenshot-dir=path    bot clients with a window save PNGs at key test steps

var is_server: bool = false
var port: int = NetProtocol.DEFAULT_PORT
var max_players: int = NetProtocol.MAX_CLIENTS
var connect_address: String = ""
var player_name: String = ""
var team: int = Teams.NONE
var bot: String = ""
var test_out: String = ""
var test_timeout: float = 0.0
var exit_when_empty: bool = false
var screenshot_dir: String = ""


static func parse(args: PackedStringArray) -> LaunchArgs:
	var result := LaunchArgs.new()
	for raw: String in args:
		var key: String = raw
		var value: String = ""
		var eq: int = raw.find("=")
		if eq >= 0:
			key = raw.substr(0, eq)
			value = raw.substr(eq + 1)
		match key:
			"--server":
				result.is_server = true
			"--port":
				result.port = clampi(value.to_int(), 1, 65535)
			"--max-players":
				result.max_players = clampi(value.to_int(), 1, 128)
			"--connect":
				result.connect_address = value
			"--name":
				result.player_name = value
			"--team":
				result.team = Teams.parse_team(value)
			"--bot":
				result.bot = value
			"--test-out":
				result.test_out = value
			"--test-timeout":
				result.test_timeout = value.to_float()
			"--exit-when-empty":
				result.exit_when_empty = true
			"--screenshot-dir":
				result.screenshot_dir = value
	if OS.has_feature("dedicated_server"):
		result.is_server = true
	return result
