class_name SnapshotCodec
extends RefCounted
## Compact binary snapshot format (server -> client, 15 Hz, unreliable sequenced).
##
## Header: magic u8 · tick u32 · ack_input_seq u32 · player_count u8 · vehicle_count u8
## Player:  id s32 · team u8 · flags u8 · pos 3×f32 · yaw f32 · pitch f32         (26 bytes)
## Vehicle: id u16 · team u8 · driver s32 · pos 3×f32 · yaw/pitch/roll f32 · speed f32 (35 bytes)

const MAGIC: int = 0xF1
const HEADER_BYTES: int = 11
const PLAYER_BYTES: int = 26
const VEHICLE_BYTES: int = 35

const FLAG_ALIVE: int = 1
const FLAG_IN_VEHICLE: int = 2
const FLAG_COMMANDER: int = 4


class PlayerSnap:
	var id: int = 0
	var team: int = 0
	var flags: int = 0
	var pos: Vector3 = Vector3.ZERO
	var yaw: float = 0.0
	var pitch: float = 0.0

	func is_alive() -> bool:
		return (flags & FLAG_ALIVE) != 0

	func in_vehicle() -> bool:
		return (flags & FLAG_IN_VEHICLE) != 0

	func is_commander() -> bool:
		return (flags & FLAG_COMMANDER) != 0


class VehicleSnap:
	var id: int = 0
	var team: int = 0
	var driver: int = 0
	var pos: Vector3 = Vector3.ZERO
	var yaw: float = 0.0
	var pitch: float = 0.0
	var roll: float = 0.0
	var speed: float = 0.0


class Snapshot:
	var tick: int = 0
	var ack_input_seq: int = 0
	var players: Dictionary[int, PlayerSnap] = {}
	var vehicles: Dictionary[int, VehicleSnap] = {}

	func time_sec() -> float:
		return float(tick) / NetProtocol.TICK_RATE


## Encodes the part shared by all recipients once per tick.
static func encode_body(players: Array[PlayerSnap], vehicles: Array[VehicleSnap]) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_u8(mini(players.size(), 255))
	buf.put_u8(mini(vehicles.size(), 255))
	for i: int in range(mini(players.size(), 255)):
		var p: PlayerSnap = players[i]
		buf.put_32(p.id)
		buf.put_u8(p.team)
		buf.put_u8(p.flags)
		_put_vec3(buf, p.pos)
		buf.put_float(p.yaw)
		buf.put_float(p.pitch)
	for i: int in range(mini(vehicles.size(), 255)):
		var v: VehicleSnap = vehicles[i]
		buf.put_u16(v.id)
		buf.put_u8(v.team)
		buf.put_32(v.driver)
		_put_vec3(buf, v.pos)
		buf.put_float(v.yaw)
		buf.put_float(v.pitch)
		buf.put_float(v.roll)
		buf.put_float(v.speed)
	return buf.data_array


## Prepends the per-recipient header to a shared body.
static func encode(tick: int, ack_input_seq: int, body: PackedByteArray) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_u8(MAGIC)
	buf.put_u32(tick)
	buf.put_u32(maxi(ack_input_seq, 0))
	var out: PackedByteArray = buf.data_array
	out.append_array(body)
	return out


## Returns null for anything malformed (wrong magic, truncated, trailing garbage).
static func decode(bytes: PackedByteArray) -> Snapshot:
	if bytes.size() < HEADER_BYTES:
		return null
	var buf := StreamPeerBuffer.new()
	buf.data_array = bytes
	if buf.get_u8() != MAGIC:
		return null
	var snap := Snapshot.new()
	snap.tick = buf.get_u32()
	snap.ack_input_seq = buf.get_u32()
	var np: int = buf.get_u8()
	var nv: int = buf.get_u8()
	if bytes.size() != HEADER_BYTES + np * PLAYER_BYTES + nv * VEHICLE_BYTES:
		return null
	for i: int in range(np):
		var p := PlayerSnap.new()
		p.id = buf.get_32()
		p.team = buf.get_u8()
		p.flags = buf.get_u8()
		p.pos = _get_vec3(buf)
		p.yaw = buf.get_float()
		p.pitch = buf.get_float()
		snap.players[p.id] = p
	for i: int in range(nv):
		var v := VehicleSnap.new()
		v.id = buf.get_u16()
		v.team = buf.get_u8()
		v.driver = buf.get_32()
		v.pos = _get_vec3(buf)
		v.yaw = buf.get_float()
		v.pitch = buf.get_float()
		v.roll = buf.get_float()
		v.speed = buf.get_float()
		snap.vehicles[v.id] = v
	return snap


static func _put_vec3(buf: StreamPeerBuffer, v: Vector3) -> void:
	buf.put_float(v.x)
	buf.put_float(v.y)
	buf.put_float(v.z)


static func _get_vec3(buf: StreamPeerBuffer) -> Vector3:
	var x: float = buf.get_float()
	var y: float = buf.get_float()
	var z: float = buf.get_float()
	return Vector3(x, y, z)
