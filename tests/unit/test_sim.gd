extends TestCase

const DT: float = 1.0 / 30.0


func test_infantry_forward_strafe_and_jump() -> void:
	var v: Vector3 = Vector3.ZERO
	for i: int in range(30):
		v = PlayerMotor.compute_velocity(v, Vector2(0, 1), 0.0, true, false, DT)
	check_near(v.z, -PlayerMotor.WALK_SPEED, 0.01, "yaw 0 walks toward -Z at walk speed")
	check_near(v.x, 0.0, 0.001, "no sideways drift")
	var s: Vector3 = PlayerMotor.compute_velocity(Vector3.ZERO, Vector2(1, 0), 0.0, true, false, 1.0)
	check(s.x > 0.0, "strafe right is +X at yaw 0")
	var diag: Vector3 = PlayerMotor.compute_velocity(Vector3.ZERO, Vector2(1, 1), 0.0, true, false, 1.0)
	check(Vector2(diag.x, diag.z).length() <= PlayerMotor.WALK_SPEED + 0.001, "diagonal not faster")
	check_near(PlayerMotor.compute_velocity(Vector3.ZERO, Vector2.ZERO, 0.0, true, true, DT).y, PlayerMotor.JUMP_SPEED, 0.001, "jump on floor")
	check(PlayerMotor.compute_velocity(Vector3.ZERO, Vector2.ZERO, 0.0, false, true, DT).y < 0.0, "no air jump")


func test_tank_speed_limits_and_coasting() -> void:
	var speed: float = 0.0
	for i: int in range(30 * 10):
		speed = TankDriveModel.step_speed(speed, 1.0, DT)
	check_near(speed, TankDriveModel.MAX_FORWARD_SPEED, 0.001, "top speed reached, never exceeded")
	for i: int in range(30 * 10):
		speed = TankDriveModel.step_speed(speed, 0.0, DT)
	check_eq(speed, 0.0, "coasts to a stop")
	for i: int in range(30 * 10):
		speed = TankDriveModel.step_speed(speed, -1.0, DT)
	check_near(speed, -TankDriveModel.MAX_REVERSE_SPEED, 0.001, "reverse limit")
	var braking: float = TankDriveModel.step_speed(10.0, -1.0, DT)
	check(braking < 10.0 and braking > 0.0, "opposite throttle brakes first")


func test_tank_steering_direction() -> void:
	check(TankDriveModel.yaw_rate(1.0, 0.0) < 0.0, "steer right decreases yaw (turns clockwise from above)")
	check(absf(TankDriveModel.yaw_rate(1.0, 0.0)) > absf(TankDriveModel.yaw_rate(1.0, TankDriveModel.MAX_FORWARD_SPEED)), "turns tighter when slow")
	check_eq(TankDriveModel.yaw_rate(0.0, 5.0), 0.0, "no steer no turn")


func test_suspension_tilt() -> void:
	var flat: Vector2 = TankSuspension.tilt_from_heights(0, 0, 0, 0)
	check(flat.is_zero_approx(), "flat ground")
	var nose_up: Vector2 = TankSuspension.tilt_from_heights(1, 1, 0, 0)
	check(nose_up.x > 0.0 and is_zero_approx(nose_up.y), "front higher -> positive pitch")
	var right_up: Vector2 = TankSuspension.tilt_from_heights(0, 1, 0, 1)
	check(right_up.y > 0.0 and is_zero_approx(right_up.x), "right higher -> positive roll")
	# Hull basis agrees: with positive pitch the nose (-Z) points upward.
	var nose: Vector3 = TankSuspension.hull_basis(0.0, nose_up.x, 0.0) * Vector3.FORWARD
	check(nose.y > 0.0, "visual nose up")
	var right: Vector3 = TankSuspension.hull_basis(0.0, 0.0, right_up.y) * Vector3.RIGHT
	check(right.y > 0.0, "visual right side up")
