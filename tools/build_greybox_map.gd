extends SceneTree
## Generates maps/greybox_01/greybox_01.tscn (a normal, editor-editable Godot scene).
## Run:  godot --headless --path . -s tools/build_greybox_map.gd
## Layout (1 unit = 1 m): Blue base south (+Z), Red base north (-Z), mirrored 180°.
## Centre: 3 m mesa with 12° ramps on all sides. Factories open toward the centre with
## painted exit lanes; one tank parked in each lane.

const OUT_PATH: String = "res://maps/greybox_01/greybox_01.tscn"
const GRID_SHADER: String = "res://shaders/greybox_grid.gdshader"

var map_root: Node3D
var _mats: Dictionary[String, Material] = {}
var _box_meshes: Dictionary[Vector3, BoxMesh] = {}


func _init() -> void:
	map_root = Node3D.new()
	map_root.name = "Greybox01"
	map_root.set_meta("map_id", "greybox_01")
	map_root.set_meta("bounds", AABB(Vector3(-95.0, -20.0, -95.0), Vector3(190.0, 80.0, 190.0)))
	_make_materials()
	_environment()
	var geo: Node3D = _group("Geometry")
	var marks: Node3D = _group("Markings")
	var markers: Node3D = _group("Markers")

	# Ground + map edge.
	_box(geo, "Ground", Vector3(240.0, 1.0, 240.0), Transform3D(Basis(), Vector3(0.0, -0.5, 0.0)), "ground")
	for i: int in range(4):
		var yaw: float = i * PI * 0.5
		var b := Basis(Vector3.UP, yaw)
		_box(geo, "EdgeWall%d" % i, Vector3(202.0, 4.0, 1.0), Transform3D(b, b * Vector3(0.0, 2.0, 100.5)), "concrete_dark")

	# Centre mesa with four ramps.
	_box(geo, "Mesa", Vector3(24.0, 3.0, 24.0), Transform3D(Basis(), Vector3(0.0, 1.5, 0.0)), "rock")
	var ramp_yaws: Array[float] = [0.0, PI, PI * 0.5, -PI * 0.5]
	for i: int in range(4):
		_ramp(geo, "MesaRamp%d" % i, ramp_yaws[i], 12.0, 3.0, 20.0, 12.0)
	_box(geo, "MesaCoverA", Vector3(6.0, 1.2, 0.6), Transform3D(Basis(), Vector3(-7.0, 3.6, -6.0)), "concrete")
	_box(geo, "MesaCoverB", Vector3(6.0, 1.2, 0.6), Transform3D(Basis(), Vector3(7.0, 3.6, 6.0)), "concrete")

	# Both bases (team 1 = team 0 rotated 180° around the map centre).
	for team: int in range(2):
		var flip := Transform3D(Basis(Vector3.UP, PI * team), Vector3.ZERO)
		_base(geo, marks, markers, team, flip)

	# Neutral cover: concrete walls, rocks and crates, mirrored for fairness.
	var cover: Array[Array] = [
		["Wall", Vector3(8.0, 2.2, 0.6), Vector3(-32.0, 1.1, 34.0), 0.3, "concrete"],
		["Wall", Vector3(8.0, 2.2, 0.6), Vector3(-48.0, 1.1, 12.0), -0.6, "concrete"],
		["Wall", Vector3(10.0, 2.2, 0.6), Vector3(36.0, 1.1, 30.0), 1.2, "concrete"],
		["Rock", Vector3(5.0, 3.0, 4.0), Vector3(-22.0, 1.2, 50.0), 0.5, "rock"],
		["Rock", Vector3(7.0, 4.0, 5.0), Vector3(55.0, 1.5, 45.0), 1.1, "rock"],
		["Rock", Vector3(4.0, 2.5, 6.0), Vector3(-60.0, 1.0, 40.0), 0.2, "rock"],
		["Crates", Vector3(2.0, 2.0, 2.0), Vector3(30.0, 1.0, 58.0), 0.0, "crate"],
		["Crates", Vector3(2.0, 2.0, 2.0), Vector3(31.5, 1.0, 55.8), 0.4, "crate"],
		["Crates", Vector3(2.0, 2.0, 2.0), Vector3(-26.0, 1.0, 66.0), 0.2, "crate"],
	]
	var n: int = 0
	for team: int in range(2):
		var flip := Transform3D(Basis(Vector3.UP, PI * team), Vector3.ZERO)
		for c: Array in cover:
			var kind: String = c[0]
			var size: Vector3 = c[1]
			var pos: Vector3 = c[2]
			var yaw: float = c[3]
			var mat: String = c[4]
			_box(geo, "%s%d" % [kind, n], size, flip * Transform3D(Basis(Vector3.UP, yaw), pos), mat)
			n += 1

	# Resource nodes (visual only until Step D).
	for i: int in range(2):
		var p := Vector3(-40.0 if i == 0 else 40.0, 0.0, 0.0)
		_box(marks, "ResourceNodePad%d" % i, Vector3(6.0, 0.06, 6.0), Transform3D(Basis(), p + Vector3(0.0, 0.03, 0.0)), "resource", false)
		_label(marks, "ResourceNodeLabel%d" % i, "RESOURCE NODE", p + Vector3(0.0, 2.5, 0.0), 64)
		_marker(markers, "ResourceNode_%d" % i, Transform3D(Basis(), p))

	_marker(markers, "TestWaypoint", Transform3D(Basis(), Vector3(0.0, 3.0, 0.0)))

	_set_owner_recursive(map_root, map_root)
	var packed := PackedScene.new()
	var err: Error = packed.pack(map_root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_PATH)
	print("build_greybox_map: %s -> %s" % [error_string(err), OUT_PATH])
	map_root.free()
	quit(0 if err == OK else 1)


func _base(geo: Node3D, marks: Node3D, markers: Node3D, team: int, flip: Transform3D) -> void:
	var t: String = "T%d" % team
	var team_mat: String = "team%d" % team
	# Command Vehicle placeholder (static until Milestone 1 makes it drivable/vulnerable).
	var cv := Vector3(-14.0, 0.0, 72.0)
	_box(geo, "CommandVehicle_%s" % t, Vector3(3.6, 2.4, 9.0), flip * Transform3D(Basis(), cv + Vector3(0.0, 1.7, 0.0)), team_mat)
	_box(geo, "CommandVehicleCab_%s" % t, Vector3(3.2, 1.2, 3.0), flip * Transform3D(Basis(), cv + Vector3(0.0, 3.5, -2.4)), team_mat)
	_box(geo, "CommandVehicleMast_%s" % t, Vector3(0.2, 3.0, 0.2), flip * Transform3D(Basis(), cv + Vector3(1.2, 5.4, 2.5)), "concrete_dark", false)
	_label(marks, "CommandVehicleLabel_%s" % t, "COMMAND VEHICLE\npress C here to command", (flip * Transform3D(Basis(), cv + Vector3(0.0, 6.0, 0.0))).origin, 48)
	_marker(markers, "CommandPost_%s" % t, flip * Transform3D(Basis(), cv))

	# Vehicle Factory hangar, open toward the map centre (-Z for Blue).
	var f := Vector3(14.0, 0.0, 72.0)
	_box(geo, "FactoryWallL_%s" % t, Vector3(0.5, 6.0, 14.0), flip * Transform3D(Basis(), f + Vector3(-4.75, 3.0, 0.0)), "concrete")
	_box(geo, "FactoryWallR_%s" % t, Vector3(0.5, 6.0, 14.0), flip * Transform3D(Basis(), f + Vector3(4.75, 3.0, 0.0)), "concrete")
	_box(geo, "FactoryWallBack_%s" % t, Vector3(10.0, 6.0, 0.5), flip * Transform3D(Basis(), f + Vector3(0.0, 3.0, 7.25)), "concrete")
	_box(geo, "FactoryRoof_%s" % t, Vector3(10.0, 0.5, 14.5), flip * Transform3D(Basis(), f + Vector3(0.0, 6.25, 0.0)), team_mat)
	_label(marks, "FactoryLabel_%s" % t, "VEHICLE FACTORY", (flip * Transform3D(Basis(), f + Vector3(0.0, 8.0, -7.0))).origin, 64)
	# Painted exit lane: two yellow edge stripes + chevrons pointing out of the factory.
	for side: int in [-1, 1]:
		_box(marks, "ExitStripe%d_%s" % [side + 1, t], Vector3(0.4, 0.04, 20.0), flip * Transform3D(Basis(), f + Vector3(3.0 * side, 0.02, -15.0)), "lane", false)
	for i: int in range(4):
		var z: float = -9.0 - i * 4.0
		for side: int in [-1, 1]:
			var chevron := Basis(Vector3.UP, side * deg_to_rad(40.0))
			_box(marks, "Chevron%d%d_%s" % [i, side + 1, t], Vector3(0.35, 0.04, 2.0), flip * Transform3D(chevron, f + Vector3(0.65 * side, 0.025, z)), "lane", false)
	_label(marks, "ExitLaneLabel_%s" % t, "EXIT LANE — keep clear", (flip * Transform3D(Basis(), f + Vector3(0.0, 0.6, -22.0))).origin, 40)
	_marker(markers, "VehicleSpawn_%s" % t, flip * Transform3D(Basis(), f + Vector3(0.0, 0.0, -1.0)))

	# Spawn pad.
	var s := Vector3(-4.0, 0.0, 84.0)
	_box(marks, "SpawnPad_%s" % t, Vector3(7.0, 0.05, 7.0), flip * Transform3D(Basis(), s + Vector3(0.0, 0.025, 0.0)), team_mat, false)
	_marker(markers, "Spawn_%s" % t, flip * Transform3D(Basis(Vector3.UP, 0.0), s))


## A ramp descending from the mesa edge outward (local +Z after `yaw`).
func _ramp(parent: Node3D, node_name: String, yaw: float, edge_dist: float, height: float, width: float, angle_deg: float) -> void:
	var a: float = deg_to_rad(angle_deg)
	var thickness: float = 1.0
	var overlap: float = 1.0
	var slope_len: float = height / sin(a)
	var length: float = slope_len + overlap
	var s := Vector3(0.0, -sin(a), cos(a))   # down-slope direction
	var nrm := Vector3(0.0, cos(a), sin(a))  # top-face normal
	var top_edge := Vector3(0.0, height, edge_dist)
	var top_mid: Vector3 = top_edge + s * ((slope_len - overlap) * 0.5)
	var center: Vector3 = top_mid - nrm * (thickness * 0.5)
	var yaw_b := Basis(Vector3.UP, yaw)
	var xf := Transform3D(yaw_b * Basis(Vector3.RIGHT, a), yaw_b * center)
	_box(parent, node_name, Vector3(width, thickness, length), xf, "rock")


func _make_materials() -> void:
	var ground := ShaderMaterial.new()
	ground.shader = load(GRID_SHADER) as Shader
	_mats["ground"] = ground
	_mats["concrete"] = _std(Color(0.62, 0.62, 0.6), 0.9)
	_mats["concrete_dark"] = _std(Color(0.33, 0.34, 0.35), 0.9)
	_mats["rock"] = _std(Color(0.48, 0.45, 0.4), 1.0)
	_mats["crate"] = _std(Color(0.55, 0.42, 0.26), 0.85)
	_mats["lane"] = _std(Color(0.95, 0.78, 0.1), 0.7)
	_mats["resource"] = _std(Color(0.15, 0.75, 0.55), 0.5)
	_mats["team0"] = _std(Teams.color_of(0).darkened(0.25), 0.6)
	_mats["team1"] = _std(Teams.color_of(1).darkened(0.25), 0.6)


func _std(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.5, 0.68)
	sky_mat.sky_horizon_color = Color(0.68, 0.72, 0.76)
	sky_mat.ground_horizon_color = Color(0.5, 0.5, 0.48)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	map_root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(35.0), 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.light_energy = 1.1
	map_root.add_child(sun)


func _group(node_name: String) -> Node3D:
	var g := Node3D.new()
	g.name = node_name
	map_root.add_child(g)
	return g


func _box(parent: Node3D, node_name: String, size: Vector3, xf: Transform3D, mat_key: String, collide: bool = true) -> void:
	var holder: Node3D
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = BodyFactory.LAYER_WORLD
		body.collision_mask = 0
		var shape := BoxShape3D.new()
		shape.size = size
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		cs.shape = shape
		body.add_child(cs)
		holder = body
	else:
		holder = Node3D.new()
	holder.name = node_name
	holder.transform = xf
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _box_mesh(size)
	mi.material_override = _mats[mat_key]
	if not collide:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mi)
	parent.add_child(holder)


func _box_mesh(size: Vector3) -> BoxMesh:
	if not _box_meshes.has(size):
		var m := BoxMesh.new()
		m.size = size
		_box_meshes[size] = m
	return _box_meshes[size]


func _label(parent: Node3D, node_name: String, text: String, pos: Vector3, font_size: int) -> void:
	var l := Label3D.new()
	l.name = node_name
	l.text = text
	l.font_size = font_size
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.outline_size = 12
	l.position = pos
	parent.add_child(l)


func _marker(parent: Node3D, node_name: String, xf: Transform3D) -> void:
	var m := Marker3D.new()
	m.name = node_name
	m.transform = xf
	parent.add_child(m)


func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_node
		_set_owner_recursive(child, owner_node)
