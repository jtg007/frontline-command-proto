class_name ClientInput
extends RefCounted
## Input actions registered in code (physical keys, so WASD works on any keyboard layout).

const MOUSE_SENSITIVITY: float = 0.0025


static func ensure_actions() -> void:
	_bind("move_forward", [KEY_W, KEY_UP])
	_bind("move_back", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("jump", [KEY_SPACE])
	_bind("use", [KEY_E])
	_bind("command", [KEY_C])
	_bind("respawn", [KEY_K])
	_bind("switch_team", [KEY_F2])
	_bind("bug_report", [KEY_F8])
	_bind("menu", [KEY_ESCAPE])
	_bind("cmd_rotate_left", [KEY_Q])
	_bind("cmd_rotate_right", [KEY_E])


static func _bind(action: String, keys: Array[Key]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k: Key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
