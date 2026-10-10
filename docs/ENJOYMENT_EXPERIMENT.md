# Enjoyment pass: the eliminated-player dead end

**I could not run the game.** Roblox Studio is not available in the cloud, so every "observed" item below was read from the scripts and the snapshot, not seen while playing. No playtest observations exist yet; the sheet in section 9 is how to get them. Automated checks (section 10) show that code compiles and helper functions behave; they say nothing about whether the game is fun.

## 1. The core loop as it exists

**Survivor.** Goal: finish the 19 tasks (Camp Power 9, Camp Bus 10), then get on the bus within its 5-minute window, without being killed.
Decision: which of the nine available tasks to start with, whom to work next to (two per station), where to be when night falls, whether to loot batteries and bandages, when to risk the flare. Action: walk, hold the prompt, play a 1-3 round mini-game. Feedback: the station lamp, the Escape Plan segments filling, "TASK COMPLETE", a named alert on every sabotage, the day/night banner, "THE HUNT HAS BEGUN". Consequence: progress, or a sabotaged station undoing it, or elimination. Next decision: the "NEXT: task / site" line suggests one.

**Killer.** Goal: no innocent left alive, or the bus leaving empty. Decision: when and where to take the mask (it appears at night in a random place), which station to sabotage by day, where to patrol (task sites are on everyone's map), when to vent. Action: move, strike (click / tap / trigger), sabotage, push at the well or tower. Feedback: the kill animation and a 1.8 s freeze, cooldown, a sabotage alert broadcast to survivors. Consequence: eliminations, tasks undone. Next decision: where the survivors will be.

## 2. Time structure (from the code)

- **First 30 seconds.** Arrival wait (until the group is loaded, at most 12 s), then a forced 15 s camper picker (I found no "ready" button; its help text says "the round starts when the red line runs out"), then an 8 s non-skippable intro that ends in first person. So **23 to 35+ seconds with no control**, before the first real decision. After that the HUD gives a clear first goal: "RESTORE POWER AND FIX THE BUS", the Escape Plan panel, and "NEXT: FIND GENERATOR FUEL / CAMP". I found no general controls tutorial; only per-mini-game hints and the `[R]` flashlight hint.
- **First session.** Day lasts 13 minutes of real time and night 11; the first night starts 11 minutes in. Tasks run by day only. The killer role does not exist until the mask spawns at night.
- **Later sessions.** What changes: group, mask location, loot, mini-game parameters, who wins the mask race, pad assignment. What does not: the map, the same 19 tasks and dependencies, the clock. Practice pays off in mini-game speed, route knowledge, hiding and chasing. Cosmetic picks and XP levels persist; no gameplay unlocks were found. Restarting after a loss is **not** possible until the whole trial ends (see below).

## 3. Findings

**A. Observed in the code or snapshot (not yet seen in play)**
1. **An eliminated player gets a dead end.** The HUD flips to "LOBBY" and "ENTER A READY ZONE • 6 PLAYERS", but this place has no ready zones. The round banner, clock, Escape Plan panel and map all disappear (they are gated on "in the round"). The player respawns after 3 s into the live forest, with no spectator view and no way into another round until this one ends (no timer, so that can be many minutes).
2. **Late joiners see the same stale lobby text.**
3. **Deaths are silent.** Eliminated players drop out of the survivor roster (the "ELIMINATED" row is effectively unreachable) and there is no kill feed, so others learn of a death only from a body or a smaller count.
4. **Forced waiting every session:** the picker and intro cannot be skipped.
5. **No default sprint:** the sprint script sits in `Workspace.StaminaGui` and nothing runs it.
6. The picker and wristband code still assume **11** players, not 10.

**B. Design hypotheses to test**
- A long stretch before any threat exists (11 minutes, no killer) makes the early game low-tension.
- Tasks are offline at night, so survivors have little to decide then except hiding.
- A miss with the strike gives the killer little feedback; survivors cannot tell why a strike failed or succeeded under latency.
- Task mini-games wait for a server round trip on every input, which may feel laggy on slow connections.
- New players may not know the controls (no tutorial found).
- Fixed tasks and a fixed map may feel repetitive after many rounds.

**C. Optional ideas with insufficient evidence**
Spectating, ghost activities, kill feed, killer tracking aids, terror-radius audio, a second map, more mini-games, new perks.

## 4. Largest obstacle

For eliminated players, the **dead end after elimination** (A1, A3) is the largest *evidenced* obstacle: it affects exactly the players who just lost, removes information, agency and a restart, and is the likely moment someone quits instead of wanting "one more round". The largest *hypothesized* obstacle for everyone is the threat-free first 11 minutes (B1). I picked the first because it is certain from the code, cheap to fix safely, and measurable. A playtest may show that the second matters more.

## 5. Three experiments for the dead end

| | Current experience | Change | Why it might help | Possible downside | Evaluation |
|---|---|---|---|---|---|
| **E1 Briefing** (implemented) | "LOBBY / ENTER A READY ZONE", no banner or plan | Honest status text and the round banner and Escape Plan stay visible when out | The player understands what is happening and how it ends; they can still follow the team | Information leak to a party on outside voice (progress is public to survivors anyway); text may crowd the HUD | Interviews, comprehension question, quit count |
| **E2 Spectate** | none | Eliminated players can watch living survivors, never the mask holder, perhaps with a delay | Agency and learning | Ghosting: a spectator can relay positions; camera bugs with first-person lock | Playtest first with E1; see section 7 |
| **E3 Leave early** | wait for the trial to end | A button to return to the lobby and requeue now, with their XP settled | Fast restart | Changes XP and teleport handling (player data); fewer observers | Needs a design decision on XP, section 7 |

## 6. What is implemented (E1)

Display-only. **Off switch:** set `Workspace.MaskSystem` attribute `OutBriefing` to `false` and the original screens return (use this for the comparison version).

- `ReadyQueueServer`: sets player attribute `Eliminated` when a player dies in a round; cleared at round start, round end and join.
- `ForestClock` (shared): `SideRole` and `SideLine` produce the HUD text (24 characters at most, to fit the 175 px label).
- `HUDController`: role label "ELIMINATED" / "ESCAPED" / "LOBBY"; objective line `3 LEFT • PLAN 7/19`, `1 LEFT • BUS IS HERE`, `WAIT FOR THE BUS`, `JOINING NEXT TRIAL`, `TRIAL STARTING`, `WAITING FOR PLAYERS` instead of the ready-zone text.
- `RoundStatusHUD`: the banner and clock stay, with "ELIMINATED" or "ESCAPED" added.
- `ForestRescueHUD` + `CampHUDLayout`: the Escape Plan panel stays for eliminated and escaped players.
- Telemetry (dev only): `eliminatedSeconds`, `eliminatedShare` (share of all player-time spent out), `quitsAfterElimination`, `quitsWhilePlaying`.

**Fairness re-check:** the panel shows task progress, bus state and survivors-left, which survivors already see. It shows no positions and nothing about the mask holder. **Performance:** `HUDController` runs 4 times a second and does the new lookup only for players out of the round; the other additions are a few attribute reads.

## 7. Choices that would change what the game is (not done)

- **Spectating (E2):** (a) none (today), (b) spectate living survivors only, (c) the same with a 20-30 s delay to blunt ghosting. I recommend testing (b) only after E1, because it can leak positions through outside voice.
- **Leave early (E3):** (a) wait (today), (b) return to lobby at once but keep partial XP (needs a rule for the XP now zeroed for leavers), (c) a short side activity for the eliminated. Each changes rewards or role identity: your decision.
- **Pre-night pacing:** a start hour is a constant in `ForestClock`; a one-line change would bring the first night forward, but it also shortens the first day for tasks. Measure first with `allTasksAt` vs `firstNightAt`.

## 8. Evidence for keep, revise or revert

- **Keep E1** if, in the changed version, most eliminated testers can say without prompting that they are out and how the trial ends; no new HUD overlap or Output errors; quits after elimination are not higher than in the original; and testers prefer it.
- **Revise** if comprehension improves but they still describe waiting as boring (then test E2 or E3), or text is clipped on a phone.
- **Revert** (set `OutBriefing=false`) if it adds confusion, errors, or a clear information leak.
With a handful of testers this is qualitative evidence; do not treat counts as statistics.

## 9. Playtest sheet

**Setup.** Same build, 6 to 10 players: at least 2 newcomers who have never seen the game and 2 experienced players. Two blocks with the same group. Version A: `OutBriefing=false`. Version B: default. Alternate the order (group 1 A then B, group 2 B then A). Set `BalanceLog=true` on `MaskSystem` and keep each round's `LastRoundSummary`. Choose one volunteer per round who may take the mask (honour system) and rotate it.

**Give only neutral instructions:** "Play as you like. Think aloud. I cannot answer how-to questions; I will write them down." Do not explain the objective, controls, or the mask.

**Observe and tick (per player):**
- First 30 s: when did they first move? what did they do first? did they find the first task? needed help?
- Failed inputs: strike misses, prompts missed, mini-game restarts, wrong tool or key.
- Idle time: standing still, wandering after elimination, time on the lobby screen.
- Strategy changes between rounds; recovery after a death or a failed task.
- For eliminated players: what did they do for the first 60 seconds; did they leave the game?

**Ask after each round:** What did you think was happening when you got out? How did you know when the trial would end? What felt satisfying, frustrating, unfair, repetitive? Was there a moment you did not understand why something worked or failed? Would you play another round, and why?
**Ask after both versions:** Which did you prefer and why? Did you notice any difference?

**Record:** version, order, player count, device, party or solo, newcomer or experienced, `LastRoundSummary` values, and answers. Keep technical checks (errors, layout) separate from opinions.

## 10. Checks

**Completed (automated):** `python3 -m unittest discover -s tests` (8 tests; the Luau specs run only with a `luau` binary on `PATH`) including the new HUD text spec and telemetry spec; repository validation; `luau-compile` accepts every edited script; `luau-analyze` shows no new problems beyond the files' existing style warnings.
**Not done:** any Studio run: HUD layout and text fit on desktop, phone and controller; the eliminated, escaped and late-join states; the off switch; multi-client behavior; real performance. The fake-object tests prove the helper functions only.
