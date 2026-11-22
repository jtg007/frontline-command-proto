# Project Vision for a Free, Open-Source FPS/RTS Spiritual Successor to Empires

**Last Updated: November 22, 2026 · Decision Blueprint for a Community Team · "Empires 2" is a working title.**

**Recommendation:** Build an independent, clean-room game with its own world, maps, and self-hostable dedicated Linux server. Prototype first on **Godot 4.7** (strictly typed GDScript, Compatibility/Forward+ scalable rendering, Jolt multi-threaded physics, ENet networking). Milestone 1 is reached when two teams can play a complete online round: a Commander secures a resource node, an Engineer builds a Vehicle Factory, a teammate buys a vehicle, drives to the front, and changes the outcome of the match. This loop validates the game far earlier than a catalog of finished weapon models.

| Decision | Proposal | What Would Change This Decision |
|---|---|---|
| Technical Stack | Godot 4.7, strictly typed GDScript (Milestones 0–2), Jolt physics, ENet, headless Linux server | The exact same dense combat scene misses the $60\text{ FPS}$ frame budget on baseline older hardware despite localized CPU/GPU optimization. Then evaluate Dæmon with the same test scene. |
| Licensing & Distribution | Original code under Apache-2.0, original final assets under CC BY 4.0, direct IP/server join without platform account lock-in | The team explicitly chooses copyleft enforcement (GPLv3) or obtains verified rights for an official sequel. |
| Version 1.0 Scope | **V1.0 Core:** Classic mode, 2 original factions, 4 classes, streamlined research tree, 4 chassis + CV, fill-bots, 2–3 dense modular maps. Everything else is Post-1.0. | External playtesters consistently finish rounds unassisted and 64-player load tests pass. |
| Performance & Visual Scaling | Uncapped high-refresh rendering ($120/144+\text{ Hz}$) on modern PCs; hard baseline of $60+\text{ FPS}$ ($p95 \le 16.6\text{ ms}$) at $1280 \times 720$ Low on older quad-core + entry GPU (GTX 750 Ti / Vega 8 class); 3D resolution scaling for ancient office iGPUs | Measurements from both FPS ground view **and** RTS Commander view show whether CPU main-thread, GPU fillrate, VRAM, or bandwidth is the true limiter. |

**Start here:** The [Agent-Driven Development Plan to First Match](#workplan) defines how coding agents deliver small, online-playable builds and which three live playtests the community runs. A copy-pasteable kickoff prompt sits at the bottom. Use the research chapters below as reference when making specific architectural, legal, or design decisions.

**Reading Path:** [Why Switch? (Core Improvements)](#improvements) · [Original Feature Matrix](#original) · [Lessons from Earlier Ports](#ports) · [Legal, Clean Room & Distribution](#legal) · [Engine Comparison](#engines) · [Multiplayer, CPU & Performance](#netcode) · [Art Direction & Dense Maps](#art) · [AI Workflow & QA](#ai) · [Community, Governance & Hosting](#community) · [Roadmap](#roadmap) · [Agent Workplan](#workplan)

Original game mechanics reference the official player manual, project wiki, and changelogs. Notes on earlier ports come from statements by involved developers. Technical budgets, scope cuts, and governance roles are concrete proposals for this project. This document does not contain proprietary engine benchmarks. From legacy bot projects we adopt one key test habit: observe vehicle purchase, factory exit, and arrival separately — a completed purchase transaction alone does not prove a playable rollout.

<a id="improvements"></a>
## 0. Why Switch? Core Improvements Over Classic Empires

Rebuilding an existing mod solely for 1:1 parity rarely excites players enough to migrate. From Day 1, this successor targets the structural pain points of the Source 2013 original while preserving its tactical depth:

1. **Dense, lived-in battlefields without losing the high-FPS feel:** Classic *Empires* runs fast on modern PCs primarily because Source 2013's tight entity, brush, and prop limits force maps to remain sparse and flat — while heavy single-core combat spikes can still cut frame rates sharply on older CPUs. Multi-threaded physics (Jolt), GPU-instanced modular prop kits (`MultiMeshInstance3D`), and strict main-thread discipline allow rich cover, ruins, fortifications, and foliage while maintaining responsive high-refresh FPS on modern rigs and steady $60+\text{ FPS}$ on older hardware.
2. **Never an empty server (Fill-Bots as a core feature):** Small lobbies kill 32-to-64-player games. Lightweight server-side **fill-bots** (infantry, simple vehicle drivers, and an optional emergency Bot-Commander) keep matches playable with 4–8 humans and accelerate automated playtesting.
3. **Readable onboarding & plain-English feedback:** Clear 3D in-world Commander waypoints/build ghosts, concise failure explanations (*"Factory exit blocked"*, *"Need 150 more team resources"*), and an intuitive vehicle customizer with clear weight/heat/armor indicators.
4. **Anti-griefing & decisive match endings:** Built-in Commander vote-eject, basic CV-griefing protections (e.g., team-kill/self-destruct limits, inactivity takeover), squad-preserving auto-balance, and clear endgame ticket/sudden-death pressure to prevent endless stalemates.
5. **Realistic V1.0 Core vs. Post-1.0 split:** Instead of burning out chasing every historical mode, research branch, and edge chassis at once, Version 1.0 ships a tight, balanced **Classic** experience first (including our all-in-one Godot terrain & modular mapping kit); Conquest, Mission/Escort, Artillery/AFVs, built-in VoIP, expanded modding APIs, and optional TrenchBroom brush-mapping support follow cleanly as Post-1.0 expansions.

<a id="original"></a>
## 1. Functional Feature Matrix of the Original Game

As a dated behavioral reference, we use the documented Source release **2.39.4 (February 21, 2026)**. The older manual best explains how systems interact, while patch notes and wiki entries show evolved balance values. This matrix defines **functional** behavior only — exact numerical balance is tuned independently for our game. Every row is tagged for **V1.0 Core** or **Post-1.0** to protect schedule realism. [Release History](https://www.empiresmod.com/posts/) · [2.39.x Changes](https://wiki.empiresmod.com/Version/2.39.x) · [Squad Manual](https://www.empiresmod.com/docs/squads.htm) · [Squad Wiki](https://wiki.empiresmod.com/Squads)

| Core System | Function & Interactions | Functional Parity Criterion | Target Phase |
|---|---|---|---|
| Teams & Roles | Two asymmetric factions with distinct gear, structures, and chassis. One player per side can take strategic command. | Both sides execute the same economy-to-frontline loop with distinct tactical strengths. | **V1.0 Core** |
| Infantry & Progression | Class, loadout, and personal skill selection; points/rank unlock extra skill slots. Health, ammo, stamina, death, revive, spawn choice, and class swaps shape the front. | A player can re-equip at a valid point and fulfill a meaningful role between respawns. | **V1.0 Core** (core skills); extra skills **Post-1.0** |
| Scout | Recon, target spotting, stealth/cloak, and building sabotage disrupt enemies and provide intel. | Teammates can act on spotted contacts; sabotage measurably alters target building state. | **V1.0 Core** |
| Rifleman | Infantry combat (rifles/LMG), personal survivability, and grenades including an anti-armor option. | Class can clear ground so Engineers can safely push and construct forward spawns. | **V1.0 Core** |
| Grenadier | Rockets, mortar, and mines counter vehicles and static defenses. | Position, range, and target movement change which tool is optimal. | **V1.0 Core** |
| Engineer | Build, repair, heal, revive (with skill), resupply ammo, and deploy turrets, sensors, cameras, and walls. | Unbuilt blueprints become functional, damaged vehicles return to combat, downed allies rejoin the fight. | **V1.0 Core** |
| Squads | Join, invite, lock, transfer/claim lead; HUD shows squad state. Coordinated play earns squad points. Leader class determines passive proximity aura and two active squad abilities. | Changing leader updates available perks; squad orders reach only the right players. | **V1.0 Core** |
| Commander | Election and enterable Command Vehicle (CV), RTS top-down camera, unit/group selection, move/attack/build orders, structure placement, and research. The CV is a vulnerable world entity. | Ground players immediately understand orders; a threatened base forces spatial trade-offs. | **V1.0 Core** |
| Recon & Comms | Line-of-sight contacts, sensors, minimap, 3D pings, quick-voice commands, text chat, and order feedback bridge RTS and FPS views. | A Scout contact appears for the correct team and decays when stale. | **V1.0 Core** (Built-in VoIP **Post-1.0**) |
| Economy | Refineries on fixed resource nodes generate periodic team income. Map control funds tech and vehicles. Personal wages contribute to vehicle purchases. | Losing a node measurably delays the next vehicle; costs remain transparent to buyer and Commander. | **V1.0 Core** |
| Structures | Barracks (spawns), Armory (resupply/loadout), Radar (research), Vehicle Factory, Repair Pad (rearm/refit), Refinery, Walls, MG/ML turrets. Placement, unbuilt, built, damaged, repaired, and destroyed are distinct states. | Unfinished structures do not provide full service; losing a forward Barracks shifts the frontline. | **V1.0 Core** |
| Research | Active Radar required, Commander selects tech, prerequisites, research timer, team-wide unlocks modifying chassis, weapons, engines, armor, and defenses. (Original has 5 branches: Physics, Chemistry, Mechanical, Electrical, Biology.) | Early tech decisions unlock visibly different vehicle loadouts later; late joiners see the exact same tech state. | **V1.0 Core** (streamlined 3-branch tree); full 5-branch expansion **Post-1.0** |
| Chassis & Production | Jeep, APC (mobile spawn/transport), Medium Tank, Heavy Tank, plus Command Vehicle. Original also includes faction Light Tank/AFV and Artillery. Chassis restrict seats, weight, and slot types/sizes. | Illegal loadouts cannot fit every chassis; an APC physically shifts reinforcement flow. | **V1.0 Core** (Jeep, APC, Med, Heavy, CV); Light/AFV & Artillery **Post-1.0** |
| Vehicle Customization | Select engine, armor type, plate counts per side, and weapons within slot type, slot size, weight, and cost limits; assign firing groups. | Factory rejects invalid builds server-side; two legal builds of the same chassis play noticeably differently. | **V1.0 Core** |
| Vehicle Combat & Logistics | Separate Front/Rear/Left/Right armor pools; hitting stripped armor damages hull. Firing builds heat; engine/cooling dissipate it; overheating restricts fire/movement. Ammo, repairs, and refits tie vehicles back to logistics. | Flanking, heat discipline, and retreating to repair are all meaningful tactical decisions. | **V1.0 Core** |
| Classic Mode | Base building, resources, Commander, and CV. Destroying the enemy CV (or removing their ability to fight), ticket exhaustion, or sudden death ends the round. | CV destruction, ticket depletion, and endgame pressure are verified separately. | **V1.0 Core** |
| Conquest Mode | Capturable flags grant spawns, resources, or ticket bleed per map rules. | Holding a flag changes actual supply or victory countdown. | **Post-1.0** |
| Mission Mode | Asymmetric map-defined objectives (e.g., escort/breakthrough) with sequential phases. | Attackers and defenders have distinct win paths; every player sees the active objective. | **Post-1.0** |

**Squad Abilities Reference:** Scout provides stamina aura, squad hide, and recon scan. Rifleman boosts accuracy and reduces stamina drain or incoming damage. Grenadier boosts damage and activates extra damage buff or artillery/area strike. Engineer regenerates health and triggers squad heal or squad revive. Leader proximity, point cost, and active duration belong as explicit data rules. [Squad Mechanics](https://wiki.empiresmod.com/Squads) · [Personal Skills](https://wiki.empiresmod.com/Skills)

**Matrix Sources:** [Classes & Equipment](https://www.empiresmod.com/docs/classes_and_skills.htm) · [Commander](https://www.empiresmod.com/docs/commanding_and_research.htm) · [Structures](https://www.empiresmod.com/docs/structures_appendix.htm) · [Research Trees](https://wiki.empiresmod.com/Research) · [Vehicle Customization](https://www.empiresmod.com/docs/vehicle_customization.htm) · [Chassis](https://www.empiresmod.com/docs/vehicle_chassis_appendix.htm) · [Modes & Maps](https://www.empiresmod.com/docs/maps_and_gameplay.htm) · [Wages & Gameplay History](https://wiki.empiresmod.com/Version/2.13.x)

<a id="ports"></a>
## 2. What Earlier Port Attempts Actually Teach Us

| Attempt | Documented Finding | Takeaway for an Independent Successor |
|---|---|---|
| Battlefield 1942 → Source | *Empires* began as a solo BF1942 project, moved to Source, and matured into a community project that actually shipped. | Switching engines can work. A playable target build and maintainable handoff matter more than chasing cutting-edge rendering. [Project History](https://www.empiresmod.com/developer-team/) |
| Multiple attempts since 2008 | Former dev RoyAwesome noted several remakes and ports stalled primarily due to lack of unified direction rather than a single technical flaw. | Product decisions require a named Design Owner and a written scope boundary to prevent endless committee drift. [Retrospective & Roadmap, May 2020](https://www.empiresmod.com/posts/unreal-progress-report-may-2020/) |
| UE4 Effort (2020+) | Volunteers worked evenings/weekends on a roadmap covering shooter netcode, squads, vehicles, full moddability, reusable art pipelines, and every classic map. One roadmap sentence expanded into 30+ tasks. | Good long-term dreams can delay the first real match indefinitely. Connect Commander, Factory, and Driver in one tiny playable loop first; defer Mod APIs and huge map catalogs. [UE4 Progress Report](https://www.empiresmod.com/posts/unreal-progress-report-may-2020/) |
| Production Bottlenecks | In May 2021, vehicle suspension modeling stalled while engineering implementation was unresolved; fast projectile tests worked locally before network synchronization existed. | An offline editor asset and a local stress demo prove the wrong things. A greybox tank driving over the internet exposes real risks months earlier. [Dev Report, May 2021](https://www.empiresmod.com/posts/unreal-progress-report-may-2021/) |
| UE5 & Ongoing Status | The official team continues recruiting UE5 animators/designers alongside Source patches; public records neither show a shipped feature-complete UE sequel nor an official cancellation. | Volunteer bandwidth and integration overhead are proven realities. Stay respectful of existing teams and prove our approach via fast, playable slices. [Team Page](https://www.empiresmod.com/developer-team/) · [Dev Archive](https://www.empiresmod.com/posts/) |

<a id="legal"></a>
## 3. Legal Framework, Clean-Room Process & Distribution

### Independent Development (EU / German Legal Baseline)

The CJEU distinguishes unprotectable software **functionality** from protected **expression**. *SAS Institute* clarified that functionality and programming languages are not copyright-protected as such; *Nintendo v. PC Box* confirmed video games are complex works whose graphics, audio, and code enjoy independent protection. Practically: *"A Refinery pays periodic resources to its team"* is an unprotectable functional rule. Specific factory silhouettes, audio clips, manuals, map geometry, and lore require 100% original creation. A documented clean-room workflow strengthens legal defensibility; final store release still warrants a legal check for target markets. [CJEU C‑406/10](https://eur-lex.europa.eu/legal-content/DE/TXT/?uri=CELEX:62010CJ0406) · [CJEU C‑355/12](https://eur-lex.europa.eu/legal-content/DE/TXT/?uri=CELEX:62012CJ0355)

| Area | Mandatory Clean-Room Rule |
|---|---|
| Mechanics & Specs | Authorized players observe normal gameplay and write functional specs (inputs, observable outcomes, test cases) in their own words (cf. German UrhG § 69d(3)). Decompilation (§ 69e) is neither needed nor permitted for an independent successor. [§ 69d](https://www.gesetze-im-internet.de/urhg/__69d.html) · [§ 69e](https://www.gesetze-im-internet.de/urhg/__69e.html) |
| Implementation & AI Context | Spec writers document behavior with dates/sources. A separate gate filters out expressive elements before handing specs to coding agents or programmers. **Zero original Source/Empires code, restricted SDK samples, decompiled dumps, bot hooks, original scripts, or extracted assets** may ever enter the repository or any AI prompt/context. [UrhG § 69a](https://www.gesetze-im-internet.de/urhg/__69a.html) · [Source SDK License](https://github.com/ValveSoftware/source-sdk-2013/blob/master/LICENSE) |
| Name, Factions & Lore | Fully original public title, faction names, logos, lore, and terminology. Never ship publicly as "Empires 2" without legal rights. Check similar trademarks and work titles in target markets before public branding. [DPMA Search Guide](https://www.dpma.de/marken/markenrecherche/) · [MarkenG § 5](https://www.gesetze-im-internet.de/markeng/__5.html) |
| Maps, 3D Art & Audio | Brief mappers/artists with abstract tactical goals (*"two armored flanks toward a contested refinery valley"*). Design new terrain, proportions, sightlines, and landmarks. **Never** convert BSP/VMF maps, trace minimaps, re-texture original meshes, or re-record original voice lines. [UrhG § 2](https://www.gesetze-im-internet.de/urhg/__2.html) · [UrhG § 23](https://www.gesetze-im-internet.de/urhg/__23.html) |
| Contribution Provenance | Track source file, author, input material, license version, and sign-off for every PR. Require **Developer Certificate of Origin (DCO)** sign-off on all commits. [DCO](https://developercertificate.org/) |

### License Selection

| License | Effect on Redistribution | Project Role |
|---|---|---|
| MIT | Permissive reuse including commercial forks; preserve notice. No explicit patent grant. | Acceptable for third-party dependencies. [MIT](https://opensource.org/license/mit) |
| **Apache-2.0** | Permissive with explicit patent grant and patent retaliation clause; retain license/NOTICE. | **Recommended for all project code and tools.** Valve lists Apache-2.0 as generally Steamworks-compatible. [Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0) · [Valve Open Source Docs](https://partner.steamgames.com/doc/sdk/uploading/distributing_opensource) |
| GPLv3 | Strong copyleft for distributed combined works (hosting a modified server alone does not trigger source release under standard GPLv3). | Only if mandatory open forks outweigh Steamworks SDK friction. [GPLv3](https://www.gnu.org/licenses/gpl-3.0.html) |
| **CC BY 4.0** | Allows remixing and commercial redistribution with attribution, license link, and change notes. | **Recommended for original final 3D models, textures, audio, and maps.** Bundle full credits in-game and in release zips. [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| CC BY-SA 4.0 | Share-alike requirement for adapted works; requires careful tracking across texture atlases and combined packs. | Optional only for standalone community asset packs; avoid NC/ND licenses entirely so the game remains freely moddable and distributable. [CC Licenses](https://creativecommons.org/share-your-work/cclicenses/) |

Generate an automated **license & attribution manifest** from every shipped build's actual files (including fonts, shaders, plugins, and third-party libraries).

### Distribution Channels & AI Disclosures

| Channel | Role | Pre-Release Check |
|---|---|---|
| **GitHub Releases** | Source snapshots, Windows/Linux clients, dedicated Linux server packages, SHA-256 checksums. | Include `LICENSE`, `NOTICE`, and full asset credits in every downloadable archive. [GitHub Licensing](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository) |
| **itch.io** | Free early playtests, direct zips, optional donations. | Apply accurate AI Disclosure tags if any player-facing generated assets exist (procedural logic and classic bot AI are explicitly exempt). [itch.io Quality Guidelines](https://itch.io/docs/creators/quality-guidelines) |
| **Steam** | Free release, automated patching, and broad visibility once V1.0 Core is battle-tested. | Budget the $100 USD Steam Direct fee (unrecouped for a free game with no microtransactions). Keep Steamworks SDK integration strictly optional/decoupled so standalone non-Steam builds always work. [Steam Direct Fee](https://partner.steamgames.com/doc/gettingstarted/appfee) |
| **Steam Content Survey** | Auto-generate accurate disclosure from our asset provenance manifest. | Valve focuses on pre-generated or live-generated player-consumed content (art, audio, text), not internal coding productivity tools. Re-verify before every major release. [Steam Content Survey](https://partner.steamgames.com/doc/gettingstarted/contentsurvey) |

**AI & Copyright Note:** Under German law (UrhG § 2), copyright requires personal intellectual creation; the U.S. Copyright Office likewise treats pure prompt outputs as generally uncopyrightable unless accompanied by substantial human authorship, selection, or modification. For every AI-assisted asset, record tool/version, input ownership, license terms, and human polish. [UrhG § 2](https://www.gesetze-im-internet.de/urhg/__2.html) · [U.S. Copyright Office AI Guidance](https://www.copyright.gov/ai/)

<a id="engines"></a>
## 4. Engine Comparison for Scalable Visuals, High FPS & Volunteer Teams

The practical shortlist is **Godot 4.7 vs. Dæmon**. Godot offers a dramatically faster path to a custom RTS Commander UI, vehicle customizer, open terrain/modular PBR maps, and approachable volunteer contributions. Dæmon has battle-tested legacy-GPU FPS heritage, but requires heavy C++ engineering for vehicles, RTS command, and research. Only a shared benchmark scene can settle edge cases — never judge runtime performance by editor minimum specs.

| Engine | Rendering, CPU & Scaling | Multiplayer & 3D Production | Maintainability & Verdict |
|---|---|---|---|
| **Godot 4.7** (MIT) | Compatibility renderer (Desktop OpenGL 3.3) for older GPUs + Forward+/Mobile (Vulkan/D3D12) for modern High-preset visuals. **Jolt** multi-threaded 3D physics is default since 4.6. `MultiMeshInstance3D` enables dense instanced maps with minimal CPU draw-call overhead. | Integrated WYSIWYG scene editor, open-source terrain plugins, glTF 2.0 pipeline, strong UI system, GDScript/C#/GDExtension (C++), built-in ENet and headless Linux server export. Custom netcode prediction, lag comp, and RTS relevance are project code. | **First choice for the prototype.** Pin one exact stable 4.7.x release, export templates, and plugins. Do not switch physics or renderer mid-benchmark. [Godot 4.7](https://godotengine.org/releases/4.7/) · [System Requirements](https://docs.godotengine.org/en/4.7/about/system_requirements.html) · [Jolt Default](https://godotengine.org/releases/4.6/) |
| **Dæmon / Unvanquished** | OpenGL 2.1 floor, lean FPS path, precomputed BSP visibility. Excellent for ultra-old GPUs, though open vehicle maps differ greatly from indoor corridors. | Proven FPS + building + dedicated server + NetRadiant/BSP workflow. Adding RTS Commander view, multi-seat physics vehicles, customization, and research is major C++ work. | **Fallback only** if Godot misses the $60\text{ FPS}$ budget on GTX 750 Ti / older quad-core hardware in Milestone 0 despite optimization. Audit BSD/GPL component boundaries carefully. [Unvanquished Specs](https://unvanquished.net/download/) · [License Breakdown](https://raw.githubusercontent.com/DaemonEngine/Daemon/master/COPYING.txt) |
| **Bevy** (MIT/Apache-2.0) | Rust ECS parallelizes systems cleanly; `wgpu` targets Vulkan/DX12 (older native GL Windows drivers require explicit testing). | Great for headless server simulation; lacks turnkey visual editors, map authoring pipelines, and mature networking/UI tooling out of the box. | Strong only if the core team is already experienced in Rust ECS and willing to maintain custom editor tooling. [Bevy](https://bevy.org/) |
| **Stride** (MIT) | Mature D3D11 path on Windows; Vulkan on non-Windows (hurts older Linux GL-only GPUs). Monitor C# GC pauses in combat. | Pleasant C#/.NET workflow; Windows-centric editor complicates cross-platform Linux mapping/testing. | Conditional option only for an existing Windows/C# team. [Stride Graphics APIs](https://doc.stride3d.net/latest/en/manual/graphics/graphics-api.html) |
| **O3DE** (Apache-2.0) | Atom renderer targets DX12/Vulkan; heavy dev requirements (16 GB RAM recommended) and long C++ build times. | Built-in Multiplayer Gem with prediction/reconciliation, but steep onboarding and profiling overhead for volunteers. | Deprioritized for an accessible volunteer/older-PC project. [O3DE Requirements](https://docs.o3de.org/docs/welcome-guide/requirements/) |

**Language Decision (Binding for Milestones 0–2):** Start exclusively with **strictly typed GDScript** (`var x: int`, typed return values, strict static warnings enabled). It provides the fastest iteration loop, zero C#/C++ build friction for community reviewers, and clear diffs for AI coding agents. Only move a **measured, profiled CPU hotspot** (such as 64-player projectile arrays or spatial relevance filtering) into a C++ **GDExtension** module after Milestone 3 profiling proves it is necessary.

<a id="netcode"></a>
## 5. Multiplayer, CPU Discipline & Performance Architecture

### Two-Stage Networking Strategy (Preventing Early Agent Deadlocks)

Full vehicle client-side prediction and server reconciliation in 3D physics is notoriously error-prone. Trying to ship it in Week 1 traps coding agents in subtle physics desyncs. We explicitly split networking into two stages:

* **Stage 1 (Steps A–H · First Playable Match):**
  * **Server-authoritative movement & custom simple raycast vehicle** (avoiding black-box rigid-body wheel physics quirks).
  * Client sends timestamped inputs and numbered intent commands (`request_id`); server owns movement, economy, building, vehicle purchase, combat, and victory.
  * Remote entities and early vehicles use **smooth snapshot interpolation** on the client. Focus first on rock-solid economy/purchase idempotency (duplicate packets never double-charge or spawn two tanks) and crisp Commander-to-driver sync.
* **Stage 2 (Milestone 2+ · Responsive 32/64-Player Combat):**
  * **Client-side prediction & server reconciliation** for local infantry movement and local player vehicle steering (collisions remain server-confirmed; measure correction distances).
  * **Bounded Lag Compensation:** Server retains a short hitbox history window for hitscan weapons; slower tank shells/rockets simulate continuously with instant local muzzle feedback. Tune rewind window in live tests against "shot behind cover" feel.
  * **Spatial Relevance & RTS Data Stream:** Grid cells + team intel filter high-frequency transforms. The Commander camera receives a dedicated low-bandwidth tactical stream (team-known contacts, icon types, timestamps) — enemies outside team vision are **never** sent to clients (prevents wallhacks/maphacks).
  * **Channels & Join-in-Progress:** Sequenced unreliable packets for transforms/aim; reliable ordered channels for purchases, build states, seat changes, research, and round state. Late joiners receive a consistent baseline snapshot + delta stream.

References: [Client-Side Prediction](https://www.gabrielgambetta.com/client-side-prediction-server-reconciliation.html) · [Lag Compensation](https://www.gabrielgambetta.com/lag-compensation.html) · [Snapshot Interpolation](https://gafferongames.com/post/snapshot_interpolation/)

| Transport | Strengths | Decision |
|---|---|---|
| **ENet** (MIT) | Lightweight UDP, reliable/unreliable channels, built directly into Godot's high-level multiplayer API. | **Use from Day 1.** Keep gameplay/purchase/movement rules decoupled from the transport layer so swapping later is clean. [ENet](https://github.com/lsalzman/enet) |
| **GameNetworkingSockets** (BSD-3-Clause) | Standalone open-source encryption, fragmentation, and diagnostics (independent of proprietary Steamworks SDR). | Evaluate post-V1.0 only if encryption/NAT-traversal needs justify native integration overhead. [GameNetworkingSockets](https://github.com/ValveSoftware/GameNetworkingSockets) |

### Anti-Cheat, Moderation, Comms & Fill-Bots

* **Server-Authoritative Anti-Cheat & Rate Limiting:** Clients never report damage, money, position authority, or enemy positions outside team fog-of-war. Apply strict server-side rate limits on all RPCs (purchase spam, waypoint spam, chat spam) and sanity-check movement speed/fire rates.
* **Moderation & Anti-Griefing (Built into Core, not bolted on late):** Commander vote-eject, basic CV-griefing protection (preventing intentional rapid CV destruction/AFK lockout), admin RCON/kick/ban lists, and squad-preserving auto-balance.
* **Communication:** Fast 3D contextual pings, quick-voice radio wheel, team/squad text chat, and clear Commander order markers are **V1.0 Core**. Integrated VoIP (Commander/Squad channels) is **Post-1.0** (use Discord/Mumble during early community playtests).
* **Fill-Bots (Server-Side):** Lightweight state-machine bots occupy infantry slots (push objectives, defend structures, repair near combat) and can act as an emergency Bot-Commander (places Refineries, Barracks, Vehicle Factory, basic research) when no human claims the CV. Bots execute through the exact same server action validation as human players.

### Performance Targets & Repeatable Hardware Benchmarks

* **Client Frame Rate (Uncapped & Smooth):** Rendering is completely decoupled from the server simulation tick via interpolation. Modern PCs run uncapped ($120/144+\text{ Hz}$).
* **Baseline Older-PC Target (Hard Gate):** $60+\text{ FPS}$ ($p95 \le 16.6\text{ ms}$) at $1280 \times 720$ Low in active 32-player (Milestone 3) and 64-player (Milestone 4) combat — tested on an older quad-core CPU + entry-level discrete/integrated GPU (e.g., **4th-gen i5 + GTX 750 Ti 2 GB** or **Ryzen Vega 8**, 8 GB dual-channel RAM).
* **Ultra-Low / Ancient Office iGPU Fallback:** Built-in **3D Render Resolution Scaling** ($50\%$–$100\%$ internal 3D scale while keeping 2D HUD, minimap, and text at native resolution) so ancient iGPUs (e.g., Intel HD 4600) remain smoothly playable near $60\text{ FPS}$ without forcing the entire game down to a $30\text{ FPS}$ target.
* **Server Simulation Budget:** $30$ fixed simulation ticks/sec ($33.3\text{ ms}$ per tick), targeting server tick work $p99 < 28\text{ ms}$ at full player load, sending $15$–$20$ snapshots/sec for nearby relevant entities.

### Preventing Single-Core CPU Bottlenecks (Main-Thread Discipline)

Classic Source 2013 achieves high frame rates on modern PCs largely because tight entity/prop limits keep levels bare — yet big combat spikes still funnel through one CPU thread, causing steep frame-rate drops that punish older CPUs. In Godot, multi-threaded Jolt physics and GPU instancing relieve huge pressure, **unless naive per-node GDScript recreates a single-core bottleneck**. Every coding agent and contributor must follow four strict rules:

1. **Centralized Managers over Per-Entity Tick Scripts:** Active projectiles, sensor pings, turret target scans, and minimap contacts update in compact, flat arrays inside centralized managers — never as 200 independent nodes running `_physics_process()` every tick.
2. **Staggered Non-Critical Updates:** Vision/fog-of-war updates, bot decision-making, turret scanning, and minimap refreshes spread their workload across multiple ticks (round-robin batches) instead of spiking all units on the same frame.
3. **Aggressive Instancing & Sleeping Physics:** Static map props share meshes via `MultiMeshInstance3D` (single draw call per prop type/cluster). Built structures use static colliders; idle vehicles sleep; distant wheels animate visually without active raycasts.
4. **Profile Before Threading or C++:** Measure main-thread vs. physics vs. GPU time on real older hardware (`p50/p95/p99`, worst frame hitch, peak RAM/VRAM). Only migrate verified hotspots to worker threads or C++ GDExtension.

### Built-In Diagnostics (`F8` Debug Bundle) & Online Test Access

* **One-Key Bug Capture (`F8`) from Step A:** Pressing `F8` (or typing `/bug`) saves a lightweight local zip containing Build-ID, commit hash, OS/GPU/driver string, FPS/frame-time percentiles, ping/packet loss, and the last 200 client/server state events. Players attach this file to their 1-sentence Discord report so agents never have to guess what caused a desync or failed purchase.
* **Zero-Friction Online Playtests:** Never rely on LAN or home router port-forwarding for Playtest 1. Deploy the headless Linux server from Day 1 on a cheap hosted VPS (~$5/month) or a free UDP tunnel (e.g., Playit.gg) with a one-click server address pre-filled in the test client.

### Module Boundaries & Data Validation

Keep strict boundaries: **Rules** (economy, research, damage, victory) · **Simulation** (movement, physics) · **Network** (numbered commands, snapshots, relevance) · **Presentation** (FPS/Commander cameras, HUD, VFX/SFX) · **Map Data** (spawns, resource nodes, build zones, objectives). Weapons, chassis, armor, and research live in versioned data files with stable IDs. CI and the dedicated server run the exact same schema validator (rejecting missing IDs, cyclic tech dependencies, negative costs, invalid slots). A **manifest hash** checked at join immediately blocks mismatched clients.

<a id="art"></a>
## 6. Art Direction, Dense Modular Maps & Mapping Workflow

**Visual Identity — Scalable Stylized PBR (Mid-Poly):** Not blocky toy low-poly, and not bloated 60 GB UE5 photorealism. Aim for a clean, grounded military-industrial look (think modernized *Battlefield 2* / *Source* readability with the cohesive material clarity of *Foxhole* or *Deep Rock Galactic*): weathered painted metal, concrete, mud, fabric, bold silhouettes, distinct faction shape languages, colorblind-safe faction icons, and unmistakable audio signatures. Every vehicle and structure must read instantaneously from both eye-level FPS view and zoomed-out RTS Commander view.

**Solving Source's "Empty Map" Problem Without Art Burnout:** Instead of modeling 500 unique bespoke props, build a **reusable modular kit of 25–40 mid-poly assets** (concrete barriers, sandbags, trenches, ruined walls, shipping containers, rocks, trees, bushes, craters, road signs) sharing **trim-sheet PBR textures**. Combine them with `MultiMeshInstance3D` GPU instancing and 3 clean LOD stages so maps feel rich, tactical, and lived-in while keeping draw calls and VRAM tiny.

| Area | Production Rule | Low vs. High Scaling & Verification |
|---|---|---|
| Materials & Lighting | Grounded stylized PBR with unified palettes and shared trim-sheets. Static terrain/buildings use baked Lightmaps (`LightmapGI` UV2) for crisp, zero-cost ambient lighting; dynamic vehicles/built structures use light probes. | **Low (Compatibility):** Baked lightmaps, short shadow distance, no SSAO/volumetric fog/RTGI, optional 3D resolution scaling. **High (Forward+):** Crisp dynamic shadows, richer specular/metal reflections, atmospheric lighting, denser decorative grass/debris, richer smoke/explosions. **Rule:** Tactical cover, enemy silhouettes, and warning telegraphs must remain identical on Low and High. [Godot Renderers](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html) |
| Geometry & Draw Calls | Mandatory LODs for vehicles, structures, and foliage; simplified convex/box collision meshes separate from render meshes. Instance repeated props via `MultiMeshInstance3D`. | Measure draw calls, shadow casters, and alpha overdraw (smoke/foliage) from **both** ground combat and zoomed-out Commander view over a built-up base. [Godot 3D Optimization](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html) |
| VRAM & Effects | Mipmaps, VRAM texture compression (S3TC/BPTC), bounded atlas sizes, scalable particle counts and dynamic lights. | Profile smoke, dust, and foliage overdraw specifically on 2 GB VRAM GPUs and integrated graphics. |
| Terrain & Sightlines | Ridges, road embankments, ruins, and building clusters naturally break long sightlines (helping both tactics and culling). Test turning radii and factory exits during greybox. | Drive every main lane with both infantry and the widest planned Heavy Tank chassis before any art pass. |

### Phased Mapping Pipeline (Native Godot First, TrenchBroom Optional)

Because *Empires*-style battlefields are primarily **large, open vehicle landscapes** with hills, valleys, roads, and dense instanced cover, classic Quake-style brush editors are poorly suited as the primary workflow (they lack native terrain sculpting and WYSIWYG foliage/lighting previews). We therefore make the native Godot editor the official first-class mapping pipeline:

* **Milestones 0–2 (Fast Agent & Prototype Phase):** Build the first test map directly as a clean **native Godot 4.7 scene** using simple modular greybox meshes and real-time directional light (no terrain plugins or heavy lightmap-baking steps required on contributors' older GPUs). This removes importer friction while coding agents rapidly iterate on Steps A–H.
* **Milestone 3+ (Primary Community Mapping Pipeline — Native Godot + Terrain):** Ship an official **Godot 4.7 Mapper Starter Kit** combining an open-source terrain sculpting/painting addon (e.g., **Terrain3D**), our reusable **modular mid-poly prop kit**, GPU-instanced foliage/cover scatter tools (`MultiMeshInstance3D`), and drag-and-drop gameplay entities (Team Spawns, Resource Nodes, Factory Exits, No-Build Zones), plus human-scale dummies and Heavy Tank turning-clearance guides. Mappers sculpt hills, paint mud/roads, scatter cover, preview real lighting, and test directly on a dedicated server inside one single program.
  * **Mapper Onboarding Gate:** A non-programmer opens the starter kit in Godot, sculpts a hill, places a new spawn and resource node, adds instanced cover, saves, and boots the map on the dedicated server without breaking IDs or collision scale.
* **Post-1.0 / Optional Bridge for Hammer Veterans:** For experienced Source/Hammer mappers who specifically prefer classic brush-based blockouts, **TrenchBroom + FuncGodot** can be supported as an *optional* secondary workflow — ideal for authoring custom concrete bunkers, bridges, or urban interiors and dropping them as reusable scenes onto a Godot terrain map. [FuncGodot](https://github.com/func-godot/func_godot_plugin)

<a id="ai"></a>
## 7. AI-Assisted Contributions & Quality Assurance

We do **not** pin volatile AI model names in this blueprint (models evolve every few months). Instead, we enforce **strict provenance, clean-room, and automated verification rules** regardless of which coding or creative tool a contributor uses.

| Discipline | Practical AI Role | Mandatory Quality & Legal Gate |
|---|---|---|
| **Programming** | Coding agents tackle scoped issues against pinned Godot 4.7, strictly typed GDScript, and observable tests (e.g., *"duplicate purchase packet never double-charges"*). | Agent writes automated tests covering happy path, retry/duplicate, abort, and edge cases. Zero proprietary Valve/Empires code in prompts. A clean build alone is never sufficient — automated rule tests and human/review-agent diff checks are required. |
| **3D Assets & Props** | Optional early silhouette/blockout ideation only; core modular kits and vehicles are authored or heavily reworked by humans in Blender. | Final game assets must have clean topology, proper scale/pivots, UV unwrapping, shared trim-sheet PBR compliance, LODs, seat/muzzle markers, and simplified colliders before merging. |
| **Textures & UI** | Optional concept exploration or base material ideation (only tools with clean commercial/CC-compatible output rights). | Humans strip baked lighting from albedo, author clean roughness/normal maps, enforce consistent texel density, check colorblind accessibility, and verify crisp UI legibility at $1280 \times 720$. |
| **Audio** | Prefer original foley recordings or cleanly licensed CC0/CC BY samples. Verify exact license terms of any AI audio tool before use (avoid restrictive/non-commercial licenses). | Test mono 3D spatialization, clean loops, loudness normalization, and combat clarity. Voice lines always require documented human consent and rights clearance. |

**Living Style & Code Guides:** Instead of a 50-page manifesto, pin one approved reference vehicle, one reference structure, one modular prop set, and one HUD panel in the repository with concrete budgets (triangle counts, LOD distances, material count, texel density, audio levels). The Code Guide enforces state ownership, metric units ($1\text{ unit} = 1\text{ meter}$), strict GDScript typing, single-core CPU rules, and network protocol versioning.

**Issue-to-Release Pipeline:**

1. Every issue specifies player-visible behavior, affected data, and acceptance test. Contributors log provenance (original work vs. AI tool/version + human modification) with DCO sign-off.
2. Every PR runs formatting, strict GDScript type/static checks, unit/rule tests, schema validation, and asset checks (missing refs, LODs, colliders, license metadata).
3. A headless smoke test boots the dedicated server, connects 2 clients, generates income, constructs a Factory, buys a tank, and completes a round. From Milestone 3 onward, automated stress runs benchmark 32 and 64 active clients.
4. CI builds and packages Client, Dedicated Server, checksums, and auto-generated license/credit manifests, then unpacks and smoke-tests the actual release archive before handing it to the community.

<a id="community"></a>
## 8. Community, Governance & Sustainable Hosting

| Reference Project | Proven Practice | Adopted for This Project |
|---|---|---|
| **Beyond All Reason** | Public infrastructure docs and transparent financial reports make hosting costs clear to players. | Publish exact monthly server costs, bandwidth usage, donations, and runway months. [BAR Infra](https://beyond-all-reason.github.io/infrastructure/current_infra/) |
| **OpenRA** | Clean engine/content separation and accessible playtest builds before stable releases. | Ship standalone, zero-install playtest archives with clear version tags and simple community bug reporting. [OpenRA Playtests](https://www.openra.net/download/) |
| **Unvanquished** | Role-based contributor onboarding split cleanly across Media, Mapping, and Code. | Offer clear mini-onboarding paths (*"My first modular prop"*, *"My first HUD icon"*, *"My first GDScript fix"*) with a named reviewer. [Unvanquished Contributing](https://wiki.unvanquished.net/wiki/Contributing) |
| **0 A.D.** | Clear discipline separation and fiscal hosting (SPI) once donations scale. | Keep technical lead, asset rights tracking, and finances transparent; adopt a fiscal host only if donations grow beyond basic server costs. [0 A.D. Contributors](https://play0ad.com/about/contributors/) |

### Governance & Decision Authority (Preventing Committee Stagnation)

Lesson from Chapter 2: volunteer FPS/RTS projects stall when nobody can resolve design deadlocks.

* **Project Lead / Design Owner:** Holds final tie-breaking authority on V1.0 scope, art direction, core balance philosophy, and milestone gates. Community feedback shapes every decision, but contentious debates are decided and documented (via short Architecture/Design Decision Records in the repo) rather than looping forever.
* **Agent-Assisted Execution Loop:** The coding agent reads the latest playtest report (plus any `F8` debug zips), fixes failed playtest issues **before** adding new features, and implements the next approved roadmap slice.
* **Zero Single Point of Failure:** At least two trusted community members hold repository admin and server recovery access.

### Sustainable Server Operations

* **Decentralized by Design:** A tiny master server directory lists version, region, and player count. Match servers are lightweight, self-hostable Linux packages/Docker images; **direct IP join always works** even if the master server goes offline.
* **Lean Start:** Launch with one hosted community reference server (covered by a small transparent budget), scale regions only when real player concurrency and recurring community support justify it.

<a id="roadmap"></a>
## 9. Roadmap with Playable Gates

| Milestone | Scope & Deliverables | Acceptance Gate & Conscious Boundary |
|---|---|---|
| **0 · Tech Proof** | Native Godot greybox map, headless Linux server (hosted online), 2 clients, movement, custom raycast vehicle, Commander camera, `F8` debug bundle. | Drive from factory to center and observe from Commander view over the internet on older baseline hardware. Log CPU/GPU split and FPS. Missing the $60\text{ FPS}$ budget despite optimization triggers a tightly scoped Dæmon comparison. |
| **1 · Smallest Complete Match** | 2 teams, 1 spawn per side, Engineer & Rifleman, 1 resource node, Refinery, Vehicle Factory, 1 tank, vulnerable CV, win state & clean round restart. | $4\text{v}4$ (or humans + early fill-bots) complete the entire economy-to-tank-to-victory loop without console commands. Log time to first contact, successful rollouts, and any broken round. |
| **2 · Tactical Depth & Stage-2 Netcode** | Squads, Recon/spotting, Radar, streamlined research choices, directional armor plates, weapon heat/cooling, repair, client-side prediction & lag compensation, modular prop kit pilot. | Two legal tank loadouts visibly change combat outcomes; drivers & Commanders can articulate meaningful strategic trade-offs; Stage-2 netcode feels crisp at $80$–$150\text{ ms}$ RTT. |
| **3 · Public 32-Player Test & V1.0 Core Systems** | Second dense modular map, all 4 classes, squad leader abilities, 4 chassis (Jeep, APC spawn, Med, Heavy) + CV, fill-bots + emergency Bot-Commander, server browser, moderation/vote-eject, Godot Terrain & Modular Mapper Starter Kit. | 32 active clients pass load/network tests at $60+\text{ FPS}$ on baseline older hardware; external hosters run a match from the release package; a non-programmer edits and boots a map in Godot; humans complete a full map rotation. |
| **4 · 64+ Players & V1.0 Polish** | Full spatial relevance & RTS stream optimization, Low/High scalable PBR presets + 3D resolution scaling, 2–3 polished modular maps, full clean-room license audit. | 64 active clients meet server tick ($p99 < 28\text{ ms}$) and client $60+\text{ FPS}$ targets during peak combat (then run an 80-client headroom test). **V1.0 Release** (GitHub/itch.io, optional Steam). |
| **5 · Post-1.0 Expansions** | Conquest & Mission/Escort modes, Light Tank/AFV & Artillery, expanded 5-branch research, built-in VoIP, expanded modding tools, and optional TrenchBroom/FuncGodot bridge for Hammer veterans. | Every addition ships only behind playable test gates without regressing the 64-player performance baseline. |

<a id="workplan"></a>
## 10. Agent-Driven Development to the First Match

**Agents build and package playable slices. The community plays them.** Task breakdown, strictly typed GDScript implementation, greybox map creation, code review, automated tests, bugfixes, and release packaging belong to the agent workflow. "Community testing" means jumping onto the hosted online test server with your normal PC, playing a short objective, pressing `F8` if anything breaks, and dropping a 1-sentence report.

### One Continuous Path, Three Live Online Playtests

Every step extends the same small native Godot test map and dedicated Linux server. The agent advances autonomously within each block and pauses at the three human playtests where real player feel guides the next decision.

| Step | What the Agent Integrates | Release Gate for Next Step |
|---|---|---|
| **A · Join & Diagnostics** | Headless Linux server, two team colors, FPS movement, respawn, Build-ID watermark, and `F8` debug log export on the greybox test map. | Two automated headless clients see each other cleanly before and after reconnect; `F8` generates a valid diagnostic zip. |
| **B · Issue Order** | RTS Commander camera and a 3D team-only waypoint marker visible to players from Step A. | Order reaches teammates cleanly; opposing-team client never receives the private marker. |
| **C · Drive to Order** | One pre-placed custom raycast tank, enter/exit driver seat, factory exit lane, Stage-1 server-authoritative movement with smooth interpolation. | **Playtest 1 (2 players online):** One drops a waypoint, the other finds it without voice callouts and drives there while the Commander watches. Report any unclear UI, input sluggishness, or vehicle jitter (plus `F8` log if broken). |
| **D · Generate Income** | Engineer constructs a Refinery on the marked resource node. | Team balance stays unchanged while unbuilt; once complete, server credits exactly one payout per interval. |
| **E · Build Factory** | Commander places a Vehicle Factory using team funds; Engineer builds it to completion. | Insufficient funds, unbuilt state, and completed construction each produce exact expected balances and states. |
| **F · Buy & Roll Out** | Completed Factory spawns the vehicle from Step C (reusing seats, driving, and waypoint). | Automated tests verify duplicate purchase packets (`request_id`), concurrent buys, and blocked factory exit. **Playtest 2 (2 players online):** Earn resources, build Factory, buy tank, drive to waypoint. Report the very first confusing moment or bug. |
| **G · End Match** | Two playable sides, basic combat rifle/tank cannon, vulnerable CV, victory condition, and clean round restart (plus optional simple test bots). | Both clients see identical winner; post-restart funds, spawns, structures, and vehicles reset cleanly. |
| **H · Package & Ship** | Agent packages Windows/Linux clients, Linux server + one-command start script, checksums, and quick-join guide. | **Playtest 3 (~4v4 online + fill-bots if needed):** Fresh players pick roles themselves and finish a round to restart. Report whether the bought tank meaningfully impacted the fight. |

**1-Sentence Feedback + `F8` Log:** Example: *"Build 12, Test 2: Money deducted, Factory exit empty (attached F8 zip)."* The agent maps the report to the exact commit and event trace, adds a regression test reproducing the bug, fixes it, and ships Build 13 for re-testing before moving on.

### Multi-Agent & Code Quality Discipline

* **One Active Step, One Owner Agent:** One agent owns a vertical slice (UI + server + map changes together when needed to complete the flow). Never let two agents simultaneously modify the same core state or purchase rule.
* **Single Repo Status File (`STATUS.md`):** Tracks active step, latest commit, last human-verified build, open playtest bugs, and next approved step so any new session resumes cleanly.
* **Independent Review Agent:** For shared state, networking, CPU hot loops, and data schemas, a separate review agent inspects the raw diff without the author's rationale, traces the actual execution path by file/symbol, verifies anti-single-core rules, and checks at least one failure path before merge.

| Pre-Merge Check | Concrete Proof Required |
|---|---|
| Clear state ownership? | Diff names the exact entry method, authoritative server rule, and automated test using consistent Godot/game terms. |
| Single source of truth? | Price, balance deduction, and error states live in one server location; UI and network layers only forward intents/results. |
| Zero over-engineering? | No premature generic event buses, deep manager chains, or speculative abstractions without a concrete need in the current step. |
| CPU main-thread safe? | Strict GDScript types used; no per-entity tick sprawl; static colliders and centralized managers respected. |
| Maintainable without original agent? | Clean checkout builds Client & Server via documented commands; zero reliance on private chat history. |

### Copy-Pasteable Kickoff Prompt (Steps A–C)

> Build Steps **A–C** of `docs/PROJECT_VISION.md` in a new, clean-room Git repository (Apache-2.0 code, zero external/proprietary Valve or Empires code or assets).
>
> **Fixed Tech Constraints:**
> * **Engine & Language:** Pin the latest stable **Godot 4.7.x** release, Jolt 3D physics, **strictly typed GDScript** (strict static type warnings enabled), and built-in **ENet** networking.
> * **Map & Visuals:** Build a small, native Godot greybox test map (no external terrain plugins or custom map importers yet) with clear factory exit markings, simple grounded placeholder meshes, and clean scale ($1\text{ unit} = 1\text{ meter}$).
> * **Stage-1 Netcode & Vehicle:** Use **server-authoritative movement with smooth client interpolation** and a **custom simple raycast vehicle** (do NOT build complex client-side physics reconciliation yet). Keep gameplay rules strictly decoupled from UI and networking, and follow the anti-single-core CPU rules (no per-entity tick sprawl).
> * **Diagnostics:** Include a visible Build-ID watermark on screen and an **`F8` debug bundle exporter** (saving Build-ID, FPS/frame-time stats, ping, and the last 200 client/server events).
>
> **Deliverables for Online Playtest 1:**
> * Execute planning, implementation, independent diff review, automated headless 2-client tests, and packaging autonomously.
> * Maintain `STATUS.md` in the repo root.
> * Deliver tested Windows & Linux client zips, a headless Linux dedicated server package with a 1-command start script (ready for a hosted Linux VPS or UDP tunnel so 2 remote players can join without LAN/port-forwarding headaches), Build-ID, quick-join instructions, and the test task: *"Commander places a waypoint; Driver finds it and drives the tank there while both observe the same ride."*
> * **Stop after delivering Playtest 1** and wait for human playtest feedback before starting Steps D–F. If Playtest 1 fails, diagnose from the `F8` log, add a regression test, fix, and re-ship.

The first milestone ends on one clear question that real players answer better than any agent: **Does the driver immediately understand where the Commander wants them to go, and do both experience a smooth, synchronized ride over the internet?**