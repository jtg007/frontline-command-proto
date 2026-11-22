class_name Hud
extends Control
## In-game HUD, built in code. Pure presentation: ClientGame pushes text/state in.

signal resume_pressed()
signal disconnect_pressed()
signal quit_pressed()

const TOAST_SECONDS: float = 5.0
const WARN_COLOR: Color = Color(1.0, 0.62, 0.25)

var _crosshair: Label
var _status: Label
var _hint: Label
var _help: Label
var _perf: Label
var _watermark: Label
var _toasts: VBoxContainer
var _center: Label
var _menu: PanelContainer
var _indicator: WaypointIndicator


class WaypointIndicator:
	extends Control
	var active: bool = false
	var screen_pos: Vector2 = Vector2.ZERO
	var behind: bool = false
	var text: String = ""
	var font: Font = ThemeDB.fallback_font

	func _draw() -> void:
		if not active:
			return
		var rect: Rect2 = get_viewport_rect()
		var margin: float = 48.0
		var center: Vector2 = rect.size * 0.5
		var p: Vector2 = screen_pos
		if behind:
			p = center - (p - center) * 1000.0  # mirror: target is behind the camera
		var inner := Rect2(Vector2(margin, margin), rect.size - Vector2(margin, margin) * 2.0)
		var on_screen: bool = not behind and inner.has_point(p)
		var col: Color = VisualFactory.ORDER_COLOR
		if on_screen:
			draw_arc(p, 14.0, 0.0, TAU, 24, col, 3.0)
			return
		# Off-screen: clamp to the screen edge and point toward the order.
		var dir: Vector2 = (p - center).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.UP
		var half: Vector2 = inner.size * 0.5
		var scale: float = minf(half.x / maxf(absf(dir.x), 0.0001), half.y / maxf(absf(dir.y), 0.0001))
		var edge: Vector2 = center + dir * scale
		var tip: Vector2 = edge + dir * 18.0
		var side: Vector2 = Vector2(-dir.y, dir.x) * 12.0
		draw_colored_polygon(PackedVector2Array([tip, edge - dir * 6.0 + side, edge - dir * 6.0 - side]), col)
		draw_string(font, edge - dir * 34.0 + Vector2(-60.0, 6.0), text, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 18, col)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_indicator = WaypointIndicator.new()
	_indicator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_indicator)

	_crosshair = _label("+", 28, Control.PRESET_CENTER)
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.position -= Vector2(10, 20)

	_status = _label("", 20, Control.PRESET_TOP_LEFT)
	_status.position = Vector2(16, 12)
	_hint = _label("", 22, Control.PRESET_CENTER_BOTTOM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.position.y -= 150
	_help = _label("", 15, Control.PRESET_BOTTOM_LEFT)
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help.position += Vector2(16, -12)
	_perf = _label("", 15, Control.PRESET_TOP_RIGHT)
	_perf.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_perf.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_perf.position += Vector2(-16, 12)
	_watermark = _label(BuildInfo.watermark(), 13, Control.PRESET_BOTTOM_RIGHT)
	_watermark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_watermark.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_watermark.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_watermark.position += Vector2(-12, -8)
	_watermark.modulate = Color(1, 1, 1, 0.6)
	_center = _label("", 30, Control.PRESET_CENTER)
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_center.position.y += 60

	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toasts.offset_top = 64.0

	_build_menu()


func set_status(text: String, color: Color) -> void:
	_status.text = text
	_status.modulate = color


func set_hint(text: String) -> void:
	_hint.text = text


func set_help(text: String) -> void:
	_help.text = text


func set_perf(text: String) -> void:
	_perf.text = text


func set_center(text: String) -> void:
	_center.text = text


func set_crosshair_visible(v: bool) -> void:
	_crosshair.visible = v


func set_waypoint_indicator(active: bool, screen_pos: Vector2, behind: bool, text: String) -> void:
	_indicator.active = active
	_indicator.screen_pos = screen_pos
	_indicator.behind = behind
	_indicator.text = text
	_indicator.queue_redraw()


func toast(text: String, color: Color = Color.WHITE) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = color
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_toasts.add_child(l)
	while _toasts.get_child_count() > 5:
		_toasts.get_child(0).free()
	var tw: Tween = l.create_tween()
	tw.tween_interval(TOAST_SECONDS)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func is_menu_open() -> bool:
	return _menu.visible


func set_menu_open(open: bool) -> void:
	_menu.visible = open


func _build_menu() -> void:
	_menu = PanelContainer.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_menu.custom_minimum_size = Vector2(320, 0)
	_menu.visible = false
	add_child(_menu)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_menu.add_child(box)
	var title := Label.new()
	title.text = "Paused (game keeps running)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var buttons: Array[Array] = [["Resume", resume_pressed], ["Disconnect", disconnect_pressed], ["Quit game", quit_pressed]]
	for entry: Array in buttons:
		var b := Button.new()
		b.text = entry[0]
		var sig: Signal = entry[1]
		b.pressed.connect(sig.emit)
		box.add_child(b)


func _label(text: String, size: int, preset: Control.LayoutPreset) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.set_anchors_and_offsets_preset(preset)
	return l
