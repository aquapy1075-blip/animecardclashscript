# Origin Story

Standalone Story UI adapted from anime_origin_ui.lua (upstream blob 543f7f2b12f690f6b6592dcf10d805807fe2c29b), with searchable multi-dropdowns.

## Load

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/codex/origin-story-ui-draft/origin_story.lua"))()
```

Choose Maps and Mob / Boss, then choose independent difficulties for each selected target. Easy is selected initially; deselect it if unwanted. PREVIEW displays the exact queue. START uses the supplied StartEncounter request. Enable the native game's combat AUTO yourself where needed.

Order: story maps, then route encounter order within each map, then Easy / Medium / Hard / Impossible / Cosmic within each target. All selected difficulties of one target run before the next target. Selections are snapshotted at START. Repeat whole queue defaults OFF, so the run stops after one pass.

## Combat detection and retry

Uses the user supplied signal in LocalPlayer.PlayerGui.BattleEyeGui:
- ShowBattle.Visible OR ShowBattle2.Visible true means combat.
- Both false continuously for one second means combat ended.
- Missing either object is unknown, not combat ended; missing UI for 15 seconds stops the run.
- Existing combat must end before any new request.
- Observe visibility concurrently with InvokeServer so a yielding call does not hide combat transitions.
- After requesting an encounter, wait up to 12 seconds for combat.
- If no combat starts and the request has returned, go back one entry in the selected queue, replay it, then try the following entry again. At the first entry, retry that same entry. Wait three seconds before retrying.
- Retries continue until admission succeeds or STOP is pressed. Failed admission can also mean a locked target, cooldown or server refusal; it does not prove the previous battle was lost. The rollback behavior follows the user's requested heuristic.
- Pending requests are never overlapped. Request errors, unresolved start calls, or a battle exceeding 15 minutes stop the run.
- Final entry: stop when combat ends. Visibility alone cannot determine the final win/loss.
- STOP invalidates the worker; the native battle continues. Restart waits for any existing combat to end.

Right Shift or mobile AO toggles the UI. Selections and appearance are session-only. COPY CAPTURE exports bounded local response diagnostics to clipboard, local file if supported, or console; no network upload.

This script does not teleport between maps or bypass server progress locks. If the server requires location changes, travel there using the native game. Repeated start failure will otherwise keep retrying per the configured behavior.

## Validation

Full script syntax compilation and mocked tests passed for all 180 target/difficulty combinations, selected-map filtering, queue ordering, boss markers, either eye indicating combat, stable hidden completion, failed-next rollback, one-pass stop, missing UI, and STOP/restart waiting for existing combat. Live Roblox UI, executor and server integration remain untested.
