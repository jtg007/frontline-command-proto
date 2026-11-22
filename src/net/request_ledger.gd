class_name RequestLedger
extends RefCounted
## Server-side idempotency for numbered player intents.
## A duplicated or retried packet (same request_id) is never executed twice: the server
## re-sends the cached result instead. Older ids are ignored. Foundation for purchases (Step F).

enum Verdict { NEW, DUPLICATE, STALE }

var _last_id: Dictionary[int, int] = {}
var _last_ok: Dictionary[int, bool] = {}
var _last_message: Dictionary[int, String] = {}


func classify(peer_id: int, request_id: int) -> Verdict:
	if not _last_id.has(peer_id):
		return Verdict.NEW
	var last: int = _last_id[peer_id]
	if request_id > last:
		return Verdict.NEW
	if request_id == last:
		return Verdict.DUPLICATE
	return Verdict.STALE


func remember(peer_id: int, request_id: int, ok: bool, message: String) -> void:
	_last_id[peer_id] = request_id
	_last_ok[peer_id] = ok
	_last_message[peer_id] = message


func cached_ok(peer_id: int) -> bool:
	return _last_ok.get(peer_id, false)


func cached_message(peer_id: int) -> String:
	return _last_message.get(peer_id, "")


func forget(peer_id: int) -> void:
	_last_id.erase(peer_id)
	_last_ok.erase(peer_id)
	_last_message.erase(peer_id)
