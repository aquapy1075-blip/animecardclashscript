# Origin Story

Standalone Roblox Story UI adapted from anime_origin_ui.lua. Multi-select maps/targets, per-target difficulties, searchable dropdowns preserving scroll, theme-aware selected surfaces without tick marks, multicolor accents and Config profiles.

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

## Notification and stop diagnostics

Per-fight Starting/WIN/LOSS messages update the live Story Status and Last server result rows only; they are not queued as corner toasts. Start/Stop clear old toasts, hidden toasts are discarded rather than replayed, and pending notifications expire after six seconds. A final completion toast identifies the selected count and last encounter.

COPY CAPTURE now includes current status, last result, running state, current item, index and queue size. QueueStarted records selections, QueueCompleted explicitly records successful exhaustion of the selected queue, and QueueStopped records the reason. Routine unrelated Tower completions are no longer logged repeatedly, preserving space for relevant Story records.

The user's later capture shows nine matching server wins through FirstDemon/Hard, but lacks a completion/stop record. It does not establish a loss or explain any later stop. The prior UI retained and replayed notifications when hidden, which can make old WIN messages appear after combat has stopped. This revision fixes that independently of server result handling. Mock tests assert no per-fight WIN/LOSS toast, clearing on Start/Stop, and completion text containing the queue size. Live-game behavior is still to be checked.

## Gradient text and transparency slider

Bold headings and control labels use a violet → blue → mint text gradient. Dark themes use bright colors and Light uses darker colors for readability; the dark Story hero retains the brighter palette. Body copy and live values stay plain. Text gradients update when switching themes.

Dropdown choices use selected background/text colors only, with no tick badge or ASCII checkbox. Selection still updates in place and preserves scroll.

Settings → Transparency is now a mouse/touch slider from 0 to 65%, with a gradient fill, thumb and numeric percentage. It uses AO_UI_Transparency, preserving existing profile compatibility and the upper limit for readable surfaces. The shared input lifecycle cancels dragging when the window hides. Slider endpoint, midpoint, clamping and zero-width guard checks passed, along with script compilation and server controller regression checks. Roblox rendering and physical input still need a live-game check.

## Auto Skill Tree

The uploaded place contains 16 nodes in ReplicatedStorage.Shared.Config.SkillDefinitions. The new Skill Tree tab lists all nodes, max ranks and prerequisites. Select multiple skills, choose Purchase or PurchaseMax, set a 1–10-second request interval, and START. STOP is separate from Story; UNLOAD stops both. Settings are saved in Config, but Auto Load never starts purchases automatically.

Uses the user's supplied SkillAction:InvokeServer("Purchase" or "PurchaseMax", skillId). Requests are sequential, at least one second apart; errors stop the worker. Server funds, locks and caps still apply. Responses are logged as SkillResponse and SkillResult; request success is not invented from pcall success.

Rank synchronization reads validated numeric profile.skills values from ProfileSync. The skills property is referenced by TitleConfig in the place, but the live ProfileSync envelope has not been captured. A RequestSync event is requested once at START where available. Confirmed ranks let the scheduler skip capped nodes and stop once selected goals are reached. Without a recognized rank snapshot, selected-only mode can still send the supplied purchase requests and reports ranks as unconfirmed.

Optional Auto prerequisites spends coins on dependencies and requires confirmed ranks. It waits without spending if rank data is unavailable. It purchases prerequisites one rank at a time up to their required thresholds; PurchaseMax applies only to explicitly selected nodes. Selected nodes themselves target their definition's maximum rank. Selection is snapshotted at START; restart after changing selected targets.

| Skill ID | Max rank | Requires |
| --- | ---: | --- |
| Awakening | 1 | None |
| LuckBoost | 1000 | Awakening 1 |
| SwiftHands | 1500 | Awakening 1 |
| BorderChance | 100 | Awakening 1 |
| BattleSpeed1 | 1 | Awakening 1 |
| FortuneFlow | 250 | LuckBoost 100 |
| CoinAffinity | 1000 | LuckBoost 50 + SwiftHands 200 |
| RapidDraw | 1000 | SwiftHands 350 |
| BossChance | 100 | BorderChance 25 |
| BattleSpeed2 | 1 | BattleSpeed1 1 |
| Windwalker | 1000 | RapidDraw 400 + CoinAffinity 300 |
| PotionDuration | 100 | BossChance 25 |
| BattleSpeed3 | 1 | BattleSpeed2 1 |
| ElderAscension | 1 | FortuneFlow 100 + Windwalker 400 + PotionDuration 100 |
| BattleSpeed4 | 1 | BattleSpeed3 1 |
| TwinBattle | 1 | BattleSpeed4 1 |

Coin Affinity example: Awakening 1, Luck Boost 50, Swift Hands 200, then Coin Affinity. Windwalker crosses Rapid Draw 400 and Coin Affinity 300. Elder Ascension requires Fortune Flow 100, Windwalker 400 and Potion Duration 100. Battle Speed I–IV lead to Twin Battle.

Checks passed for all 16 definitions, prerequisite thresholds/chains, confirmed caps, unknown-rank spending guard, single-rank prerequisite purchases versus selected PurchaseMax, and Stop/restart worker invalidation. Existing Story server-protocol regression checks still pass. Live SkillAction/SkillResult/ProfileSync integration remains untested; COPY CAPTURE contains skill request/response diagnostics.
