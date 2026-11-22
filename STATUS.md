# Project Status

Shared memory for humans and coding agents. **Read this first, update it last.**
Any new session (human or agent) must be able to resume from this file plus the repo alone.

| Field | Value |
|---|---|
| Active step | **A–C** (Join & Diagnostics → Issue Order → Drive to Order) |
| Next human gate | **Playtest 1** (2 players online: Commander places waypoint, driver drives the tank there) |
| Latest commit | see `git log -1` |
| Last human-verified build | none yet |
| Engine | Godot 4.7.x stable, strictly typed GDScript, Jolt Physics, ENet |
| Working title | *frontline-command-proto* (final game name to be chosen by the community) |

## Open playtest bugs

_None reported yet._

## Decisions log

| Date | Decision | Why |
|---|---|---|
| 2026-11-22 | Neutral repo name `frontline-command-proto`, no "Empires" branding in code/assets | Trademark safety; clean-room original IP |
| 2026-11-22 | Apache-2.0 for code, CC BY 4.0 for original final assets | See `docs/PROJECT_VISION.md` §3 |

## Rules for agents

1. One active step, one owner agent. Do not touch core state owned by another active step.
2. Fix failed playtest issues **before** adding new features.
3. Never put Valve / Empires code, assets, or proprietary material into prompts, code, or PRs.
4. Update this file at the end of every work session (active step, open bugs, next step).
