extends TestCase


func _sample_body() -> PackedByteArray:
	var p := SnapshotCodec.PlayerSnap.new()
	p.id = 123456789
	p.team = Teams.RED
	p.flags = SnapshotCodec.FLAG_ALIVE | SnapshotCodec.FLAG_COMMANDER
	p.pos = Vector3(1.5, 2.25, -3.75)
	p.yaw = 1.25
	p.pitch = -0.5
	var v := SnapshotCodec.VehicleSnap.new()
	v.id = 7
	v.team = Teams.BLUE
	v.driver = 123456789
	v.pos = Vector3(10.0, 3.0, -20.0)
	v.yaw = -2.0
	v.pitch = 0.2
	v.roll = -0.1
	v.speed = 9.5
	var players: Array[SnapshotCodec.PlayerSnap] = [p]
	var vehicles: Array[SnapshotCodec.VehicleSnap] = [v]
	return SnapshotCodec.encode_body(players, vehicles)


func test_roundtrip_preserves_every_field() -> void:
	var bytes: PackedByteArray = SnapshotCodec.encode(4242, 99, _sample_body())
	check_eq(bytes.size(), SnapshotCodec.HEADER_BYTES + SnapshotCodec.PLAYER_BYTES + SnapshotCodec.VEHICLE_BYTES, "encoded size")
	var s: SnapshotCodec.Snapshot = SnapshotCodec.decode(bytes)
	check(s != null, "decodes")
	if s == null:
		return
	check_eq(s.tick, 4242, "tick")
	check_eq(s.ack_input_seq, 99, "ack")
	var p: SnapshotCodec.PlayerSnap = s.players[123456789]
	check_eq(p.team, Teams.RED, "player team")
	check(p.is_alive() and p.is_commander() and not p.in_vehicle(), "player flags")
	check(p.pos.is_equal_approx(Vector3(1.5, 2.25, -3.75)), "player pos")
	check_near(p.yaw, 1.25, 0.0001, "player yaw")
	var v: SnapshotCodec.VehicleSnap = s.vehicles[7]
	check_eq(v.driver, 123456789, "vehicle driver")
	check_near(v.speed, 9.5, 0.0001, "vehicle speed")
	check_near(v.roll, -0.1, 0.0001, "vehicle roll")


func test_rejects_malformed_packets() -> void:
	var good: PackedByteArray = SnapshotCodec.encode(1, 1, _sample_body())
	check(SnapshotCodec.decode(PackedByteArray()) == null, "empty")
	check(SnapshotCodec.decode(good.slice(0, good.size() - 1)) == null, "truncated")
	var extra: PackedByteArray = good.duplicate()
	extra.append(0)
	check(SnapshotCodec.decode(extra) == null, "trailing byte")
	var bad_magic: PackedByteArray = good.duplicate()
	bad_magic[0] = 0x00
	check(SnapshotCodec.decode(bad_magic) == null, "wrong magic")
