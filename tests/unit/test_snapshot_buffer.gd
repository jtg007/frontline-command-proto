extends TestCase


func _snap(tick: int, x: float) -> SnapshotCodec.Snapshot:
	var s := SnapshotCodec.Snapshot.new()
	s.tick = tick
	var p := SnapshotCodec.PlayerSnap.new()
	p.id = 5
	p.pos = Vector3(x, 0.0, 0.0)
	p.yaw = 0.0
	s.players[5] = p
	return s


func test_interpolates_between_snapshots() -> void:
	var b := SnapshotBuffer.new()
	b.push(_snap(30, 0.0))   # t = 1.0 s
	b.push(_snap(32, 10.0))  # t = 1.0667 s
	var t: float = 1.0 + (2.0 / 30.0) * 0.25
	var f: SnapshotBuffer.Frame = b.frame_at(t)
	check(f != null, "frame exists")
	check_near(f.alpha, 0.25, 0.001, "alpha")
	var p: SnapshotCodec.PlayerSnap = SnapshotBuffer.lerp_player(f.a.players[5], f.b.players[5], f.alpha)
	check_near(p.pos.x, 2.5, 0.01, "interpolated x")


func test_holds_newest_without_extrapolating() -> void:
	var b := SnapshotBuffer.new()
	b.push(_snap(30, 0.0))
	b.push(_snap(32, 10.0))
	var f: SnapshotBuffer.Frame = b.frame_at(5.0)
	check(f.a == f.b and f.b.tick == 32, "holds newest")


func test_ignores_old_and_duplicate_snapshots() -> void:
	var b := SnapshotBuffer.new()
	check(b.push(_snap(10, 0.0)), "first accepted")
	check(not b.push(_snap(10, 1.0)), "duplicate rejected")
	check(not b.push(_snap(8, 1.0)), "older rejected")
	check_eq(b.latest().tick, 10, "latest tick")


func test_render_time_trails_newest_by_interp_delay() -> void:
	var b := SnapshotBuffer.new()
	b.push(_snap(300, 0.0))
	check_near(b.render_time(), 10.0 - NetProtocol.INTERP_DELAY_SEC, 0.001, "render time")
