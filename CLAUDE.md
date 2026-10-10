# THE MASK — cloud development

This repository now contains the actual Studio source exported on 2026-10-10, not just the original Rojo starter.

## Product
THE MASK is a Roblox multiplayer horror game. The owner's target is **one killer versus up to nine survivors**, with fun, fair, replayable matches and smooth controls on supported devices. The existing game has a forest campsite, a day/night cycle, a cursed mask, survivor rescue tasks, camp power and a camp bus escape, meetings, killer abilities and vents, progression, cosmetics and a shop. Inspect the code before declaring the exact rules. Existing code/configuration may disagree with the intended ten-player match size; identify the discrepancy rather than silently assuming it is correct.

## Start here
- `game/` contains all 203 exported Script, LocalScript and ModuleScript sources, including archived copies stored in ServerStorage. Number prefixes uniquely identify instances; they are NOT execution order.
- `studio/scripts.json` maps each file to its exact Studio path, class, referent, original hash, Disabled and RunContext properties when serialized. Distinguish active scripts from backups. A ModuleScript in ServerStorage may still be required; trace callers.
- `studio/hierarchy.json` is an instance index. Search it programmatically; do not paste the entire file into context.
- `studio/base.rbxlx.gz` is the native Studio snapshot including terrain, map, GUIs, attributes, assets and all instance properties. The source-only builder preserves every byte outside edited Source elements. Do not read the expanded 366 MB XML into the conversation.
- `src/` and `default.project.json` are the OLD starter. They do not represent the game. Do not use their Rojo serve/build workflow on the real place, and do not spend time improving Hello World.

## Workflow
1. Read the relevant scripts and their manifest paths. Search narrowly; avoid reading archived source indiscriminately.
2. Make small, reviewable changes to existing files under `game/`. Do not rename files, change referents or hashes, edit the base snapshot, add/delete instances, or change game properties through this source-only workflow. Explain when an instance/property edit is required in Studio.
3. Run `python3 -m unittest discover -s tests` and `python3 tools/studio_source.py validate`. Validation checks identity, integrity and source roundtrip; it is NOT a Luau parser, gameplay test or exploit audit. Be explicit about tests you could not run.
4. Build a separate local test place with `python3 tools/studio_source.py build build/TheMask-review.rbxlx`. The output must not exist. Open it in Roblox Studio and use a multi-client test before applying to the live game. Never overwrite a newer Studio place using this snapshot.
5. Deliver a focused branch/PR with exact files, reasoning, checks and required Studio testing. Do not publish Roblox, merge to main, or enable paid services automatically.

## Engineering priorities
Server-authoritative damage, role assignment, rewards, purchases and task completion; validate every client request's type, range, rate, current role and round state. Handle disconnects, deaths, reset/respawn, late joins and round cleanup. Prevent duplicate events, leaked connections and stale delayed callbacks crossing rounds. Preserve map, visual direction and existing content.

Balance means both sides have understandable counterplay and meaningful decisions; it does not mean identical powers. Tune with measured outcomes, role win rates, escape rates, match length, spawn fairness and skill brackets. Do not claim balance from a guessed constant. Prefer enjoyable replayability over manipulative retention, paid combat advantages or punitive daily streaks.

## Credit efficiency
Use one bounded cloud task at a time. First trace the requested system, then fix a small set of verified issues. Avoid whole-game rewrites, repeated broad audits, giant context dumps and speculative dependencies. Stop when the task's acceptance criteria are met, with a concise handoff. Cloud sessions cannot access the user's local Studio MCP connection.
