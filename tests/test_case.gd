class_name TestCase
extends RefCounted
## Minimal assertion base for tests/unit/test_*.gd (no external test framework needed).

var failures: PackedStringArray = PackedStringArray()
var current: String = ""


func check(cond: bool, what: String) -> void:
	if not cond:
		failures.append("%s: %s" % [current, what])


func check_eq(actual: Variant, expected: Variant, what: String) -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s: %s — expected %s, got %s" % [current, what, str(expected), str(actual)])


func check_near(actual: float, expected: float, tolerance: float, what: String) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s: %s — expected %.4f ± %.4f, got %.4f" % [current, what, expected, tolerance, actual])
