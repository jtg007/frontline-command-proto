class_name BugReporter
extends RefCounted
## F8 debug bundle: one small zip a playtester attaches to a 1-sentence report.
## Contents: info.json (build, OS/GPU, FPS percentiles, ping/loss, state),
## client_events.log and server_events.log (last 200 events each, own team only).

const DIR: String = "user://bug_reports"


static func make_bug_id() -> String:
	var t: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d%02d%02d-%02d%02d%02d-%04d" % [t["year"], t["month"], t["day"], t["hour"], t["minute"], t["second"], randi() % 10000]


static func system_info() -> Dictionary:
	return {
		"os": OS.get_name(),
		"os_version": OS.get_version(),
		"cpu": OS.get_processor_name(),
		"cpu_threads": OS.get_processor_count(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"gpu_driver": Array(OS.get_video_adapter_driver_info()),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"display_server": DisplayServer.get_name(),
		"window_size": str(DisplayServer.window_get_size()) if DisplayServer.get_name() != "headless" else "headless",
		"memory_static_mb": snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1),
	}


## Returns the absolute path of the written zip, or "" on failure.
static func write_bundle(bug_id: String, info: Dictionary, client_lines: PackedStringArray, server_lines: PackedStringArray) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path: String = "%s/bug_%s_%s.zip" % [DIR, BuildInfo.build_id(), bug_id]
	var zip := ZIPPacker.new()
	if zip.open(path) != OK:
		return ""
	_add_file(zip, "info.json", JSON.stringify(info, "  "))
	_add_file(zip, "client_events.log", "\n".join(client_lines) + "\n")
	var server_text: String = "\n".join(server_lines) + "\n" if not server_lines.is_empty() else "(server log not available — not connected or no reply)\n"
	_add_file(zip, "server_events.log", server_text)
	zip.close()
	return ProjectSettings.globalize_path(path)


static func _add_file(zip: ZIPPacker, file_name: String, text: String) -> void:
	zip.start_file(file_name)
	zip.write_file(text.to_utf8_buffer())
	zip.close_file()
