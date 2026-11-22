class_name SnapshotBuffer
extends RefCounted
## Client-side snapshot history + clock for smooth interpolation (Stage-1 netcode).
## Remote AND local entities are rendered INTERP_DELAY_SEC behind the newest snapshot.

const MAX_SNAPSHOTS: int = 32
const CLOCK_SNAP_THRESHOLD_SEC: float = 0.5
const CLOCK_CORRECTION: float = 0.1

var interp_delay: float = NetProtocol.INTERP_DELAY_SEC
var _snaps: Array[SnapshotCodec.Snapshot] = []
var _clock: float = -1.0


class Frame:
	var a: SnapshotCodec.Snapshot
	var b: SnapshotCodec.Snapshot
	var alpha: float = 0.0


func clear() -> void:
	_snaps.clear()
	_clock = -1.0


func is_empty() -> bool:
	return _snaps.is_empty()


func latest() -> SnapshotCodec.Snapshot:
	return null if _snaps.is_empty() else _snaps[_snaps.size() - 1]


## Returns false if the snapshot is older than (or equal to) the newest one.
func push(snap: SnapshotCodec.Snapshot) -> bool:
	var newest: SnapshotCodec.Snapshot = latest()
	if newest != null and snap.tick <= newest.tick:
		return false
	_snaps.append(snap)
	while _snaps.size() > MAX_SNAPSHOTS:
		_snaps.remove_at(0)
	var t: float = snap.time_sec()
	var err: float = t - _clock
	if _clock < 0.0 or absf(err) > CLOCK_SNAP_THRESHOLD_SEC:
		_clock = t
	else:
		_clock += err * CLOCK_CORRECTION
	return true


func advance(delta: float) -> void:
	if _clock >= 0.0:
		_clock += delta


func render_time() -> float:
	return _clock - interp_delay


func frame_at(t: float) -> Frame:
	if _snaps.is_empty():
		return null
	var f := Frame.new()
	var first: SnapshotCodec.Snapshot = _snaps[0]
	if t <= first.time_sec():
		f.a = first
		f.b = first
		return f
	for i: int in range(_snaps.size() - 1, -1, -1):
		var s: SnapshotCodec.Snapshot = _snaps[i]
		if s.time_sec() <= t:
			f.a = s
			if i == _snaps.size() - 1:
				f.b = s  # Hold the newest state; no extrapolation in Stage 1.
			else:
				f.b = _snaps[i + 1]
				var ta: float = f.a.time_sec()
				f.alpha = clampf((t - ta) / maxf(f.b.time_sec() - ta, 0.0001), 0.0, 1.0)
			return f
	return null


static func lerp_player(a: SnapshotCodec.PlayerSnap, b: SnapshotCodec.PlayerSnap, alpha: float) -> SnapshotCodec.PlayerSnap:
	if a == null:
		return b
	var out := SnapshotCodec.PlayerSnap.new()
	out.id = b.id
	out.team = b.team
	out.flags = b.flags
	out.pos = a.pos.lerp(b.pos, alpha)
	out.yaw = lerp_angle(a.yaw, b.yaw, alpha)
	out.pitch = lerpf(a.pitch, b.pitch, alpha)
	return out


static func lerp_vehicle(a: SnapshotCodec.VehicleSnap, b: SnapshotCodec.VehicleSnap, alpha: float) -> SnapshotCodec.VehicleSnap:
	if a == null:
		return b
	var out := SnapshotCodec.VehicleSnap.new()
	out.id = b.id
	out.team = b.team
	out.driver = b.driver
	out.pos = a.pos.lerp(b.pos, alpha)
	out.yaw = lerp_angle(a.yaw, b.yaw, alpha)
	out.pitch = lerp_angle(a.pitch, b.pitch, alpha)
	out.roll = lerp_angle(a.roll, b.roll, alpha)
	out.speed = lerpf(a.speed, b.speed, alpha)
	return out
