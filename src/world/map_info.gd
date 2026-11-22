class_name MapInfo
extends RefCounted
## Gameplay data read from a map scene's `Markers` node. Map scenes contain only
## geometry + markers (no scripts), so mappers can edit them in the Godot editor.
##
## Marker names: Spawn_T<team>, CommandPost_T<team>, VehicleSpawn_T<team>[_n],
## ResourceNode_<n>, TestWaypoint. Root metadata: map_id (String), bounds (AABB).

const DEFAULT_MAP: String = "res://maps/greybox_01/greybox_01.tscn"

var map_id: String = ""
var root: Node3D
var bounds: AABB = AABB(Vector3(-100, -20, -100), Vector3(200, 80, 200))
var spawns: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var command_posts: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var vehicle_spawns: Array[Transform3D] = []
var vehicle_spawn_teams: PackedInt32Array = PackedInt32Array()
var resource_nodes: Array[Vector3] = []
var test_waypoint: Vector3 = Vector3.ZERO


static func load_into(parent: Node, path: String = DEFAULT_MAP) -> MapInfo:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Map not found: %s" % path)
		return null
	var scene_root := packed.instantiate() as Node3D
	parent.add_child(scene_root)
	return from_root(scene_root)


static func from_root(scene_root: Node3D) -> MapInfo:
	var info := MapInfo.new()
	info.root = scene_root
	info.map_id = str(scene_root.get_meta("map_id", scene_root.name))
	if scene_root.has_meta("bounds"):
		info.bounds = scene_root.get_meta("bounds")
	var markers: Node = scene_root.get_node_or_null("Markers")
	if markers == null:
		push_error("Map %s has no Markers node" % info.map_id)
		return info
	for child: Node in markers.get_children():
		var marker := child as Node3D
		if marker == null:
			continue
		var n: String = marker.name
		var team: int = 1 if n.contains("_T1") else 0
		if n.begins_with("Spawn_T"):
			info.spawns[team] = marker.global_position
		elif n.begins_with("CommandPost_T"):
			info.command_posts[team] = marker.global_position
		elif n.begins_with("VehicleSpawn_T"):
			info.vehicle_spawns.append(marker.global_transform)
			info.vehicle_spawn_teams.append(team)
		elif n.begins_with("ResourceNode"):
			info.resource_nodes.append(marker.global_position)
		elif n == "TestWaypoint":
			info.test_waypoint = marker.global_position
	return info
