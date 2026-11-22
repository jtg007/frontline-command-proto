class_name JoinMenu
extends Control
## Join screen: server address is pre-filled from config/default_server.cfg (set by the
## packager for each playtest) or the last address used.

signal join_requested(address: String, player_name: String, team: int)
signal host_local_requested(player_name: String, team: int)
signal quit_requested()

const SETTINGS_PATH: String = "user://settings.cfg"
const DEFAULTS_PATH: String = "res://config/default_server.cfg"

var _address: LineEdit
var _name: LineEdit
var _team: OptionButton
var _status: Label
var _join: Button
var _host: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.06, 0.08, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(460, 0)
	add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Frontline Command — Prototype"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var task := Label.new()
	task.text = "Playtest 1: the Commander places a waypoint,\nthe driver finds it and drives the tank there."
	task.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	task.modulate = Color(1, 1, 1, 0.75)
	box.add_child(task)

	_address = _field(box, "Server address (host:port)")
	_name = _field(box, "Your name")
	box.add_child(_caption("Team (both playtesters pick the same team)"))
	_team = OptionButton.new()
	_team.add_item("Blue", Teams.BLUE)
	_team.add_item("Red", Teams.RED)
	_team.add_item("Auto (balance)", 99)
	box.add_child(_team)

	_join = Button.new()
	_join.text = "Join"
	_join.custom_minimum_size.y = 40
	_join.pressed.connect(_on_join)
	box.add_child(_join)
	_host = Button.new()
	_host.text = "Host local test server + join"
	_host.pressed.connect(_on_host)
	box.add_child(_host)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(quit_requested.emit)
	box.add_child(quit)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(420, 0)
	box.add_child(_status)
	var wm := Label.new()
	wm.text = BuildInfo.watermark()
	wm.modulate = Color(1, 1, 1, 0.5)
	wm.add_theme_font_size_override("font_size", 12)
	box.add_child(wm)
	_address.text_submitted.connect(func(_t: String) -> void: _on_join())
	_load_settings()


func set_status(text: String, is_error: bool = false) -> void:
	_status.text = text
	_status.modulate = Color(1.0, 0.55, 0.45) if is_error else Color(0.8, 0.9, 1.0)


func set_busy(busy: bool) -> void:
	_join.disabled = busy
	_host.disabled = busy


func _on_join() -> void:
	var addr: String = _address.text.strip_edges()
	if addr == "":
		set_status("Enter a server address, e.g. 203.0.113.5:27515", true)
		return
	_save_settings()
	join_requested.emit(addr, _name.text.strip_edges(), _selected_team())


func _on_host() -> void:
	_save_settings()
	host_local_requested.emit(_name.text.strip_edges(), _selected_team())


func _selected_team() -> int:
	var id: int = _team.get_selected_id()
	return id if Teams.is_valid(id) else Teams.NONE


func _load_settings() -> void:
	var defaults := ConfigFile.new()
	defaults.load(DEFAULTS_PATH)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	var default_addr: String = str(defaults.get_value("server", "address", "127.0.0.1:%d" % NetProtocol.DEFAULT_PORT))
	# A freshly packaged playtest address wins over an older remembered one.
	var remembered_for: String = str(cfg.get_value("client", "default_address_seen", ""))
	_address.text = str(cfg.get_value("client", "address", default_addr)) if remembered_for == default_addr else default_addr
	_name.text = str(cfg.get_value("client", "name", "Player%d" % (randi() % 900 + 100)))
	var team: int = Teams.parse_team(str(cfg.get_value("client", "team", defaults.get_value("server", "default_team", "blue"))))
	_team.select(_team.get_item_index(team if Teams.is_valid(team) else 99))


func _save_settings() -> void:
	var defaults := ConfigFile.new()
	defaults.load(DEFAULTS_PATH)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("client", "address", _address.text.strip_edges())
	cfg.set_value("client", "default_address_seen", str(defaults.get_value("server", "address", "")))
	cfg.set_value("client", "name", _name.text.strip_edges())
	var t: int = _selected_team()
	cfg.set_value("client", "team", "auto" if t == Teams.NONE else Teams.name_of(t).to_lower())
	cfg.save(SETTINGS_PATH)


func _field(box: VBoxContainer, caption: String) -> LineEdit:
	box.add_child(_caption(caption))
	var e := LineEdit.new()
	e.custom_minimum_size.y = 34
	box.add_child(e)
	return e


func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.modulate = Color(1, 1, 1, 0.7)
	return l
