class_name BodyFactory
extends RefCounted
## Server-side physics bodies. Bodies carry NO scripts: centralized managers in
## ServerGame step them (anti per-entity tick sprawl).

const LAYER_WORLD: int = 1
const LAYER_PLAYERS: int = 2
const LAYER_VEHICLES: int = 4

const PLAYER_RADIUS: float = 0.4
const PLAYER_HEIGHT: float = 1.8

const TANK_SKID_RADIUS: float = 0.55
const TANK_HULL_SIZE: Vector3 = Vector3(3.2, 1.3, 4.6)
const TANK_HULL_CLEARANCE: float = 0.6


static func make_player_body() -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.collision_layer = LAYER_PLAYERS
	body.collision_mask = LAYER_WORLD | LAYER_PLAYERS | LAYER_VEHICLES
	body.floor_snap_length = 0.3
	body.floor_max_angle = deg_to_rad(46.0)
	var shape := CapsuleShape3D.new()
	shape.radius = PLAYER_RADIUS
	shape.height = PLAYER_HEIGHT
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0.0, PLAYER_HEIGHT * 0.5, 0.0)
	body.add_child(cs)
	return body


static func set_player_collision(body: CharacterBody3D, enabled: bool) -> void:
	body.collision_layer = LAYER_PLAYERS if enabled else 0
	body.collision_mask = (LAYER_WORLD | LAYER_PLAYERS | LAYER_VEHICLES) if enabled else 0


## Tank: a skid sphere under the centre rides the ground (origin = ground under centre);
## the hull box is raised so 12° ramps don't snag it. Tilt comes from TankSuspension rays.
static func make_tank_body() -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.collision_layer = LAYER_VEHICLES
	body.collision_mask = LAYER_WORLD | LAYER_VEHICLES | LAYER_PLAYERS
	body.floor_snap_length = 0.8
	body.floor_max_angle = deg_to_rad(35.0)
	body.floor_constant_speed = true
	body.wall_min_slide_angle = deg_to_rad(10.0)
	var skid := SphereShape3D.new()
	skid.radius = TANK_SKID_RADIUS
	var skid_cs := CollisionShape3D.new()
	skid_cs.shape = skid
	skid_cs.position = Vector3(0.0, TANK_SKID_RADIUS, 0.0)
	body.add_child(skid_cs)
	var hull := BoxShape3D.new()
	hull.size = TANK_HULL_SIZE
	var hull_cs := CollisionShape3D.new()
	hull_cs.shape = hull
	hull_cs.position = Vector3(0.0, TANK_HULL_CLEARANCE + TANK_HULL_SIZE.y * 0.5, 0.0)
	body.add_child(hull_cs)
	return body
