# Balance and server-authority review

Basis: the exported scripts, a few small queries of `studio/hierarchy.json`, and decoded attributes of the snapshot. **No match data exists and nothing here was played in Studio.** Everything under "hypotheses" is a claim to test, not a finding about balance.

## 1. What changed, and what deliberately did not

| Change | Why | File |
|---|---|---|
| Bandage heal is now decided by the server | The server script healed whatever number the client sent (`Health + HealAmount`) and let any player fire any bandage's remote. A tampered client could heal to full instantly, from anywhere, without holding or applying the item. Now: fixed 35, capped at max health, bandage must be in the sender's hands, the use button must have been held about as long as the client's 3.3 s loop. This is the live loot template (`ServerStorage.LootItems.Bandage`), not an archive. | `game/ServerStorage/0154_Script.server.luau` |
| Flare cooldown is reset when a round ends | `readyAt` carried into the next round on the same server. | `game/ServerScriptService/0061_MeetingService.luau` |
| Development-only round telemetry | There is no data to tune from. One JSON line per round (printed, and in `MaskSystem.LastRoundSummary`) in Studio or when `MaskSystem.BalanceLog` is true. Stores nothing, touches no player data, every hook is `pcall`-isolated. | `0058_ReadyQueueCore.luau`, `0059_ReadyQueueServer.server.luau` |

**Balance changes made: none.** `CLAUDE.md` forbids claiming balance from a guessed constant and the repository contains no measured outcomes, so there is no justified tuning change. Section 6 lists the experiments to run, with the existing `MaskSystem` attributes that make each one a one-line, reversible change.

## 2. The real rules (verified from code and snapshot)

- **Killer win:** no live innocent remains and nobody boarded the bus; or the bus leaves with nobody aboard.
- **Survivor-team win:** the bus leaves with at least one passenger; or the last live innocents are gone and at least one boarded. Boarding (`EscapeVanService.board`) is the only individual escape; it removes the player from the round and makes them untargetable.
- **Rewards are by team, not by escape:** every record on the winning team who did not leave gets "Victory" (+100 XP), including survivors who died or never boarded. Anyone who leaves, including after boarding, loses participation and victory XP.
- **Team membership:** `ProgressionService.MarkMonster` marks anyone who ever wears the mask as Monster for the round, even if they were a survivor an hour earlier and die seconds later.
- **Draw:** none exists. A round that fails to start ends with no winner and no XP.
- **Players:** minimum none (one player starts a round); maximum intended 10, now enforced at launch (see `docs/MATCH_LIFECYCLE.md`). The snapshot says `MaxPlayers` 60.
- **Killer selection:** nobody is assigned. A survivor takes the mask (hold 0.6 s) from a random spot outside any safe zone, inside a square of ±260 studs around the origin; it only appears at night, 5 s after the previous holder is released. There is no repeat-selection handling; a player may win the race every round. You decided the location stays random, which also lowers the chance of two players arriving together.
- **Clock:** 24-minute cycle, 60 s per game hour; a round **now starts at 14:00, so the first night (and the first mask) comes 5 minutes in**; it was 08:00 and 11 minutes before the change in `docs/FIRST_NIGHT.md`. Day 13 min, night 11 min. Meetings pause the clock, tasks and the bus timer.
- **Tasks:** 19 (Power list 9, Bus list 10), at most 2 workers each, online **by day only** (also offline in meetings and after the mask appears until dawn). Nine tasks have no prerequisite at the start; the longest prerequisite chain is 6 (1 → 2 → 5 → 11 → 13 → 15). 27 mini-game rounds in total; the server judges every result and enforces a minimum time.
- **Bus:** starts when all 19 are done; waits 300 s, moves once at 180 s.
- **Killer by night:** Mask Strike, range 7 (cone about ±75° of facing), cooldown 1.2 s, instant kill, line of sight required; creature run speed 22 (survivors walk at 16); frozen for 1.8 s after a kill; vents (30 s cooldown, 2 s travel, range 12). **Killer by day** (looks like any camper): sabotage (cooldown 75 s, jams 20 s, range 9, undoes a finished task; 13 of 19 tasks are sabotageable) and pushing a survivor off the two kill spots, the well and the radio tower (cooldown 45 s, range 6.5), and tearing down the tower ladder.
- **Survivors:** no weapon by default. The flare gun starts an emergency meeting (4.9 s cinematic, then 45 s; everyone in the round is frozen and protected; cooldown from firing is 60 s). Sprint (LeftShift, speed 30) exists only in `Workspace.StaminaGui`, which nothing activates, so it should be inactive; confirm in Studio.
- **Safe zones:** `MaskService` honours `MaskSafeZone` tags, but the only two tagged parts in the snapshot are lobby backups in ServerStorage. **The live forest has no safe zone.**
- **Information:** everyone sees task locations on the map. Survivors get a named alert on every sabotage and can look for bodies in the well. Wristband colours identify players; a lit flashlight makes its holder visible. The killer has no tracking tool in the code I read.
- **AI creature:** `CreatureControlMode` is `Player` in the snapshot, so none.

## 3. 1v9 hypotheses (mechanism, how to test)

1. **A killer may not exist for the first stretch of the round** (5 minutes by default now, 11 before the change). The mask only spawns at night. Nine survivors can start nine tasks at once. *If they finish all 19 before the first night, the bus runs mostly unopposed.* Test: `allTasksAt` against `firstNightAt` and `firstMaskWornAt`.
2. **Night is lopsided in the killer's favour on paper:** tasks are offline, the killer is 37% faster with an instant 7-stud kill, there is no safe zone, and survivors' only counterplay is distance, the flare, light discipline and (if drawn) the hatchet. Test: `firstDeathAt` relative to `firstNightAt`, deaths per night minute, survivors alive at dawn.
3. **The flare can chain control of the killer.** A meeting freezes the killer for about 50 s and the next flare is ready 10 s later; survivors must reach the camp stump each time, and the killer can wait near their return positions. Test: `meetings` per round, and the share of round time spent in meetings (about 50 s each).
4. **Sabotage against parallel work:** one sabotage per 75 s against up to 18 simultaneous workers. Test: `halfTasksAt` and `allTasksAt` in rounds where the killer holds the mask by day.
5. **Snowball:** dead players leave the round permanently and the task total does not shrink, so a survivor who is last faces all 19 tasks. I found no revive or rescue mechanic. Test: win rate by deaths before the first night.
6. **No timer:** nobody can win by waiting, but a mask holder who stands still is never replaced (they are not released until they die or leave), which removes the killer role for everyone. Test: playtest with an idle holder; consider an idle release later.
7. **Spawn traps:** the 12 pads are safe in practice (the first possible threat is 5 minutes later, 11 under the original start, and everyone has 11 s of protection). Pad assignment is now by arrival order instead of always by user id.
8. **Coordination:** the only in-game talking is the meeting chat. Parties on outside voice can coordinate; solos cannot. Test: split results by party size.
9. **Mobile and controller:** prompts have gamepad keys; the strike is a tool activation (click, tap, trigger); the flashlight reload is R or D-pad up. Test on a phone and a controller: pick up the mask, strike, sabotage, push, use the flare, reload.

## 4. Player-count edge cases

- **Task count does not scale.** With 2 players the single survivor must complete all 19 tasks against one killer; with 10, nine share them. Win and XP are identical either way.
- **Solo and tiny rounds farm rewards.** A lone player can finish the tasks, or wear the mask and win instantly as Monster, for full victory XP. Whether live lobbies can create such rounds depends on the lobby place, which is not in this repository. Needs a decision (for example no victory XP below a participant count); I did not add one.
- **AFK players** earn participation and, on a winning team, victory XP.
- **Disconnects:** survivors leaving only helps the killer win and costs the leaver all XP; a killer leaving removes the role until the next night. There is no hidden mid-round scaling, and I did not add one. If you want scaling, make it a visible rule set at round start.

## 5. Server authority

Verified server-side: mask pickup and strike (role, holder, round, night, meeting, cooldown, range, cone, line of sight), sabotage, push, ladder, vents, flare, bus boarding, tower carrying, graveyard digging, task mini-games (types, ranges, minimum time), loot pickup (open container and distance), camp hatchet, flashlight reload (owner only), looks (only outside a round), fortune draws (price, session, distance, throttle).

Gaps, in order of importance:
1. **Bandage** — fixed here.
2. **Movement is client-authoritative.** Speed, position and facing come from the owning client; the server does not check them. I did not add a check: gross speed or teleport detection needs a measured tolerance so latency is not punished. A log-only monitor is the safe first step.
3. **Loot** can be taken by anyone, including spectators and the killer. Probably harmless; decide if intended.
4. **Sabotage** has no line-of-sight check (range only).

## 6. Balance table and experiments

| Mechanism | Current value (where) | Purpose | Suspected issue | Experiment |
|---|---|---|---|---|
| First night | 14:00 start, 5 min (`ForestClock.StartHour`; override with `MaskSystem.StartHour`; was 08:00 / 11 min) | Day tasks, night hunt | Too little daylight for the first tasks, or still unopposed | Compare `allTasksAt` with `firstNightAt` across 8, 11 and 14 |
| Strike range / cooldown | 7 / 1.2 s (`MaskSystem.AttackRange`, `.AttackCooldown`) | Kill reach | Reach perks stack on it | Vary only with data |
| Creature speed | 22 vs 16 (`CreatureRunSpeed`) | Chase pressure | No escape without obstacles | Chase length telemetry (not yet captured) |
| Vent | 30 s, 2 s, 12 studs (hard-coded in `VentService`; the `VentCooldown`/`VentDuration` attributes are ignored) | Killer travel | Tuning attributes do nothing | Read them in `VentService` before any experiment |
| Sabotage | 75 s / 20 s jam / 9 studs (`SabotageCooldown`, `SabotageJam`, `SabotageRange`) | Day pressure | Slow versus 9 workers | Halve cooldown for one test block |
| Push | 45 s / 6.5 (`PushCooldown`, `PushRange`) | Day kill | Only 2 spots | Count push kills |
| Task capacity | 2 (`TaskCapacity`) | Parallelism cap | Maybe too high for 9 | Test 1 and 2 |
| Flare | 60 s cooldown, 45 s meeting (`camp` attributes) | Counterplay | Chained control | Count and time meetings |
| Hatchet | 25 damage, 6 studs, 1.1 s (`FortuneRewards`, hard-coded) | Counter-kill | Four hits would kill a killer with the default 100 HP (StarterCharacter health not checked); several carriers could delete the killer | Do not tune without data |
| Reach / jump perks | +1.5 or +3 studs on 7; jump +1.5 or +3 | Cosmetic-ish luck | Combat advantage (below) | See section 7 |

## 7. Paid or luck-based competitive advantages (flagged, not removed)

- **2× Perk Luck pass** doubles the chance of *rare* cards from 20% to 40%. The rare cards are Long Reach II (+3 studs on a 7-stud strike, +43%) and High Ground II (+3 jump height). That is a paid combat advantage, mostly for killers.
- **VIP** gives +30% XP and a name tag: progression only.
- The camp hatchet and the common perks come from Moins, not from purchase.

Fair alternatives that keep what buyers paid for: have the pass improve luck for cosmetic or non-combat cards only; let it grant extra Moins or draws instead of better odds; cap killer reach perks so they cannot exceed the base strike by a fixed share; rebalance the rare cards as sidegrades. Any change should be announced and should keep existing owners' benefit in some form.

## 8. Human playtest plan (rotating roles)

- **Controlled killer:** the mask race is open, so tell exactly one named player they may take it each round (honour system) and rotate who that is. Over 10 rounds with 10 players, each plays killer once and survivor nine times.
- **Settings to hold constant:** one build, same map, same player count per block. Blocks of 6, 8 and 10 players.
- **Record per round** (`LastRoundSummary`): players, winner, duration, `firstNightAt`, `firstMaskWornAt`, `allTasksAt`, `busAt`, `escaped`, `deaths`, `meetings`, `killerDeaths`; plus by hand: who was in a party, who was new, device.
- **Sample size:** with 20 rounds, a 50% win rate has a 95% interval of roughly ±22 points, and 100 rounds gives roughly ±10. Do not call a side balanced from a handful.
- **Proposed pass criteria (my suggestions, not measured):** killer-side win share between 35% and 65% at 8 to 10 players; median round 12 to 25 minutes; tasks finished before the first night in under 20% of rounds; first death not in the first minute of night.
- **Cases to cover on each device:** keyboard, touch, controller.

## 9. Checks

- `python3 -m unittest discover -s tests`: 7 tests (Luau specs for the queue planner, the telemetry state machine and the bandage script; they need a `luau` binary on `PATH` and are otherwise skipped).
- The original bandage script fails 6 of the 7 bandage specs; one run healed to 1,000,000,040 HP.
- `python3 tools/studio_source.py validate`: 4 scripts changed, everything else byte-identical. `luau-compile` accepts each edited script and `luau-analyze` reports nothing new.
- Not run: any gameplay, replication or multi-client behavior. The fake-object bandage test cannot prove real network behavior.
