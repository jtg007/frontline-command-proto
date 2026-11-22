class_name RateLimiter
extends RefCounted
## Per-peer token bucket. Server applies one limiter per intent type (waypoint spam, etc.).

var capacity: float = 1.0
var refill_per_sec: float = 1.0
var _tokens: Dictionary[int, float] = {}
var _stamp: Dictionary[int, float] = {}


func _init(burst: float, per_second: float) -> void:
	capacity = burst
	refill_per_sec = per_second


func allow(peer_id: int, now_sec: float) -> bool:
	var tokens: float = _tokens.get(peer_id, capacity)
	var last: float = _stamp.get(peer_id, now_sec)
	tokens = minf(capacity, tokens + maxf(now_sec - last, 0.0) * refill_per_sec)
	_stamp[peer_id] = now_sec
	if tokens < 1.0:
		_tokens[peer_id] = tokens
		return false
	_tokens[peer_id] = tokens - 1.0
	return true


func forget(peer_id: int) -> void:
	_tokens.erase(peer_id)
	_stamp.erase(peer_id)
