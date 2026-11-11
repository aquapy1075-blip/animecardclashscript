# Origin Story

Standalone Roblox Story UI adapted from anime_origin_ui.lua, with layered dark themes, gradient accents, searchable multi-select dropdowns and Config profiles. Selection updates in place to preserve dropdown scroll.

## Run

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/codex/origin-story-ui-draft/origin_story.lua"))()
```

Choose Maps, Mob / Boss and independent difficulties per target (Easy is initially selected). PREVIEW shows the ordered queue. Order: map → encounter → difficulty. START snapshots the selections. One pass is default. Enable native game combat AUTO where needed. Right Shift or mobile AO toggles visibility.

## Dual battle combat and results

Uses LocalPlayer.PlayerGui.BattleEyeGui.ShowBattle and ShowBattle2, and LocalPlayer.PlayerGui.BattleRewards.Enabled, as supplied by the user.

Before each request, sample the exact screen state for 1.5 continuous seconds:
- Both off: baseline count 0. Either screen becoming visible continuously for 1.5 seconds starts Story combat.
- One on: baseline count 1 (for example a concurrent Inf fight). Both screens must become visible continuously for 1.5 seconds to start Story combat.
- Both on: wait for an available slot and then a stable baseline.
- Changes during baseline sampling restart the stability timer.

After a confirmed start, combat ends when screen count returns to the baseline or below continuously for 1.5 seconds. Thus a baseline of 0 requires both off, and a baseline of 1 requires at least one off. Brief 0.5–1 second floor-transition flickers reset the timer rather than ending the fight.

Observe BattleRewards for three seconds from the initial end candidate, including the end debounce period. A new enabled transition during that window confirms a win. Existing reward popups from before combat do not count. Rewards shown briefly during the debounce are retained. On win, advance to the following selected mode, boss or map; on no new reward, retry the same target/mode after three seconds. This is the user's UI-based result rule, not a server-result protocol. A shared reward popup cannot distinguish rewards from simultaneous fights without a battle-specific payload.

If combat does not start within 20 seconds, retry the current target without moving backward. Missing combat GUI is unknown and stops after 15 seconds. Missing BattleRewards at result check stops instead of inventing a result. Pending InvokeServer calls are never overlapped; visibility is sampled on Heartbeat while requests yield. STOP invalidates old workers. Final completion requires the last fight's reward confirmation.

## Config

Config supports named SAVE / LOAD / DELETE profiles and SET AUTO LOAD. Names allow 1–48 letters/numbers/spaces/underscores/hyphens. Profiles save selected maps, targets, independent difficulty choices, repeat, theme, transparency and window geometry in OriginStory/<name>.json and OriginStory/index.json in executor storage.

Auto Load restores configuration on next execution without starting combat. Loading during an active run or pending request is blocked. Persistence requires readfile/writefile/isfile/makefolder; deletion needs delfile. Without them the UI works for the current session.

## Validation and limits

No unlock bypass or map teleport is added. Use native map travel where required. COPY CAPTURE exports bounded local diagnostics without uploading them.

Syntax compilation and mocks passed for queue ordering/filtering, all 180 target/mode combinations, profiles, one-screen and zero-screen baselines, 0.8-second Inf transitions, continuous start/end debounce, reward-confirmed advancement, loss retry, stale reward rejection, missing GUI, and final-win completion. Live Roblox visuals, server behavior and executor storage remain untested.
