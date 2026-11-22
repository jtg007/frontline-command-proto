class_name WorldView
extends Node3D
## Renders interpolated snapshot state. One central update per frame drives every
## entity visual (visual nodes have no scripts).

var hide_player_id: int = 0
## Interpolated state from the last apply(), read by ClientGame (camera, hints, bots).
var players: Dictionary[int, SnapshotCodec.PlayerSnap] = {}
var vehicles: Dictionary[int, SnapshotCodec.VehicleSnap] = {}

var _player_nodes: Dictionary[int, Node3D] = {}
var _player_tags: Dictionary[int, Label3D] = {}
var _vehicle_nodes: Dictionary[int, Node3D] = {}
var _vehicle_tags: Dictionary[int, Label3D] = {}
var _waypoint: Node3D
var _waypoint_label: Label3D


func _ready() -> void:
	_waypoint = VisualFactory.make_waypoint()
	_waypoint.visible = false
	add_child(_waypoint)
	_waypoint_label = VisualFactory.make_tag(30, true)
	_waypoint_label.modulate = VisualFactory.ORDER_COLOR
	_waypoint_label.position = Vector3(0.0, 6.0, 0.0)
	_waypoint.add_child(_waypoint_label)


func apply(frame: SnapshotBuffer.Frame, my_id: int, my_team: int, names: Dictionary[int, String]) -> void:
	players.clear()
	for id: int in frame.b.players:
		var a: SnapshotCodec.PlayerSnap = frame.a.players.get(id)
		var s: SnapshotCodec.PlayerSnap = SnapshotBuffer.lerp_player(a, frame.b.players[id], frame.alpha)
		players[id] = s
		if not _player_nodes.has(id) or _player_nodes[id].get_meta("team", -1) != s.team:
			_remove_player(id)
			var node: Node3D = VisualFactory.make_player(s.team)
			node.set_meta("team", s.team)
			add_child(node)
			_player_nodes[id] = node
			var tag: Label3D = VisualFactory.make_tag(36, false)
			tag.position = Vector3(0.0, 2.3, 0.0)
			node.add_child(tag)
			_player_tags[id] = tag
		var n: Node3D = _player_nodes[id]
		n.visible = s.is_alive() and not s.in_vehicle() and not s.is_commander() and id != hide_player_id
		n.position = s.pos
		n.rotation = Vector3(0.0, s.yaw, 0.0)
		var t: Label3D = _player_tags[id]
		t.visible = s.team == my_team and id != my_id
		t.text = names.get(id, "?")
	for id: int in _player_nodes.keys():
		if not frame.b.players.has(id):
			_remove_player(id)

	vehicles.clear()
	for id: int in frame.b.vehicles:
		var a: SnapshotCodec.VehicleSnap = frame.a.vehicles.get(id)
		var s: SnapshotCodec.VehicleSnap = SnapshotBuffer.lerp_vehicle(a, frame.b.vehicles[id], frame.alpha)
		vehicles[id] = s
		if not _vehicle_nodes.has(id):
			var node: Node3D = VisualFactory.make_tank(s.team)
			add_child(node)
			_vehicle_nodes[id] = node
			var tag: Label3D = VisualFactory.make_tag(34, false)
			tag.position = Vector3(0.0, 3.6, 0.0)
			node.add_child(tag)
			_vehicle_tags[id] = tag
		_vehicle_nodes[id].transform = Transform3D(TankSuspension.hull_basis(s.yaw, s.pitch, s.roll), s.pos)
		var vt: Label3D = _vehicle_tags[id]
		vt.visible = s.team == my_team and s.driver != my_id
		vt.text = "TANK · %s" % (names.get(s.driver, "?") if s.driver != 0 else "empty — press E")
	for id: int in _vehicle_nodes.keys():
		if not frame.b.vehicles.has(id):
			_vehicle_nodes[id].queue_free()
			_vehicle_nodes.erase(id)
			_vehicle_tags.erase(id)


func set_waypoint(active: bool, pos: Vector3) -> void:
	_waypoint.visible = active
	_waypoint.position = pos


func update_waypoint_text(distance: float, placed_by: String) -> void:
	_waypoint_label.text = "MOVE HERE · %d m\norder by %s" % [roundi(distance), placed_by]


func clear() -> void:
	for id: int in _player_nodes.keys():
		_remove_player(id)
	for id: int in _vehicle_nodes.keys():
		_vehicle_nodes[id].queue_free()
	_vehicle_nodes.clear()
	_vehicle_tags.clear()
	players.clear()
	vehicles.clear()
	set_waypoint(false, Vector3.ZERO)


func _remove_player(id: int) -> void:
	if _player_nodes.has(id):
		_player_nodes[id].queue_free()
		_player_nodes.erase(id)
		_player_tags.erase(id)
