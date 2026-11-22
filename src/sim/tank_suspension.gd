class_name TankSuspension
extends RefCounted
## Raycast suspension: four corner rays sample the ground; the hull is tilted to match.
## Pure math so it can be unit-tested without physics.

const HALF_WIDTH: float = 1.5
const HALF_LENGTH: float = 2.6
const RAY_UP: float = 2.0
const RAY_DOWN: float = 3.0
const SMOOTHING: float = 0.35  # per tick, 0..1


## Local corner offsets: front-left, front-right, rear-left, rear-right (front = -Z).
static func corner_offsets() -> Array[Vector3]:
	return [
		Vector3(-HALF_WIDTH, 0.0, -HALF_LENGTH),
		Vector3(HALF_WIDTH, 0.0, -HALF_LENGTH),
		Vector3(-HALF_WIDTH, 0.0, HALF_LENGTH),
		Vector3(HALF_WIDTH, 0.0, HALF_LENGTH),
	]


## Returns Vector2(pitch, roll). pitch > 0 = nose up; roll > 0 = right side up
## (rotation about local +Z).
static func tilt_from_heights(front_left: float, front_right: float, rear_left: float, rear_right: float) -> Vector2:
	var front: float = (front_left + front_right) * 0.5
	var rear: float = (rear_left + rear_right) * 0.5
	var left: float = (front_left + rear_left) * 0.5
	var right: float = (front_right + rear_right) * 0.5
	var pitch: float = atan2(front - rear, HALF_LENGTH * 2.0)
	var roll: float = atan2(right - left, HALF_WIDTH * 2.0)
	return Vector2(pitch, roll)


## Hull orientation used by both the server (ground clearance) and the client visual.
static func hull_basis(yaw: float, pitch: float, roll: float) -> Basis:
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)
