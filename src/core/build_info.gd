class_name BuildInfo
extends RefCounted
## Build identification for the on-screen watermark, join handshake and F8 bug reports.
##
## Packaged builds read `res://build_stamp.json` (written by tools/stamp_build.sh).
## Dev checkouts fall back to asking git for the current commit.

const STAMP_PATH: String = "res://build_stamp.json"
const GAME_NAME: String = "Frontline Command Proto"

static var _loaded: bool = false
static var _build_id: String = "dev"
static var _commit: String = "unknown"
static var _built_at: String = ""


static func build_id() -> String:
	_ensure_loaded()
	return _build_id


static func commit() -> String:
	_ensure_loaded()
	return _commit


static func built_at() -> String:
	_ensure_loaded()
	return _built_at


static func watermark() -> String:
	return "%s · build %s · protocol %d" % [GAME_NAME, build_id(), NetProtocol.PROTOCOL_VERSION]


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(STAMP_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STAMP_PATH))
		if parsed is Dictionary:
			var stamp: Dictionary = parsed
			_build_id = str(stamp.get("build_id", "dev"))
			_commit = str(stamp.get("commit", "unknown"))
			_built_at = str(stamp.get("built_at", ""))
		return
	if OS.has_feature("template"):
		return  # Exported build without stamp: keep "dev".
	var output: Array = []
	var project_dir: String = ProjectSettings.globalize_path("res://")
	if OS.execute("git", ["-C", project_dir, "rev-parse", "--short", "HEAD"], output) == 0 and not output.is_empty():
		_commit = str(output[0]).strip_edges()
		_build_id = "dev-" + _commit
