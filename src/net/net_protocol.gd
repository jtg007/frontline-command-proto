class_name NetProtocol
extends RefCounted
## Shared network constants. Bump PROTOCOL_VERSION whenever an RPC signature,
## the snapshot layout or an Action id changes — mismatched clients are rejected at join.

const PROTOCOL_VERSION: int = 1
const DEFAULT_PORT: int = 27515
const MAX_CLIENTS: int = 32
## ENet user channels: 0 = reliable commands, 1 = input (unreliable sequenced),
## 2 = snapshots (unreliable sequenced).
const ENET_CHANNELS: int = 3

const TICK_RATE: int = 30
const SNAPSHOT_INTERVAL_TICKS: int = 2  # 15 snapshots/s
const INTERP_DELAY_SEC: float = 0.12   # ~2 snapshot intervals behind newest
const HELLO_TIMEOUT_SEC: float = 10.0
const CONNECT_TIMEOUT_SEC: float = 8.0

const BUTTON_JUMP: int = 1

## Discrete player intents. Each carries a client-chosen, strictly increasing request_id.
enum Action {
	USE_VEHICLE = 1,     ## enter the nearest own-team vehicle, or exit the current one
	TOGGLE_COMMAND = 2,  ## take / leave the Commander seat at the team's Command Vehicle
	PLACE_WAYPOINT = 3,  ## Commander only: arg = world position
	RESPAWN = 4,         ## give up and respawn at the team spawn
	SWITCH_TEAM = 5,     ## move to the other team
}


static func is_valid_action(action: int) -> bool:
	return action >= Action.USE_VEHICLE and action <= Action.SWITCH_TEAM


## "host:port", "host" or "udp://host:port" -> host
static func parse_host(address: String) -> String:
	var a: String = _strip_scheme(address)
	var colon: int = a.rfind(":")
	if colon > 0 and a.substr(colon + 1).is_valid_int():
		return a.substr(0, colon)
	return a


static func parse_port(address: String, fallback: int = DEFAULT_PORT) -> int:
	var a: String = _strip_scheme(address)
	var colon: int = a.rfind(":")
	if colon > 0 and a.substr(colon + 1).is_valid_int():
		var p: int = a.substr(colon + 1).to_int()
		if p > 0 and p <= 65535:
			return p
	return fallback


static func _strip_scheme(address: String) -> String:
	var a: String = address.strip_edges()
	var scheme: int = a.find("://")
	if scheme >= 0:
		a = a.substr(scheme + 3)
	return a.trim_suffix("/")
