#!/usr/bin/env python3
"""Automated release gate for Steps A-C (simulated Playtest 1).

Starts one headless dedicated server and three headless bot clients as separate
processes talking real ENet over localhost:

  BotCommander (Blue)  takes command, places waypoint, watches the ride, saves F8 bundle
  BotDriver    (Blue)  reconnects, receives the order, drives the tank to it
  BotSpy       (Red)   must never receive Blue's private waypoint

Usage: tests/integration/run_playtest1_sim.py [--godot godot] [--project .] [--port 27611]
Exit code 0 = every check passed. Results land in tests/output/.
"""
import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path


# Engine messages known to be harmless. Keep this list tiny and justified.
KNOWN_BENIGN = [
    # Godot 4.7.2 *release* templates only (editor binary is silent): SceneMultiplayer's
    # path cache logs this when a client swaps its peer on disconnect/reconnect. Gameplay,
    # reconnect and RPCs are verified unaffected by the checks above. See STATUS.md.
    "Signal: 'tree_exited', callable: ''",
    "Signal 'tree_exited' is already connected to given callable ''",
]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    ap.add_argument("--project", default=str(Path(__file__).resolve().parents[2]))
    ap.add_argument("--port", type=int, default=27611)
    ap.add_argument("--timeout", type=float, default=150.0)
    ap.add_argument("--exported", action="store_true",
                    help="--godot is an exported game binary (release smoke test): don't pass --path")
    args = ap.parse_args()

    project = Path(args.project).resolve()
    out = project / "tests" / "output"
    out.mkdir(parents=True, exist_ok=True)
    for f in out.glob("*.json"):
        f.unlink()
    base = [args.godot, "--headless"] + ([] if args.exported else ["--path", str(project)])
    addr = f"127.0.0.1:{args.port}"
    logs = {}

    def spawn(name, user_args):
        log = open(out / f"{name}.log", "w")
        logs[name] = log
        return subprocess.Popen(base + ["--"] + user_args, stdout=log, stderr=subprocess.STDOUT)

    server = spawn("server", ["--server", f"--port={args.port}", "--exit-when-empty",
                              f"--test-timeout={args.timeout}", f"--test-out={out / 'server.json'}"])
    deadline = time.time() + 20
    while time.time() < deadline:
        if "SERVER_READY" in (out / "server.log").read_text(errors="replace"):
            break
        if server.poll() is not None:
            print("server exited before becoming ready")
            print((out / "server.log").read_text(errors="replace"))
            return 1
        time.sleep(0.2)
    else:
        print("server did not become ready")
        server.kill()
        return 1

    bots = {
        "commander": ["--name=BotCommander", "--team=blue"],
        "driver": ["--name=BotDriver", "--team=blue"],
        "spy": ["--name=BotSpy", "--team=red"],
    }
    procs = {}
    for role, extra in bots.items():
        procs[role] = spawn(role, [f"--connect={addr}", f"--bot={role}", f"--test-timeout={args.timeout - 10}",
                                   f"--test-out={out / (role + '.json')}"] + extra)
        time.sleep(0.4)

    end = time.time() + args.timeout
    for p in list(procs.values()) + [server]:
        try:
            p.wait(timeout=max(1.0, end - time.time()))
        except subprocess.TimeoutExpired:
            p.kill()
    for log in logs.values():
        log.close()

    ok = True
    print("=" * 64)
    for role in list(bots) + ["server"]:
        path = out / f"{role}.json"
        if not path.exists():
            print(f"[{role}] NO RESULT FILE (see tests/output/{role}.log)")
            ok = False
            continue
        res = json.loads(path.read_text())
        passed = bool(res.get("passed"))
        ok &= passed
        print(f"[{role}] {'PASSED' if passed else 'FAILED'}" + (f" in {res.get('duration_sec')} s" if "duration_sec" in res else ""))
        for name, val in sorted(res.get("checks", {}).items()):
            print(f"    {'ok ' if val else 'XX '} {name}")
        for note in res.get("notes", []):
            print(f"    note: {note}")

    # Cross-check from the server side: the Red client never got a Blue waypoint message.
    server_res = out / "server.json"
    if server_res.exists():
        sends = json.loads(server_res.read_text()).get("waypoint_sends_by_peer", {})
        spy_log = (out / "spy.log").read_text(errors="replace") if (out / "spy.log").exists() else ""
        print(f"[server] waypoint messages per peer [blue, red]: {sends}")
        leaked = [peer for peer, counts in sends.items() if counts[0] > 0 and counts[1] > 0]
        if leaked:
            print(f"[server] XX a peer received waypoints of both teams: {leaked}")
            ok = False
        if "FAIL" in spy_log:
            ok = False

    for name in ["server"] + list(bots):
        text = (out / f"{name}.log").read_text(errors="replace")
        errors = [l for l in text.splitlines() if ("SCRIPT ERROR" in l or l.startswith("ERROR:"))
                  and not any(k in l for k in KNOWN_BENIGN)]
        if errors:
            ok = False
            print(f"[{name}] engine errors:")
            for l in errors[:10]:
                print("    " + l)
    print("=" * 64)
    print("PLAYTEST 1 SIMULATION: " + ("PASSED" if ok else "FAILED"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
