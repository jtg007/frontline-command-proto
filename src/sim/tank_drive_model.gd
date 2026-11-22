class_name TankDriveModel
extends RefCounted
## Pure, deterministic tank drive model (skid steering). Stage 1: kinematic, server-only.
## throttle/steer in [-1, 1]; steer > 0 turns right (yaw decreases).

const MAX_FORWARD_SPEED: float = 11.0   # m/s (~40 km/h)
const MAX_REVERSE_SPEED: float = 4.5
const ACCELERATION: float = 5.0         # m/s²
const BRAKE_DECELERATION: float = 12.0  # pressing against the direction of travel
const COAST_DECELERATION: float = 3.5   # no throttle
const TURN_RATE_STANDING: float = 1.2   # rad/s
const TURN_RATE_AT_SPEED: float = 0.75


static func step_speed(speed: float, throttle: float, delta: float) -> float:
	var t: float = clampf(throttle, -1.0, 1.0)
	if is_zero_approx(t):
		return move_toward(speed, 0.0, COAST_DECELERATION * delta)
	if speed * t < 0.0:
		return move_toward(speed, 0.0, BRAKE_DECELERATION * delta * absf(t))
	# Throttle sets a target speed proportional to the pedal; partial throttle cruises slower.
	var target: float = MAX_FORWARD_SPEED * t if t > 0.0 else MAX_REVERSE_SPEED * t
	if absf(speed) > absf(target):
		return move_toward(speed, target, COAST_DECELERATION * delta)
	return move_toward(speed, target, ACCELERATION * absf(t) * delta)


static func yaw_rate(steer: float, speed: float) -> float:
	var s: float = clampf(steer, -1.0, 1.0)
	var t: float = clampf(absf(speed) / MAX_FORWARD_SPEED, 0.0, 1.0)
	return -s * lerpf(TURN_RATE_STANDING, TURN_RATE_AT_SPEED, t)
