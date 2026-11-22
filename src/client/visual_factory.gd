class_name VisualFactory
extends RefCounted
## Builds greybox placeholder visuals in code (no art assets yet). Meshes and materials
## are cached and shared between instances so draw calls stay batched.

static var _materials: Dictionary[String, Material] = {}
static var _meshes: Dictionary[String, Mesh] = {}

const ORDER_COLOR: Color = Color(1.0, 0.82, 0.12)


static func make_player(team: int) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = _capsule()
	body.material_override = _team_material(team)
	body.position = Vector3(0.0, 0.9, 0.0)
	root.add_child(body)
	var visor := MeshInstance3D.new()
	visor.mesh = _box("visor", Vector3(0.5, 0.16, 0.2))
	visor.material_override = _flat("visor", Color(0.08, 0.09, 0.1), 0.3)
	visor.position = Vector3(0.0, 1.55, -0.33)
	root.add_child(visor)
	return root


static func make_tank(team: int) -> Node3D:
	var root := Node3D.new()
	var dark: Material = _flat("track", Color(0.12, 0.12, 0.12), 0.9)
	var team_mat: Material = _team_material(team)
	for side: int in [-1, 1]:
		_add(root, _box("track", Vector3(0.8, 1.0, 6.2)), dark, Vector3(1.45 * side, 0.5, 0.0))
	_add(root, _box("hull", Vector3(2.6, 0.9, 5.6)), team_mat, Vector3(0.0, 1.25, 0.0))
	_add(root, _box("glacis", Vector3(2.6, 0.5, 1.0)), team_mat, Vector3(0.0, 1.0, -3.0))
	_add(root, _box("turret", Vector3(2.2, 0.75, 2.6)), team_mat, Vector3(0.0, 2.07, 0.4))
	var barrel := MeshInstance3D.new()
	barrel.mesh = _cylinder("barrel", 0.12, 3.6)
	barrel.material_override = dark
	barrel.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	barrel.position = Vector3(0.0, 2.1, -2.7)
	root.add_child(barrel)
	return root


static func make_waypoint() -> Node3D:
	var root := Node3D.new()
	var beam := MeshInstance3D.new()
	beam.mesh = _cylinder("beam", 0.35, 80.0)
	beam.material_override = _order_material("beam", 0.32, true)
	beam.position = Vector3(0.0, 40.0, 0.0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beam)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = OrderRules.WAYPOINT_REACHED_RADIUS - 0.35
	torus.outer_radius = OrderRules.WAYPOINT_REACHED_RADIUS
	ring.mesh = torus
	ring.material_override = _order_material("ring", 0.85, false)
	ring.position = Vector3(0.0, 0.15, 0.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	return root


static func make_tag(font_size: int, through_walls: bool) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0012
	l.font_size = font_size
	l.outline_size = 10
	l.no_depth_test = through_walls
	return l


static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


static func _team_material(team: int) -> Material:
	return _flat("team%d" % team, Teams.color_of(team), 0.55)


static func _flat(key: String, color: Color, roughness: float) -> Material:
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		_materials[key] = m
	return _materials[key]


static func _order_material(key: String, alpha: float, through_walls: bool) -> Material:
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = through_walls
		m.albedo_color = Color(ORDER_COLOR, alpha)
		_materials[key] = m
	return _materials[key]


static func _box(key: String, size: Vector3) -> Mesh:
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]


static func _cylinder(key: String, radius: float, height: float) -> Mesh:
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = radius
		m.bottom_radius = radius
		m.height = height
		m.radial_segments = 12
		_meshes[key] = m
	return _meshes[key]


static func _capsule() -> Mesh:
	if not _meshes.has("capsule"):
		var m := CapsuleMesh.new()
		m.radius = BodyFactory.PLAYER_RADIUS
		m.height = BodyFactory.PLAYER_HEIGHT
		_meshes["capsule"] = m
	return _meshes["capsule"]
