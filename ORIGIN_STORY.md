# Origin Story

Standalone Roblox Story UI adapted from anime_origin_ui.lua, with layered dark themes, gradient accents, searchable multi-select dropdowns and Config profiles. Selection updates in place to preserve dropdown scroll. Mob / Boss options are resolved from selected maps each time the dropdown opens: two maps show their 12 encounters, and no maps show an empty dropdown. Hidden-map selections are retained for later but do not enter the run queue or visible selection count. Selected rows use contrasting theme-aware surfaces with a mint tick badge, rather than ASCII checkboxes. Semantic mint/violet/gold/rose accents distinguish controls, and selected-text palettes meet a calculated 4.5:1 contrast ratio for all six themes.

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

Start admission is also confirmed from the captured StartEncounter response tuple: pcall success, server admission true, and a fresh active snapshot with a battleId and matching enemy portrait cardId. This prevents fast fights from being missed by the 1.5-second visual start filter. Admission alone is never treated as victory or completion; occupied UI or a new reward popup must still be observed.

After a confirmed start, combat ends when screen count returns to the baseline or below continuously for 1.5 seconds. Thus a baseline of 0 requires both off, and a baseline of 1 requires at least one off. Brief 0.5–1 second floor-transition flickers reset the timer rather than ending the fight.

Track newly enabled rewards throughout the accepted battle and retain reward evidence that appears just before the eyes hide. After the 1.5-second stable end, wait a full three seconds for BattleRewards. A newly armed enabled reward in or immediately before this end window confirms victory. Existing reward popups from before combat do not count. On win, advance to the next selected mode/boss/map; otherwise retry the same entry. A shared reward popup still cannot attribute rewards to simultaneous fights without a battle-specific result payload.

If combat does not start within 20 seconds, retry the current target without moving backward. Missing combat GUI is unknown and stops after 15 seconds. Missing BattleRewards at result check stops instead of inventing a result. Pending InvokeServer calls are never overlapped; visibility is sampled on Heartbeat while requests yield. STOP invalidates old workers. Final completion requires the last fight's reward confirmation.

## Config

Config supports named SAVE / LOAD / DELETE profiles and SET AUTO LOAD. Names allow 1–48 letters/numbers/spaces/underscores/hyphens. Profiles save selected maps, targets, independent difficulty choices, repeat, theme, transparency and window geometry in OriginStory/<name>.json and OriginStory/index.json in executor storage.

Auto Load restores configuration on next execution without starting combat. Loading during an active run or pending request is blocked. Persistence requires readfile/writefile/isfile/makefolder; deletion needs delfile. Without them the UI works for the current session.

## Validation and limits

No unlock bypass or map teleport is added. Use native map travel where required. COPY CAPTURE exports bounded local diagnostics without uploading them.

Syntax compilation and mocks passed for queue ordering/filtering, all 180 target/mode combinations, profiles, one-screen and zero-screen baselines, 0.8-second Inf transitions, continuous start/end debounce, reward-confirmed advancement, loss retry, stale reward rejection, missing GUI, and final-win completion. Live Roblox visuals, server behavior and executor storage remain untested.

## First-mode repeat fix

The user's capture contains three accepted fresh CompassDemon starts roughly 24.6 seconds apart, with no UI/result records. That interval suggests the start-timeout retry path but does not prove the live UI timing. This revision validates the observed admission tuple, retains early rewards, extends the result check to a full three seconds after stable end, and captures StartRequest / CombatUI / BattleResult transitions for diagnosis. Regression mocks cover fast confirmed fights, rewards before eyes hide, and stale/wrong-target admission rejection. No live-game run has been performed.
