# First night earlier (mask appears about 5 minutes in)

**What you chose:** bring the first night, and so the first mask, forward. The mask already only appears at night; the change is when the first night arrives.

| | Before | Now |
|---|---|---|
| Round starts at | 08:00 | **14:00** (`ForestClock.StartHour`) |
| First night (mask can appear) | 11 minutes in | **5 minutes in** |
| Daylight left for tasks before it | 11 minutes | 5 minutes |
| Later days and nights | 13 min day, 11 min night | unchanged |

One game hour lasts 60 s, night starts at 19:00, so the first night comes (19 − start hour) minutes in. Meetings pause the clock, so a flare delays dusk by the meeting's length.

## Tuning without a rebuild
Add a number attribute `StartHour` (0 up to, but not including, 24) to `Workspace.MaskSystem` in Studio. Examples: `8` restores the original 11 minutes; `12` gives 7 minutes; `16` gives 3. Anything missing or invalid falls back to 14. It is read at every round start. To change the shipped default, edit `StartHour` at the top of `ForestClock`.

## What else changed
- `ReadyQueueServer` no longer calls `Mask.Spawn()` at round start. That call ran before the clock reset, so on a server that had already played a round and left the clock at night, the mask could appear at second zero. The mask is now spawned only by `MaskService` when the round's own clock reaches night (or within 5 s if a round starts at a night hour).
- The intro caption and HUD clock read the live hour, so they show "2:00 PM — THE FIRST DAY" with no further change.

## Things to watch (not measured)
- **Tasks:** the nine opening tasks and the longest chain of six may not fit in 5 minutes of daylight. Progress is kept overnight, tasks resume at the next dawn (about 16 minutes in), and the bus only starts when all 19 are done. The dev telemetry prints `firstNightAt`, `firstMaskWornAt`, `halfTasksAt`, `allTasksAt`, `busAt` and `winner`; compare the same group on `StartHour` 8, 11 and 14.
- **Killer side:** a shorter first day means the aspiring killer waits less, and survivors face the first night with less done. Judge by the killer-side win share and by how long eliminated players wait, not by feel.
- **Visuals:** the round now opens in afternoon light instead of morning light; check the intro shot in Studio.

## Checks
Luau specs run the real clock functions: by default dusk arrives after 300 s; an 8:00 start still gives 660 s; a 100 s meeting pause moves dusk to 400 s; invalid overrides fall back to 14. Not run in Studio: the intro, lighting at 14:00, mask spawn timing in a real round, task pacing.
