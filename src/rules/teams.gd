class_name Teams
extends RefCounted
## Two placeholder sides until the community names the factions.

const NONE: int = -1
const COUNT: int = 2
const BLUE: int = 0
const RED: int = 1


static func is_valid(team: int) -> bool:
	return team >= 0 and team < COUNT


static func name_of(team: int) -> String:
	match team:
		BLUE:
			return "Blue"
		RED:
			return "Red"
	return "Unassigned"


static func color_of(team: int) -> Color:
	match team:
		BLUE:
			return Color(0.22, 0.48, 0.95)
		RED:
			return Color(0.92, 0.28, 0.22)
	return Color(0.6, 0.6, 0.6)


static func other(team: int) -> int:
	return RED if team == BLUE else BLUE


## "0"/"blue"/"1"/"red" -> team id; anything else (e.g. "auto") -> NONE.
static func parse_team(text: String) -> int:
	match text.strip_edges().to_lower():
		"0", "blue":
			return BLUE
		"1", "red":
			return RED
	return NONE


## Smallest team wins; ties go to Blue.
static func auto_assign(counts: PackedInt32Array) -> int:
	var best: int = 0
	for t: int in range(1, mini(counts.size(), COUNT)):
		if counts[t] < counts[best]:
			best = t
	return best
