# Hosting a Test Server

The dedicated server is a headless Linux program. It needs **one UDP port** (default 27515)
that players can reach. About 1 CPU core and 200 MB RAM is enough for playtests.

## Option A — Linux VPS (recommended, ~5 €/month)

```bash
unzip frontline-command-<build>-server-linux.zip
cd frontline-command-<build>-server-linux
./start_server.sh                 # listens on UDP 27515
# PORT=28000 ./start_server.sh    # other port
```

Open the port in the firewall (e.g. `sudo ufw allow 27515/udp`). Players join with `<server-ip>:27515`.
To keep it running after you log out, use `tmux`, `screen` or a systemd service.

## Option B — Home PC + UDP tunnel (no port forwarding)

Run the server on any Linux PC and use a UDP tunnel service (for example playit.gg, which has a free tier):
create a **UDP** tunnel to local port 27515 and give players the public address it prints.

## Pre-filling the address for players

Build the client packages with the address baked into the join screen:

```bash
tools/package.sh --server-address=203.0.113.5:27515
```

## Logs and bug reports

The server prints every state event to stdout. When a player presses F8, the server saves its own
copy of the event log to `~/.local/share/godot/app_userdata/Frontline Command Proto/bug_reports/`.
Clients with a different protocol version are rejected with a clear message.
