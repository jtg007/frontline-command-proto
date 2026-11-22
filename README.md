# Let's Build a Free, Open-Source Spiritual Successor to Empires — Together (Modern Look, High-FPS Feel)

**Community Discussion Draft · Working Title: "Empires 2" (we'll pick a real name together)**

There is still nothing quite like *Empires*. A real RTS Commander managing economy and research from above, Engineers racing to build a Vehicle Factory under fire, custom-built tanks with directional armor and heat management rolling out to break a stalemate — it's one of the best multiplayer loops ever made.

We want to build a **100% free, open-source, clean-room spiritual successor** that preserves that tactical magic, fixes the biggest frustrations that keep lobbies empty today, and unlocks richer, more detailed battlefields without losing the snappy, high-FPS feel — even on older PCs.

Above all, this is meant to be a **clean slate** for everyone who still loves this genre. No baggage, no endless theorycrafting — just an open project where anyone in the community can pull in the same direction and settle ideas by actually playing them.

Before we write a single line of code, I want to pitch how this project would work, be upfront about how AI fits in, and show **exactly how you can get involved** — even if you've never written code in your life.

---

## Straight Talk: 3 Honest Answers Up Front

1. **"Why start from scratch when full FPS/RTS remakes take years of volunteer time?"**
   Fair question — building an FPS/RTS hybrid is a massive undertaking, and everyone here has a job, classes, or a life outside gaming. That's why we aren't disappearing for a year to build 40 weapons and massive art packs in private. Instead, we're shipping **tiny, playable online slices from week one**. Milestone 1 is just one small greybox map, one Commander, one Vehicle Factory, and one tank rolling out to end a match. You don't have to trust promises or concept art — you'll be able to download a build, jump onto a test server, and judge real gameplay step by step.
2. **"You mentioned AI — is this going to be soulless AI slop?"**
   **No.** We are not dumping ugly, mismatched AI art into a folder and calling it a game. AI coding agents handle the repetitive heavy lifting (networking boilerplate, automated tests, server builds, bugfixes) under strict human direction, clean-room legal rules, and readable architecture. **Real players decide what stays, what gets cut, and what feels good** through live playtests.
3. **"Will it look like blocky toy graphics — or sacrifice smooth FPS for eye candy?"**
   **Neither.** Source 2013 runs at high FPS on modern PCs largely because tight entity and prop limits force maps to stay bare and flat — and heavy single-core combat spikes still cause steep frame drops that hit older CPUs hard. We are **not** doing blocky *BattleBit*-style low-poly, and we aren't chasing bloated 60 GB UE5 photorealism either. We're targeting **Godot 4.7** with multi-threaded Jolt physics, GPU instancing, and a grounded, **scalable stylized PBR (mid-poly)** art direction — real weathered metal, concrete, mud, and bold readable silhouettes.
   * **On a modern PC (High):** Crisp dynamic shadows, rich materials, atmospheric lighting, dense cover/foliage, and uncapped high-refresh FPS (120/144+ Hz).
   * **On an 8–12-year-old PC (Low):** A hard baseline of **60+ FPS** on an older quad-core CPU + entry-level GPU (GTX 750 Ti / Ryzen Vega 8 class). Even ancient office iGPUs (like Intel HD 4600) stay smoothly playable via built-in **3D Render Resolution Scaling** that keeps the HUD and text razor-sharp.

---

## What We Keep — and What We Fix From Day 1

* **Dense, lived-in maps without losing that high-FPS feel:** Source 2013 stays fast largely because strict entity and prop limits force maps to stay bare. With multi-threaded physics, GPU-instanced modular prop kits, and clean CPU main-thread budgets, maps can finally be packed with real cover, ruins, fortifications, and foliage — while keeping big fights super responsive on modern rigs and reliably **60+ FPS** on older PCs.
* **Never an empty server:** Lightweight **fill-bots** are a core feature, not an afterthought. Even if only 6 people log on at 10 PM, bots fill out the frontline — and an emergency bot-Commander can step in when nobody wants to sit in the CV.
* **Less confusion, better feedback:** Clear 3D in-world Commander orders, plain-English UI feedback (*"Factory exit blocked"*, *"Need 150 more res"*), and a readable tank customizer without memorizing spreadsheets.
* **Anti-griefing & real match endings:** Built-in Commander vote-eject, basic CV-griefing safeguards, squad-preserving auto-balance, and endgame pressure so rounds reach an exciting climax instead of stalling forever.
* **Keep the depth that makes it special:** Asymmetric factions, 4 classic classes (Scout, Rifleman, Grenadier, Engineer), Squads & leader abilities, Radar research choices, directional armor (front/side/rear), weapon heat & cooling, and custom tank loadouts.
* **Free, Open Source, Forever:** Apache-2.0 code, CC BY 4.0 assets, original clean-room IP (zero Valve/Empires code or stolen assets), direct IP join, self-hostable Linux servers, zero microtransactions, zero account locks.

### A Realistic Version 1.0 Scope
* **In V1.0:** Classic mode, 2 original factions, 4 classes, a streamlined research tree with real tech trade-offs, 4 distinct chassis (Jeep, APC with mobile spawn, Medium Tank, Heavy Tank) + Command Vehicle, fill-bots, and 2–3 well-detailed maps built with our Godot terrain & modular prop kit.
* **After V1.0:** Conquest & Mission/Escort modes, Artillery/AFVs, expanded research branches, built-in VoIP, expanded community modding tools, and optional TrenchBroom brush-mapping support for Hammer veterans.

---

## How You Can Help (and Exactly What You Need)

You do **not** need to be a programmer or commit 20 hours a week. Pick whatever matches your skills and free time:

| Role | What You Actually Do | What You Need | Time Needed |
|---|---|---|---|
| **Playtester & Hardware Benchmarker** | Download a small zip, join our hosted online test server, play a 10–30 min match, hit **`F8`** if a bug happens (saves an automatic log), and post a 1-sentence report + your FPS/specs. | **Any Windows or Linux PC** (both older CPUs/GPUs *and* modern rigs are valuable so we test 60+ FPS Low scaling and High-refresh visuals!). No coding, no Steam account, no port-forwarding. | **15–30 mins** whenever a playtest drops |
| **Empires Veteran & Balance Reviewer** | Keep the tactical soul alive. Critique mechanics specs (armor angles, heat curves, research costs, anti-griefing rules), suggest faction/game names, and tell us what feels wrong after playtests. | Experience playing *Empires* (or similar FPS/RTS games) and honest text feedback in Discord/forum. **Zero tools required.** | **5–15 mins** whenever you want to chime in |
| **3D Modeler, Texture, UI & Sound Creator** | Create or polish grounded mid-poly tanks, buildings, reusable modular map props (barriers, rocks, ruins, foliage), shared trim-sheet PBR textures, crisp HUD icons, or punchy SFX (all original or CC-compatible). | Free tools you already know — **Blender** (3D), **Krita / GIMP / Inkscape** (textures & UI), or **Audacity** (Audio). GitHub optional (you can drop files in Discord and we'll commit them with full credit). | **Flexible** — even a single modular prop, icon, or sound helps |
| **Mapper & Layout Designer** | Early on: sketch 2D tactical map layouts (choke points, cover density, resource nodes, sightlines, tank turning paths). Later: sculpt hills, paint roads, and place modular cover/fortifications directly in Godot (or optionally block out custom bunkers/structures in TrenchBroom if you're a Hammer veteran). | Right now: literally **pen & paper, Paint, or Excalidraw**. Later: free **Godot 4.7** with our all-in-one terrain & modular prop starter kit (instant WYSIWYG preview, no clunky import steps; optional TrenchBroom bridge for Hammer veterans). | **Flexible** — from one napkin sketch to a full map |
| **Coder, Reviewer or AI-Assisted Builder** | Review pull requests for clean, CPU-friendly architecture, debug tricky netcode/physics edge cases, OR grab a small issue, pair with your preferred AI coding assistant following our clean-room rules, run the tests, and submit a PR. | Free **Godot 4.7** (strictly typed GDScript), **Git / GitHub**, and basic reading/testing discipline. *(Strict rule: never feed original Valve/Empires code or assets into prompts or PRs.)* | **1–2 hours** per small issue or PR review |
| **Test Server Hoster** | Spin up a community dedicated server instance during 32/64-player stress tests (we provide a 1-command Linux package/Docker image). | Any basic **Linux VPS** (even a $5/month box) or spare Linux machine with an open UDP port. | **10 mins** setup per major stress test |

---

## Our First 3 Online Playtests (No Setup Headaches)

Every early test runs on a **hosted online test server** — just unzip, launch, and click Join:

* **Playtest 1 (2 players, ~10 mins):** Commander drops a waypoint; driver hops into a tank and drives there. *Test goal: Does driving feel smooth over the internet, and are orders instantly clear?*
* **Playtest 2 (2 players, ~15 mins):** Secure a resource node, build a Refinery & Vehicle Factory, buy a tank, and roll out. *Test goal: Catch every UI and economy annoyance.*
* **Playtest 3 (~4v4 + fill-bots, ~30 mins):** First complete match to CV destruction and round restart. *Test goal: Does the core loop actually feel exciting?*

---

## Want to Jump In? Reply With 2 Quick Things:

To kick off the discussion (and see who wants in on Playtest 1), drop a reply below:

1. **Your non-negotiables & pet peeves:** What 2 mechanics from *Empires* MUST stay, and what annoyed you most that we should fix from Day 1?
2. **How you'd like to help (if at all):** Just drop your role(s) from the table above — e.g. *"Playtester on an old i5 + GTX 750 Ti"*, *"Balance feedback"*, *"Can model modular map props in Blender"*, or *"Happy to review GDScript PRs"*.

Skeptics, lurkers, and wild name/faction ideas are all welcome.

> **Want the full technical & legal blueprint?** Everything from the Godot 4.7 vs. Dæmon breakdown, clean-room IP rules, two-stage netcode, anti-single-core CPU rules, scalable PBR art & Godot terrain mapping pipeline, 60+ FPS hardware benchmarks, and governance to the exact AI agent kickoff spec is documented in [`docs/PROJECT_VISION.md`](docs/PROJECT_VISION.md).