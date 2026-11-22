extends SceneTree
## Runs every test_* method in tests/unit/test_*.gd.
## godot --headless --path . -s tests/run_unit_tests.gd

const DIR: String = "res://tests/unit"


func _init() -> void:
	var total: int = 0
	var failed: PackedStringArray = PackedStringArray()
	var files: PackedStringArray = DirAccess.get_files_at(DIR)
	files.sort()
	for file: String in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script := load("%s/%s" % [DIR, file]) as GDScript
		if script == null or not script.can_instantiate():
			failed.append("%s: failed to load" % file)
			continue
		var suite := script.new() as TestCase
		for m: Dictionary in script.get_script_method_list():
			var method: String = m["name"]
			if not method.begins_with("test_"):
				continue
			total += 1
			suite.current = "%s::%s" % [file.get_basename(), method]
			var before: int = suite.failures.size()
			suite.call(method)
			print("  %s %s" % ["ok  " if suite.failures.size() == before else "FAIL", suite.current])
		failed.append_array(suite.failures)
	print("")
	for f: String in failed:
		print("FAIL " + f)
	print("%d tests, %d failures" % [total, failed.size()])
	quit(0 if failed.is_empty() and total > 0 else 1)
