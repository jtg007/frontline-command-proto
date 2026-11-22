extends TestCase

const BOUNDS: AABB = AABB(Vector3(-95, -20, -95), Vector3(190, 80, 190))


func test_waypoint_requires_commander_and_map_bounds() -> void:
	check(OrderRules.check_place_waypoint(false, Vector3.ZERO, BOUNDS).begins_with("Only the Commander"), "non-commander refused")
	check_eq(OrderRules.check_place_waypoint(true, Vector3(500, 0, 0), BOUNDS), "That spot is outside the map.", "outside map")
	check(OrderRules.check_place_waypoint(true, Vector3(NAN, 0, 0), BOUNDS) != "", "NaN refused")
	check_eq(OrderRules.check_place_waypoint(true, Vector3(10, 3, -20), BOUNDS), "", "valid order")


func test_waypoint_recipients_are_team_only() -> void:
	var teams: Dictionary[int, int] = {11: Teams.BLUE, 12: Teams.RED, 13: Teams.BLUE}
	var blue: PackedInt32Array = OrderRules.waypoint_recipients(Teams.BLUE, teams)
	check(blue.has(11) and blue.has(13) and not blue.has(12), "only Blue peers receive Blue orders")
	check_eq(OrderRules.waypoint_recipients(Teams.RED, teams), PackedInt32Array([12]), "Red recipients")


func test_enter_vehicle_reasons() -> void:
	check_eq(OrderRules.check_enter_vehicle(true, false, true, 2.0, ""), "", "allowed")
	check(OrderRules.check_enter_vehicle(false, false, true, 2.0, "").contains("dead"), "dead")
	check(OrderRules.check_enter_vehicle(true, true, true, 2.0, "").contains("Commander"), "commander")
	check(OrderRules.check_enter_vehicle(true, false, true, 9.0, "").begins_with("Too far from the tank (9 m)"), "distance")
	check(OrderRules.check_enter_vehicle(true, false, false, 2.0, "").contains("enemy"), "enemy tank")
	check_eq(OrderRules.check_enter_vehicle(true, false, true, 2.0, "Ann"), "The driver seat is taken by Ann.", "seat taken")


func test_take_command_reasons() -> void:
	check_eq(OrderRules.check_take_command(true, false, 3.0, ""), "", "allowed")
	check_eq(OrderRules.check_take_command(true, false, 3.0, "Bob"), "Bob is already your Commander.", "taken")
	check(OrderRules.check_take_command(true, false, 20.0, "").begins_with("Too far from your Command Vehicle (20 m)"), "distance")
	check(OrderRules.check_take_command(true, true, 3.0, "").contains("vehicle"), "in vehicle")


func test_sanitize_name() -> void:
	check_eq(OrderRules.sanitize_name("  Ann  ", "x"), "Ann", "trims")
	check_eq(OrderRules.sanitize_name("[b]Evil[/b]\n", "x"), "bEvil/b", "strips markup chars and control chars")
	check_eq(OrderRules.sanitize_name("", "Player7"), "Player7", "fallback")
	check_eq(OrderRules.sanitize_name("abcdefghijklmnopqrstuvwxyz", "x").length(), OrderRules.MAX_NAME_LENGTH, "max length")


func test_team_helpers() -> void:
	check_eq(Teams.auto_assign(PackedInt32Array([0, 0])), Teams.BLUE, "tie goes to Blue")
	check_eq(Teams.auto_assign(PackedInt32Array([2, 1])), Teams.RED, "smaller team")
	check_eq(Teams.parse_team("RED"), Teams.RED, "parse red")
	check_eq(Teams.parse_team("auto"), Teams.NONE, "auto")
