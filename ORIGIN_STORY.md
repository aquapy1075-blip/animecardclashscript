# Origin Story

Standalone Roblox Story UI adapted from anime_origin_ui.lua. Uses a dark layered theme, indigo/cyan gradient accents, a Story header card, and searchable multi-select dropdowns. Selected options update in place so selecting after scrolling preserves the popup's position. Search and opening a different dropdown reset scroll intentionally.

## Run

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/codex/origin-story-ui-draft/origin_story.lua"))()
```

Select Maps, Mob / Boss, and independent difficulties for each selected target. Easy is selected initially. PREVIEW shows the queue. Order is map → encounter → difficulty. START snapshots the selections. One pass is the default; native game combat AUTO should be enabled where needed. Right Shift or the mobile AO button toggles visibility.

## Story progression

Combat is ShowBattle.Visible OR ShowBattle2.Visible under LocalPlayer.PlayerGui.BattleEyeGui. Both false continuously for one second ends combat. The next selected difficulty/target is attempted immediately after the transition waits.

If the next target has not entered combat within 20 seconds, retry **that next target** after three seconds. Completed queue entries are not replayed. This supersedes the earlier rollback heuristic because failed admission can also be caused by cooldowns/locks. STOP ends retries.

Missing either GUI object means unknown and stops after 15 seconds. Pending InvokeServer calls are not overlapped. Visibility is observed concurrently while the call yields. Existing combat is allowed to finish before requesting a new encounter. Requests/battles time out conservatively. The final battle's win/loss cannot be established solely from visibility; the queue stops when it ends.

## Config

The Config tab supports profile name, saved-profile dropdown, SAVE, LOAD, DELETE and SET AUTO LOAD. Names allow 1–48 letters/numbers/spaces/underscores/hyphens.

Profiles store selected maps, targets, independent difficulty choices, repeat flag, theme, transparency and window geometry. They use OriginStory/<name>.json and OriginStory/index.json in the executor's file storage. A saved Auto Load profile restores on the next execution, without starting combat automatically. Loading while Story is running or a request is pending is blocked. Config persistence requires executor readfile/writefile/isfile/makefolder APIs; deletion additionally requires delfile. Without them the UI remains usable for the current session.

## Limits and validation

No server unlock bypass or map teleport is added. Use native game travel when required. COPY CAPTURE exports bounded local diagnostics without network upload.

Full file syntax compilation and mock tests passed for queue order/filtering, all 180 target/mode combinations, combat visibility from either eye, advancing to the next selected mode, retrying a blocked next mode without replaying completed modes, missing UI, one-pass stop, stop/restart, profile save/load, restored selections, Auto Load selection, deletion, invalid names and active-run load protection.

Actual Roblox visual appearance, scrolling on the user's device, filesystem APIs and live server integration still need a live-game check.
