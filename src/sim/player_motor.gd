class_name PlayerMotor
extends RefCounted
## Pure infantry movement math (metres, seconds). The server applies it to the body.
## Yaw 0 faces -Z (Godot forward); positive yaw turns left.

const WALK_SPEED: float = 6.0
const GROUND_ACCEL: float = 60.0
const AIR_ACCEL: float = 8.0
const GRAVITY: float = 18.0
const JUMP_SPEED: float = 6.5
const EYE_HEIGHT: float = 1.6


static func forward(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


static func right(yaw: float) -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


## move.x = strafe right, move.y = forward. Returns the new velocity.
static func compute_velocity(current: Vector3, move: Vector2, yaw: float, on_floor: bool, jump: bool, delta: float) -> Vector3:
	var m: Vector2 = move.limit_length(1.0)
	var wish: Vector3 = (right(yaw) * m.x + forward(yaw) * m.y) * WALK_SPEED
	var horizontal := Vector3(current.x, 0.0, current.z)
	var accel: float = GROUND_ACCEL if on_floor else AIR_ACCEL
	horizontal = horizontal.move_toward(wish, accel * delta)
	var vy: float = current.y
	if on_floor:
		vy = JUMP_SPEED if jump else 0.0
	else:
		vy -= GRAVITY * delta
	return Vector3(horizontal.x, vy, horizontal.z)


## Tank-style heading so a body faces `direction` (xz-plane).
static func yaw_towards(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)
