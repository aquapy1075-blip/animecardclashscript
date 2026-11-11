# Origin Story

Standalone Roblox Story UI adapted from anime_origin_ui.lua. Multi-select maps/targets, per-target difficulties, searchable dropdowns preserving scroll, themed selected surfaces/tick badges, multicolor accents and Config profiles.

## Run

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/codex/origin-story-ui-draft/origin_story.lua"))()
```

Select maps, then mob/boss options limited to those maps. Select difficulties independently per target (Easy initially selected). PREVIEW shows map → encounter → difficulty order. START snapshots selections; default is one pass. Native game AUTO should be enabled where needed. Right Shift or mobile AO toggles the UI.

## Verified server combat/results

**ShowBattle, ShowBattle2 and BattleRewards are no longer used.**

The user's passive capture contains simultaneous Tower and Story traffic. For example:
- Tower: BattleEvent type BattleEnd, lane 2, won true, battleId 11042356355-1507268926.
- Story: BattleEvent type BattleEnd, lane 1, won true, difficulty Easy, battleId 11042356355-1512618733.

StartEncounter admission is anchored to its returned tuple: successful pcall, admission true, nil, and a fresh active snapshot containing battleId, lane and the matching enemy portrait cardId. Each request owns its own tracker.

Only a BattleEnd with the admitted battleId is accepted. Lane and difficulty, when present, must also match. A boolean won=true advances to the next selected entry. won=false retries the same entry after three seconds. Other battle IDs, including concurrent Tower floors, are ignored.

The listener is connected before sending requests. Early BattleEnd events are buffered by ID until the admission tuple returns, so short fights are not missed. UI visibility does not affect tracking. STOP invalidates the worker; requests are never overlapped. Unknown admission or a missing matching result stops without inventing victory/loss or repeatedly starting an untracked fight. Admission waits at most 30 seconds; result waits at most 15 minutes. The final matching victory completes a one-pass queue.

COPY CAPTURE exports bounded StartRequest, StartResponse, StoryAdmitted, BattleEnd and BattleResult diagnostics locally. No log upload is performed.

## Config

Config supports SAVE, LOAD, DELETE and SET AUTO LOAD. Profiles include map/target selections, independent difficulties, repeat flag, theme, transparency and window geometry.

Files are OriginStory/<name>.json and OriginStory/index.json in executor storage. Names allow 1–48 letters/numbers/spaces/underscores/hyphens. Persistence requires readfile/writefile/isfile/makefolder; deletion requires delfile. Auto Load restores settings without starting combat. Loading during a running queue or pending request is blocked.

## Validation and limitations

Full script syntax and queue checks passed. Replayed both actual uploaded BattleEnd examples to verify that Tower wins do not advance Story and the matching Story win does. Mock tests cover result-before-admission races, stale IDs, lane/difficulty mismatch, synthetic won=false retries, final-win completion and Stop. The mock has no combat GUI objects, proving that those objects are not required by the new controller.

The provided capture contains wins but no explicit won=false event; false handling is tested synthetically. Live Roblox integration remains untested. This does not change combat decisions, bypass unlocks or teleport between maps; native travel may be needed.
