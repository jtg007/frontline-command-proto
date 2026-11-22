extends TestCase


func test_event_log_ring_and_team_filter() -> void:
	var log_: EventLog = EventLog.new(false)
	for i: int in range(EventLog.CAPACITY + 50):
		log_.add("T", "event %d" % i, Teams.BLUE if i % 2 == 0 else Teams.RED)
	check_eq(log_.size(), EventLog.CAPACITY, "capped at capacity")
	var all: PackedStringArray = log_.tail()
	check(all[0].ends_with("event 50") and all[all.size() - 1].ends_with("event 249"), "oldest first, newest last")
	log_.add("T", "global")
	var red: PackedStringArray = log_.tail(Teams.RED)
	var leaked: bool = false
	for line: String in red:
		var n: int = line.get_slice("event ", 1).to_int() if line.contains("event ") else 1
		if n % 2 == 0:
			leaked = true
	check(not leaked, "Red tail contains no Blue events")
	check(red[red.size() - 1].ends_with("global"), "untagged events visible to all")


func test_frame_stats_percentiles() -> void:
	var fs := FrameStats.new()
	for i: int in range(100):
		fs.add_frame((i + 1) / 1000.0)  # 1..100 ms
	check_near(fs.percentile_ms(0.5), 50.0, 0.01, "p50")
	check_near(fs.percentile_ms(0.95), 95.0, 0.01, "p95")
	var s: Dictionary = fs.summary()
	var worst: float = s["worst_ms"]
	check_near(worst, 100.0, 0.01, "worst")


func test_address_parsing() -> void:
	check_eq(NetProtocol.parse_host("203.0.113.5:4000"), "203.0.113.5", "host")
	check_eq(NetProtocol.parse_port("203.0.113.5:4000"), 4000, "port")
	check_eq(NetProtocol.parse_port("example.org"), NetProtocol.DEFAULT_PORT, "default port")
	check_eq(NetProtocol.parse_host("udp://play.example.org:1234/"), "play.example.org", "scheme stripped")
	check_eq(NetProtocol.parse_port("host:99999"), NetProtocol.DEFAULT_PORT, "invalid port falls back")


func test_launch_args() -> void:
	var a: LaunchArgs = LaunchArgs.parse(PackedStringArray(["--server", "--port=4000", "--team=red", "--name=Ann"]))
	check(a.is_server, "server flag")
	check_eq(a.port, 4000, "port")
	check_eq(a.team, Teams.RED, "team")
	check_eq(a.player_name, "Ann", "name")
