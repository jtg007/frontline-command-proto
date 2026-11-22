class_name FrameStats
extends RefCounted
## Rolling frame-time statistics (last ~20 s at 60 FPS) for the HUD and F8 bug reports.

const CAPACITY: int = 1200

var _samples_ms: PackedFloat32Array = PackedFloat32Array()
var _next: int = 0
var _count: int = 0


func _init() -> void:
	_samples_ms.resize(CAPACITY)


func add_frame(delta_sec: float) -> void:
	_samples_ms[_next] = delta_sec * 1000.0
	_next = (_next + 1) % CAPACITY
	_count = mini(_count + 1, CAPACITY)


func count() -> int:
	return _count


func percentile_ms(p: float) -> float:
	if _count == 0:
		return 0.0
	var sorted: PackedFloat32Array = _samples_ms.slice(0, _count) if _count < CAPACITY else _samples_ms.duplicate()
	sorted.sort()
	var idx: int = clampi(ceili(p * _count) - 1, 0, _count - 1)
	return sorted[idx]


func summary() -> Dictionary:
	if _count == 0:
		return {"frames": 0}
	var total: float = 0.0
	var worst: float = 0.0
	for i: int in range(_count):
		total += _samples_ms[i]
		worst = maxf(worst, _samples_ms[i])
	var avg_ms: float = total / _count
	return {
		"frames": _count,
		"avg_fps": snappedf(1000.0 / maxf(avg_ms, 0.001), 0.1),
		"p50_ms": snappedf(percentile_ms(0.50), 0.01),
		"p95_ms": snappedf(percentile_ms(0.95), 0.01),
		"p99_ms": snappedf(percentile_ms(0.99), 0.01),
		"worst_ms": snappedf(worst, 0.01),
	}
