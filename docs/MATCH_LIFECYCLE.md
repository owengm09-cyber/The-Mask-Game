# Match lifecycle — task 1 findings

Evidence is from the exported sources (`game/ServerScriptService/…`) and a few small queries of `studio/hierarchy.json` and the snapshot. Nothing here was run in Roblox Studio.

## State diagram (as implemented)

```
Lobby ──(players arrive: lobbyArrivals)──► planLaunch ──► Picking (15 s, "Your Camper")
  ▲                                                          │ begin(): InRound, Role=Survivor, spawn pads, 8 s intro
  │                                                          ▼
  │                                                       Playing  (day/night clock restarts at 08:00 on RoundId change)
  │   tasks online only by DAY, offline by night / meeting / after the mask drops until dawn
  │   all 19 tasks done (RescueWon) ─► bus arrives, waits 300 s (moves once at 180 s) ─► leaves
  │   ends when: bus has left (escaped>0 → Innocents, else Monster)
  │              or no live Innocent is left (any escape → Innocents, else Monster)   [no time limit]
  └── endRound: Rescue.End, Progression.Finish, MatchActive=false, Mask.ResetRound, players → lobby spawn,
      then TeleportAsync back to the lobby place (Studio: skipped)
```

Roles: there is **no pre-assigned killer**. Everyone starts as `Survivor`. One survivor becomes `Killer` by taking the cursed mask (`MaskService.TryPickup`; needs `InRound`, no meeting, no current holder). That player is counted as `Monster` in `ProgressionService`. A holder who dies, leaves or has the character removed is released (`Role` back to `Survivor`, `KillerUserId=0`); the mask spawns again after `RespawnDelay` (5 s) but only at night. By day an unclaimed mask can still be picked up (`KillerAbilities` hides a worn mask by day), and at night with no holder `CreatureServer` runs an AI creature in the default `Hybrid` mode. Zero killers, or several in sequence, is possible. There is no minimum player count anywhere.

## Player-count discrepancy (intended: 1 killer + up to 9 survivors = 10)

| Where | Value |
|---|---|
| `ReadyQueueServer` `Expected` clamp | 1–**11** (now 1–10) |
| `Wristbands` | 11 colours, comment says "the 11 players in a match" |
| `Workspace.SpawnPoints` | 12 pads (`Spawn_01…12`) |
| `Players.MaxPlayersInternal` in the snapshot | 60 (the website setting governs the live game) |
| `ReadyQueueCore.step` default cap | 6 — but `Workspace.Lobby.ReadyZones` does not exist, so this zone queue is dead code in this place |

The real queue is `lobbyArrivals` in `ReadyQueueServer`: players arrive from the lobby place with `TeleportData.Expected`; direct joins and Studio tests have `Expected = 1`.

## Fixes in this change (2 of the allowed 3)

1. **Arrival queue stranded players and had no cap** (`ReadyQueueServer` + `ReadyQueueCore.planLaunch/settle`).
   - Before: launching did `lobbyArrivals = {}`, wiping players who were connected but still loading; a 35 s branch wiped everyone if nobody was loaded; players dropped between the camper pick and `begin()` were forgotten. Those players were left in the forest with no round, and nothing ever queued them again. The batch was unbounded, so 13+ queued players made `begin()` fail ("need at least N spawn points") and strand the whole group. A direct joiner started a round alone the instant their character loaded, even if others were mid-load.
   - Now: at most 10 players per round (also bounded by the number of spawn pads); earliest arrivals first; a launch waits up to the existing 12 s window for players who are connected but still loading; only launched players leave the queue; players missed at the camper pick, or whose start was not attempted, are queued again.
2. **Return to lobby had one teleport attempt and no fallback.** Now up to 4 attempts (2 s, 4 s, 8 s backoff); if the lobby still refuses, the group is queued for another round here instead of being left idle. In Studio (no teleport) a finished round queues the group again so a test session can replay.

## Seen but not changed

- The `endRound` save-wait loop never gives up if XP saving keeps failing (players are never returned). Bounding it trades off data safety, so it needs an owner decision.
- No round time limit and no pre-assigned killer: a round with no mask pickup lasts until the tasks and bus are done or everyone is dead. Design decision for task 4.
- The main loop in `ReadyQueueServer` has no `pcall`; one uncaught error in a tick would stop round management. Not reproduced, so left alone.
- Round-start and end-of-round positions both use `Spawn_01` (`RespawnLocation`); `MeetingService.readyAt` (flare cooldown) carries between rounds.

## Checks run in the cloud (automated only)

- `python3 -m unittest discover -s tests`: 6 tests, including the new Luau spec for `planLaunch`/`settle`/`step`. The new test runs only when a `luau` binary is on `PATH` (or `LUAU` is set); otherwise it is skipped. A scratch mutation (removing the player cap) made it fail as expected.
- `python3 tools/studio_source.py validate`: 203 scripts, 2 changed, bytes outside Source preserved. A review place built successfully (not committed).
- `luau-compile` accepts both edited scripts; `luau-analyze` reports no new diagnostics beyond the files' existing style warnings.

Not run: any gameplay, networking, teleport or multi-client behavior. The Luau test covers only the pure planner.

## Studio test plan (multi-client; Test tab → Local Server)

Build with `python3 tools/studio_source.py build build/TheMask-review.rbxlx`. Watch Output and the `Workspace.MaskSystem` attributes (`RoundState`, `MatchActive`, `RoundId`, `KillerUserId`).

1. **Solo** — 1 client: round still starts right after the character loads; Picking 15 s, intro, Playing.
2. **Staggered join** — 4 clients started together: the round includes all four (it waits ≤12 s for slow loaders) and each has `InRound=true`.
3. **Late join** — add a client after launch: it is `InRound=false` and cannot work tasks or take the mask. When the round ends it is included in the next round.
4. **Studio replay** — end a round (everyone dies, or the bus leaves): players return to the lobby spawn and a new Picking starts automatically.
5. **Leave during Picking** — close one client in the 15 s pick: the others still start; close all: state returns to `Lobby`, no errors.
6. **Leave during play** — survivor leaves (count drops); killer leaves or dies (`MaskState` → `Respawning`, mask returns at night, tasks stay offline until dawn); last live survivor dies (Monster win); a survivor boards the bus (Innocents win once the bus leaves or no Innocents remain).
7. **Not testable in Studio**: teleport retry/fallback (needs a published private-server test with the lobby place ID temporarily wrong in a throwaway copy), and the 11–12 player overflow (Studio supports at most 8 clients; the cap is covered only by the isolated Luau test).
